import CoreGraphics
import Foundation

struct WindowFrameAnimation: Sendable {
    static let duration: TimeInterval = 0.16
    static let queuedDuration: TimeInterval = 0.09
    static let resizeUpdateInterval: TimeInterval = 1.0 / 60.0
    static let resizeRecoveryInterval: TimeInterval = 1.0 / 120.0
    private static let timingTolerance: TimeInterval = 0.000001

    static func easeOut(_ progress: CGFloat) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        let remaining = 1 - clamped
        let squared = remaining * remaining
        return 1 - squared * squared
    }

    static func interpolate(
        from start: CGRect,
        to end: CGRect,
        progress: CGFloat
    ) -> CGRect {
        CGRect(
            x: interpolate(from: start.minX, to: end.minX, progress: progress),
            y: interpolate(from: start.minY, to: end.minY, progress: progress),
            width: interpolate(from: start.width, to: end.width, progress: progress),
            height: interpolate(from: start.height, to: end.height, progress: progress)
        )
    }

    static func frame(
        accepting acceptedSize: CGSize,
        for requestedFrame: CGRect,
        positionMode: PositionMode
    ) -> CGRect {
        let origin: CGPoint
        switch positionMode {
        case .keep, .leftEdge:
            origin = requestedFrame.origin
        case .center:
            origin = CGPoint(
                x: requestedFrame.midX - acceptedSize.width / 2,
                y: requestedFrame.midY - acceptedSize.height / 2
            )
        case .rightEdge:
            origin = CGPoint(
                x: requestedFrame.maxX - acceptedSize.width,
                y: requestedFrame.minY
            )
        }
        return CGRect(origin: origin, size: acceptedSize)
    }

    static func shouldPositionBeforeResizing(
        from currentSize: CGSize,
        to requestedSize: CGSize,
        tolerance: CGFloat = 0.5
    ) -> Bool {
        requestedSize.width > currentSize.width + tolerance
            || requestedSize.height > currentSize.height + tolerance
    }

    static func shouldApplyUpdate(
        at timestamp: TimeInterval,
        lastStartedAt startTimestamp: TimeInterval?,
        lastCompletedAt completionTimestamp: TimeInterval?,
        changesSize: Bool,
        isFinalFrame: Bool
    ) -> Bool {
        guard changesSize, !isFinalFrame else { return true }

        // A timestamp discontinuity should never prevent the animation from advancing.
        if let startTimestamp {
            guard timestamp >= startTimestamp else { return true }
            // Give expensive target apps time to finish laying out before the next resize.
            let updateDuration = completionTimestamp.map { max($0 - startTimestamp, 0) } ?? 0
            let updateInterval = max(resizeUpdateInterval, updateDuration * 2)
            guard timestamp - startTimestamp >= updateInterval - timingTolerance else { return false }
        }
        if let completionTimestamp {
            guard timestamp >= completionTimestamp else { return true }
            guard timestamp - completionTimestamp >= resizeRecoveryInterval - timingTolerance else {
                return false
            }
        }
        return true
    }

    private static func interpolate(
        from start: CGFloat,
        to end: CGFloat,
        progress: CGFloat
    ) -> CGFloat {
        start + (end - start) * progress
    }
}
