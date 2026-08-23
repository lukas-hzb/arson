import AppKit
import SwiftUI

struct OnboardingView: View {
    private enum Page {
        case welcome
        case permission
    }

    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = Page.welcome
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case .welcome:
                    welcomePage
                case .permission:
                    permissionPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            footer
                .padding(20)
        }
        .frame(width: 620, height: 590)
        .interactiveDismissDisabled()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: page)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.permissions.refresh()
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 58, weight: .semibold))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("onboarding.title")
                    .font(.largeTitle.bold())
                Text("onboarding.description")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 460)
            }

            VStack(alignment: .leading, spacing: 14) {
                Label("onboarding.presets", systemImage: "slider.horizontal.3")
                Label("onboarding.shortcuts", systemImage: "command")
                Label("onboarding.permissionReason", systemImage: "hand.raised.fill")
            }
            .frame(maxWidth: 460, alignment: .leading)
        }
        .padding(36)
        .transition(.opacity)
    }

    private var permissionPage: some View {
        VStack(spacing: 22) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text("onboarding.permissionTitle")
                    .font(.title.bold())
                Text("onboarding.permissionDescription")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 500)
            }

            VStack(alignment: .leading, spacing: 13) {
                InstructionRow(number: 1, text: "onboarding.permissionStep1")
                InstructionRow(number: 2, text: "onboarding.permissionStep2")
                InstructionRow(number: 3, text: "onboarding.permissionStep3")
                InstructionRow(number: 4, text: "onboarding.permissionStep4")
            }
            .frame(maxWidth: 510, alignment: .leading)

            VStack(spacing: 8) {
                Text("onboarding.permissionPath")
                    .font(.callout.monospaced())
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                Text("onboarding.permissionFallback")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 510)

            Label(
                model.permissions.isTrusted
                    ? String(localized: "permission.allowed")
                    : String(localized: "permission.missing"),
                systemImage: model.permissions.isTrusted
                    ? "checkmark.circle.fill"
                    : "exclamationmark.circle.fill"
            )
            .foregroundStyle(model.permissions.isTrusted ? .green : .orange)
            .fontWeight(.semibold)
            .accessibilityIdentifier("onboardingPermissionStatus")
        }
        .padding(30)
        .transition(.opacity)
    }

    @ViewBuilder
    private var footer: some View {
        switch page {
        case .welcome:
            HStack {
                Button("onboarding.later", action: onComplete)
                Spacer()
                Button("onboarding.continue") { page = .permission }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        case .permission:
            HStack {
                Button("onboarding.back") { page = .welcome }
                Button("onboarding.later", action: onComplete)
                Spacer()
                Button("permission.check") { model.permissions.refresh() }
                Button("permission.openSettings") { model.permissions.openSystemSettings() }
                if model.permissions.isTrusted {
                    Button("onboarding.done", action: onComplete)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("onboarding.requestAccess") { model.permissions.requestAccess() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}

private struct InstructionRow: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(number.formatted())
                .font(.caption.bold())
                .foregroundStyle(.black)
                .frame(width: 24, height: 24)
                .background(.orange, in: Circle())
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
