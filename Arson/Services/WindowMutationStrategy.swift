import CoreGraphics

enum WindowMutationStep: Equatable, Sendable {
    case size
    case position
}

struct WindowMutationStrategy: Sendable {
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
