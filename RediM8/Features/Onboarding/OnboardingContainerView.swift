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
                .fill(ColorTheme.info.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 130, y: -260)

            Circle()
                .fill(ColorTheme.accent.opacity(0.1))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -140, y: -120)

            Circle()
                .fill(ColorTheme.warning.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: 120, y: 320)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("REDIM8 SETUP")
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.info)
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
                    .frame(width: 110)
                }
            }

            Text(viewModel.currentStep.heroSubtitle)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            TrustPillGroup(items: viewModel.currentStep.headerPills)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Step \(viewModel.currentStepNumber) of \(OnboardingViewModel.Step.allCases.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ColorTheme.textFaint)
                    Spacer()
                    Text("\(Int((viewModel.progressValue * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ColorTheme.textFaint)
                }

                ProgressView(value: viewModel.progressValue)
                    .tint(ColorTheme.info)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .background(ColorTheme.background.opacity(0.9))
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
            "Calm, Honest Setup"
        case .safety:
            "Safety First"
        case .scenarios:
            "Choose What Matters"
        case .household:
            "Plan For Real People"
        case .medicalProfile:
            "Critical Health Info"
        case .supplies:
            "Snapshot Your Readiness"
        case .trust:
            "Set Safer Defaults"
        case .result:
            "Launch With Clarity"
        }
    }

    var heroSubtitle: String {
        switch self {
        case .welcome:
            "RediM8 works best when the first-run flow is simple, local, and trustworthy."
        case .safety:
            "Read the scope once, acknowledge it once, and reopen it later anytime from Settings."
        case .scenarios:
            "We’ll tune targets, maps, and Priority Mode around the situations you actually face."
        case .household:
            "Save the details that matter when leaving quickly: people, pets, route, contact, and meeting point."
        case .medicalProfile:
            "Add only the critical conditions, severe allergies, blood type, or medication details that matter if someone is helping you urgently."
        case .supplies:
            "Use rough numbers now. You can refine food, water, fuel, and power later in Plan."
        case .trust:
            "Choose privacy, location, and battery behaviour before you rely on them under stress."
        case .result:
            "Here’s what RediM8 can already do for you, and what to tighten next."
        }
    }

    var headerPills: [TrustPillItem] {
        switch self {
        case .welcome:
            [
                TrustPillItem(title: "Offline first", tone: .verified),
                TrustPillItem(title: "Local only docs", tone: .info),
                TrustPillItem(title: "Assistive signal", tone: .caution)
            ]
        case .safety:
            [
                TrustPillItem(title: "Not a replacement", tone: .caution),
                TrustPillItem(title: "Official alerts first", tone: .verified),
                TrustPillItem(title: "Review later in Settings", tone: .info)
            ]
        case .scenarios:
            [
                TrustPillItem(title: "Priority tuned", tone: .info),
                TrustPillItem(title: "Map defaults", tone: .neutral)
            ]
        case .household:
            [
                TrustPillItem(title: "Route saved offline", tone: .verified),
                TrustPillItem(title: "Meeting point ready", tone: .info)
            ]
        case .medicalProfile:
            [
                TrustPillItem(title: "Optional", tone: .neutral),
                TrustPillItem(title: "Local only", tone: .verified),
                TrustPillItem(title: "Shared only by choice", tone: .info)
            ]
        case .supplies:
            [
                TrustPillItem(title: "Targets, not promises", tone: .caution),
                TrustPillItem(title: "Edit later", tone: .neutral)
            ]
        case .trust:
            [
                TrustPillItem(title: "Approximate by default", tone: .verified),
                TrustPillItem(title: "Delivery not guaranteed", tone: .caution)
            ]
        case .result:
            [
                TrustPillItem(title: "Ready to launch", tone: .verified),
                TrustPillItem(title: "Review later anytime", tone: .neutral)
            ]
        }
    }
}

private struct SafetyNoticeView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModeHeroCard(
                eyebrow: "Safety & Limitations",
                title: "Assistive, not authoritative.",
                subtitle: "RediM8 helps you prepare, navigate, and understand local conditions, but it should never outrank official instructions or professional medical help.",
                iconName: "shield",
                accent: ColorTheme.warning
            ) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Official instructions first", tone: .verified),
                    TrustPillItem(title: "Mesh delivery not guaranteed", tone: .caution),
                    TrustPillItem(title: "Community reports unverified", tone: .info)
                ])
            }

            PanelCard(title: "What RediM8 Is", subtitle: "The short version Apple reviewers and users both need to see clearly.") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(TrustLayer.safetyLimitationsLines.enumerated()), id: \.offset) { _, line in
                        safetyLine(line)
                    }
                }
            }

            PanelCard(title: "What Can Change Fast", subtitle: "These tools help, but conditions and information can move faster than any app.") {
                VStack(alignment: .leading, spacing: 12) {
                    safetyLine(TrustLayer.mapFreshnessNotice)
                    safetyLine(TrustLayer.signalAssistiveReminder)
                    safetyLine(TrustLayer.signalDeliveryNotice)
                }
            }

            PanelCard(title: "Keep This Handy", subtitle: "You can reopen the same notice later from Settings > Safety.") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: viewModel.hasAcknowledgedSafetyNotice ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                        .foregroundStyle(viewModel.hasAcknowledgedSafetyNotice ? ColorTheme.ready : ColorTheme.info)
                        .frame(width: 20, height: 20)

                    Text(viewModel.hasAcknowledgedSafetyNotice
                         ? "Safety notice already acknowledged on this device."
                         : "Tap I Understand once to continue. RediM8 will not nag you with repeated safety popups afterward.")
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
                .foregroundStyle(ColorTheme.warning)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModeHeroCard(
                eyebrow: "Emergency Medical Info",
                title: "Save only what matters in a life-threatening moment.",
                subtitle: "This is not a full medical history. Keep it to critical conditions, severe allergies, blood type, and medication details someone may need if you trigger a help alert.",
                iconName: "first_aid",
                accent: ColorTheme.danger
            ) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Optional", tone: .neutral),
                    TrustPillItem(title: "Local only", tone: .verified),
                    TrustPillItem(title: "Shared only by choice", tone: .info)
                ])
            }

            PanelCard(title: "Critical Health Information", subtitle: "Add only details that change urgent care or evacuation help") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Do you want to add critical medical information?")
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)

                    Text(TrustLayer.emergencyMedicalInfoScopeNotice)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textMuted)

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

                    TextField("Blood type (optional)", text: $viewModel.bloodType)
                        .textFieldStyle(TacticalTextFieldStyle())

                    TextField("Emergency medication or location", text: $viewModel.emergencyMedication, axis: .vertical)
                        .textFieldStyle(TacticalTextFieldStyle())

                    TextField("Other critical condition", text: $viewModel.otherCriticalCondition, axis: .vertical)
                        .textFieldStyle(TacticalTextFieldStyle())
                }
            }

            PanelCard(title: "Privacy", subtitle: "Keep trust high by making sharing explicit") {
                VStack(alignment: .leading, spacing: 12) {
                    safetyLine(TrustLayer.emergencyMedicalInfoPrivacyNotice)

                    if let preview = EmergencyMedicalInfo(
                        criticalConditions: Array(viewModel.emergencyMedicalConditions),
                        severeAllergies: viewModel.severeAllergies,
                        otherCriticalCondition: viewModel.otherCriticalCondition,
                        bloodType: viewModel.bloodType,
                        emergencyMedication: viewModel.emergencyMedication
                    ).broadcastSummary {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("IF YOU CHOOSE TO SHARE")
                                .font(RediTypography.caption)
                                .foregroundStyle(ColorTheme.danger)
                            Text(preview)
                                .font(.subheadline)
                                .foregroundStyle(ColorTheme.text)
                        }
                        .padding(12)
                        .background(ColorTheme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        Text("Leave this blank and RediM8 will skip it for now.")
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textMuted)
                    }
                }
            }
        }
    }

    private func safetyLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ColorTheme.danger)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
