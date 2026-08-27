import AppKit
import Testing
@testable import Arson

struct MenuBarIconStyleTests {
    @Test func stylesHaveStablePersistenceValues() {
        #expect(MenuBarIconStyle.allCases == [.windows, .flame, .appWindow])
        #expect(MenuBarIconStyle.defaultStyle == .flame)
        #expect(MenuBarIconStyle(rawValue: "windows") == .windows)
        #expect(MenuBarIconStyle(rawValue: "flame") == .flame)
        #expect(MenuBarIconStyle(rawValue: "appWindow") == .appWindow)
    }

    @MainActor
    @Test func suppliedFlameLoadsAsATemplateVectorAsset() throws {
        let image = try #require(NSImage(named: "MenuBarFlame"))

        #expect(image.isTemplate)
        #expect(image.size == NSSize(width: 18, height: 18))
    }
}
