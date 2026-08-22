import ApplicationServices
import AppKit
import Combine

@MainActor
final class AccessibilityPermissionService: ObservableObject {
    @Published private(set) var isTrusted = AXIsProcessTrusted()

    func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    func requestAccess() {
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
