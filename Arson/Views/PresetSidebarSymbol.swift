import Foundation

enum PresetSidebarSymbol {
    static func name(for preset: Preset) -> String {
        let changesWidth = preset.width.mode != .unchanged
        let changesHeight = preset.height.mode != .unchanged

        switch (changesWidth, changesHeight) {
        case (true, false):
            return "arrow.left.and.right"
        case (false, true):
            return "arrow.up.and.down"
        case (true, true):
            return sizeSymbol(width: preset.width.mode, height: preset.height.mode)
        case (false, false):
            return positionSymbol(for: preset)
        }
    }

    private static func sizeSymbol(width: DimensionMode, height: DimensionMode) -> String {
        if width == .percent && height == .percent {
            return "aspectratio"
        }
        if width == .points && height == .points {
            return "square.resize"
        }
        return "arrow.up.and.down.and.arrow.left.and.right"
    }

    private static func positionSymbol(for preset: Preset) -> String {
        let horizontalDirection = direction(of: preset.offsetX)
        let verticalDirection = direction(of: preset.offsetY)

        if horizontalDirection == 0 && verticalDirection == 0 {
            return preset.position == .center ? "scope" : "rectangle.on.rectangle"
        }

        switch (horizontalDirection, verticalDirection) {
        case (-1, -1): return "arrow.up.left"
        case (0, -1): return "arrow.up"
        case (1, -1): return "arrow.up.right"
        case (-1, 0): return "arrow.left"
        case (1, 0): return "arrow.right"
        case (-1, 1): return "arrow.down.left"
        case (0, 1): return "arrow.down"
        case (1, 1): return "arrow.down.right"
        default: return "rectangle.on.rectangle"
        }
    }

    private static func direction(of value: Double) -> Int {
        if value < 0 { return -1 }
        if value > 0 { return 1 }
        return 0
    }
}
