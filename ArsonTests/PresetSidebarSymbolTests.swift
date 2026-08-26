import Testing
@testable import Arson

struct PresetSidebarSymbolTests {
    @Test func seedPresetsUseDistinctSemanticSymbols() {
        let symbols = Preset.seedPresets().map(PresetSidebarSymbol.name(for:))

        #expect(symbols == [
            "aspectratio",
            "rectangle.lefthalf.filled",
            "rectangle.righthalf.filled",
            "arrow.down.right"
        ])
    }

    @Test func singleDimensionChangesShowTheirAxis() {
        let widthOnly = Preset(name: "Width", width: .points(400))
        let heightOnly = Preset(name: "Height", height: .percent(70))

        #expect(PresetSidebarSymbol.name(for: widthOnly) == "arrow.left.and.right")
        #expect(PresetSidebarSymbol.name(for: heightOnly) == "arrow.up.and.down")
    }

    @Test func mixedDimensionUnitsUseTwoAxisResizeSymbol() {
        let preset = Preset(
            name: "Mixed",
            width: .points(400),
            height: .percent(70)
        )

        #expect(
            PresetSidebarSymbol.name(for: preset)
                == "arrow.up.and.down.and.arrow.left.and.right"
        )
    }

    @Test func centerOnlyUsesTargetSymbol() {
        let preset = Preset(name: "Center", position: .center)

        #expect(PresetSidebarSymbol.name(for: preset) == "scope")
    }

    @Test func edgePositionsUseTheirAlignedSide() {
        let left = Preset(
            name: "Left",
            width: .percent(50),
            height: .percent(100),
            position: .leftEdge
        )
        let right = Preset(
            name: "Right",
            width: .percent(50),
            height: .percent(100),
            position: .rightEdge
        )

        #expect(PresetSidebarSymbol.name(for: left) == "rectangle.lefthalf.filled")
        #expect(PresetSidebarSymbol.name(for: right) == "rectangle.righthalf.filled")
    }

    @Test func offsetsUseTheirVisualDirection() {
        let upLeft = Preset(name: "Up left", offsetX: -20, offsetY: -30)
        let right = Preset(name: "Right", offsetX: 20)
        let down = Preset(name: "Down", offsetY: 30)

        #expect(PresetSidebarSymbol.name(for: upLeft) == "arrow.up.left")
        #expect(PresetSidebarSymbol.name(for: right) == "arrow.right")
        #expect(PresetSidebarSymbol.name(for: down) == "arrow.down")
    }

    @Test func resizingTakesPriorityOverAnAdditionalOffset() {
        let preset = Preset(
            name: "Resize and move",
            width: .percent(90),
            height: .percent(70),
            offsetX: 60,
            offsetY: 60
        )

        #expect(PresetSidebarSymbol.name(for: preset) == "aspectratio")
    }
}
