import AppKit
import Foundation
import Testing
@testable import Arson

@MainActor
struct MainWindowControllerTests {
    @Test func presentationRestoresAnUnusableWindowHeight() throws {
        let defaults = temporaryDefaults(completedOnboardingVersion: 2)
        let store = PresetStore(
            fileURL: temporaryFileURL(),
            seedPresets: []
        )
        let controller = MainWindowController(
            model: AppModel(store: store),
            defaults: defaults
        )
        let window = try #require(controller.window)

        window.contentMinSize = .zero
        window.minSize = .zero
        window.setContentSize(NSSize(width: 920, height: 160))

        controller.prepareForPresentation()

        let contentSize = try #require(window.contentView?.bounds.size)
        #expect(contentSize.width >= 720)
        #expect(contentSize.height >= 480)
        controller.close()
    }

    @Test func onboardingUsesTheExistingWindowWithoutChangingItsFrame() throws {
        let defaults = temporaryDefaults(completedOnboardingVersion: 0)
        let store = PresetStore(
            fileURL: temporaryFileURL(),
            seedPresets: []
        )
        let controller = MainWindowController(
            model: AppModel(store: store),
            defaults: defaults
        )
        let window = try #require(controller.window)
        window.setFrame(
            NSRect(x: 120, y: 120, width: 920, height: 660),
            display: false
        )
        let initialFrame = window.frame

        #expect(controller.isShowingOnboarding)
        #expect(window.toolbar?.isVisible == true)
        #expect(
            window.toolbar?.items.allSatisfy {
                $0.itemIdentifier == .flexibleSpace
            } == true
        )

        controller.completeOnboarding()

        #expect(!controller.isShowingOnboarding)
        #expect(window.frame == initialFrame)
        #expect(window.toolbar?.isVisible == true)
        #expect(
            defaults.integer(forKey: MainWindowController.onboardingPreferenceKey)
                == MainWindowController.currentOnboardingVersion
        )
        controller.close()
    }

    @Test func introductionCanBeShownAgainWithoutResizingTheWindow() throws {
        let defaults = temporaryDefaults(completedOnboardingVersion: 2)
        let store = PresetStore(
            fileURL: temporaryFileURL(),
            seedPresets: []
        )
        let controller = MainWindowController(
            model: AppModel(store: store),
            defaults: defaults
        )
        let window = try #require(controller.window)
        window.setFrame(
            NSRect(x: 120, y: 120, width: 920, height: 660),
            display: false
        )
        let initialFrame = window.frame

        controller.showOnboarding(animated: false)

        #expect(controller.isShowingOnboarding)
        #expect(window.frame == initialFrame)
        #expect(window.toolbar?.isVisible == true)
        #expect(
            window.toolbar?.items.allSatisfy {
                $0.itemIdentifier == .flexibleSpace
            } == true
        )
        controller.close()
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("presets.json")
    }

    private func temporaryDefaults(
        completedOnboardingVersion: Int
    ) -> UserDefaults {
        let suiteName = "MainWindowControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(
            completedOnboardingVersion,
            forKey: MainWindowController.onboardingPreferenceKey
        )
        return defaults
    }
}
