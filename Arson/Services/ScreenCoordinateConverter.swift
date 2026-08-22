import AppKit
import CoreGraphics

struct ScreenDescriptor: Equatable, Sendable {
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let visibleFrame: CGRect
}

@MainActor
struct ScreenCoordinateConverter {
    func screens() -> [ScreenDescriptor] {
        let primaryHeight = NSScreen.screens
            .first(where: { $0.frame.origin == .zero })?
            .frame.height ?? NSScreen.screens.first?.frame.height ?? 0

        return NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return ScreenDescriptor(
                displayID: CGDirectDisplayID(number.uint32Value),
                frame: Self.convert(screen.frame, primaryHeight: primaryHeight),
                visibleFrame: Self.convert(screen.visibleFrame, primaryHeight: primaryHeight)
            )
        }
    }

    func screen(containing windowFrame: CGRect) -> ScreenDescriptor? {
        screens().max { lhs, rhs in
            intersectionArea(lhs.frame, windowFrame) < intersectionArea(rhs.frame, windowFrame)
        }
    }

    static func convert(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}
