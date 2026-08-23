import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private static let visibilityPreferenceKey = "showMenuBarItem"

    private let model: AppModel
    private let menu = NSMenu()
    private var statusItem: NSStatusItem?
    private var observations: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model
        super.init()

        menu.delegate = self
        observeState()
        updateVisibility()
    }

    func stop() {
        observations.removeAll()
        removeStatusItem()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        model.permissions.refresh()
        rebuildMenu()
    }

    private func observeState() {
        NotificationCenter.default.publisher(
            for: UserDefaults.didChangeNotification,
            object: UserDefaults.standard
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateVisibility()
        }
        .store(in: &observations)

        Publishers.CombineLatest(
            model.store.$presets,
            model.permissions.$isTrusted
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _ in
            self?.rebuildMenu()
        }
        .store(in: &observations)
    }

    private func updateVisibility() {
        let preference = UserDefaults.standard.object(
            forKey: Self.visibilityPreferenceKey
        ) as? Bool ?? true

        if preference {
            installStatusItemIfNeeded()
        } else {
            removeStatusItem()
        }
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "rectangle.on.rectangle",
                accessibilityDescription: "Arson"
            )
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.toolTip = "Arson"
            button.setAccessibilityLabel("Arson")
        }
        item.menu = menu
        statusItem = item
        rebuildMenu()
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private func rebuildMenu() {
        guard statusItem != nil else { return }

        menu.removeAllItems()
        for preset in model.store.presets {
            let item = NSMenuItem(
                title: preset.name,
                action: #selector(performPreset(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preset.id
            item.isEnabled = preset.isValid && preset.hasEffect
            configureShortcut(preset.shortcut, for: item)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let openItem = NSMenuItem(
            title: String(localized: "menu.openArson"),
            action: #selector(openArson(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        if !model.permissions.isTrusted {
            let permissionItem = NSMenuItem(
                title: String(localized: "permission.openSettings"),
                action: #selector(openPermissionSettings(_:)),
                keyEquivalent: ""
            )
            permissionItem.target = self
            menu.addItem(permissionItem)
        }

        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: String(localized: "menu.quit"),
            action: #selector(quitArson(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func configureShortcut(_ shortcut: HotKeyShortcut?, for item: NSMenuItem) {
        guard let shortcut,
              let keyEquivalent = shortcut.appKitMenuKeyEquivalent else {
            return
        }
        item.keyEquivalent = keyEquivalent
        item.keyEquivalentModifierMask = shortcut.modifiers.appKitModifierFlags
    }

    @objc private func performPreset(_ sender: NSMenuItem) {
        guard let presetID = sender.representedObject as? UUID else { return }
        model.perform(presetID: presetID)
    }

    @objc private func openArson(_ sender: Any?) {
        AppDelegate.shared.showMainWindow()
    }

    @objc private func openPermissionSettings(_ sender: Any?) {
        model.permissions.openSystemSettings()
    }

    @objc private func quitArson(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}

private extension HotKeyShortcut {
    var appKitMenuKeyEquivalent: String? {
        let functionKey: Int?
        switch keyLabel {
        case "↩": return "\r"
        case "⇥": return "\t"
        case "Space": return " "
        case "←": functionKey = NSLeftArrowFunctionKey
        case "→": functionKey = NSRightArrowFunctionKey
        case "↑": functionKey = NSUpArrowFunctionKey
        case "↓": functionKey = NSDownArrowFunctionKey
        case "Home": functionKey = NSHomeFunctionKey
        case "End": functionKey = NSEndFunctionKey
        case "Page Up": functionKey = NSPageUpFunctionKey
        case "Page Down": functionKey = NSPageDownFunctionKey
        case "F1": functionKey = NSF1FunctionKey
        case "F2": functionKey = NSF2FunctionKey
        case "F3": functionKey = NSF3FunctionKey
        case "F4": functionKey = NSF4FunctionKey
        case "F5": functionKey = NSF5FunctionKey
        case "F6": functionKey = NSF6FunctionKey
        case "F7": functionKey = NSF7FunctionKey
        case "F8": functionKey = NSF8FunctionKey
        case "F9": functionKey = NSF9FunctionKey
        case "F10": functionKey = NSF10FunctionKey
        case "F11": functionKey = NSF11FunctionKey
        case "F12": functionKey = NSF12FunctionKey
        default:
            guard keyLabel.count == 1, let character = keyLabel.first else {
                return nil
            }
            return String(character).lowercased()
        }

        guard let functionKey, let scalar = UnicodeScalar(functionKey) else { return nil }
        return String(Character(scalar))
    }
}

private extension HotKeyModifiers {
    var appKitModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.command) { flags.insert(.command) }
        if contains(.option) { flags.insert(.option) }
        if contains(.control) { flags.insert(.control) }
        if contains(.shift) { flags.insert(.shift) }
        return flags
    }
}
