import SwiftUI

@main
struct ArsonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.model)
                .onAppear { appDelegate.markWindowVisible() }
        }
    }
}
