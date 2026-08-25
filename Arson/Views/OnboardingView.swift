import AppKit
import Combine
import SwiftUI

enum OnboardingStage: Hashable {
    case welcome
    case permissionRationale
    case waitingForPermission
    case permissionGranted
}

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage = OnboardingStage.welcome
    @State private var isTroubleshootingExpanded = false
    @AccessibilityFocusState private var focusedStage: OnboardingStage?

    private let permissionRefreshTimer = Timer.publish(
        every: 0.75,
        on: .main,
        in: .common
    ).autoconnect()

    let onComplete: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                stageContent
                    .id(stage)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            model.permissions.refresh()
            focusCurrentStage()
        }
        .onChange(of: stage) { _, _ in
            focusCurrentStage()
        }
        .onChange(of: model.permissions.isTrusted) { _, isTrusted in
            guard isTrusted, stage == .waitingForPermission else { return }
            move(to: .permissionGranted)
            announcePermissionGranted()
        }
        .onReceive(permissionRefreshTimer) { _ in
            guard stage == .waitingForPermission else { return }
            model.permissions.refresh()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            guard stage == .waitingForPermission else { return }
            model.permissions.refresh()
        }
    }

    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case .welcome:
            welcomePage
        case .permissionRationale:
            permissionRationalePage
        case .waitingForPermission:
            waitingForPermissionPage
        case .permissionGranted:
            permissionGrantedPage
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 0) {
            onboardingHeader(
                symbolName: "rectangle.on.rectangle",
                title: "onboarding.title",
                description: "onboarding.description",
                stage: .welcome,
                symbolStyle: AnyShapeStyle(.tint)
            )

            HStack(spacing: 10) {
                Button("onboarding.later", action: onComplete)
                Button("onboarding.getStarted") {
                    model.permissions.refresh()
                    move(
                        to: model.permissions.isTrusted
                            ? .permissionGranted
                            : .permissionRationale
                    )
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 28)
        }
        .onboardingPageLayout()
        .accessibilityIdentifier("onboardingWelcome")
    }

    private var permissionRationalePage: some View {
        VStack(spacing: 0) {
            onboardingHeader(
                symbolName: "hand.raised.fill",
                title: "onboarding.permissionRationaleTitle",
                description: "onboarding.permissionDescription",
                stage: .permissionRationale,
                symbolStyle: AnyShapeStyle(.tint)
            )

            Label("onboarding.permissionPrivacy", systemImage: "lock.shield")
                .font(.callout)
                .labelIconToTitleSpacing(6)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)

            Button("onboarding.continue") {
                beginPermissionRequest()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .padding(.top, 28)
        }
        .onboardingPageLayout()
        .accessibilityIdentifier("onboardingPermissionRationale")
    }

    private var waitingForPermissionPage: some View {
        VStack(spacing: 0) {
            onboardingHeader(
                symbolName: "gearshape.2.fill",
                title: "onboarding.permissionWaitingTitle",
                description: "onboarding.permissionWaitingDescription",
                stage: .waitingForPermission,
                symbolStyle: AnyShapeStyle(.tint)
            )

            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("onboarding.permissionWaitingStatus")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("onboardingPermissionStatus")
            .padding(.top, 20)

            VStack(spacing: 10) {
                Button("permission.openSettings") {
                    model.permissions.openSystemSettings()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

                Button("onboarding.continueWithoutPermission", action: onComplete)
                    .buttonStyle(.borderless)
            }
            .padding(.top, 28)

            DisclosureGroup(
                "onboarding.permissionTroubleshooting",
                isExpanded: $isTroubleshootingExpanded
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("onboarding.permissionPath")
                        .font(.callout)
                        .textSelection(.enabled)
                    Text("onboarding.permissionFallback")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 30)
            .focusEffectDisabled()
            .accessibilityIdentifier("onboardingPermissionTroubleshooting")
        }
        .onboardingPageLayout()
        .accessibilityIdentifier("onboardingPermissionWaiting")
    }

    private var permissionGrantedPage: some View {
        VStack(spacing: 0) {
            onboardingHeader(
                symbolName: "checkmark.circle.fill",
                title: "onboarding.permissionReadyTitle",
                description: "onboarding.permissionReadyDescription",
                stage: .permissionGranted,
                symbolStyle: AnyShapeStyle(.green)
            )

            Button("onboarding.done", action: onComplete)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 28)
        }
        .onboardingPageLayout()
        .accessibilityIdentifier("onboardingPermissionGranted")
    }

    private func onboardingHeader(
        symbolName: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        stage: OnboardingStage,
        symbolStyle: AnyShapeStyle
    ) -> some View {
        VStack(spacing: 0) {
            Image(systemName: symbolName)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(symbolStyle)
                .accessibilityHidden(true)

            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusedStage, equals: stage)
                .padding(.top, 22)

            Text(description)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
    }

    private func beginPermissionRequest() {
        model.permissions.refresh()
        guard !model.permissions.isTrusted else {
            move(to: .permissionGranted)
            announcePermissionGranted()
            return
        }

        move(to: .waitingForPermission)
        Task { @MainActor in
            await Task.yield()
            model.permissions.requestAccess()
        }
    }

    private func move(to newStage: OnboardingStage) {
        if reduceMotion {
            stage = newStage
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                stage = newStage
            }
        }
    }

    private func focusCurrentStage() {
        let currentStage = stage
        Task { @MainActor in
            await Task.yield()
            focusedStage = currentStage
        }
    }

    private func announcePermissionGranted() {
        NSAccessibility.post(
            element: NSApp!,
            notification: .announcementRequested,
            userInfo: [
                .announcement: String(localized: "onboarding.permissionReadyTitle"),
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }
}

private extension View {
    func onboardingPageLayout() -> some View {
        frame(maxWidth: 480)
            .padding(.horizontal, 48)
            .padding(.vertical, 40)
    }
}
