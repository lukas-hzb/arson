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

// Accessibility calls into another process are synchronous. A dedicated actor keeps
// them serialized and away from Arson's Main Actor without allowing commands to overlap.
actor AccessibilityWindowController {
    private static let messagingTimeout: Float = 0.25
    private static let enhancedUserInterfaceAttribute = "AXEnhancedUserInterface"

    private let geometry = WindowGeometryEngine()
    private let logger = Logger(subsystem: "de.lukasharzbecker.arson", category: "Accessibility")

    func apply(_ preset: Preset) async throws -> ScreenDescriptor {
        let context = try await MainActor.run {
            guard AXIsProcessTrusted() else { throw WindowActionError.permissionRequired }
            guard preset.isValid, preset.hasEffect else { throw WindowActionError.invalidPreset }
            guard let application = NSWorkspace.shared.frontmostApplication else {
                throw WindowActionError.noActiveApplication
            }
            guard application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
                throw WindowActionError.ownWindow
            }
            return WindowActionContext(
                processIdentifier: application.processIdentifier,
                screens: ScreenCoordinateConverter().screens()
            )
        }
        try Task.checkCancellation()

        let appElement = AXUIElementCreateApplication(context.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, Self.messagingTimeout)
        let window = try copyElement(appElement, attribute: kAXFocusedWindowAttribute)
        AXUIElementSetMessagingTimeout(window, Self.messagingTimeout)

        if let role: String = try? copyValue(window, attribute: kAXRoleAttribute), role != kAXWindowRole {
            throw WindowActionError.unsupportedWindow
        }
        if let isFullScreen: Bool = try? copyValue(window, attribute: "AXFullScreen"), isFullScreen {
            throw WindowActionError.fullScreenWindow
        }

        let originalFrame = try copyFrame(window)
        let originalPosition = originalFrame.origin
        let originalSize = originalFrame.size
        guard let screen = ScreenCoordinateConverter.screen(
            containing: originalFrame,
            in: context.screens
        ) else {
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

        let disabledEnhancedUserInterface = disableEnhancedUserInterfaceIfNeeded(appElement)
        defer {
            if disabledEnhancedUserInterface {
                restoreEnhancedUserInterface(appElement)
            }
        }

        var didChangeFrame = false
        do {
            var acceptedSize = originalSize
            var positionedForSize: CGSize?

            for step in WindowMutationStrategy.steps(
                changesSize: changesSize,
                changesPosition: changesPosition
            ) {
                try Task.checkCancellation()
                switch step {
                case .size:
                    try setSize(window, attribute: kAXSizeAttribute, value: requestedSize)
                    acceptedSize = try copySize(window, attribute: kAXSizeAttribute)
                    didChangeFrame = true
                case .position:
                    let position = try geometry.targetOrigin(
                        for: preset,
                        originalOrigin: originalPosition,
                        actualSize: acceptedSize,
                        visibleFrame: screen.visibleFrame
                    )
                    try setPoint(window, attribute: kAXPositionAttribute, value: position)
                    positionedForSize = acceptedSize
                    didChangeFrame = true
                }
            }

            if changesPosition,
               let positionedForSize,
               !WindowMutationStrategy.sizesAreEquivalent(positionedForSize, acceptedSize) {
                try Task.checkCancellation()
                let correctedPosition = try geometry.targetOrigin(
                    for: preset,
                    originalOrigin: originalPosition,
                    actualSize: acceptedSize,
                    visibleFrame: screen.visibleFrame
                )
                try setPoint(window, attribute: kAXPositionAttribute, value: correctedPosition)
            }

            if changesPosition && changesSize {
                _ = try copyFrame(window)
            } else if changesPosition {
                _ = try copyPoint(window, attribute: kAXPositionAttribute)
            } else if changesSize {
                _ = try copySize(window, attribute: kAXSizeAttribute)
            }
        } catch is CancellationError {
            if didChangeFrame {
                rollback(
                    window,
                    frame: originalFrame,
                    restoreSize: changesSize,
                    restorePosition: changesPosition
                )
            }
            throw CancellationError()
        } catch {
            if didChangeFrame {
                rollback(
                    window,
                    frame: originalFrame,
                    restoreSize: changesSize,
                    restorePosition: changesPosition
                )
            }
            throw error
        }

        return screen
    }

    private func disableEnhancedUserInterfaceIfNeeded(_ application: AXUIElement) -> Bool {
        // This compatibility attribute is not available as a public SDK constant. Treat
        // it as best-effort and restore the target application's original state afterward.
        guard let wasEnabled: Bool = try? copyValue(
            application,
            attribute: Self.enhancedUserInterfaceAttribute
        ), wasEnabled else {
            return false
        }

        let error = setBoolean(
            application,
            attribute: Self.enhancedUserInterfaceAttribute,
            value: false
        )
        if error == .success {
            logger.debug("Temporarily disabled enhanced accessibility resizing")
            return true
        }
        return false
    }

    private func restoreEnhancedUserInterface(_ application: AXUIElement) {
        let error = setBoolean(
            application,
            attribute: Self.enhancedUserInterfaceAttribute,
            value: true
        )
        if error != .success {
            logger.debug("Unable to restore enhanced accessibility resizing")
        }
    }

    private func setBoolean(
        _ element: AXUIElement,
        attribute: String,
        value: Bool
    ) -> AXError {
        AXUIElementSetAttributeValue(
            element,
            attribute as CFString,
            value ? kCFBooleanTrue : kCFBooleanFalse
        )
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

    private func copyFrame(_ element: AXUIElement) throws -> CGRect {
        let attributes = [kAXPositionAttribute, kAXSizeAttribute] as CFArray
        var rawValues: CFArray?
        let error = AXUIElementCopyMultipleAttributeValues(
            element,
            attributes,
            [],
            &rawValues
        )
        guard error == .success,
              let values = rawValues as? [AXValue],
              values.count == 2 else {
            if error == .attributeUnsupported || error == .notImplemented {
                return CGRect(
                    origin: try copyPoint(element, attribute: kAXPositionAttribute),
                    size: try copySize(element, attribute: kAXSizeAttribute)
                )
            }
            throw WindowActionError.accessibilityFailure(error)
        }
        return CGRect(
            origin: try point(from: values[0]),
            size: try size(from: values[1])
        )
    }

    private func copyPoint(_ element: AXUIElement, attribute: String) throws -> CGPoint {
        try point(from: copyRawAXValue(element, attribute: attribute))
    }

    private func point(from axValue: AXValue) throws -> CGPoint {
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
        try size(from: copyRawAXValue(element, attribute: attribute))
    }

    private func size(from axValue: AXValue) throws -> CGSize {
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

    private func rollback(
        _ window: AXUIElement,
        frame: CGRect,
        restoreSize: Bool,
        restorePosition: Bool
    ) {
        do {
            if restoreSize {
                try setSize(window, attribute: kAXSizeAttribute, value: frame.size)
            }
            if restorePosition {
                try setPoint(window, attribute: kAXPositionAttribute, value: frame.origin)
            }
            if restoreSize && restorePosition {
                try setSize(window, attribute: kAXSizeAttribute, value: frame.size)
            }
        } catch {
            logger.error("Unable to restore a window after a partial operation")
        }
    }
}

private struct WindowActionContext: Sendable {
    let processIdentifier: pid_t
    let screens: [ScreenDescriptor]
}
