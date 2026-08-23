import CoreGraphics

struct WindowAnimationCurve: Sendable {
    static func easeInOut(_ progress: CGFloat) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    static func interpolate(from start: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: interpolate(from: start.x, to: end.x, progress: progress),
            y: interpolate(from: start.y, to: end.y, progress: progress)
        )
    }

    static func interpolate(from start: CGSize, to end: CGSize, progress: CGFloat) -> CGSize {
        CGSize(
            width: interpolate(from: start.width, to: end.width, progress: progress),
            height: interpolate(from: start.height, to: end.height, progress: progress)
        )
    }

    private static func interpolate(from start: CGFloat, to end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }
}
