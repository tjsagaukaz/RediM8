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
        case .household:
            HouseholdSetupView(viewModel: viewModel)
        case .medicalProfile:
            EmergencyMedicalInfoSetupView(viewModel: viewModel)
        case .supplies:
            SuppliesSetupView(viewModel: viewModel)
        case .trust:
            GearChecklistView(viewModel: viewModel, locationService: appState.locationService)
        case .result:
            PrepScoreResultView(
                viewModel: viewModel,
                locationPermissionState: appState.permissionsManager.locationPermissionState(for: appState.locationService.authorizationStatus)
            )
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
                    if viewModel.currentStep == .result {
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
            "Fast Setup"
        case .safety:
            "Safety"
        case .scenarios:
            "Risks"
        case .household:
            "Household"
        case .medicalProfile:
            "Health Info"
        case .supplies:
            "Supplies"
        case .trust:
            "Defaults"
        case .result:
            "Ready"
        }
    }

    var heroSubtitle: String {
        switch self {
        case .welcome:
            "We only need the basics. Everything here can be changed later."
        case .safety:
            "Official instructions always outrank the app."
        case .scenarios:
            "Pick the situations RediM8 should prioritize first."
        case .household:
            "Save one route, one contact, and a simple household count."
        case .medicalProfile:
            "Optional. Add only details that change urgent care."
        case .supplies:
            "Use rough numbers so RediM8 can show real gaps."
        case .trust:
            "Choose privacy, battery, and grab-and-go defaults."
        case .result:
            "You now have a usable baseline and can launch."
        }
    }
}

private struct SafetyNoticeView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModeHeroCard(
                eyebrow: "Safety",
                title: "Use RediM8 as support, not authority.",
                subtitle: "It helps you prepare and act faster, but official alerts, emergency services, and professional medical advice come first.",
                iconName: "shield",
                accent: ColorTheme.textTertiary,
                backgroundAssetName: "marketing_coast_storm",
                backgroundImageOffset: CGSize(width: 8, height: 0)
            ) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Official instructions first", tone: .verified),
                    TrustPillItem(title: "Signal is assistive", tone: .caution),
                    TrustPillItem(title: "Maps can be stale", tone: .info)
                ])
            }

            PanelCard(title: "Read This Once", subtitle: "The short version before you rely on the app.") {
                VStack(alignment: .leading, spacing: 12) {
                    safetyLine("Official warnings and emergency crews outrank anything shown here.")
                    safetyLine("Nearby signal, mesh delivery, and community reports can fail, lag, or be wrong.")
                    safetyLine("Offline maps and cached data help, but they can still be incomplete or out of date.")
                }
            }

            PanelCard(title: "Acknowledgement", subtitle: "You only need to do this once on this device.") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: viewModel.hasAcknowledgedSafetyNotice ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                        .foregroundStyle(viewModel.hasAcknowledgedSafetyNotice ? ColorTheme.ready : ColorTheme.info)
                        .frame(width: 20, height: 20)

                    Text(viewModel.hasAcknowledgedSafetyNotice
                         ? "Safety notice already acknowledged."
                         : "Tap I Understand to continue. You can reopen this later from Settings.")
                        .font(.subheadline)
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
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EmergencyMedicalInfoSetupView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 10)
    ]

    private var preview: String? {
        EmergencyMedicalInfo(
            criticalConditions: Array(viewModel.emergencyMedicalConditions),
            severeAllergies: viewModel.severeAllergies,
            otherCriticalCondition: viewModel.otherCriticalCondition,
            bloodType: viewModel.bloodType,
            emergencyMedication: viewModel.emergencyMedication
        ).broadcastSummary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModeHeroCard(
                eyebrow: "Optional",
                title: "Add only critical health details.",
                subtitle: "Skip this unless it changes urgent care or evacuation help. This is not a full medical history.",
                iconName: "first_aid",
                accent: ColorTheme.textTertiary,
                backgroundAssetName: "vault_essentials",
                backgroundImageOffset: CGSize(width: 10, height: 0)
            ) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Optional", tone: .neutral),
                    TrustPillItem(title: "Local only", tone: .verified),
                    TrustPillItem(title: "Shared only by choice", tone: .info)
                ])
            }

            PanelCard(title: "Critical Details", subtitle: "Only add information a helper may need immediately.") {
                VStack(alignment: .leading, spacing: 14) {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(CriticalMedicalCondition.allCases) { condition in
                            Button {
                                if viewModel.emergencyMedicalConditions.contains(condition) {
                                    viewModel.emergencyMedicalConditions.remove(condition)
                                } else {
                                    viewModel.emergencyMedicalConditions.insert(condition)
                                }
                            } label: {
                                Text(condition.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(ColorTheme.text)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        viewModel.emergencyMedicalConditions.contains(condition)
                                            ? ColorTheme.danger.opacity(0.18)
                                            : Color.black.opacity(0.2),
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                (viewModel.emergencyMedicalConditions.contains(condition) ? ColorTheme.danger : ColorTheme.divider).opacity(0.28),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    TextField("Severe allergies", text: $viewModel.severeAllergies, axis: .vertical)
                        .textFieldStyle(TacticalTextFieldStyle())

                    TextField("Emergency medication", text: $viewModel.emergencyMedication, axis: .vertical)
                        .textFieldStyle(TacticalTextFieldStyle())

                    TextField("Blood type (optional)", text: $viewModel.bloodType)
                        .textFieldStyle(TacticalTextFieldStyle())

                    TextField("Other critical condition", text: $viewModel.otherCriticalCondition, axis: .vertical)
                        .textFieldStyle(TacticalTextFieldStyle())

                    Text("Leave this blank and RediM8 will skip it for now.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textFaint)
                }
            }

            if let preview {
                PanelCard(title: "Sharing Preview", subtitle: "This is only shared if you explicitly choose to include it in a signal.") {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.text)
                        .padding(12)
                        .background(ColorTheme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}
