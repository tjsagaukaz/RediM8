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

                    if appState.isStealthModeEnabled {
                        StealthModeIndicatorView()
                    }

                    if appState.settings.privacy.isAnonymousModeEnabled {
                        HiddenModeIndicatorView()
                    }

                    todayReadinessCard

                    todayNextStepCard

                    if let safeModeSummary = viewModel.safeModeSummary {
                        safeModeCard(summary: safeModeSummary)
                    } else {
                        todayLocalStatusCard
                    }

                    if !appState.profile.isProfileFullyComplete {
                        ProfileCompletionCard(profile: appState.profile) { step in
                            router.openProfileStep(step)
                        }
                    }

                    quickAccessHubCard

                    homeStatusRail
                    officialAlertsPanel

                    if appState.emergencyUnlockState.isVisible {
                        emergencyUnlockCard
                    }

                    if shouldShowOperationalInsights {
                        CollapsiblePanelCard(
                            title: L10n.tr("home.section.operational_insights.title", "Operational Insights"),
                            subtitle: L10n.tr(
                                "home.section.operational_insights.subtitle",
                                "Forgotten items, expiry reminders, and water guidance."
                            ),
                            accent: ColorTheme.textTertiary,
                            isExpanded: $isShowingOperationalInsights
                        ) {
                            operationalInsightsContent
                        }
                    }

                    CollapsiblePanelCard(
                        title: L10n.tr("home.section.priority_situations.title", "Priority Situations"),
                        subtitle: viewModel.priorityModeSummary?.subtitle ?? L10n.tr(
                            "home.section.priority_situations.subtitle",
                            "Activate a live situation to surface the right actions."
                        ),
                        accent: ColorTheme.textTertiary,
                        isExpanded: $isShowingPriorityTools
                    ) {
                        priorityModeCard
                    }

                    if viewModel.isBushfireModeEnabled {
                        CollapsiblePanelCard(
                            title: L10n.tr("home.section.bushfire_readiness.title", "Bushfire Readiness"),
                            subtitle: L10n.tr(
                                "home.section.bushfire_readiness.subtitle",
                                "Bushfire scenario preparation and checklists."
                            ),
                            accent: ColorTheme.textTertiary,
                            isExpanded: $isShowingBushfireReadiness
                        ) {
                            bushfireModeCard
                        }
                    }

                    compactProBanner
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
}
