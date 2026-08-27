import SwiftUI

struct PresetEditorView: View {
    @Binding var preset: Preset
    let hotKeyError: String?

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    InlineValidatedControl(
                        validationMessage: preset.name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                            ? String(localized: "validation.name")
                            : nil
                    ) {
                        TextField("", text: $preset.name)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)
                            .accessibilityLabel(Text("editor.name"))
                            .accessibilityIdentifier("presetNameField")
                    }
                } label: {
                    Text("editor.name")
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("configurationFieldLabel")
                }
            } header: {
                Text("editor.general")
            } footer: {
                if !preset.hasEffect {
                    ValidationMessage(
                        String(localized: "validation.noEffect"),
                        color: .orange,
                        systemImage: "exclamationmark.triangle.fill"
                    )
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
                    Text("position.leftEdge").tag(PositionMode.leftEdge)
                    Text("position.rightEdge").tag(PositionMode.rightEdge)
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
                Text("editor.offsetHint")
                    .accessibilityIdentifier("configurationHelpText")
                    .foregroundStyle(.primary)
            }

            Section {
                LabeledContent {
                    InlineValidatedControl(validationMessage: hotKeyError) {
                        HotKeyRecorderView(shortcut: $preset.shortcut)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(height: 28)
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
        .labeledContentStyle(CenteredFormLabeledContentStyle())
    }
}

private struct CenteredFormLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 16) {
            configuration.label
            Spacer(minLength: 16)
            configuration.content
        }
        .frame(minHeight: 28, alignment: .center)
        // Keep the centered regular controls at the compact height of a native
        // grouped form row instead of inheriting the larger generic-content inset.
        .padding(.vertical, -4)
    }
}

private struct DimensionRuleEditor: View {
    let title: LocalizedStringKey
    @Binding var rule: DimensionRule
    let defaultPoints: Double
    let validationMessage: String?

    var body: some View {
        LabeledContent {
            InlineValidatedControl(validationMessage: validationMessage) {
                HStack(spacing: 8) {
                    Picker("", selection: mode) {
                        Text("dimension.unchanged").tag(DimensionMode.unchanged)
                        Text("dimension.points").tag(DimensionMode.points)
                        Text("dimension.percent").tag(DimensionMode.percent)
                    }
                    .labelsHidden()
                    .fixedSize(horizontal: true, vertical: false)

                    if rule.mode != .unchanged {
                        NumericStepper(
                            label: title,
                            value: $rule.value,
                            range: rule.mode == .percent
                                ? 0.1...100
                                : 0.1...Double.greatestFiniteMagnitude,
                            unit: rule.mode == .percent ? "%" : "unit.points"
                        )
                    }
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
            InlineValidatedControl(validationMessage: validationMessage) {
                NumericStepper(
                    label: label,
                    value: $value,
                    range: nil,
                    unit: "unit.points"
                )
            }
        } label: {
            Text(label)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("configurationFieldLabel")
        }
    }
}

private struct NumericStepper: View {
    let label: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>?
    let unit: LocalizedStringKey

    var body: some View {
        HStack(spacing: 6) {
            stepper
                .labelsHidden()
                .fixedSize(horizontal: true, vertical: false)

            Text(unit)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var stepper: some View {
        if let range {
            Stepper(
                value: $value,
                in: range,
                step: 1,
                format: .number.precision(.fractionLength(0...1))
            ) {
                Text(label)
            }
        } else {
            Stepper(
                value: $value,
                step: 1,
                format: .number.precision(.fractionLength(0...1))
            ) {
                Text(label)
            }
        }
    }
}

private struct InlineValidatedControl<Control: View>: View {
    let validationMessage: String?
    let control: Control

    init(
        validationMessage: String?,
        @ViewBuilder control: () -> Control
    ) {
        self.validationMessage = validationMessage
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let validationMessage {
                ValidationMessage(validationMessage)
                    .multilineTextAlignment(.trailing)
                    .layoutPriority(1)
            }

            control
                .fixedSize(horizontal: true, vertical: false)
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
            .labelIconToTitleSpacing(6)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
