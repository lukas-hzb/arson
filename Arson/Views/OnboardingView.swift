import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("onboarding.title")
                    .font(.largeTitle.bold())
                Text("onboarding.description")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 430)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("onboarding.presets", systemImage: "slider.horizontal.3")
                Label("onboarding.shortcuts", systemImage: "command")
                Label("onboarding.permissionReason", systemImage: "hand.raised.fill")
            }
            .frame(maxWidth: 430, alignment: .leading)

            HStack {
                Button("onboarding.later") { onComplete() }
                Spacer()
                Button("onboarding.allow") {
                    model.permissions.requestAccess()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 540)
        .interactiveDismissDisabled()
    }
}

