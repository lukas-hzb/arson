import SwiftUI

struct MainView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var selection: PresetSelection

    var body: some View {
        PresetDetailView(model: model, store: model.store, selection: selection)
    }
}

private struct PresetDetailView: View {
    private static let currentOnboardingVersion = 1

    @ObservedObject var model: AppModel
    @ObservedObject var store: PresetStore
    @ObservedObject var selection: PresetSelection
    @State private var requiresUITestOnboarding = ProcessInfo.processInfo.arguments.contains("-ui-testing-reset")
    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0

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
        .sheet(isPresented: onboardingPresented) {
            OnboardingView {
                requiresUITestOnboarding = false
                completedOnboardingVersion = Self.currentOnboardingVersion
            }
            .environmentObject(model)
        }
    }

    private var onboardingPresented: Binding<Bool> {
        Binding(
            get: {
                requiresUITestOnboarding
                    || completedOnboardingVersion < Self.currentOnboardingVersion
            },
            set: {
                if !$0 {
                    requiresUITestOnboarding = false
                    completedOnboardingVersion = Self.currentOnboardingVersion
                }
            }
        )
    }
}
