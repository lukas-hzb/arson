import CoreGraphics

enum WindowMutationStep: Equatable, Sendable {
    case size
    case position
}

struct WindowMutationPlan: Equatable, Sendable {
    let changesSize: Bool
    let changesPosition: Bool
}

struct WindowMutationStrategy: Sendable {
    static func plan(
        from originalFrame: CGRect,
        to requestedFrame: CGRect,
        positionMode: PositionMode,
        tolerance: CGFloat = 0.5
    ) -> WindowMutationPlan {
        let changesSize = !sizesAreEquivalent(
            originalFrame.size,
            requestedFrame.size,
            tolerance: tolerance
        )
        let changesOrigin = abs(originalFrame.minX - requestedFrame.minX) > tolerance
            || abs(originalFrame.minY - requestedFrame.minY) > tolerance

        return WindowMutationPlan(
            changesSize: changesSize,
            // A centered resize may need an origin correction when the target app
            // accepts a constrained size even if the requested origin is unchanged.
            changesPosition: changesOrigin || (changesSize && positionMode == .center)
        )
    }

    // macOS can constrain a size against the window's current display. Repeating the
    // requested size after moving matches the behavior used by mature AX window managers.
    static func steps(
        changesSize: Bool,
        changesPosition: Bool
    ) -> [WindowMutationStep] {
        switch (changesSize, changesPosition) {
        case (true, true):
            return [.size, .position, .size]
        case (true, false):
            return [.size]
        case (false, true):
            return [.position]
        case (false, false):
            return []
        }
    }

    static func sizesAreEquivalent(
        _ lhs: CGSize,
        _ rhs: CGSize,
        tolerance: CGFloat = 0.5
    ) -> Bool {
        abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}
