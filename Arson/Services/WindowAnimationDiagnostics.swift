import Foundation
import OSLog

/// Opt-in, local timing data only. AX completion is not a presentation timestamp.
enum WindowAnimationDiagnostics {
    static let isEnabled = ProcessInfo.processInfo.environment["ARSON_ANIMATION_DIAGNOSTICS"] == "1"
    private static let signposter = OSSignposter(
        subsystem: "de.lukasharzbecker.arson",
        category: "WindowAnimation"
    )

    struct Interval: Sendable {
        fileprivate let state: OSSignpostIntervalState
    }

    static func begin(_ name: StaticString) -> Interval? {
        guard isEnabled else { return nil }
        return Interval(state: signposter.beginInterval(name, id: signposter.makeSignpostID()))
    }

    static func end(_ name: StaticString, _ interval: Interval?) {
        guard let interval else { return }
        signposter.endInterval(name, interval.state)
    }

    static func measureAX<T>(_ name: StaticString, _ operation: () throws -> T) rethrows -> T {
        let interval = begin(name)
        defer { end(name, interval) }
        return try operation()
    }

    static func displayTick(timestamp: TimeInterval, targetTimestamp: TimeInterval) {
        guard isEnabled else { return }
        signposter.emitEvent(
            "DisplayTick",
            "timestamp=\(timestamp) target=\(targetTimestamp)"
        )
    }

    static func tickReplaced() {
        guard isEnabled else { return }
        signposter.emitEvent("BufferedTickReplaced")
    }

    static func processedTick(
        timestamp: TimeInterval,
        callbackTime: TimeInterval,
        processedAt: TimeInterval,
        skipped: Bool
    ) {
        guard isEnabled else { return }
        signposter.emitEvent(
            "ProcessedTick",
            "timestamp=\(timestamp) callback=\(callbackTime) processed=\(processedAt) throttled=\(skipped)"
        )
    }

    static func animation(changesSize: Bool, changesPosition: Bool, duration: TimeInterval) {
        guard isEnabled else { return }
        signposter.emitEvent(
            "AnimationConfiguration",
            "resize=\(changesSize) move=\(changesPosition) duration=\(duration)"
        )
    }

    static func outcome(_ outcome: StaticString) {
        guard isEnabled else { return }
        signposter.emitEvent(outcome)
    }
}
