import CoreGraphics
import Testing
@testable import Arson

struct WindowGeometryEngineTests {
    private let engine = WindowGeometryEngine()
    private let visible = CGRect(x: 0, y: 24, width: 1_440, height: 876)
    private let original = CGRect(x: 100, y: 120, width: 700, height: 500)

    @Test func fixedSizeCentersWindow() throws {
        let preset = Preset(
            name: "Fixed",
            width: .points(400),
            height: .points(600),
            position: .center
        )

        let result = try engine.targetFrame(for: preset, originalFrame: original, visibleFrame: visible)

        #expect(result.size == CGSize(width: 400, height: 600))
        #expect(result.origin == CGPoint(x: 520, y: 162))
    }

    @Test func percentageUsesVisibleArea() throws {
        let preset = Preset(
            name: "Percent",
            width: .percent(90),
            height: .percent(70),
            position: .center
        )

        let result = try engine.targetFrame(for: preset, originalFrame: original, visibleFrame: visible)

        #expect(result.width == 1_296)
        #expect(abs(result.height - 613.2) < 0.001)
        #expect(abs(result.midX - visible.midX) < 0.001)
        #expect(abs(result.midY - visible.midY) < 0.001)
    }

    @Test func dimensionsAreIndependent() throws {
        let preset = Preset(name: "Width only", width: .points(900))
        let size = try engine.targetSize(
            for: preset,
            originalSize: original.size,
            visibleFrame: visible
        )

        #expect(size == CGSize(width: 900, height: 500))
    }

    @Test func pointValuesClampToVisibleArea() throws {
        let preset = Preset(
            name: "Clamp",
            width: .points(2_000),
            height: .points(2_000)
        )

        let size = try engine.targetSize(
            for: preset,
            originalSize: original.size,
            visibleFrame: visible
        )

        #expect(size == visible.size)
    }

    @Test func keepPositionAddsOffsetWithoutClamping() throws {
        let preset = Preset(name: "Move", offsetX: 2_000, offsetY: -60)
        let result = try engine.targetFrame(for: preset, originalFrame: original, visibleFrame: visible)

        #expect(result.origin == CGPoint(x: 2_100, y: 60))
        #expect(result.size == original.size)
    }

    @Test func centeredOffsetIsAppliedLast() throws {
        let preset = Preset(
            name: "Centered offset",
            width: .points(400),
            height: .points(300),
            position: .center,
            offsetX: 60,
            offsetY: 60
        )

        let result = try engine.targetFrame(for: preset, originalFrame: original, visibleFrame: visible)

        #expect(result.origin == CGPoint(x: 580, y: 372))
    }

    @Test func rejectsInvalidPercent() {
        let preset = Preset(name: "Invalid", width: .percent(101))
        #expect(throws: GeometryError.invalidWidth) {
            try engine.targetSize(for: preset, originalSize: original.size, visibleFrame: visible)
        }
    }
}

