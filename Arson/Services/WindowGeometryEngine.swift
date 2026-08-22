import CoreGraphics
import Foundation

enum GeometryError: Error, Equatable {
    case invalidWidth
    case invalidHeight
    case invalidOffset
}

struct WindowGeometryEngine: Sendable {
    func targetSize(
        for preset: Preset,
        originalSize: CGSize,
        visibleFrame: CGRect
    ) throws -> CGSize {
        let width = try resolve(
            preset.width,
            original: originalSize.width,
            available: visibleFrame.width,
            error: .invalidWidth
        )
        let height = try resolve(
            preset.height,
            original: originalSize.height,
            available: visibleFrame.height,
            error: .invalidHeight
        )
        return CGSize(width: width, height: height)
    }

    func targetOrigin(
        for preset: Preset,
        originalOrigin: CGPoint,
        actualSize: CGSize,
        visibleFrame: CGRect
    ) throws -> CGPoint {
        guard preset.offsetX.isFinite, preset.offsetY.isFinite else {
            throw GeometryError.invalidOffset
        }

        let base: CGPoint
        switch preset.position {
        case .keep:
            base = originalOrigin
        case .center:
            base = CGPoint(
                x: visibleFrame.midX - actualSize.width / 2,
                y: visibleFrame.midY - actualSize.height / 2
            )
        }

        return CGPoint(x: base.x + preset.offsetX, y: base.y + preset.offsetY)
    }

    func targetFrame(
        for preset: Preset,
        originalFrame: CGRect,
        visibleFrame: CGRect
    ) throws -> CGRect {
        let size = try targetSize(
            for: preset,
            originalSize: originalFrame.size,
            visibleFrame: visibleFrame
        )
        let origin = try targetOrigin(
            for: preset,
            originalOrigin: originalFrame.origin,
            actualSize: size,
            visibleFrame: visibleFrame
        )
        return CGRect(origin: origin, size: size)
    }

    private func resolve(
        _ rule: DimensionRule,
        original: CGFloat,
        available: CGFloat,
        error: GeometryError
    ) throws -> CGFloat {
        guard rule.isValid else { throw error }

        switch rule.mode {
        case .unchanged:
            return original
        case .points:
            return min(CGFloat(rule.value), available)
        case .percent:
            return available * CGFloat(rule.value / 100)
        }
    }
}

