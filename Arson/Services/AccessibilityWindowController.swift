import ApplicationServices
import AppKit
import Foundation
import OSLog

enum WindowActionError: LocalizedError, Equatable {
    case permissionRequired
    case noActiveApplication
    case ownWindow
    case noFocusedWindow
    case fullScreenWindow
    case unsupportedWindow
    case windowCannotResize
    case windowCannotMove
    case screenNotFound
    case invalidPreset
    case accessibilityFailure(AXError)

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return String(localized: "error.permissionRequired")
        case .noActiveApplication:
            return String(localized: "error.noActiveApplication")
        case .ownWindow:
            return String(localized: "error.ownWindow")
        case .noFocusedWindow:
            return String(localized: "error.noFocusedWindow")
        case .fullScreenWindow:
            return String(localized: "error.fullScreen")
        case .unsupportedWindow:
            return String(localized: "error.unsupportedWindow")
        case .windowCannotResize:
            return String(localized: "error.cannotResize")
        case .windowCannotMove:
            return String(localized: "error.cannotMove")
        case .screenNotFound:
            return String(localized: "error.screenNotFound")
        case .invalidPreset:
            return String(localized: "error.invalidPreset")
        case .accessibilityFailure:
            return String(localized: "error.accessibilityFailure")
        }
    }
}

@MainActor
final class AccessibilityWindowController {
    private static let animationDuration: TimeInterval = 0.14
    private static let animationFrameDuration = Duration.milliseconds(10)

    private let geometry = WindowGeometryEngine()
    private let converter = ScreenCoordinateConverter()
    private let logger = Logger(subsystem: "de.lukasharzbecker.arson", category: "Accessibility")

    func apply(_ preset: Preset, animated: Bool) async throws -> ScreenDescriptor {
        guard AXIsProcessTrusted() else { throw WindowActionError.permissionRequired }
        guard preset.isValid, preset.hasEffect else { throw WindowActionError.invalidPreset }
        guard let application = NSWorkspace.shared.frontmostApplication else {
            throw WindowActionError.noActiveApplication
        }
        guard application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            throw WindowActionError.ownWindow
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        let window = try copyElement(appElement, attribute: kAXFocusedWindowAttribute)

        if let role: String = try? copyValue(window, attribute: kAXRoleAttribute), role != kAXWindowRole {
            throw WindowActionError.unsupportedWindow
        }
        if let isFullScreen: Bool = try? copyValue(window, attribute: "AXFullScreen"), isFullScreen {
            throw WindowActionError.fullScreenWindow
        }

        let originalPosition = try copyPoint(window, attribute: kAXPositionAttribute)
        let originalSize = try copySize(window, attribute: kAXSizeAttribute)
        let originalFrame = CGRect(origin: originalPosition, size: originalSize)
        guard let screen = converter.screen(containing: originalFrame) else {
            throw WindowActionError.screenNotFound
        }

        let changesSize = preset.width.mode != .unchanged || preset.height.mode != .unchanged
        let changesPosition = preset.position == .center || preset.offsetX != 0 || preset.offsetY != 0
        if changesSize && !isSettable(window, attribute: kAXSizeAttribute) {
            throw WindowActionError.windowCannotResize
        }
        if changesPosition && !isSettable(window, attribute: kAXPositionAttribute) {
            throw WindowActionError.windowCannotMove
        }

        let requestedSize: CGSize
        do {
            requestedSize = try geometry.targetSize(
                for: preset,
                originalSize: originalSize,
                visibleFrame: screen.visibleFrame
            )
        } catch {
            throw WindowActionError.invalidPreset
        }

        var didChangeFrame = false
        do {
            if animated {
                let requestedPosition = try geometry.targetOrigin(
                    for: preset,
                    originalOrigin: originalPosition,
                    actualSize: requestedSize,
                    visibleFrame: screen.visibleFrame
                )
                let startTime = ProcessInfo.processInfo.systemUptime

                while true {
                    try Task.checkCancellation()
                    let elapsed = ProcessInfo.processInfo.systemUptime - startTime
                    let linearProgress = min(CGFloat(elapsed / Self.animationDuration), 1)
                    let progress = WindowAnimationCurve.snap(linearProgress)

                    if changesSize {
                        let intermediateSize = WindowAnimationCurve.interpolate(
                            from: originalSize,
                            to: requestedSize,
                            progress: progress
                        )
                        try setSize(window, attribute: kAXSizeAttribute, value: intermediateSize)
                        didChangeFrame = true
                    }

                    if changesPosition {
                        let intermediatePosition = WindowAnimationCurve.interpolate(
                            from: originalPosition,
                            to: requestedPosition,
                            progress: progress
                        )
                        try setPoint(
                            window,
                            attribute: kAXPositionAttribute,
                            value: intermediatePosition
                        )
                        didChangeFrame = true
                    }

                    if linearProgress >= 1 { break }
                    try await Task.sleep(for: Self.animationFrameDuration)
                }
            } else if changesSize {
                try setSize(window, attribute: kAXSizeAttribute, value: requestedSize)
                didChangeFrame = true
            }

            let actualSize: CGSize = changesSize
                ? try copySize(window, attribute: kAXSizeAttribute)
                : originalSize

            if changesPosition {
                let finalPosition = try geometry.targetOrigin(
                    for: preset,
                    originalOrigin: originalPosition,
                    actualSize: actualSize,
                    visibleFrame: screen.visibleFrame
                )
                try setPoint(window, attribute: kAXPositionAttribute, value: finalPosition)
                didChangeFrame = true
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if didChangeFrame {
                rollback(window, frame: originalFrame)
            }
            throw error
        }

        return screen
    }

    private func copyElement(_ element: AXUIElement, attribute: String) throws -> AXUIElement {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &rawValue)
        guard error == .success else {
            if error == .noValue || error == .attributeUnsupported {
                throw WindowActionError.noFocusedWindow
            }
            throw WindowActionError.accessibilityFailure(error)
        }
        guard let rawValue, CFGetTypeID(rawValue) == AXUIElementGetTypeID() else {
            throw WindowActionError.noFocusedWindow
        }
        return unsafeDowncast(rawValue, to: AXUIElement.self)
    }

    private func copyValue<T>(_ element: AXUIElement, attribute: String) throws -> T {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &rawValue)
        guard error == .success, let value = rawValue as? T else {
            throw WindowActionError.accessibilityFailure(error)
        }
        return value
    }

    private func copyRawAXValue(_ element: AXUIElement, attribute: String) throws -> AXValue {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &rawValue)
        guard error == .success, let rawValue, CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            throw WindowActionError.accessibilityFailure(error)
        }
        return unsafeDowncast(rawValue, to: AXValue.self)
    }

    private func copyPoint(_ element: AXUIElement, attribute: String) throws -> CGPoint {
        let axValue = try copyRawAXValue(element, attribute: attribute)
        guard AXValueGetType(axValue) == .cgPoint else {
            throw WindowActionError.unsupportedWindow
        }
        var output = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &output) else {
            throw WindowActionError.unsupportedWindow
        }
        return output
    }

    private func copySize(_ element: AXUIElement, attribute: String) throws -> CGSize {
        let axValue = try copyRawAXValue(element, attribute: attribute)
        guard AXValueGetType(axValue) == .cgSize else {
            throw WindowActionError.unsupportedWindow
        }
        var output = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &output) else {
            throw WindowActionError.unsupportedWindow
        }
        return output
    }

    private func isSettable(_ element: AXUIElement, attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success && settable.boolValue
    }

    private func setPoint(_ element: AXUIElement, attribute: String, value: CGPoint) throws {
        var mutableValue = value
        guard let axValue = AXValueCreate(.cgPoint, &mutableValue) else {
            throw WindowActionError.unsupportedWindow
        }
        let error = AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
        guard error == .success else {
            throw WindowActionError.accessibilityFailure(error)
        }
    }

    private func setSize(_ element: AXUIElement, attribute: String, value: CGSize) throws {
        var mutableValue = value
        guard let axValue = AXValueCreate(.cgSize, &mutableValue) else {
            throw WindowActionError.unsupportedWindow
        }
        let error = AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
        guard error == .success else {
            throw WindowActionError.accessibilityFailure(error)
        }
    }

    private func rollback(_ window: AXUIElement, frame: CGRect) {
        do {
            try setSize(window, attribute: kAXSizeAttribute, value: frame.size)
            try setPoint(window, attribute: kAXPositionAttribute, value: frame.origin)
        } catch {
            logger.error("Unable to restore a window after a partial operation")
        }
    }
}
