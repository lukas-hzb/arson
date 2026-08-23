import CoreGraphics
import Foundation

struct WindowFrameAnimation: Sendable {
    static let duration: TimeInterval = 0.30

    static func easeOut(_ progress: CGFloat) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        return 1 - pow(1 - clamped, 3)
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
        case .keep:
            origin = requestedFrame.origin
        case .center:
            origin = CGPoint(
                x: requestedFrame.midX - acceptedSize.width / 2,
                y: requestedFrame.midY - acceptedSize.height / 2
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

    private static func interpolate(
        from start: CGFloat,
        to end: CGFloat,
        progress: CGFloat
    ) -> CGFloat {
        start + (end - start) * progress
    }
}
