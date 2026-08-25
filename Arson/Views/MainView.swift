import SwiftUI

struct MainView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var selection: PresetSelection

    var body: some View {
        PresetDetailView(model: model, store: model.store, selection: selection)
    }
}

private struct PresetDetailView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: PresetStore
    @ObservedObject var selection: PresetSelection

    var body: some View {
        Group {
            if let selectedID = selection.selectedID,
               let index = store.bindingIndex(for: selectedID) {
                PresetEditorView(
                    preset: $store.presets[index],
                    hotKeyError: model.hotKeyErrors[store.presets[index].id]?.errorDescription
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
        .onAppear {
            if selection.selectedID == nil {
                selection.selectedID = store.presets.first?.id
            }
        }
    }
}
