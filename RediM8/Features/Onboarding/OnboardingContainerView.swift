import SwiftUI

struct OnboardingContainerView: View {
    private let appState: AppState
    @StateObject private var viewModel: OnboardingViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(appState: appState))
    }

    var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    currentStepContent
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 120)
                        .id(viewModel.currentStep)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.92), value: viewModel.currentStep)
    }

    private var onboardingBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ColorTheme.background,
                    Color(hex: "07131A"),
                    ColorTheme.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(ColorTheme.dividerSubtle)
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 130, y: -260)

            Circle()
                .fill(ColorTheme.dividerSubtle)
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -140, y: -120)

            Circle()
                .fill(ColorTheme.dividerSubtle)
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: 120, y: 320)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STEP \(viewModel.currentStepNumber) OF \(OnboardingViewModel.Step.allCases.count)")
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text(viewModel.currentStep.heroTitle)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(ColorTheme.text)
                }

                Spacer()

                if viewModel.canDismiss {
                    Button("Close") {
                        appState.isShowingOnboarding = false
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .frame(width: 108)
                }
            }

            Text(viewModel.currentStep.heroSubtitle)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: viewModel.progressValue)
                .tint(ColorTheme.info)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(ColorTheme.background.opacity(0.92))
    }

    @ViewBuilder
    private var currentStepContent: some View {
        switch viewModel.currentStep {
        case .welcome:
            WelcomeView(viewModel: viewModel)
        case .safety:
            SafetyNoticeView(viewModel: viewModel)
        case .scenarios:
            ScenarioSelectionView(viewModel: viewModel)
        case .launch:
            OnboardingLaunchView(viewModel: viewModel)
        }
    }

    private var footer: some View {
        ThumbActionDock {
            HStack(spacing: 12) {
                if viewModel.canGoBack {
                    Button("Back") {
                        viewModel.back()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .frame(maxWidth: 150)
                }

                Button(viewModel.currentStepActionTitle) {
                    if viewModel.currentStep == .launch {
                        viewModel.finish()
                    } else {
                        viewModel.next()
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
    }
}

private extension OnboardingViewModel.Step {
    var heroTitle: String {
        switch self {
        case .welcome:
            "System Setup"
        case .safety:
            "Authority"
        case .scenarios:
            "Operational Context"
        case .launch:
            "Activation"
        }
    }

    var heroSubtitle: String {
        switch self {
        case .welcome:
            "Takes under a minute. Set your baseline. Refine later."
        case .safety:
            "Official warnings and emergency services outrank this system."
        case .scenarios:
            "Select the situations RediM8 should configure first."
        case .launch:
            "Baseline configured. Activate the system."
        }
    }
}

private struct SafetyNoticeView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModeHeroCard(
                eyebrow: "Authority",
                title: "RediM8 is a support system, not the authority.",
                subtitle: "Follow official warnings, emergency services, and medical advice at all times.",
                iconName: "shield",
                accent: ColorTheme.textTertiary,
                backgroundAssetName: "marketing_coast_storm",
                backgroundImageOffset: CGSize(width: 8, height: 0)
            ) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Official instructions first", tone: .verified),
                    TrustPillItem(title: "Signal can fail", tone: .caution),
                    TrustPillItem(title: "Maps can be stale", tone: .info)
                ])
            }

            PanelCard(title: "Before You Rely On This", subtitle: "Required before initial activation.") {
                VStack(alignment: .leading, spacing: 12) {
                    safetyLine("Official warnings and emergency crews outrank any guidance shown here.")
                    safetyLine("Nearby signal, mesh delivery, and community reports can fail, lag, or be wrong.")
                    safetyLine("Offline maps and cached data help, but can still be incomplete or out of date.")
                }
            }

            PanelCard(title: "Acknowledgement", subtitle: "Recorded once on this device.") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: viewModel.hasAcknowledgedSafetyNotice ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                        .foregroundStyle(viewModel.hasAcknowledgedSafetyNotice ? ColorTheme.ready : ColorTheme.info)
                        .frame(width: 20, height: 20)

                    Text(viewModel.hasAcknowledgedSafetyNotice
                         ? "Operating limits acknowledged on this device."
                         : "Select I Understand to record this acknowledgement. You can reopen the notice later from Settings.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ColorTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func safetyLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ColorTheme.textTertiary)
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
