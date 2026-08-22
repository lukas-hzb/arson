import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true

    var body: some View {
        Form {
            Section("settings.general") {
                Toggle("settings.showMenuBar", isOn: $showMenuBarItem)
                Toggle(
                    "settings.launchAtLogin",
                    isOn: Binding(
                        get: { model.loginItem.isEnabled },
                        set: { model.loginItem.setEnabled($0) }
                    )
                )
                if let error = model.loginItem.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Section("settings.permission") {
                LabeledContent("settings.accessibility") {
                    Label(
                        model.permissions.isTrusted
                            ? String(localized: "permission.allowed")
                            : String(localized: "permission.missing"),
                        systemImage: model.permissions.isTrusted ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(model.permissions.isTrusted ? .green : .orange)
                }
                HStack {
                    Button("permission.check") { model.permissions.refresh() }
                    Button("permission.openSettings") { model.permissions.openSystemSettings() }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520)
        .onAppear {
            model.permissions.refresh()
            model.loginItem.refresh()
        }
    }
}

