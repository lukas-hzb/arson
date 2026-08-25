import ApplicationServices
import AppKit
import Combine

@MainActor
final class AccessibilityPermissionService: ObservableObject {
    @Published private(set) var isTrusted: Bool

    private let forcesMissingPermissionForUITesting: Bool

    init() {
        forcesMissingPermissionForUITesting = ProcessInfo.processInfo.arguments.contains(
            "-ui-testing-permission-untrusted"
        )
        isTrusted = forcesMissingPermissionForUITesting ? false : AXIsProcessTrusted()
    }

    func refresh() {
        isTrusted = forcesMissingPermissionForUITesting ? false : AXIsProcessTrusted()
    }

    func requestAccess() {
        guard !forcesMissingPermissionForUITesting else { return }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshSoon()
    }

    func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func refreshSoon() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.refresh()
        }
    }
}
