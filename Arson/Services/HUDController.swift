import AppKit
import SwiftUI

@MainActor
final class HUDController {
    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?

    func show(message: String, on screen: ScreenDescriptor?) {
        dismissalTask?.cancel()
        panel?.orderOut(nil)

        let content = HUDView(message: message)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = CGRect(x: 0, y: 0, width: 360, height: 72)

        let panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.hidesOnDeactivate = false

        let target = appKitVisibleFrame(for: screen) ?? NSScreen.main?.visibleFrame ?? .zero
        panel.setFrameOrigin(
            CGPoint(x: target.midX - panel.frame.width / 2, y: target.minY + 48)
        )
        panel.orderFrontRegardless()
        self.panel = panel

        NSAccessibility.post(
            element: NSApp!,
            notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue]
        )

        dismissalTask = Task { @MainActor [weak self, weak panel] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            panel?.orderOut(nil)
            if self?.panel === panel { self?.panel = nil }
        }
    }

    private func appKitVisibleFrame(for descriptor: ScreenDescriptor?) -> CGRect? {
        guard let descriptor else { return nil }
        return NSScreen.screens.first { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return CGDirectDisplayID(number.uint32Value) == descriptor.displayID
        }?.visibleFrame
    }
}

private struct HUDView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.headline)
            .labelIconToTitleSpacing(6)
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityLabel(message)
    }
}
