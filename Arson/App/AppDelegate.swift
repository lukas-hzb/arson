import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!
    let model = AppModel()
    private var mainWindowController: MainWindowController?
    private var menuBarController: MenuBarController?
    private var isWaitingToBecomeAccessory = false

    override init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing-reset")
            || arguments.contains("-show-onboarding") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "completedOnboardingVersion")
        }
        if arguments.contains("-ui-testing-reset") {
            UserDefaults.standard.set(true, forKey: "showMenuBarItem")
            UserDefaults.standard.set(
                MenuBarIconStyle.windows.rawValue,
                forKey: MenuBarIconStyle.preferenceKey
            )
        }
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        menuBarController = MenuBarController(model: model)
        showMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        beginAccessoryTransition(for: sender)
        return false
    }

    func applicationDidResignActive(_ notification: Notification) {
        guard isWaitingToBecomeAccessory else { return }
        isWaitingToBecomeAccessory = false

        guard !hasVisibleNormalWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func applicationDidUpdate(_ notification: Notification) {
        // SwiftUI owns the standard main menu and can finish or rebuild it after launch.
        // Installing idempotently here keeps the native Preset menu attached reliably.
        mainWindowController?.installPresetMenuIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.stop()
        model.shutdown()
    }

    func showMainWindow() {
        isWaitingToBecomeAccessory = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        if mainWindowController == nil {
            mainWindowController = MainWindowController(model: model)
        }
        mainWindowController?.prepareForPresentation()
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        Task { @MainActor [weak self] in
            // SwiftUI finishes constructing the main menu after the app delegate's
            // launch callback. Yield once so the native menu can be extended reliably.
            await Task.yield()
            self?.mainWindowController?.installPresetMenuIfNeeded()
        }
    }

    func showIntroduction() {
        isWaitingToBecomeAccessory = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        if mainWindowController == nil {
            mainWindowController = MainWindowController(model: model)
        }
        mainWindowController?.prepareForPresentation()
        mainWindowController?.showOnboarding()
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    func markWindowVisible() {
        isWaitingToBecomeAccessory = false
        NSApp.setActivationPolicy(.regular)
    }

    private var hasVisibleNormalWindow: Bool {
        NSApp.windows.contains { window in
            window.isVisible && window.level == .normal && !window.isMiniaturized
        }
    }

    private func beginAccessoryTransition(for application: NSApplication) {
        isWaitingToBecomeAccessory = true

        guard application.isActive else {
            isWaitingToBecomeAccessory = false
            application.setActivationPolicy(.accessory)
            return
        }

        guard let finder = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.finder"
        ).first else {
            return
        }

        application.yieldActivation(to: finder)
        _ = finder.activate(from: .current, options: [])
    }
}
