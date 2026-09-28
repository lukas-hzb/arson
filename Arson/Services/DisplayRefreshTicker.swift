import AppKit
import CoreGraphics
import QuartzCore

@MainActor
final class DisplayRefreshTicker: NSObject {
    struct Tick: Sendable {
        let timestamp: TimeInterval
        let frameInterval: TimeInterval
    }

    let ticks: AsyncStream<Tick>

    private let continuation: AsyncStream<Tick>.Continuation
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
            of: Tick.self,
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
        continuation.yield(Tick(
            timestamp: displayLink.timestamp,
            frameInterval: max(displayLink.targetTimestamp - displayLink.timestamp, 0)
        ))
    }
}
