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
    private var fullScreenObservationTask: Task<Void, Never>?
    private var hotKeysAreSuspended = false

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

        observeFullScreenChanges()
        refreshHotKeys(store.presets)
        refreshFullScreenState()
    }

    func perform(presetID: UUID) {
        guard let preset = store.presets.first(where: { $0.id == presetID }) else { return }
        perform(preset)
    }

    func perform(_ preset: Preset) {
        permissions.refresh()
        let previousTask = windowActionTask
        previousTask?.cancel()
        windowActionTask = Task { @MainActor [weak self] in
            await previousTask?.value
            guard !Task.isCancelled else { return }
            guard let self else { return }
            do {
                _ = try await windowController.apply(preset)
            } catch is CancellationError {
                // A newer preset replaces a pending window operation.
            } catch let error as WindowActionError where !error.presentsHUD {
                // Native full-screen windows retain their own keyboard shortcuts.
            } catch {
                hud.show(message: error.localizedDescription, on: nil)
            }
        }
    }

    func refreshHotKeys(_ presets: [Preset]? = nil) {
        hotKeyErrors = hotKeys.register(
            presets ?? store.presets,
            isEnabled: !hotKeysAreSuspended
        )
    }

    func shutdown() {
        windowActionTask?.cancel()
        fullScreenObservationTask?.cancel()
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

    private func observeFullScreenChanges() {
        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        Publishers.Merge(
            workspaceNotifications.publisher(for: NSWorkspace.didActivateApplicationNotification),
            workspaceNotifications.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.refreshFullScreenState()
        }
        .store(in: &observations)
    }

    private func refreshFullScreenState() {
        fullScreenObservationTask?.cancel()
        fullScreenObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await updateFullScreenState()

            // Space changes are delivered while macOS is still settling the target
            // application's focused window. Confirm once more after the transition.
            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return
            }
            await updateFullScreenState()
        }
    }

    private func updateFullScreenState() async {
        let shouldSuspend = await windowController.frontmostWindowIsFullScreen()
        guard !Task.isCancelled, shouldSuspend != hotKeysAreSuspended else { return }
        hotKeysAreSuspended = shouldSuspend
        refreshHotKeys()
    }
}
