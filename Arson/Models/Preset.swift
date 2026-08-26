import Carbon
import Foundation

enum DimensionMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case unchanged
    case points
    case percent

    var id: Self { self }
}

struct DimensionRule: Codable, Equatable, Hashable, Sendable {
    var mode: DimensionMode
    var value: Double

    static let unchanged = DimensionRule(mode: .unchanged, value: 0)

    static func points(_ value: Double) -> DimensionRule {
        DimensionRule(mode: .points, value: value)
    }

    static func percent(_ value: Double) -> DimensionRule {
        DimensionRule(mode: .percent, value: value)
    }

    var isValid: Bool {
        guard value.isFinite else { return false }
        switch mode {
        case .unchanged:
            return true
        case .points:
            return value > 0
        case .percent:
            return value > 0 && value <= 100
        }
    }
}

enum PositionMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case keep
    case center
    case leftEdge
    case rightEdge

    var id: Self { self }
}

struct HotKeyModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt32

    static let command = HotKeyModifiers(rawValue: 1 << 0)
    static let option = HotKeyModifiers(rawValue: 1 << 1)
    static let control = HotKeyModifiers(rawValue: 1 << 2)
    static let shift = HotKeyModifiers(rawValue: 1 << 3)

    static let primary: HotKeyModifiers = [.command, .option, .control]

    var displayPrefix: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}

struct HotKeyShortcut: Codable, Equatable, Hashable, Sendable {
    var keyCode: UInt32
    var modifiers: HotKeyModifiers
    var keyLabel: String

    var displayValue: String {
        modifiers.displayPrefix + keyLabel.uppercased()
    }

    static func == (lhs: HotKeyShortcut, rhs: HotKeyShortcut) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers)
    }
}

struct Preset: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var width: DimensionRule
    var height: DimensionRule
    var position: PositionMode
    var offsetX: Double
    var offsetY: Double
    var shortcut: HotKeyShortcut?

    init(
        id: UUID = UUID(),
        name: String,
        width: DimensionRule = .unchanged,
        height: DimensionRule = .unchanged,
        position: PositionMode = .keep,
        offsetX: Double = 0,
        offsetY: Double = 0,
        shortcut: HotKeyShortcut? = nil
    ) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.position = position
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.shortcut = shortcut
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && width.isValid
            && height.isValid
            && offsetX.isFinite
            && offsetY.isFinite
    }

    var hasEffect: Bool {
        width.mode != .unchanged
            || height.mode != .unchanged
            || position != .keep
            || offsetX != 0
            || offsetY != 0
    }

    static func seedPresets() -> [Preset] {
        let shortcutModifiers: HotKeyModifiers = [.command, .control]

        return [
            Preset(
                name: String(localized: "preset.seed.fixed"),
                width: .percent(80),
                height: .percent(80),
                position: .center,
                shortcut: HotKeyShortcut(
                    keyCode: UInt32(kVK_Return),
                    modifiers: shortcutModifiers,
                    keyLabel: "↩"
                )
            ),
            Preset(
                name: String(localized: "preset.seed.leftHalf"),
                width: .percent(50),
                height: .percent(100),
                position: .leftEdge,
                offsetX: 1,
                offsetY: 1,
                shortcut: HotKeyShortcut(
                    keyCode: UInt32(kVK_LeftArrow),
                    modifiers: shortcutModifiers,
                    keyLabel: "←"
                )
            ),
            Preset(
                name: String(localized: "preset.seed.rightHalf"),
                width: .percent(50),
                height: .percent(100),
                position: .rightEdge,
                shortcut: HotKeyShortcut(
                    keyCode: UInt32(kVK_RightArrow),
                    modifiers: shortcutModifiers,
                    keyLabel: "→"
                )
            ),
            Preset(
                name: String(localized: "preset.seed.offset"),
                offsetX: 20,
                offsetY: 20,
                shortcut: HotKeyShortcut(
                    keyCode: UInt32(kVK_Delete),
                    modifiers: shortcutModifiers,
                    keyLabel: "⌫"
                )
            )
        ]
    }
}
