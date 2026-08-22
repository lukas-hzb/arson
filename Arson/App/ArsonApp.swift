import SwiftUI

@main
struct ArsonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.model)
                .onAppear { appDelegate.markWindowVisible() }
        }

        MenuBarExtra(
            "Arson",
            systemImage: "rectangle.on.rectangle",
            isInserted: $showMenuBarItem
        ) {
            MenuBarContentView()
                .environmentObject(appDelegate.model)
        }
        .menuBarExtraStyle(.menu)
    }
}
