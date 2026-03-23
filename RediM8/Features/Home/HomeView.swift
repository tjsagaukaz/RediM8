import SwiftUI

struct HomeView: View {
    @Environment(\.openURL) var openURL
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @StateObject var viewModel: HomeViewModel
    let appState: AppState
    @ObservedObject var router: NavigationRouter
    private let scrollToTopRequestID: Int
    let monetizationCatalog = RediM8MonetizationCatalog.launch

    @State var activeSheet: HomeSheet?
    @State var isShowingOperationalInsights = false
    @State var isShowingPriorityTools = false
    @State var isShowingBushfireReadiness = false
    @State var isShowingOfficialAlerts = true
    @State var isShowingQuickAccess = false
    @State var selectedOfficialAlertScope: HomeOfficialAlertScope = .local
    @State var selectedOfficialAlertJurisdiction: AustralianJurisdiction?

    let quickActionColumns = [
        GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 12)
    ]

    let priorityColumns = [
        GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 10)
    ]

    let decisionColumns = [
        GridItem(.adaptive(minimum: 156, maximum: 260), spacing: 12)
    ]

    init(
        appState: AppState,
        router: NavigationRouter,
        scrollToTopRequestID: Int,
        disablesAutomaticAlertRefresh: Bool = false
    ) {
        self.appState = appState
        self.router = router
        self.scrollToTopRequestID = scrollToTopRequestID
        _viewModel = StateObject(
            wrappedValue: HomeViewModel(
                appState: appState,
                disablesAutomaticAlertRefresh: disablesAutomaticAlertRefresh
            )
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: RediSpacing.section) {
                    Color.clear
                        .frame(height: 0)
                        .id(HomeScrollAnchor.top)

                    if isElevatedMode {
                        elevatedModeContent
                    } else {
                        calmModeContent
                    }
                }
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.screen)
                .padding(.bottom, RediLayout.commandDockContentInset)
            }
            .accessibilityIdentifier("home.root")
            .scrollIndicators(.hidden)
            .onChange(of: scrollToTopRequestID) { _, _ in
                scrollToHomeTop(using: proxy)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                RediM8Wordmark(
                    iconSize: 24,
                    titleFont: .system(size: 18, weight: .bold)
                )
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .settings
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityIdentifier("home.settings")
            }
        }
        .background(Color.clear)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .readinessReport:
                NavigationStack {
                    ReadinessReportView(
                        report: viewModel.readinessReport,
                        isProUser: appState.isProUser,
                        onShare: viewModel.shareReadinessReportItems,
                        onSavePDF: viewModel.saveReadinessReportPDF,
                        onSendToFamily: viewModel.sendToFamilyItems
                    )
                }
                .rediSheetPresentation()
            case .settings:
                NavigationStack {
                    SettingsView(appState: appState)
                }
                .rediSheetPresentation()
            case .pro:
                NavigationStack {
                    RediM8ProView(storeKitService: appState.storeKitService, emergencyUnlockState: appState.emergencyUnlockState)
                }
                .rediSheetPresentation()
            case let .assistant(context):
                NavigationStack {
                    AssistantView(
                        appState: appState,
                        initialQuery: context.initialQuery,
                        sourceLabel: context.sourceLabel
                    )
                }
                .rediSheetPresentation()
            }
        }
    }

    enum HomeSheet: Identifiable {
        case readinessReport
        case settings
        case pro
        case assistant(AssistantLaunchContext)

        var id: String {
            switch self {
            case .readinessReport: "readinessReport"
            case .settings: "settings"
            case .pro: "pro"
            case .assistant: "assistant"
            }
        }
    }

    private enum HomeScrollAnchor {
        static let top = "home-scroll-top"
    }

    private func scrollToHomeTop(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(RediMotion.selection) {
                proxy.scrollTo(HomeScrollAnchor.top, anchor: .top)
            }
        }
    }

    // MARK: - Calm Mode (Day-to-Day Dashboard)

    /// True when the user is still in early setup.
    /// Graduates when ANY of these become true:
    /// - Prep score reaches 30% (data-based)
    /// - Profile is over 50% complete (action-based)
    /// - More than 3 days since onboarding (time-based)
    /// This prevents dumping full system complexity on a user who completed
    /// profile fields quickly but hasn't internalized the system yet.
    var isEarlyStageUser: Bool {
        guard viewModel.prepScore.overall < 30 else { return false }
        guard appState.profile.profileCompletionFraction < 0.5 else { return false }

        if let onboardedAt = appState.profile.lastCompletedOnboardingAt {
            let daysSinceOnboarding = Date.now.timeIntervalSince(onboardedAt) / 86400
            if daysSinceOnboarding > 3 { return false }
        }

        return true
    }

    @ViewBuilder
    var calmModeContent: some View {
        if appState.isStealthModeEnabled {
            StealthModeIndicatorView()
        }

        if appState.settings.privacy.isAnonymousModeEnabled {
            HiddenModeIndicatorView()
        }

        if isEarlyStageUser {
            earlyStageContent
        } else {
            operationalContent
        }
    }

    // MARK: - Early Stage (First 5 Minutes)

    /// Encouraging, progress-oriented dashboard for new users.
    /// No deficit metrics. No "0%". Just guided next steps.
    @ViewBuilder
    private var earlyStageContent: some View {
        earlyStageWelcomeCard

        todayNextStepCard

        ProfileCompletionCard(profile: appState.profile) { step in
            router.openProfileStep(step)
        }

        todayLocalStatusCard

        officialAlertsPanel

        quickAccessHubCard
    }

    private var earlyStageWelcomeCard: some View {
        CommandPanel(eyebrow: "Getting Started") {
            VStack(alignment: .leading, spacing: RediSpacing.content) {
                Text("Let's get you ready")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(ColorTheme.text)

                Text("Complete a few quick steps to build your emergency baseline. RediM8 gets more useful with every detail you add.")
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                let completedSteps = appState.profile.profileCompletionSteps.filter(\.isComplete).count
                let totalSteps = appState.profile.profileCompletionSteps.count

                HStack(spacing: RediSpacing.content) {
                    ReadinessMeter(
                        value: appState.profile.profileCompletionFraction,
                        tint: ColorTheme.accent,
                        height: 6
                    )

                    Text("\(completedSteps)/\(totalSteps)")
                        .font(RediTypography.data)
                        .foregroundStyle(ColorTheme.accent)
                        .layoutPriority(1)
                }

                TrustPillGroup(items: [
                    TrustPillItem(title: "Works offline now", tone: .verified),
                    TrustPillItem(title: "Emergency tools ready", tone: .verified),
                    TrustPillItem(title: "Refine anytime", tone: .info)
                ])
            }
        }
    }

    // MARK: - Operational Mode (Established Users)

    /// Full system-truth dashboard for users who have built their baseline.
    @ViewBuilder
    private var operationalContent: some View {
        todayReadinessCard

        todayNextStepCard

        todayLocalStatusCard

        if !appState.profile.isProfileFullyComplete {
            ProfileCompletionCard(profile: appState.profile) { step in
                router.openProfileStep(step)
            }
        }

        quickAccessHubCard

        officialAlertsPanel

        if appState.emergencyUnlockState.isVisible {
            emergencyUnlockCard
        }

        if hasAdvancedContent {
            CollapsiblePanelCard(
                title: "Advanced",
                subtitle: "Insights, priority situations, and scenario readiness.",
                accent: ColorTheme.textTertiary,
                isExpanded: $isShowingOperationalInsights
            ) {
                advancedSectionContent
            }
        }

        compactProBanner
    }

    private var hasAdvancedContent: Bool {
        shouldShowOperationalInsights || viewModel.priorityModeSummary != nil || viewModel.isBushfireModeEnabled
    }

    @ViewBuilder
    private var advancedSectionContent: some View {
        if shouldShowOperationalInsights {
            operationalInsightsContent
        }

        priorityModeCard

        if viewModel.isBushfireModeEnabled {
            bushfireModeCard
        }
    }
}
