import SwiftUI

struct PresetEditorView: View {
    @Binding var preset: Preset
    let validationMessages: [String]

    var body: some View {
        Form {
            Section("editor.identity") {
                TextField("editor.name", text: $preset.name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("presetNameField")
            }

            Section("editor.size") {
                DimensionRuleEditor(
                    title: "editor.width",
                    rule: $preset.width,
                    defaultPoints: 800
                )
                DimensionRuleEditor(
                    title: "editor.height",
                    rule: $preset.height,
                    defaultPoints: 600
                )
                Text("editor.visibleAreaHint")
                    .font(.caption)
            }

            Section("editor.position") {
                Picker("editor.basePosition", selection: $preset.position) {
                    Text("position.keep").tag(PositionMode.keep)
                    Text("position.center").tag(PositionMode.center)
                }
                .pickerStyle(.segmented)

                LabeledContent("editor.offset") {
                    HStack(spacing: 12) {
                        NumberField(label: "X", value: $preset.offsetX)
                        NumberField(label: "Y", value: $preset.offsetY)
                    }
                }
                Text("editor.offsetHint")
                    .font(.caption)
            }

            Section("editor.shortcut") {
                LabeledContent("editor.globalShortcut") {
                    HotKeyRecorderView(shortcut: $preset.shortcut)
                        .frame(width: 150, height: 28)
                }
                Text("editor.shortcutHint")
                    .font(.caption)
            }

            if !validationMessages.isEmpty {
                Section("validation.title") {
                    ForEach(validationMessages, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(preset.name.isEmpty ? String(localized: "preset.untitled") : preset.name)
        .padding(.horizontal, 8)
    }
}

private struct DimensionRuleEditor: View {
    let title: LocalizedStringKey
    @Binding var rule: DimensionRule
    let defaultPoints: Double

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                Picker("", selection: mode) {
                    Text("dimension.unchanged").tag(DimensionMode.unchanged)
                    Text("dimension.points").tag(DimensionMode.points)
                    Text("dimension.percent").tag(DimensionMode.percent)
                }
                .labelsHidden()
                .frame(width: 135)

                if rule.mode != .unchanged {
                    TextField("", value: $rule.value, format: .number.precision(.fractionLength(0...1)))
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Text(rule.mode == .percent ? "%" : String(localized: "unit.points"))
                        .foregroundStyle(.primary)
                        .frame(width: 45, alignment: .leading)
                }
            }
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

private struct NumberField: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.primary)
            TextField("", value: $value, format: .number.precision(.fractionLength(0...1)))
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
            Text("unit.points")
                .foregroundStyle(.primary)
        }
    }
}
