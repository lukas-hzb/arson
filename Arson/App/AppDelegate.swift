import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!
    let model = AppModel()
    private var mainWindowController: MainWindowController?

    override init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "completedOnboardingVersion")
            UserDefaults.standard.set(true, forKey: "showMenuBarItem")
        }
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        showMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationDidUpdate(_ notification: Notification) {
        // SwiftUI owns the standard main menu and can finish or rebuild it after launch.
        // Installing idempotently here keeps the native Preset menu attached reliably.
        mainWindowController?.installPresetMenuIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if mainWindowController == nil {
            mainWindowController = MainWindowController(model: model)
        }
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        Task { @MainActor [weak self] in
            // SwiftUI finishes constructing the main menu after the app delegate's
            // launch callback. Yield once so the native menu can be extended reliably.
            await Task.yield()
            self?.mainWindowController?.installPresetMenuIfNeeded()
        }
    }

    func markWindowVisible() {
        NSApp.setActivationPolicy(.regular)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            await Task.yield()
            let hasVisibleWindow = NSApp.windows.contains { window in
                window.isVisible && window.level == .normal && !window.isMiniaturized
            }
            if !hasVisibleWindow {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
