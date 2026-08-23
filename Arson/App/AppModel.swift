import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let store: PresetStore
    let permissions: AccessibilityPermissionService
    let loginItem: LoginItemService

    @Published private(set) var hotKeyErrors: [UUID: HotKeyValidationError] = [:]

    private let hotKeys: GlobalHotKeyManager
    private let windowController: AccessibilityWindowController
    private let hud: HUDController
    private var observations: Set<AnyCancellable> = []
    private var windowActionTask: Task<Void, Never>?

    init(
        store: PresetStore = PresetStore(),
        permissions: AccessibilityPermissionService = AccessibilityPermissionService(),
        loginItem: LoginItemService = LoginItemService()
    ) {
        self.store = store
        self.permissions = permissions
        self.loginItem = loginItem
        hotKeys = GlobalHotKeyManager()
        windowController = AccessibilityWindowController()
        hud = HUDController()

        hotKeys.onPressed = { [weak self] presetID in
            self?.perform(presetID: presetID)
        }

        Publishers.Merge3(
            store.objectWillChange,
            permissions.objectWillChange,
            loginItem.objectWillChange
        )
        .sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &observations)

        store.onChange = { [weak self] presets in
            self?.refreshHotKeys(presets)
        }
        refreshHotKeys(store.presets)
    }

    func perform(presetID: UUID) {
        guard let preset = store.presets.first(where: { $0.id == presetID }) else { return }
        perform(preset)
    }

    func perform(_ preset: Preset) {
        permissions.refresh()
        windowActionTask?.cancel()
        windowActionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await windowController.apply(
                    preset,
                    animated: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                )
            } catch is CancellationError {
                // A newer preset replaces an animation already in progress.
            } catch {
                hud.show(message: error.localizedDescription, on: nil)
            }
        }
    }

    func refreshHotKeys(_ presets: [Preset]? = nil) {
        hotKeyErrors = hotKeys.register(presets ?? store.presets)
    }

    func shutdown() {
        windowActionTask?.cancel()
        hotKeys.unregisterAll()
    }

    func validationMessages(for preset: Preset) -> [String] {
        var messages: [String] = []
        if preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(String(localized: "validation.name"))
        }
        if !preset.width.isValid || !preset.height.isValid {
            messages.append(String(localized: "validation.dimension"))
        }
        if !preset.offsetX.isFinite || !preset.offsetY.isFinite {
            messages.append(String(localized: "validation.offset"))
        }
        if !preset.hasEffect {
            messages.append(String(localized: "validation.noEffect"))
        }
        if let error = hotKeyErrors[preset.id]?.errorDescription {
            messages.append(error)
        }
        return messages
    }
}
