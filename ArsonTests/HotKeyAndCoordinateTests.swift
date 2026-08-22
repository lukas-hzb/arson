import Carbon
import CoreGraphics
import Testing
@testable import Arson

@MainActor
struct HotKeyAndCoordinateTests {
    @Test func shortcutRequiresPrimaryModifier() {
        let shortcut = HotKeyShortcut(
            keyCode: UInt32(kVK_ANSI_A),
            modifiers: .shift,
            keyLabel: "A"
        )
        #expect(GlobalHotKeyManager.validate(shortcut) == .missingPrimaryModifier)
    }

    @Test func standardMacShortcutIsReserved() {
        let shortcut = HotKeyShortcut(
            keyCode: UInt32(kVK_ANSI_Q),
            modifiers: .command,
            keyLabel: "Q"
        )
        #expect(GlobalHotKeyManager.validate(shortcut) == .reservedShortcut)
    }

    @Test func customShortcutIsValid() {
        let shortcut = HotKeyShortcut(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: [.command, .option],
            keyLabel: "K"
        )
        #expect(GlobalHotKeyManager.validate(shortcut) == nil)
    }

    @Test func convertsDisplayAbovePrimaryScreen() {
        let appKitFrame = CGRect(x: 0, y: 900, width: 1_440, height: 900)
        let converted = ScreenCoordinateConverter.convert(appKitFrame, primaryHeight: 900)

        #expect(converted == CGRect(x: 0, y: -900, width: 1_440, height: 900))
    }

    @Test func preservesNegativeHorizontalCoordinates() {
        let appKitFrame = CGRect(x: -1_920, y: 0, width: 1_920, height: 1_080)
        let converted = ScreenCoordinateConverter.convert(appKitFrame, primaryHeight: 1_080)

        #expect(converted == appKitFrame)
    }
}
