import AppKit
import CoreGraphics
import QuartzCore

@MainActor
final class DisplayRefreshTicker: NSObject {
    let ticks: AsyncStream<TimeInterval>

    private let continuation: AsyncStream<TimeInterval>.Continuation
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
            of: TimeInterval.self,
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
        continuation.yield(displayLink.timestamp)
    }
}
