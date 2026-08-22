import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ForEach(model.store.presets) { preset in
            Button {
                model.perform(preset)
            } label: {
                HStack {
                    Text(preset.name)
                    if let shortcut = preset.shortcut {
                        Spacer()
                        Text(shortcut.displayValue)
                    }
                }
            }
            .disabled(!preset.isValid || !preset.hasEffect)
        }

        Divider()

        Button("menu.openArson") {
            AppDelegate.shared.showMainWindow()
        }

        if !model.permissions.isTrusted {
            Button("permission.openSettings") {
                model.permissions.openSystemSettings()
            }
        }

        Divider()

        Button("menu.quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
