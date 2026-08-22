import SwiftUI

struct MainView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        PresetManagerView(model: model, store: model.store)
    }
}

private struct PresetManagerView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: PresetStore
    @Environment(\.undoManager) private var undoManager
    @State private var selectedID: UUID?
    @State private var requiresUITestOnboarding = ProcessInfo.processInfo.arguments.contains("-ui-testing-reset")
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                ForEach(store.presets) { preset in
                    PresetRow(preset: preset, hasError: !model.validationMessages(for: preset).isEmpty)
                        .tag(preset.id)
                        .contextMenu {
                            Button("action.duplicate") { duplicate(preset.id) }
                            Divider()
                            Button("action.delete", role: .destructive) { delete(preset.id) }
                        }
                }
                .onMove(perform: store.move)
            }
            .navigationTitle("sidebar.presets")
            .frame(minWidth: 250)
            .toolbar {
                ToolbarItemGroup {
                    Button(action: add) {
                        Label("action.addPreset", systemImage: "plus")
                    }
                    Button(action: duplicateSelected) {
                        Label("action.duplicate", systemImage: "plus.square.on.square")
                    }
                    .disabled(selectedID == nil)
                    Button(action: deleteSelected) {
                        Label("action.delete", systemImage: "trash")
                    }
                    .disabled(selectedID == nil)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("sidebar.presets"))
        } detail: {
            if let selectedID, let index = store.bindingIndex(for: selectedID) {
                PresetEditorView(
                    preset: $store.presets[index],
                    validationMessages: model.validationMessages(for: store.presets[index])
                )
                .id(selectedID)
            } else {
                ContentUnavailableView(
                    "empty.title",
                    systemImage: "rectangle.on.rectangle.slash",
                    description: Text("empty.description")
                )
            }
        }
        .accessibilityLabel(Text("sidebar.presets"))
        .onAppear {
            if selectedID == nil { selectedID = store.presets.first?.id }
        }
        .sheet(isPresented: onboardingPresented) {
            OnboardingView {
                requiresUITestOnboarding = false
                hasCompletedOnboarding = true
            }
            .environmentObject(model)
        }
    }

    private var onboardingPresented: Binding<Bool> {
        Binding(
            get: { requiresUITestOnboarding || !hasCompletedOnboarding },
            set: {
                if !$0 {
                    requiresUITestOnboarding = false
                    hasCompletedOnboarding = true
                }
            }
        )
    }

    private func add() {
        selectedID = store.addPreset()
    }

    private func duplicate(_ id: UUID) {
        selectedID = store.duplicate(id)
    }

    private func duplicateSelected() {
        guard let selectedID else { return }
        duplicate(selectedID)
    }

    private func delete(_ id: UUID) {
        let nextSelection = store.presets.first(where: { $0.id != id })?.id
        store.delete(id, undoManager: undoManager)
        selectedID = nextSelection
    }

    private func deleteSelected() {
        guard let selectedID else { return }
        delete(selectedID)
    }
}

private struct PresetRow: View {
    let preset: Preset
    let hasError: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: hasError ? "exclamationmark.circle.fill" : "rectangle.on.rectangle")
                .foregroundStyle(.primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name.isEmpty ? String(localized: "preset.untitled") : preset.name)
                    .lineLimit(1)
                if let shortcut = preset.shortcut {
                    Text(shortcut.displayValue)
                        .font(.caption.monospaced())
                }
            }
        }
    }
}
