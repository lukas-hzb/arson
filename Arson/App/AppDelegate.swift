import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!
    let model = AppModel()
    private var mainWindow: NSWindow?

    override init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
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

    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if mainWindow == nil {
            let rootView = MainView().environmentObject(model)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar],
                backing: .buffered,
                defer: false
            )
            window.title = "Arson"
            window.contentMinSize = NSSize(width: 720, height: 480)
            window.isReleasedWhenClosed = false
            window.identifier = NSUserInterfaceItemIdentifier("ArsonMainWindow")
            window.setAccessibilityLabel("Arson")
            let hostingController = NSHostingController(rootView: rootView)
            hostingController.view.setAccessibilityLabel(String(localized: "sidebar.presets"))
            window.contentViewController = hostingController
            window.center()
            mainWindow = window
        }
        mainWindow?.makeKeyAndOrderFront(nil)
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
