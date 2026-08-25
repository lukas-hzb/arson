import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true
    @AppStorage(MenuBarIconStyle.preferenceKey)
    private var menuBarIconStyle: MenuBarIconStyle = .windows

    var body: some View {
        Form {
            Section("settings.general") {
                Toggle("settings.showMenuBar", isOn: $showMenuBarItem)
                    .accessibilityIdentifier("showMenuBarItemToggle")
                Picker("settings.menuBarIcon", selection: $menuBarIconStyle) {
                    Label("settings.menuBarIconWindows", systemImage: "rectangle.on.rectangle")
                        .tag(MenuBarIconStyle.windows)
                    Label("settings.menuBarIconFlame", image: "MenuBarFlame")
                        .tag(MenuBarIconStyle.flame)
                }
                .disabled(!showMenuBarItem)
                .accessibilityIdentifier("menuBarIconPicker")
                Text("settings.menuBarBackgroundHelp")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

            Section("settings.languageSection") {
                HStack(spacing: 8) {
                    Text("settings.language")
                    Spacer()
                    Text(currentLanguageName)
                        .foregroundStyle(.secondary)
                    Button("settings.languageChange") {
                        openLanguageSettings()
                    }
                }
                Text("settings.languageHelp")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

    private var currentLanguageName: String {
        let identifier = Bundle.main.preferredLocalizations.first ?? "en"
        if identifier.lowercased().hasPrefix("de") {
            return String(localized: "language.german")
        }
        return String(localized: "language.english")
    }

    private func openLanguageSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Localization"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
