import SwiftUI

struct PresetEditorView: View {
    @Binding var preset: Preset
    let hotKeyError: String?

    var body: some View {
        Form {
            Section("editor.general") {
                LabeledContent {
                    VStack(alignment: .trailing, spacing: 5) {
                        TextField("", text: $preset.name)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 220, idealWidth: 280, maxWidth: 340)
                            .accessibilityLabel(Text("editor.name"))
                            .accessibilityIdentifier("presetNameField")

                        if preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ValidationMessage(String(localized: "validation.name"))
                                .frame(maxWidth: 340, alignment: .leading)
                        }
                    }
                } label: {
                    Text("editor.name")
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("configurationFieldLabel")
                }
            }

            Section {
                DimensionRuleEditor(
                    title: "editor.width",
                    rule: $preset.width,
                    defaultPoints: 800,
                    validationMessage: preset.width.isValid
                        ? nil
                        : String(localized: "validation.width")
                )
                DimensionRuleEditor(
                    title: "editor.height",
                    rule: $preset.height,
                    defaultPoints: 600,
                    validationMessage: preset.height.isValid
                        ? nil
                        : String(localized: "validation.height")
                )
            } header: {
                Text("editor.size")
            } footer: {
                SizeExplanation(width: preset.width.mode, height: preset.height.mode)
                    .foregroundStyle(.primary)
            }

            Section {
                Picker("editor.basePosition", selection: $preset.position) {
                    Text("position.keep").tag(PositionMode.keep)
                    Text("position.center").tag(PositionMode.center)
                }
                .pickerStyle(.segmented)
                .foregroundStyle(.primary)

                NumberField(
                    label: "editor.offsetX",
                    value: $preset.offsetX,
                    validationMessage: preset.offsetX.isFinite
                        ? nil
                        : String(localized: "validation.offsetX")
                )
                NumberField(
                    label: "editor.offsetY",
                    value: $preset.offsetY,
                    validationMessage: preset.offsetY.isFinite
                        ? nil
                        : String(localized: "validation.offsetY")
                )
            } header: {
                Text("editor.position")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("editor.offsetHint")
                        .accessibilityIdentifier("configurationHelpText")
                    if !preset.hasEffect {
                        ValidationMessage(
                            String(localized: "validation.noEffect"),
                            color: .orange,
                            systemImage: "exclamationmark.triangle.fill"
                        )
                    }
                }
                .foregroundStyle(.primary)
            }

            Section {
                LabeledContent {
                    VStack(alignment: .trailing, spacing: 5) {
                        HotKeyRecorderView(shortcut: $preset.shortcut)
                            .frame(width: 150, height: 28)

                        if let hotKeyError {
                            ValidationMessage(hotKeyError)
                                .frame(maxWidth: 300, alignment: .leading)
                        }
                    }
                } label: {
                    Text("editor.globalShortcut")
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("configurationFieldLabel")
                }
            } header: {
                Text("editor.shortcut")
            } footer: {
                Text("editor.shortcutHint")
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("configurationHelpText")
            }
        }
        .formStyle(.grouped)
    }
}

private struct DimensionRuleEditor: View {
    let title: LocalizedStringKey
    @Binding var rule: DimensionRule
    let defaultPoints: Double
    let validationMessage: String?

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 10) {
                    Picker("", selection: mode) {
                        Text("dimension.unchanged").tag(DimensionMode.unchanged)
                        Text("dimension.points").tag(DimensionMode.points)
                        Text("dimension.percent").tag(DimensionMode.percent)
                    }
                    .labelsHidden()
                    .frame(width: 135)

                    if rule.mode != .unchanged {
                        TextField(
                            "",
                            value: $rule.value,
                            format: .number.precision(.fractionLength(0...1))
                        )
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .accessibilityLabel(Text(title))
                        Text(rule.mode == .percent ? "%" : String(localized: "unit.points"))
                            .foregroundStyle(.secondary)
                            .frame(width: 45, alignment: .leading)
                            .accessibilityHidden(true)
                    }
                }

                if let validationMessage {
                    ValidationMessage(validationMessage)
                        .frame(maxWidth: 290, alignment: .leading)
                }
            }
        } label: {
            Text(title)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("configurationFieldLabel")
        }
    }

    private var mode: Binding<DimensionMode> {
        Binding(
            get: { rule.mode },
            set: { newMode in
                switch newMode {
                case .unchanged:
                    rule = .unchanged
                case .points:
                    rule = .points(rule.value > 0 ? rule.value : defaultPoints)
                case .percent:
                    let value = rule.value > 0 && rule.value <= 100 ? rule.value : 80
                    rule = .percent(value)
                }
            }
        )
    }
}

private struct SizeExplanation: View {
    let width: DimensionMode
    let height: DimensionMode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if width == .percent || height == .percent {
                Text("editor.visibleAreaHint")
                    .accessibilityIdentifier("configurationHelpText")
            }
            if width == .points || height == .points {
                Text("editor.pointAreaHint")
                    .accessibilityIdentifier("configurationHelpText")
            }
        }
    }
}

private struct NumberField: View {
    let label: LocalizedStringKey
    @Binding var value: Double
    let validationMessage: String?

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 6) {
                    TextField(
                        "",
                        value: $value,
                        format: .number.precision(.fractionLength(0...1))
                    )
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .accessibilityLabel(Text(label))
                    Text("unit.points")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                if let validationMessage {
                    ValidationMessage(validationMessage)
                        .frame(maxWidth: 260, alignment: .leading)
                }
            }
        } label: {
            Text(label)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("configurationFieldLabel")
        }
    }
}

private struct ValidationMessage: View {
    let message: String
    let color: Color
    let systemImage: String

    init(
        _ message: String,
        color: Color = .red,
        systemImage: String = "exclamationmark.circle.fill"
    ) {
        self.message = message
        self.color = color
        self.systemImage = systemImage
    }

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
