import Carbon
import Foundation

enum HotKeyValidationError: LocalizedError, Equatable {
    case missingPrimaryModifier
    case reservedShortcut
    case duplicateShortcut
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingPrimaryModifier:
            return String(localized: "error.hotkey.modifier")
        case .reservedShortcut:
            return String(localized: "error.hotkey.reserved")
        case .duplicateShortcut:
            return String(localized: "error.hotkey.duplicate")
        case .registrationFailed:
            return String(localized: "error.hotkey.registration")
        }
    }
}

@MainActor
final class GlobalHotKeyManager {
    var onPressed: ((UUID) -> Void)?

    private let signature: OSType = 0x4172736E // "Arsn"
    private var handler: EventHandlerRef?
    private var registrations: [UInt32: EventHotKeyRef] = [:]
    private var presetIDs: [UInt32: UUID] = [:]

    init() {
        installHandler()
    }

    func register(_ presets: [Preset]) -> [UUID: HotKeyValidationError] {
        unregisterAll()
        var errors: [UUID: HotKeyValidationError] = [:]
        var seen = Set<HotKeyShortcut>()
        var identifier: UInt32 = 1

        for preset in presets {
            guard let shortcut = preset.shortcut else { continue }
            if let validationError = Self.validate(shortcut) {
                errors[preset.id] = validationError
                continue
            }
            guard seen.insert(shortcut).inserted else {
                errors[preset.id] = .duplicateShortcut
                continue
            }

            var reference: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: signature, id: identifier)
            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.modifiers.carbonFlags,
                hotKeyID,
                GetApplicationEventTarget(),
                OptionBits(kEventHotKeyExclusive),
                &reference
            )
            guard status == noErr, let reference else {
                errors[preset.id] = .registrationFailed(status)
                continue
            }
            registrations[identifier] = reference
            presetIDs[identifier] = preset.id
            identifier += 1
        }
        return errors
    }

    func unregisterAll() {
        for reference in registrations.values {
            UnregisterEventHotKey(reference)
        }
        registrations.removeAll()
        presetIDs.removeAll()
    }

    static func validate(_ shortcut: HotKeyShortcut) -> HotKeyValidationError? {
        guard !shortcut.modifiers.intersection(.primary).isEmpty else {
            return .missingPrimaryModifier
        }
        if isReserved(shortcut) { return .reservedShortcut }
        return nil
    }

    private func installHandler() {
        var type = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated {
                    manager.handle(identifier: hotKeyID.id)
                }
                return noErr
            },
            1,
            &type,
            pointer,
            &handler
        )
    }

    private func handle(identifier: UInt32) {
        guard let presetID = presetIDs[identifier] else { return }
        onPressed?(presetID)
    }

    private static func isReserved(_ shortcut: HotKeyShortcut) -> Bool {
        let modifiers = shortcut.modifiers
        let commandOnly = modifiers == .command
        let commandKeyCodes: Set<UInt32> = [
            UInt32(kVK_ANSI_Q), UInt32(kVK_ANSI_W), UInt32(kVK_ANSI_H),
            UInt32(kVK_ANSI_M), UInt32(kVK_ANSI_Comma), UInt32(kVK_Space), UInt32(kVK_Tab)
        ]
        return commandOnly && commandKeyCodes.contains(shortcut.keyCode)
    }
}

private extension HotKeyModifiers {
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}
