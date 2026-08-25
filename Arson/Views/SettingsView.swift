import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("showMenuBarItem") private var showMenuBarItem = true
    @AppStorage(MenuBarIconStyle.preferenceKey)
    private var menuBarIconStyle: MenuBarIconStyle = .windows
    @FocusState private var focusedControl: FocusedControl?

    var body: some View {
        Form {
            Section("settings.general") {
                Toggle(
                    "settings.launchAtLogin",
                    isOn: Binding(
                        get: { model.loginItem.isEnabled },
                        set: {
                            model.loginItem.setEnabled($0)
                            focusedControl = .launchAtLogin
                        }
                    )
                )
                .focusable(false)
                .focusable()
                .focusEffectDisabled()
                .focused($focusedControl, equals: .launchAtLogin)
                .onKeyPress(.space) {
                    model.loginItem.setEnabled(!model.loginItem.isEnabled)
                    focusedControl = .launchAtLogin
                    return .handled
                }
                if let error = model.loginItem.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .labelIconToTitleSpacing(6)
                        .foregroundStyle(.orange)
                }
            }

            Section("settings.menuBarSection") {
                Toggle(
                    "settings.showMenuBar",
                    isOn: Binding(
                        get: { showMenuBarItem },
                        set: {
                            showMenuBarItem = $0
                            focusedControl = .showMenuBar
                        }
                    )
                )
                    .focusable(false)
                    .focusable()
                    .focusEffectDisabled()
                    .focused($focusedControl, equals: .showMenuBar)
                    .onKeyPress(.space) {
                        showMenuBarItem.toggle()
                        focusedControl = .showMenuBar
                        return .handled
                    }
                    .accessibilityIdentifier("showMenuBarItemToggle")
                LabeledContent("settings.menuBarIcon") {
                    MenuBarIconPopUpButton(selection: $menuBarIconStyle)
                        .fixedSize()
                        .accessibilityIdentifier("menuBarIconPicker")
                }
                .disabled(!showMenuBarItem)
                Text("settings.menuBarBackgroundHelp")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                    .labelIconToTitleSpacing(6)
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
            Task { @MainActor in
                await Task.yield()
                focusedControl = nil
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }

    private enum FocusedControl: Hashable {
        case launchAtLogin
        case showMenuBar
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

private struct MenuBarIconPopUpButton: NSViewRepresentable {
    @Binding var selection: MenuBarIconStyle

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.controlSize = .regular
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.imageScaling = .scaleProportionallyDown
        button.autoenablesItems = false
        button.usesItemFromMenu = false
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionChanged(_:))
        button.setAccessibilityIdentifier("menuBarIconPicker")
        update(button)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.selection = $selection
        update(button)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSPopUpButton,
        context: Context
    ) -> CGSize? {
        guard let cell = nsView.cell as? NSPopUpButtonCell else {
            return nsView.intrinsicContentSize
        }

        let displayedItem = cell.menuItem
        defer { cell.menuItem = displayedItem }

        return MenuBarIconStyle.allCases.reduce(.zero) { size, style in
            cell.menuItem = style.closedButtonSizingMenuItem
            let itemSize = cell.cellSize
            return CGSize(
                width: max(size.width, itemSize.width),
                height: max(size.height, itemSize.height)
            )
        }
    }

    private func update(_ button: NSPopUpButton) {
        let selectedTag = selection.tag
        let itemConfiguration = MenuBarIconStyle.allCases.map { style in
            (style, style.localizedTitle, style.menuImage)
        }

        let itemsNeedUpdate = button.itemArray.count != itemConfiguration.count
            || zip(button.itemArray, itemConfiguration).contains { item, configuration in
                item.tag != configuration.0.tag || item.title != configuration.1
            }

        if itemsNeedUpdate {
            button.removeAllItems()
            for (style, title, image) in itemConfiguration {
                button.addItem(withTitle: title)
                guard let item = button.lastItem else { continue }
                item.tag = style.tag
                item.image = image
            }
        }

        if button.selectedTag() != selectedTag {
            button.selectItem(withTag: selectedTag)
        }

        guard let cell = button.cell as? NSPopUpButtonCell else { return }
        cell.usesItemFromMenu = false
        cell.menuItem = selection.closedButtonMenuItem
        button.invalidateIntrinsicContentSize()
        button.needsDisplay = true
    }

    @MainActor
    final class Coordinator: NSObject {
        var selection: Binding<MenuBarIconStyle>

        init(selection: Binding<MenuBarIconStyle>) {
            self.selection = selection
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            guard let style = MenuBarIconStyle(tag: sender.selectedTag()) else { return }
            selection.wrappedValue = style
        }
    }
}

private extension MenuBarIconStyle {
    var tag: Int {
        switch self {
        case .windows: 0
        case .flame: 1
        }
    }

    init?(tag: Int) {
        switch tag {
        case 0: self = .windows
        case 1: self = .flame
        default: return nil
        }
    }

    var localizedTitle: String {
        switch self {
        case .windows:
            String(localized: "settings.menuBarIconWindows")
        case .flame:
            String(localized: "settings.menuBarIconFlame")
        }
    }

    var menuImage: NSImage? {
        makeImage(artworkSlotWidth: nil, trailingSpacing: 0)
    }

    var closedButtonMenuItem: NSMenuItem {
        closedButtonMenuItem(trailingSpacing: Metrics.closedAdditionalIconTitleSpacing)
    }

    var closedButtonSizingMenuItem: NSMenuItem {
        closedButtonMenuItem(trailingSpacing: 0)
    }

    private func closedButtonMenuItem(trailingSpacing: CGFloat) -> NSMenuItem {
        let item = NSMenuItem(title: localizedTitle, action: nil, keyEquivalent: "")
        item.image = makeImage(
            artworkSlotWidth: Metrics.closedArtworkSlotWidth,
            trailingSpacing: trailingSpacing
        )
        return item
    }

    private func makeImage(
        artworkSlotWidth: CGFloat?,
        trailingSpacing: CGFloat
    ) -> NSImage? {
        let sourceImage: NSImage?
        let artworkSize: NSSize
        switch self {
        case .windows:
            let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            sourceImage = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration)
            artworkSize = sourceImage?.size ?? .zero
        case .flame:
            sourceImage = NSImage(named: "MenuBarFlame")?.copy() as? NSImage
            artworkSize = Metrics.flameArtworkSize
        }

        guard let sourceImage else { return nil }
        sourceImage.size = artworkSize
        sourceImage.isTemplate = true

        let resolvedArtworkSlotWidth = artworkSlotWidth ?? artworkSize.width
        let imageSize = NSSize(
            width: resolvedArtworkSlotWidth + trailingSpacing,
            height: Metrics.imageHeight
        )
        let artworkOrigin = NSPoint(
            x: (resolvedArtworkSlotWidth - artworkSize.width) / 2,
            y: (imageSize.height - artworkSize.height) / 2
        )
        let image = NSImage(size: imageSize, flipped: false) { _ in
            sourceImage.draw(
                in: NSRect(origin: artworkOrigin, size: artworkSize),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = nil
        return image
    }

    private enum Metrics {
        // The configured window symbol is 21 pt wide on macOS 26/27. A 22 pt
        // slot preserves it at its natural size and centers the narrower flame.
        static let closedArtworkSlotWidth: CGFloat = 22
        // AppKit already contributes its native image-to-title gap. Four
        // additional points align the closed control with the menu rows.
        static let closedAdditionalIconTitleSpacing: CGFloat = 4
        static let flameArtworkSize = NSSize(width: 16, height: 16)
        static let imageHeight: CGFloat = 16
    }
}
