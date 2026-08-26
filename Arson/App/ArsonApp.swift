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
        .commands {
            CommandGroup(after: .appInfo) {
                if appDelegate.updates.isConfigured {
                    CheckForUpdatesCommand(updates: appDelegate.updates)
                }
            }
            CommandGroup(after: .help) {
                Divider()
                Button("menu.showIntroduction") {
                    appDelegate.showIntroduction()
                }
            }
        }
    }
}

private struct CheckForUpdatesCommand: View {
    @ObservedObject var updates: UpdateService

    var body: some View {
        Button("update.check") {
            updates.checkForUpdates()
        }
        .disabled(!updates.canCheckForUpdates)
    }
}
