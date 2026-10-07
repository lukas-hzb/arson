import AppKit
import CoreGraphics
import QuartzCore

struct DisplayRefreshTick: Sendable {
    let timestamp: TimeInterval
    let callbackTime: TimeInterval
}

@MainActor
final class DisplayRefreshTicker: NSObject {
    let ticks: AsyncStream<DisplayRefreshTick>

    private let continuation: AsyncStream<DisplayRefreshTick>.Continuation
    private var displayLink: CADisplayLink?
    private var isStopped = false

    init?(displayID: CGDirectDisplayID) {
        guard let screen = NSScreen.screens.first(where: { screen in
            guard let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber else {
                return false
            }
            return CGDirectDisplayID(number.uint32Value) == displayID
        }) else {
            return nil
        }

        let pair = AsyncStream.makeStream(
            of: DisplayRefreshTick.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        ticks = pair.stream
        continuation = pair.continuation
        super.init()

        displayLink = screen.displayLink(
            target: self,
            selector: #selector(displayLinkDidFire(_:))
        )
    }

    func start() {
        guard !isStopped, let displayLink else { return }
        displayLink.add(to: .main, forMode: .common)
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        displayLink?.invalidate()
        displayLink = nil
        continuation.finish()
    }

    @objc private func displayLinkDidFire(_ displayLink: CADisplayLink) {
        let tick = DisplayRefreshTick(
            timestamp: displayLink.timestamp,
            callbackTime: WindowAnimationDiagnostics.isEnabled ? CACurrentMediaTime() : 0
        )
        WindowAnimationDiagnostics.displayTick(
            timestamp: displayLink.timestamp,
            targetTimestamp: displayLink.targetTimestamp
        )
        if case .dropped = continuation.yield(tick) {
            WindowAnimationDiagnostics.tickReplaced()
        }
    }
}
