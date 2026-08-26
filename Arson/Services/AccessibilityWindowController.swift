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

    var presentsHUD: Bool {
        self != .fullScreenWindow
    }
}

// Accessibility calls into another process are synchronous. A dedicated actor keeps
// them serialized and away from Arson's Main Actor without allowing commands to overlap.
actor AccessibilityWindowController {
    private static let messagingTimeout: Float = 0.25
    private static let enhancedUserInterfaceAttribute = "AXEnhancedUserInterface"

    private let geometry = WindowGeometryEngine()
    private let logger = Logger(subsystem: "de.lukasharzbecker.arson", category: "Accessibility")
    private var operationGeneration: UInt64 = 0

    func frontmostWindowIsFullScreen() async -> Bool {
        let processIdentifier = await MainActor.run { () -> pid_t? in
            guard AXIsProcessTrusted(),
                  let application = NSWorkspace.shared.frontmostApplication,
                  application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
                return nil
            }
            return application.processIdentifier
        }
        guard let processIdentifier else { return false }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, Self.messagingTimeout)
        guard let window = try? copyElement(appElement, attribute: kAXFocusedWindowAttribute) else {
            return false
        }
        AXUIElementSetMessagingTimeout(window, Self.messagingTimeout)
        return (try? copyValue(window, attribute: "AXFullScreen")) ?? false
    }

    func apply(_ preset: Preset) async throws -> ScreenDescriptor {
        operationGeneration &+= 1
        let generation = operationGeneration
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
                screens: ScreenCoordinateConverter().screens(),
                shouldAnimate: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            )
        }
        try checkCancellation(for: generation)

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

        let requestedFrame: CGRect
        do {
            requestedFrame = try geometry.targetFrame(
                for: preset,
                originalFrame: originalFrame,
                visibleFrame: screen.visibleFrame
            )
        } catch {
            throw WindowActionError.invalidPreset
        }

        // A preset may already match the focused window. Base the mutation plan on
        // effective differences so an idempotent action does not force another layout.
        let mutationPlan = WindowMutationStrategy.plan(
            from: originalFrame,
            to: requestedFrame,
            positionMode: preset.position
        )
        let changesSize = mutationPlan.changesSize
        let changesPosition = mutationPlan.changesPosition
        guard changesSize || changesPosition else { return screen }

        if changesSize && !isSettable(window, attribute: kAXSizeAttribute) {
            throw WindowActionError.windowCannotResize
        }
        if changesPosition && !isSettable(window, attribute: kAXPositionAttribute) {
            throw WindowActionError.windowCannotMove
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

            if context.shouldAnimate {
                didChangeFrame = true
                let finalFrame = try await animate(
                    window,
                    from: originalFrame,
                    to: requestedFrame,
                    positionMode: preset.position,
                    changesSize: changesSize,
                    changesPosition: changesPosition,
                    displayID: screen.displayID,
                    generation: generation
                )
                acceptedSize = finalFrame.size
                if changesPosition {
                    positionedForSize = finalFrame.size
                }
            } else {
                for step in WindowMutationStrategy.steps(
                    changesSize: changesSize,
                    changesPosition: changesPosition
                ) {
                    try checkCancellation(for: generation)
                    switch step {
                    case .size:
                        try setSize(window, attribute: kAXSizeAttribute, value: requestedFrame.size)
                        acceptedSize = try copySize(window, attribute: kAXSizeAttribute)
                        didChangeFrame = true
                    case .position:
                        let position = try geometry.targetOrigin(
                            for: preset,
                            originalOrigin: originalPosition,
                            // Use the requested size to make room before retrying the
                            // resize. Some apps otherwise constrain the window against
                            // its old origin, notably for 100% width or height presets.
                            actualSize: requestedFrame.size,
                            visibleFrame: screen.visibleFrame
                        )
                        try setPoint(window, attribute: kAXPositionAttribute, value: position)
                        positionedForSize = requestedFrame.size
                        didChangeFrame = true
                    }
                }
            }

            if changesPosition,
               let positionedForSize,
               !WindowMutationStrategy.sizesAreEquivalent(positionedForSize, acceptedSize) {
                try checkCancellation(for: generation)
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
            // Leave the current interpolated frame in place. A replacement action starts
            // from exactly this visible state instead of jumping back to the old frame.
            throw CancellationError()
        } catch {
            if didChangeFrame, generation == operationGeneration {
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

    private func animate(
        _ window: AXUIElement,
        from originalFrame: CGRect,
        to targetFrame: CGRect,
        positionMode: PositionMode,
        changesSize: Bool,
        changesPosition: Bool,
        displayID: CGDirectDisplayID,
        generation: UInt64
    ) async throws -> CGRect {
        let (ticker, ticks) = try await MainActor.run {
            guard let ticker = DisplayRefreshTicker(displayID: displayID) else {
                throw WindowActionError.screenNotFound
            }
            ticker.start()
            return (ticker, ticker.ticks)
        }

        var startTime: TimeInterval?
        var lastAppliedFrame = originalFrame
        var lastResizeStartedTime: TimeInterval?
        var lastResizeCompletedTime: TimeInterval?

        do {
            for await tickTime in ticks {
                try checkCancellation(for: generation)
                let animationStart = startTime ?? tickTime
                startTime = animationStart
                let linearProgress = min(
                    max((tickTime - animationStart) / WindowFrameAnimation.duration, 0),
                    1
                )
                let progress = WindowFrameAnimation.easeOut(CGFloat(linearProgress))
                let isFinalFrame = linearProgress >= 1

                // Resizing makes the target application synchronously lay out its own
                // content. Driving that work at 60 or 120 Hz can overwhelm complex apps,
                // so resize-and-move frames use a lower display-synchronized cadence.
                // Pure movement remains at the native refresh rate.
                let updateStartedTime = ProcessInfo.processInfo.systemUptime
                guard WindowFrameAnimation.shouldApplyUpdate(
                    at: updateStartedTime,
                    lastStartedAt: lastResizeStartedTime,
                    lastCompletedAt: lastResizeCompletedTime,
                    changesSize: changesSize,
                    isFinalFrame: isFinalFrame
                ) else {
                    continue
                }

                let requestedFrame = WindowFrameAnimation.interpolate(
                    from: originalFrame,
                    to: targetFrame,
                    progress: progress
                )

                var currentOrigin = lastAppliedFrame.origin
                var acceptedSize = lastAppliedFrame.size
                var didApplyUpdate = false

                if changesSize {
                    let positionBeforeResize = changesPosition
                        && WindowFrameAnimation.shouldPositionBeforeResizing(
                            from: lastAppliedFrame.size,
                            to: requestedFrame.size
                        )
                    if positionBeforeResize,
                       !pointsAreEquivalent(currentOrigin, requestedFrame.origin) {
                        try setPoint(
                            window,
                            attribute: kAXPositionAttribute,
                            value: requestedFrame.origin
                        )
                        currentOrigin = requestedFrame.origin
                        didApplyUpdate = true
                    }

                    if isFinalFrame
                        || !WindowMutationStrategy.sizesAreEquivalent(
                            lastAppliedFrame.size,
                            requestedFrame.size
                        ) {
                        try setSize(
                            window,
                            attribute: kAXSizeAttribute,
                            value: requestedFrame.size
                        )
                        didApplyUpdate = true
                        // Intermediate reads are synchronous cross-process calls. The
                        // requested value is sufficient while animating; only the last
                        // frame needs the size actually accepted by the target app.
                        acceptedSize = isFinalFrame
                            ? try copySize(window, attribute: kAXSizeAttribute)
                            : requestedFrame.size
                    }
                }

                let acceptedFrame = WindowFrameAnimation.frame(
                    accepting: acceptedSize,
                    for: requestedFrame,
                    positionMode: positionMode
                )
                if changesPosition,
                   (isFinalFrame || !pointsAreEquivalent(currentOrigin, acceptedFrame.origin)) {
                    try setPoint(
                        window,
                        attribute: kAXPositionAttribute,
                        value: acceptedFrame.origin
                    )
                    didApplyUpdate = true
                }
                lastAppliedFrame = CGRect(
                    origin: changesPosition ? acceptedFrame.origin : originalFrame.origin,
                    size: acceptedSize
                )
                if didApplyUpdate {
                    lastResizeStartedTime = updateStartedTime
                    // AX mutations are synchronous. Measuring from their completion
                    // guarantees the target app at least one frame without more layout.
                    lastResizeCompletedTime = ProcessInfo.processInfo.systemUptime
                }

                if isFinalFrame {
                    break
                }
            }
            try checkCancellation(for: generation)
        } catch {
            await ticker.stop()
            throw error
        }

        await ticker.stop()
        return lastAppliedFrame
    }

    private func checkCancellation(for generation: UInt64) throws {
        try Task.checkCancellation()
        guard generation == operationGeneration else {
            throw CancellationError()
        }
    }

    private func pointsAreEquivalent(
        _ lhs: CGPoint,
        _ rhs: CGPoint,
        tolerance: CGFloat = 0.5
    ) -> Bool {
        abs(lhs.x - rhs.x) <= tolerance
            && abs(lhs.y - rhs.y) <= tolerance
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
    let shouldAnimate: Bool
}
