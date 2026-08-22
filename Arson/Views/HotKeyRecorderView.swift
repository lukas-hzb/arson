import AppKit
import Carbon
import SwiftUI

struct HotKeyRecorderView: NSViewRepresentable {
    @Binding var shortcut: HotKeyShortcut?

    func makeCoordinator() -> Coordinator {
        Coordinator(shortcut: $shortcut)
    }

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.bezelStyle = .rounded
        button.target = context.coordinator
        button.action = #selector(Coordinator.beginRecording(_:))
        button.setContentHuggingPriority(.required, for: .horizontal)
        context.coordinator.button = button
        context.coordinator.updateTitle()
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        context.coordinator.shortcut = $shortcut
        if !button.isRecording {
            context.coordinator.updateTitle()
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var shortcut: Binding<HotKeyShortcut?>
        weak var button: ShortcutRecorderButton?

        init(shortcut: Binding<HotKeyShortcut?>) {
            self.shortcut = shortcut
        }

        @objc func beginRecording(_ sender: ShortcutRecorderButton) {
            sender.isRecording = true
            sender.title = String(localized: "hotkey.recording")
            sender.window?.makeFirstResponder(sender)
        }

        func receive(_ event: NSEvent) {
            guard button != nil else { return }
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return
            }
            if event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete) {
                shortcut.wrappedValue = nil
                stopRecording()
                return
            }

            let modifiers = HotKeyModifiers(event.modifierFlags)
            let label = Self.label(for: event)
            guard !label.isEmpty else {
                NSSound.beep()
                return
            }
            shortcut.wrappedValue = HotKeyShortcut(
                keyCode: UInt32(event.keyCode),
                modifiers: modifiers,
                keyLabel: label
            )
            stopRecording()
        }

        func updateTitle() {
            button?.title = shortcut.wrappedValue?.displayValue ?? String(localized: "hotkey.none")
            button?.setAccessibilityLabel(String(localized: "hotkey.accessibilityLabel"))
            button?.setAccessibilityValue(button?.title)
        }

        private func stopRecording() {
            button?.isRecording = false
            button?.window?.makeFirstResponder(nil)
            updateTitle()
        }

        private static func label(for event: NSEvent) -> String {
            let special: [UInt16: String] = [
                UInt16(kVK_Return): "↩", UInt16(kVK_Tab): "⇥", UInt16(kVK_Space): "Space",
                UInt16(kVK_Delete): "⌫", UInt16(kVK_ForwardDelete): "⌦",
                UInt16(kVK_LeftArrow): "←", UInt16(kVK_RightArrow): "→",
                UInt16(kVK_UpArrow): "↑", UInt16(kVK_DownArrow): "↓",
                UInt16(kVK_Home): "Home", UInt16(kVK_End): "End",
                UInt16(kVK_PageUp): "Page Up", UInt16(kVK_PageDown): "Page Down",
                UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
                UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
                UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
                UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12"
            ]
            if let special = special[event.keyCode] { return special }
            return event.charactersIgnoringModifiers?.uppercased() ?? ""
        }
    }
}

final class ShortcutRecorderButton: NSButton {
    var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording, let coordinator = target as? HotKeyRecorderView.Coordinator else {
            super.keyDown(with: event)
            return
        }
        coordinator.receive(event)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        (target as? HotKeyRecorderView.Coordinator)?.updateTitle()
        return super.resignFirstResponder()
    }
}

private extension HotKeyModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        var value: HotKeyModifiers = []
        if flags.contains(.command) { value.insert(.command) }
        if flags.contains(.option) { value.insert(.option) }
        if flags.contains(.control) { value.insert(.control) }
        if flags.contains(.shift) { value.insert(.shift) }
        self = value
    }
}
