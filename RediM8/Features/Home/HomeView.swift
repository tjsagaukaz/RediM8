import SwiftUI

struct HomeView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel: HomeViewModel
    private let appState: AppState
    @ObservedObject private var router: NavigationRouter
    private let scrollToTopRequestID: Int
    private let monetizationCatalog = RediM8MonetizationCatalog.launch

    @State private var activeSheet: HomeSheet?
    @State private var isShowingOperationalInsights = false
    @State private var isShowingPriorityTools = false
    @State private var isShowingBushfireReadiness = false
    @State private var isShowingOfficialAlerts = true
    @State private var isShowingQuickAccess = false
    @State private var selectedOfficialAlertScope: HomeOfficialAlertScope = .local
    @State private var selectedOfficialAlertJurisdiction: AustralianJurisdiction?

    init(appState: AppState, router: NavigationRouter, scrollToTopRequestID: Int) {
        self.appState = appState
        self.router = router
        self.scrollToTopRequestID = scrollToTopRequestID
        _viewModel = StateObject(wrappedValue: HomeViewModel(appState: appState))
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

                    // MARK: — GLANCE ZONE (above fold)

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

                    // MARK: — TAP ZONE (primary actions)

                    quickAccessHubCard

                    // MARK: — BROWSE ZONE (progressive detail)

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

    private enum HomeSheet: Identifiable {
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

    private let quickActionColumns = [
        GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 12)
    ]

    private let priorityColumns = [
        GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 10)
    ]

    private let decisionColumns = [
        GridItem(.adaptive(minimum: 156, maximum: 260), spacing: 12)
    ]

    private let preparednessColumns = [
        GridItem(.adaptive(minimum: 132, maximum: 220), spacing: 12)
    ]

    private let todayStatusColumns = [
        GridItem(.adaptive(minimum: 110, maximum: 220), spacing: 12)
    ]

    private var shouldShowOperationalInsights: Bool {
        !viewModel.forgottenItems.isEmpty || viewModel.shouldShowExpiryReminders || viewModel.shouldShowWaterSourceGuidance
    }

    private var pricingSummaryText: String {
        guard appState.storeKitService.hasLoadedAllProducts else {
            return appState.storeKitService.errorMessage ?? L10n.tr(
                "home.pro.pricing.loading",
                "Pricing loads from the App Store before checkout."
            )
        }

        let monthly = appState.storeKitService.displayPrice(for: .monthly) ?? L10n.tr("common.value.unavailable", "—")
        let annual = appState.storeKitService.displayPrice(for: .annual) ?? L10n.tr("common.value.unavailable", "—")
        let lifetime = appState.storeKitService.displayPrice(for: .lifetime) ?? L10n.tr("common.value.unavailable", "—")
        return L10n.format(
            "home.pro.pricing.summary",
            "%1$@/mo • %2$@/yr • %3$@ lifetime",
            monthly,
            annual,
            lifetime
        )
    }

    private var effectiveOfficialAlertJurisdiction: AustralianJurisdiction? {
        selectedOfficialAlertJurisdiction
            ?? viewModel.defaultOfficialAlertJurisdiction
            ?? viewModel.availableOfficialAlertJurisdictions.first
    }

    private var selectedOfficialAlertSummary: OfficialAlertHomeSummary {
        viewModel.officialAlertSummary(
            for: selectedOfficialAlertScope,
            jurisdiction: effectiveOfficialAlertJurisdiction
        )
    }

    private var selectedOfficialAlerts: [OfficialAlert] {
        viewModel.officialAlerts(
            for: selectedOfficialAlertScope,
            jurisdiction: effectiveOfficialAlertJurisdiction
        )
    }

    private var officialAlertsPanelSubtitle: String {
        switch selectedOfficialAlertScope {
        case .local:
            return L10n.tr(
                "home.official_alerts.panel.subtitle.local",
                "Warnings matched to your area and current coverage."
            )
        case .state:
            return L10n.tr(
                "home.official_alerts.panel.subtitle.state",
                "Check a state or territory feed for family and travel context."
            )
        case .australia:
            return L10n.tr(
                "home.official_alerts.panel.subtitle.australia",
                "Scan the national warning picture across cached official feeds."
            )
        }
    }

    private var officialAlertScopeOptions: [PremiumSegmentedControlOption<HomeOfficialAlertScope>] {
        HomeOfficialAlertScope.allCases.map { scope in
            PremiumSegmentedControlOption(
                segmentID: scope,
                title: scope.title,
                detail: scope.detail,
                iconName: scope.iconName,
                accent: officialAlertToneColor(selectedOfficialAlertSummary.tone)
            )
        }
    }

    private var homeStatusRail: some View {
        SystemStatusRail(items: homeStatusItems, accent: ColorTheme.accent)
    }

    private var officialAlertsPanel: some View {
        CollapsiblePanelCard(
            title: L10n.tr("home.official_alerts.panel.title", "Official Alerts"),
            subtitle: officialAlertsPanelSubtitle,
            accent: officialAlertToneColor(selectedOfficialAlertSummary.tone),
            isExpanded: $isShowingOfficialAlerts
        ) {
            officialAlertsCardContent
        }
    }

    private var homeStatusItems: [OperationalStatusItem] {
        [
            OperationalStatusItem(
                iconName: "warning",
                label: L10n.tr("home.status.official_alerts.label", "Official Alerts"),
                value: officialAlertRailValue,
                tone: operationalTone(for: viewModel.officialAlertSummary.tone)
            ),
            OperationalStatusItem(
                iconName: "eye.slash.fill",
                label: L10n.tr("home.status.hidden_mode.label", "Hidden Mode"),
                value: appState.settings.privacy.isAnonymousModeEnabled
                    ? L10n.tr("common.on", "On")
                    : L10n.tr("common.off", "Off"),
                tone: appState.settings.privacy.isAnonymousModeEnabled ? .info : .neutral
            ),
            OperationalStatusItem(
                iconName: "documents",
                label: L10n.tr("home.status.vault.label", "Vault"),
                value: appState.documentVaultService.isUnlocked
                    ? L10n.tr("home.quick_access.vault.value_ready", "Ready")
                    : L10n.tr("home.quick_access.vault.value_locked", "Locked"),
                tone: appState.documentVaultService.isUnlocked ? .info : .neutral
            ),
            OperationalStatusItem(
                iconName: "map_marker",
                label: L10n.tr("home.status.maps.label", "Maps"),
                value: appState.mapDataService.loadInstalledPackIDs().isEmpty
                    ? L10n.tr("home.status.maps.value.limited", "Limited")
                    : L10n.tr("home.status.maps.value.offline_ready", "Offline ready"),
                tone: appState.mapDataService.loadInstalledPackIDs().isEmpty ? .caution : .ready
            ),
            OperationalStatusItem(
                iconName: "signal",
                label: L10n.tr("home.status.signal.label", "Signal"),
                value: signalRailValue,
                tone: signalRailTone
            )
        ]
    }

    private var officialAlertRailValue: String {
        if viewModel.nearbyOfficialAlerts.isEmpty {
            return viewModel.officialAlertSummary.tone == .ready
                ? L10n.tr("home.status.official_alerts.value.clear", "Clear")
                : L10n.tr("home.status.official_alerts.value.monitoring", "Monitoring")
        }

        return viewModel.nearbyOfficialAlerts.count == 1
            ? L10n.tr("home.status.official_alerts.value.active_one", "1 active")
            : L10n.format(
                "home.status.official_alerts.value.active_many",
                "%d active",
                viewModel.nearbyOfficialAlerts.count
            )
    }

    private var signalRailValue: String {
        if appState.isStealthModeEnabled || appState.settings.privacy.isAnonymousModeEnabled {
            return L10n.tr("home.status.signal.value.receive_only", "Receive-only")
        }

        return L10n.tr("home.status.signal.value.standby", "Standby")
    }

    private var signalRailTone: OperationalStatusTone {
        if appState.isStealthModeEnabled {
            return .caution
        }

        if appState.settings.privacy.isAnonymousModeEnabled {
            return .info
        }

        return .ready
    }

    private var installedMapPackCount: Int {
        appState.mapDataService.loadInstalledPackIDs().count
    }

    private var foodDaysSummary: String {
        "\(appState.profile.supplies.foodDays.formatted(.number.precision(.fractionLength(1)))) days"
    }

    private var powerReserveValue: String {
        switch appState.profile.supplies.batteryCapacity {
        case ..<35:
            "Low"
        case 35..<70:
            "Stable"
        default:
            "Ready"
        }
    }

    private var powerReserveDetail: String {
        "\(appState.profile.supplies.batteryCapacity.roundedIntString)% reserve stored"
    }

    private var powerReserveTint: Color {
        readinessColor(for: scoreValue(for: .power))
    }

    private var foodSupplyTint: Color {
        readinessColor(for: scoreValue(for: .food))
    }

    private var todayLocalStatusTitle: String {
        switch viewModel.officialAlertSummary.tone {
        case .ready:
            L10n.tr("home.today.local_status.title.ready", "No active threats in your area")
        case .info:
            L10n.tr("home.today.local_status.title.info", "Monitoring official feeds and local conditions")
        case .caution, .danger:
            viewModel.officialAlertSummary.title
        }
    }

    private var signalEnvironmentValue: String {
        let peerCount = viewModel.connectedMeshPeerCount
        return peerCount == 1
            ? L10n.tr("home.signal_environment.value.one", "1 node")
            : L10n.format("home.signal_environment.value.many", "%d nodes", peerCount)
    }

    private var signalEnvironmentDetail: String {
        if appState.isStealthModeEnabled || appState.settings.privacy.isAnonymousModeEnabled {
            return L10n.tr(
                "home.signal_environment.detail.hidden_mode",
                "Hidden mode keeps Signal receive-only"
            )
        }

        if viewModel.connectedMeshPeerCount == 0 {
            return L10n.tr("home.signal_environment.detail.none", "No nearby RediM8 mesh links yet")
        }

        return viewModel.connectedMeshPeerCount == 1
            ? L10n.tr("home.signal_environment.detail.one", "One nearby mesh connection is active")
            : L10n.format(
                "home.signal_environment.detail.many",
                "%d nearby mesh connections are active",
                viewModel.connectedMeshPeerCount
            )
    }

    private var signalEnvironmentTint: Color {
        if appState.isStealthModeEnabled || appState.settings.privacy.isAnonymousModeEnabled {
            return ColorTheme.accent
        }

        return viewModel.connectedMeshPeerCount == 0 ? ColorTheme.warning : ColorTheme.ready
    }

    private var mapCoverageValue: String {
        installedMapPackCount == 0
            ? L10n.tr("home.map_coverage.value.limited", "Limited")
            : L10n.tr("home.map_coverage.value.ready", "Ready")
    }

    private var mapCoverageDetail: String {
        installedMapPackCount == 0
            ? L10n.tr(
                "home.map_coverage.detail.install",
                "Install regional packs for richer offline detail"
            )
            : installedMapPackCount == 1
                ? L10n.tr("home.map_coverage.detail.one", "1 offline map pack installed")
                : L10n.format(
                    "home.map_coverage.detail.many",
                    "%d offline map packs installed",
                    installedMapPackCount
                )
    }

    private var mapCoverageTint: Color {
        installedMapPackCount == 0 ? ColorTheme.warning : ColorTheme.ready
    }

    private var preparednessStatusTitle: String {
        switch viewModel.prepScore.overall {
        case ..<35:
            "Preparedness: LOW"
        case 35..<65:
            "Preparedness: GUARDED"
        case 65..<85:
            "Preparedness: STABLE"
        default:
            "Preparedness: READY"
        }
    }

    private var preparednessPrimaryGapLine: String {
        guard let suggestion = viewModel.prepScore.suggestions.first else {
            return "Primary gap: Maintain routes, supplies, and household contacts."
        }

        switch suggestion.category {
        case .food:
            return "Primary gap: Food supply (\(foodDaysSummary))"
        case .water:
            return "Primary gap: Water reserve (\(viewModel.waterRuntimeEstimate.estimatedDaysText))"
        case .power:
            return "Primary gap: Power reserve (\(appState.profile.supplies.batteryCapacity.roundedIntString)% stored)"
        case .communication:
            return "Primary gap: Household communication plan"
        case .medical:
            return "Primary gap: Medical kit and critical records"
        case .evacuation:
            return "Primary gap: Evacuation route and movement plan"
        }
    }

    private var preparednessTargetLine: String {
        guard let suggestion = viewModel.prepScore.suggestions.first else {
            return "Target: Keep your baseline current and review for seasonal risk changes."
        }

        switch suggestion.category {
        case .food:
            return "Target: 7-14 days of household food."
        case .water:
            return "Target: \(viewModel.waterRuntimeEstimate.recommendedReserveDays)-day household water reserve."
        case .power:
            return "Target: Lighting, charging, and battery backup staged."
        case .communication:
            return "Target: Local signal path and contact plan confirmed."
        case .medical:
            return "Target: Critical medications, first aid, and saved records."
        case .evacuation:
            return "Target: Route, meeting point, and go-time checks confirmed."
        }
    }

    // MARK: - Today Cards

    private var todayReadinessCard: some View {
        let readinessTint = readinessColor(for: viewModel.prepScore.overall)

        return CinematicCommandPanel(
            assetName: "preparedness_flatlay",
            eyebrow: L10n.tr("home.today.readiness.eyebrow", "Preparedness Status")
        ) {
            HStack(alignment: .top, spacing: RediSpacing.content) {
                VStack(alignment: .leading, spacing: RediSpacing.tight) {
                    Text(preparednessStatusTitle)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(ColorTheme.text)

                    Text(preparednessPrimaryGapLine)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(preparednessTargetLine)
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text("\(viewModel.prepScore.overall)%")
                    .font(RediTypography.dataLarge)
                    .foregroundStyle(readinessTint)
                    .padding(.horizontal, RediSpacing.content)
                    .padding(.vertical, RediSpacing.compact)
                    .background(readinessTint.opacity(0.12), in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous))
                    .accessibilityLabel(L10n.tr("home.today.readiness.score_label", "Overall household readiness"))
                    .accessibilityValue(L10n.format("home.today.readiness.score_value", "%d percent", viewModel.prepScore.overall))
            }

            ReadinessMeter(
                value: Double(viewModel.prepScore.overall) / 100,
                tint: readinessTint,
                height: 6
            )

            MetricGrid(items: [
                MetricItem(
                    label: L10n.tr("home.today.readiness.metric.water", "Water"),
                    value: viewModel.waterRuntimeEstimate.estimatedDaysText,
                    status: metricStatus(for: waterRuntimeColor)
                ),
                MetricItem(
                    label: L10n.tr("home.today.readiness.metric.food", "Food"),
                    value: foodDaysSummary,
                    status: metricStatus(for: foodSupplyTint)
                ),
                MetricItem(
                    label: L10n.tr("home.today.readiness.metric.power", "Power"),
                    value: "\(appState.profile.supplies.batteryCapacity.roundedIntString)%",
                    status: metricStatus(for: powerReserveTint)
                )
            ])
        }
    }

    private var todayNextStepCard: some View {
        CommandPanel(eyebrow: L10n.tr("home.today.next_step.eyebrow", "Immediate Action")) {
            VStack(alignment: .leading, spacing: RediSpacing.content) {
                if let summary = viewModel.priorityModeSummary,
                   let action = summary.actions.first {
                    immediateActionCard(
                        iconName: action.systemImage,
                        title: action.title,
                        detail: action.detail,
                        tint: ColorTheme.warning,
                        impactLine: "Live emergency workflow",
                        timeLine: "Immediate",
                        contextLine: summary.situation.title
                    )
                } else if let suggestion = viewModel.prepScore.suggestions.first {
                    immediateActionCard(
                        iconName: suggestion.category.systemImage,
                        title: suggestion.title,
                        detail: suggestion.detail,
                        tint: readinessColor(for: scoreValue(for: suggestion.category)),
                        impactLine: "+\(suggestion.impact)% readiness",
                        timeLine: trimmedTaskEstimate(suggestion.category.quickTaskEstimate),
                        contextLine: suggestion.category.title
                    )
                } else if let task = viewModel.scenarioTasks.first {
                    immediateActionCard(
                        iconName: task.category.systemImage,
                        title: task.title,
                        detail: task.description,
                        tint: ColorTheme.accent,
                        impactLine: "+\(task.prepScoreValue)% readiness",
                        timeLine: trimmedTaskEstimate(task.category.quickTaskEstimate),
                        contextLine: "Scenario-linked"
                    )
                } else {
                    Text(L10n.tr(
                        "home.today.next_step.complete_message",
                        "Primary readiness actions are covered. Open Plan to keep routes, supplies, and contacts current."
                    ))
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    performTodayAction()
                } label: {
                    RediCommandCard(
                        title: L10n.tr("home.today.next_step.cta_title", "Open Action"),
                        detail: viewModel.priorityModeSummary == nil
                            ? L10n.tr(
                                "home.today.next_step.cta_detail_default",
                                "Open the highest-impact readiness action now."
                            )
                            : L10n.tr(
                                "home.today.next_step.cta_detail_live",
                                "Jump into the live action sequence for this situation."
                            ),
                        systemImage: "arrow.forward.circle.fill",
                        tint: viewModel.priorityModeSummary == nil ? ColorTheme.accent : ColorTheme.danger,
                        badge: viewModel.priorityModeSummary == nil
                            ? L10n.tr("home.today.next_step.cta_badge_default", "Action")
                            : L10n.tr("home.today.next_step.cta_badge_live", "Live"),
                        prominence: .accented,
                        layout: .rail
                    )
                }
                .buttonStyle(CardPressButtonStyle())
            }
        }
    }

    private var todayLocalStatusCard: some View {
        CinematicCommandPanel(
            assetName: "community_storm_town",
            eyebrow: L10n.tr("home.today.local_status.eyebrow", "Local Status"),
            bannerHeight: 140
        ) {
            VStack(alignment: .leading, spacing: RediSpacing.content) {
                HStack(alignment: .center, spacing: RediSpacing.compact) {
                    Circle()
                        .fill(officialAlertToneColor(viewModel.officialAlertSummary.tone))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)

                    Text(todayLocalStatusTitle)
                        .font(RediTypography.heading)
                        .foregroundStyle(officialAlertToneColor(viewModel.officialAlertSummary.tone))
                }
                .accessibilityElement(children: .combine)

                Text(viewModel.officialAlertSummary.detail)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                MetricGrid(items: [
                    MetricItem(
                        label: L10n.tr("home.today.local_status.metric.alerts", "Alerts"),
                        value: officialAlertRailValue,
                        status: alertMetricStatus(viewModel.officialAlertSummary.tone)
                    ),
                    MetricItem(
                        label: L10n.tr("home.today.local_status.metric.signal", "Signal"),
                        value: signalEnvironmentValue,
                        status: metricStatus(for: signalEnvironmentTint)
                    ),
                    MetricItem(
                        label: L10n.tr("home.today.local_status.metric.maps", "Maps"),
                        value: mapCoverageValue,
                        status: metricStatus(for: mapCoverageTint)
                    )
                ])
            }
        }
    }

    private var officialAlertsCardContent: some View {
        VStack(alignment: .leading, spacing: RediSpacing.content) {
            PremiumSegmentedControl(items: officialAlertScopeOptions, selection: $selectedOfficialAlertScope)

            if selectedOfficialAlertScope == .state {
                officialAlertJurisdictionPicker
            }

            HStack(alignment: .top, spacing: RediSpacing.content) {
                RediIcon(selectedOfficialAlerts.first?.kind.systemImage ?? "warning")
                    .foregroundStyle(officialAlertToneColor(selectedOfficialAlertSummary.tone))
                    .frame(width: 18, height: 18)
                    .padding(10)
                    .background(
                        officialAlertToneColor(selectedOfficialAlertSummary.tone).opacity(0.14),
                        in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text(L10n.tr("home.official_alerts.label", "OFFICIAL ALERTS"))
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(officialAlertToneColor(selectedOfficialAlertSummary.tone))
                    Text(selectedOfficialAlertSummary.title)
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)
                    Text(selectedOfficialAlertSummary.detail)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            TrustPillGroup(items: viewModel.officialAlertTrustItems(for: selectedOfficialAlertScope, jurisdiction: effectiveOfficialAlertJurisdiction))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: RediSpacing.content) {
                    alertMetaPanel(
                        title: L10n.tr("home.official_alerts.meta.official_feed", "Official Feed"),
                        value: selectedOfficialAlerts.first?.issuer
                            ?? L10n.tr("home.official_alerts.meta.cached_mirror", "Cached mirror")
                    )
                    alertMetaPanel(
                        title: L10n.tr("home.official_alerts.meta.scope", "Scope"),
                        value: selectedOfficialAlertScope == .state
                            ? (effectiveOfficialAlertJurisdiction?.title ?? L10n.tr("home.official_alerts.scope.none", "Select a state"))
                            : selectedOfficialAlertScope.title
                    )
                }

                VStack(spacing: RediSpacing.content) {
                    alertMetaPanel(
                        title: L10n.tr("home.official_alerts.meta.official_feed", "Official Feed"),
                        value: selectedOfficialAlerts.first?.issuer
                            ?? L10n.tr("home.official_alerts.meta.cached_mirror", "Cached mirror")
                    )
                    alertMetaPanel(
                        title: L10n.tr("home.official_alerts.meta.scope", "Scope"),
                        value: selectedOfficialAlertScope == .state
                            ? (effectiveOfficialAlertJurisdiction?.title ?? L10n.tr("home.official_alerts.scope.none", "Select a state"))
                            : selectedOfficialAlertScope.title
                    )
                }
            }

            if let countSummary = viewModel.officialAlertCountSummary(
                for: selectedOfficialAlertScope,
                jurisdiction: effectiveOfficialAlertJurisdiction
            ) {
                Text(countSummary)
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
            }

            if selectedOfficialAlerts.isEmpty {
                Text(L10n.tr(
                    "home.official_alerts.empty_state",
                    "No active alerts are currently listed for this scope."
                ))
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.textSecondary)
                .padding(RediSpacing.card)
                .homeInsetSurface(cornerRadius: RediRadius.card)
            } else {
                VStack(alignment: .leading, spacing: RediSpacing.content) {
                    ForEach(Array(selectedOfficialAlerts.prefix(3))) { alert in
                        officialAlertRow(alert)
                    }
                }

                if selectedOfficialAlerts.count > 3 {
                    Text(L10n.format(
                        "home.official_alerts.more_results",
                        "Showing the first 3 of %d alerts in this scope.",
                        selectedOfficialAlerts.count
                    ))
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
            }

            Text(L10n.tr(
                "home.official_alerts.note",
                "Official source labels remain separate from RediM8's readable summary so you can judge the warning against the issuing agency."
            ))
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            if selectedOfficialAlertScope == .local {
                Button(L10n.tr("home.official_alerts.view_on_map", "View on Map")) {
                    router.openMap()
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }

    private var emergencyUnlockCard: some View {
        let state = appState.emergencyUnlockState
        let accent = state.isActive ? ColorTheme.warning : ColorTheme.accent
        let unlockedRows = monetizationCatalog.emergencyUnlockRows.filter { state.unlockedFeatureIDs.contains($0.id) }

        return CommandPanel(eyebrow: state.calloutTitle) {
            VStack(alignment: .leading, spacing: RediSpacing.content) {
                if let subtitle = state.calloutDetail as String? {
                    Text(subtitle)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                }

                if let triggerAlert = state.triggerAlert {
                    HStack(alignment: .top, spacing: RediSpacing.content) {
                        RediIcon(triggerAlert.kind.systemImage)
                            .foregroundStyle(accent)
                            .frame(width: 18, height: 18)
                            .padding(10)
                            .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))

                        VStack(alignment: .leading, spacing: RediSpacing.micro) {
                            Text(triggerAlert.title)
                                .font(RediTypography.heading)
                                .foregroundStyle(ColorTheme.text)
                            Text(emergencyUnlockTimingLine(for: state, triggerAlert: triggerAlert))
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.textSecondary)
                        }

                        Spacer(minLength: 0)
                    }
                }

                TrustPillGroup(items: emergencyUnlockTrustItems)

                VStack(alignment: .leading, spacing: RediSpacing.compact) {
                    ForEach(Array(unlockedRows.prefix(3))) { row in
                        HStack(alignment: .top, spacing: RediSpacing.compact) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(RediTypography.bodyStrong)
                                    .foregroundStyle(ColorTheme.text)
                                Text(row.proValue)
                                    .font(RediTypography.caption)
                                    .foregroundStyle(accent)
                            }
                            Spacer()
                        }
                    }
                }

                Button {
                    activeSheet = .pro
                } label: {
                    RediCommandCard(
                        title: state.isActive
                            ? L10n.tr("home.emergency_unlock.cta.open", "Open Pro Tools")
                            : L10n.tr("home.emergency_unlock.cta.explore", "See Pro Plans"),
                        detail: state.isActive
                            ? L10n.tr(
                                "home.emergency_unlock.cta.active_detail",
                                "Emergency access is already active. Jump into the unlocked toolkit."
                            )
                            : L10n.tr(
                                "home.emergency_unlock.cta.default_detail",
                                "See the premium tools that open during real incidents or with Pro."
                            ),
                        systemImage: "sparkles",
                        tint: accent,
                        badge: state.isActive
                            ? L10n.tr("home.emergency_unlock.cta.active_badge", "Live")
                            : L10n.tr("home.emergency_unlock.cta.default_badge", "Explore"),
                        prominence: .accented,
                        layout: .rail
                    )
                }
                .buttonStyle(CardPressButtonStyle())
            }
        }
    }

    // MARK: - Quick Access

    private var quickAccessHubCard: some View {
        CollapsiblePanelCard(
            title: L10n.tr("home.quick_access.title", "Command Tools"),
            subtitle: L10n.tr(
                "home.quick_access.subtitle",
                "Emergency modes, signal, vault, guides, and vehicle tools."
            ),
            accent: ColorTheme.accent,
            isExpanded: $isShowingQuickAccess
        ) {
            quickAccessContent
        }
    }

    private var quickAccessContent: some View {
        VStack(alignment: .leading, spacing: RediSpacing.section) {
            // Emergency actions
            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text(L10n.tr("home.quick_access.group.emergency", "EMERGENCY"))
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                LazyVGrid(columns: decisionColumns, spacing: RediSpacing.content) {
                    Button {
                        RediHaptics.emergency(enabled: !appState.isStealthModeEnabled)
                        router.presentEmergencyMode(appState: appState)
                    } label: {
                        RediCommandCard(
                            title: L10n.tr("home.quick_access.emergency_mode.title", "Emergency Mode"),
                            detail: L10n.tr(
                                "home.quick_access.emergency_mode.detail",
                                "Official alerts, hazard actions, and command tools."
                            ),
                            systemImage: "exclamationmark.triangle.fill",
                            tint: ColorTheme.danger,
                            badge: L10n.tr("home.quick_access.emergency_mode.badge", "Critical"),
                            prominence: .critical
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())

                    Button {
                        RediHaptics.emergency(enabled: !appState.isStealthModeEnabled)
                        router.presentLeaveNowMode(appState: appState)
                    } label: {
                        RediCommandCard(
                            title: L10n.tr("home.quick_access.leave_now.title", "Leave Now"),
                            detail: L10n.tr(
                                "home.quick_access.leave_now.detail",
                                "Evacuation steps, routes, and go-time checks."
                            ),
                            systemImage: "figure.run",
                            tint: ColorTheme.warning,
                            badge: L10n.tr("home.quick_access.leave_now.badge", "Evacuate"),
                            prominence: .critical
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())
                }
            }

            // Tools grid
            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text(L10n.tr("home.quick_access.group.tools", "TOOLS"))
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                LazyVGrid(columns: quickActionColumns, spacing: RediSpacing.content) {
                    quickActionButton(
                        title: L10n.tr("home.quick_access.blackout.title", "Blackout Mode"),
                        subtitle: L10n.tr("home.quick_access.blackout.subtitle", "Dim tools"),
                        systemImage: "lightbulb.slash.fill",
                        tint: ColorTheme.textTertiary
                    ) {
                        router.presentBlackout(appState: appState)
                    }

                    quickActionButton(
                        title: L10n.tr("home.quick_access.signal_nearby.title", "Signal Nearby"),
                        subtitle: L10n.tr("home.quick_access.signal_nearby.subtitle", "Open mesh"),
                        systemImage: "antenna.radiowaves.left.and.right",
                        tint: ColorTheme.accent
                    ) {
                        router.openSignalNearby()
                    }

                    quickActionButton(
                        title: L10n.tr("home.quick_access.guides.title", "Emergency Guides"),
                        subtitle: L10n.tr("home.quick_access.guides.subtitle", "Offline help"),
                        systemImage: "books.vertical.fill",
                        tint: ColorTheme.textTertiary
                    ) {
                        router.presentEmergencyGuides(appState: appState)
                    }

                    quickActionButton(
                        title: appState.isStealthModeEnabled
                            ? L10n.tr("home.quick_access.stealth.disable_title", "Disable Stealth")
                            : L10n.tr("home.quick_access.stealth.enable_title", "Stealth Mode"),
                        subtitle: appState.isStealthModeEnabled
                            ? L10n.tr("home.quick_access.stealth.disable_subtitle", "Receive-only on")
                            : L10n.tr("home.quick_access.stealth.enable_subtitle", "Hide & conserve"),
                        systemImage: "eye.slash.fill",
                        tint: ColorTheme.textSecondary
                    ) {
                        appState.toggleStealthMode()
                    }
                }
            }

            // Readiness tools
            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text(L10n.tr("home.quick_access.group.readiness", "READINESS"))
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                LazyVGrid(columns: decisionColumns, spacing: RediSpacing.content) {
                    decisionToolButton(
                        title: L10n.tr("home.quick_access.vault.title", "Secure Vault"),
                        value: appState.documentVaultService.isUnlocked
                            ? L10n.tr("home.quick_access.vault.value_ready", "Ready")
                            : L10n.tr("home.quick_access.vault.value_locked", "Locked"),
                        subtitle: L10n.tr("home.quick_access.vault.subtitle", "ID, insurance, and medical docs"),
                        systemImage: "documents",
                        tint: appState.documentVaultService.isUnlocked ? ColorTheme.ready : ColorTheme.accent,
                        action: { router.openVault() }
                    )

                    decisionToolButton(
                        title: L10n.tr("home.quick_access.vehicle.title", "Vehicle Kit"),
                        value: viewModel.vehicleReadinessPlan.readiness.percentage.percentageText,
                        subtitle: L10n.format(
                            "home.quick_access.vehicle.subtitle",
                            "%1$d / %2$d essentials checked",
                            viewModel.vehicleReadinessPlan.readiness.completedCount,
                            viewModel.vehicleReadinessPlan.readiness.totalCount
                        ),
                        systemImage: "car.fill",
                        tint: readinessColor(for: viewModel.vehicleReadinessPlan.readiness.percentage),
                        action: { router.openVehicleReadiness() }
                    )
                }

                Button {
                    activeSheet = .readinessReport
                } label: {
                    RediCommandCard(
                        title: L10n.tr("home.quick_access.readiness_report.title", "Readiness Report"),
                        detail: L10n.tr(
                            "home.quick_access.readiness_report.detail",
                            "Generate a PDF summary to save, share, or send to family."
                        ),
                        systemImage: "doc.richtext.fill",
                        tint: ColorTheme.accent,
                        badge: L10n.tr("home.common.badge.pdf", "PDF"),
                        prominence: .neutral,
                        layout: .rail
                    )
                }
                .buttonStyle(CardPressButtonStyle())
            }
        }
    }

    // MARK: - Operational Insights

    private var operationalInsightsContent: some View {
        VStack(alignment: .leading, spacing: RediSpacing.section) {
            if !viewModel.forgottenItems.isEmpty {
                VStack(alignment: .leading, spacing: RediSpacing.compact) {
                    Text(L10n.tr("home.operational_insights.forgotten_title", "OFTEN FORGOTTEN"))
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)

                    ForEach(Array(viewModel.forgottenItems.prefix(3))) { item in
                        insightRow(
                            title: item.title,
                            detail: item.detail,
                            systemImage: item.systemImage,
                            tint: ColorTheme.warning
                        )
                    }
                }
            }

            if viewModel.shouldShowExpiryReminders {
                VStack(alignment: .leading, spacing: RediSpacing.compact) {
                    Text(L10n.tr("home.operational_insights.expiry_title", "SUPPLY EXPIRY"))
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)

                    ForEach(Array(viewModel.expiryReminders.prefix(3))) { reminder in
                        insightRow(
                            title: reminder.title,
                            detail: reminder.detail,
                            systemImage: reminder.status == .overdue ? "exclamationmark.triangle.fill" : "calendar.badge.exclamationmark",
                            tint: reminder.status == .overdue ? ColorTheme.danger : ColorTheme.warning
                        )
                    }
                }
            }

            if viewModel.shouldShowWaterSourceGuidance {
                VStack(alignment: .leading, spacing: RediSpacing.compact) {
                    Text(L10n.tr("home.operational_insights.water_sources_title", "NEAREST WATER SOURCES"))
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)

                    NearbyWaterSourcesSection(
                        sources: viewModel.nearbyWaterSources,
                        contextText: viewModel.waterSourceContext,
                        emptyMessage: viewModel.waterSourceStatusMessage
                    )
                }
            }
        }
    }

    private var readinessReportContent: some View {
        VStack(alignment: .leading, spacing: RediSpacing.card) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: RediSpacing.tight) {
                    Text(viewModel.readinessReport.scoreSummary)
                        .font(RediTypography.dataLarge)
                        .foregroundStyle(readinessColor(for: viewModel.prepScore.overall))
                    Text(viewModel.readinessReport.householdSummary)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                }
                Spacer()
                RediIcon("documents")
                    .foregroundStyle(ColorTheme.accent)
                    .frame(width: 28, height: 28)
            }

            Text(L10n.format("home.readiness_report.focus_areas", "Focus areas: %@", readinessFocusAreaText))
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.textSecondary)

            if let firstSuggestion = viewModel.readinessReport.suggestions.first {
                Text(L10n.format("home.readiness_report.next_improvement", "Next improvement: %@", firstSuggestion.title))
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
            }

            Button {
                activeSheet = .readinessReport
                } label: {
                    RediCommandCard(
                        title: L10n.tr("home.readiness_report.generate.title", "Generate Readiness Report"),
                        detail: L10n.tr(
                            "home.readiness_report.generate.detail",
                            "Create a PDF summary of score, focus areas, and next improvements."
                        ),
                        systemImage: "doc.richtext.fill",
                        tint: readinessColor(for: viewModel.prepScore.overall),
                        badge: L10n.tr("home.common.badge.pdf", "PDF"),
                        prominence: .accented,
                        layout: .rail
                    )
            }
            .buttonStyle(CardPressButtonStyle())
        }
    }

    // MARK: - Premium Tools

    private var premiumToolsSection: some View {
        PanelCard {
            proOverviewContent
        }
    }

    private var proOverviewContent: some View {
        VStack(alignment: .leading, spacing: RediSpacing.section) {
            VStack(alignment: .leading, spacing: RediSpacing.content) {
                Rectangle()
                    .fill(ColorTheme.textSecondary.opacity(0.34))
                    .frame(height: 1)

                Text(L10n.tr("paywall.brand.title", "REDIM8 PRO"))
                    .font(RediTypography.display)
                    .foregroundStyle(ColorTheme.text)

                Text(L10n.tr("paywall.hero.title", "Prepared when networks fail."))
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)

                Rectangle()
                    .fill(ColorTheme.textSecondary.opacity(0.18))
                    .frame(height: 1)
            }

            if appState.emergencyUnlockState.isActive {
                HStack(alignment: .top, spacing: RediSpacing.content) {
                    RediIcon(appState.emergencyUnlockState.triggerAlert?.kind.systemImage ?? "warning")
                        .foregroundStyle(ColorTheme.warning)
                        .frame(width: 18, height: 18)
                        .padding(10)
                        .background(ColorTheme.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))

                    VStack(alignment: .leading, spacing: RediSpacing.micro) {
                        Text(L10n.tr("home.pro.emergency_unlock.active_display", "EMERGENCY UNLOCK ACTIVE"))
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.warning)
                        Text(L10n.tr(
                            "home.pro.emergency_unlock.active_detail",
                            "Pro tools are temporarily available without billing while the nearby official warning remains active."
                        ))
                            .font(RediTypography.body)
                            .foregroundStyle(ColorTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }

            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                ForEach(proFeatureHighlights, id: \.self) { highlight in
                    proFeatureRow(title: highlight)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: RediSpacing.content) {
                    ForEach(monetizationCatalog.offers) { offer in
                        proOfferCard(offer)
                    }
                }

                VStack(spacing: RediSpacing.content) {
                    ForEach(monetizationCatalog.offers) { offer in
                        proOfferCard(offer)
                    }
                }
            }

            Text(pricingSummaryText)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)

            Text(monetizationCatalog.alwaysFreePromise)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                activeSheet = .pro
            } label: {
                RediCommandCard(
                    title: appState.emergencyUnlockState.isActive
                        ? L10n.tr("home.pro.cta.open", "Open Pro Tools")
                        : L10n.tr("home.pro.cta.upgrade", "Upgrade to Pro"),
                    detail: appState.emergencyUnlockState.isActive
                        ? L10n.tr(
                            "home.pro.cta.active_detail",
                            "Emergency access is active. Open the expanded planning and map tools."
                        )
                        : L10n.tr(
                            "home.pro.cta.default_detail",
                            "Unlock offline AI, survival maps, and advanced planning tools."
                        ),
                    systemImage: "sparkles.rectangle.stack.fill",
                    tint: ColorTheme.textSecondary,
                    badge: appState.emergencyUnlockState.isActive
                        ? L10n.tr("home.pro.cta.active_badge", "Unlocked")
                        : L10n.tr("home.pro.cta.default_badge", "Pro"),
                    prominence: .accented,
                    layout: .rail
                )
            }
            .buttonStyle(CardPressButtonStyle())
        }
    }

    private var proFeatureHighlights: [String] {
        [
            L10n.tr("home.pro.highlight.assistant", "Offline assistant safe summaries"),
            L10n.tr("home.pro.highlight.maps", "Expanded survival maps"),
            L10n.tr("home.pro.highlight.planning", "Advanced planning tools")
        ]
    }

    private func proFeatureRow(title: String) -> some View {
        HStack(alignment: .center, spacing: RediSpacing.content) {
            Circle()
                .fill(ColorTheme.textSecondary)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)

            Text(title)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)

            Spacer()
        }
        .padding(RediSpacing.card)
        .homeInsetSurface(cornerRadius: RediRadius.card)
        .accessibilityElement(children: .combine)
    }

    private func proOfferCard(_ offer: RediM8ProOffer) -> some View {
        VStack(alignment: .leading, spacing: RediSpacing.compact) {
            if let badge = offer.badge {
                Text(badge)
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(offer.isRecommended ? ColorTheme.accent : ColorTheme.textSecondary)
            }

            Text(offer.title)
                .font(RediTypography.heading)
                .foregroundStyle(ColorTheme.text)

            Text(appState.storeKitService.displayPrice(for: offer.interval.productID) ?? L10n.tr("common.loading", "Loading..."))
                .font(RediTypography.dataLarge)
                .foregroundStyle(ColorTheme.text)
                .accessibilityLabel(L10n.format("home.pro.offer.price_label", "%@ price", offer.title))
                .accessibilityValue(appState.storeKitService.displayPrice(for: offer.interval.productID) ?? L10n.tr("common.loading", "Loading..."))
 

            Text(offer.billingSummary)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textSecondary)
        }
        .padding(RediSpacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeInsetSurface(cornerRadius: RediRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                .stroke(
                    offer.isRecommended
                        ? ColorTheme.accent.opacity(0.28)
                        : offer.isFoundingOffer
                            ? ColorTheme.textSecondary.opacity(0.22)
                            : ColorTheme.dividerStrong,
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Compact Pro Banner

    private var compactProBanner: some View {
        Button {
            activeSheet = .pro
        } label: {
            HStack(spacing: RediSpacing.card) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ColorTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(ColorTheme.textSecondary.opacity(0.14), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("home.pro.banner.title", "RediM8 Pro"))
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                    Text(appState.emergencyUnlockState.isActive
                         ? L10n.tr("home.pro.banner.active_subtitle", "Emergency access active")
                         : L10n.tr("home.pro.banner.default_subtitle", "Offline AI, survival maps, advanced tools"))
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textSecondary.opacity(0.6))
            }
            .padding(RediSpacing.card)
            .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .stroke(ColorTheme.divider, lineWidth: 0.5)
                )
        }
        .buttonStyle(CardPressButtonStyle())
        .accessibilityHint(L10n.tr("home.pro.banner.hint", "Opens RediM8 Pro plans and features."))
    }

    // MARK: - Bushfire & Priority Modes

    private var bushfireModeCard: some View {
        VStack(alignment: .leading, spacing: RediSpacing.section) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: RediSpacing.tight) {
                    Text(L10n.tr("home.bushfire.mode_active.display", "BUSHFIRE MODE ACTIVE"))
                        .accessibilityLabel(L10n.tr("home.bushfire.mode_active", "Bushfire mode active"))
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.warning)
                    Text("\(viewModel.bushfireReadinessPercentage)%")
                        .font(RediTypography.dataHero)
                        .foregroundStyle(ColorTheme.text)
                        .accessibilityLabel(L10n.tr("home.bushfire.readiness_score_label", "Overall bushfire readiness"))
                        .accessibilityValue(L10n.format("home.bushfire.readiness_score_value", "%d percent", viewModel.bushfireReadinessPercentage))
                    Text(L10n.tr("home.bushfire.readiness_subtitle", "Overall bushfire readiness"))
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                }

                Spacer()

                RediIcon("fire_trail")
                    .foregroundStyle(ColorTheme.warning)
                    .frame(width: 28, height: 28)
                    .padding(RediSpacing.card)
                    .background(ColorTheme.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            }

            VStack(spacing: RediSpacing.content) {
                ForEach(viewModel.bushfireStatusRows) { row in
                    HStack(spacing: RediSpacing.content) {
                        RediIcon(row.systemImage)
                            .foregroundStyle(bushfireToneColor(row.tone))
                            .frame(width: 22, height: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(RediTypography.bodyStrong)
                                .foregroundStyle(ColorTheme.text)
                            Text(row.detail)
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(RediSpacing.content)
                    .homeInsetSurface(cornerRadius: RediRadius.card)
                }
            }

            Rectangle()
                .fill(ColorTheme.divider)
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text(L10n.tr("home.bushfire.checklist_title", "BUSHFIRE CHECKLIST"))
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                ForEach(viewModel.bushfireChecklistItems) { item in
                    Button {
                        viewModel.toggleBushfireChecklist(item.kind)
                    } label: {
                        HStack(spacing: RediSpacing.content) {
                            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isChecked ? ColorTheme.ready : ColorTheme.warning)
                            Text(item.kind.title)
                                .font(RediTypography.bodyStrong)
                                .foregroundStyle(ColorTheme.text)
                            Spacer()
                        }
                        .padding(.vertical, RediSpacing.micro)
                    }
                    .buttonStyle(CardPressButtonStyle())
                }
            }

            Rectangle()
                .fill(ColorTheme.divider)
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text(L10n.tr("home.bushfire.approaching_label", "BUSHFIRE APPROACHING"))
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                ForEach(Array(viewModel.bushfireEmergencySteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: RediSpacing.content) {
                        Text("\(index + 1).")
                            .font(RediTypography.data)
                            .foregroundStyle(ColorTheme.warning)
                        Text(step)
                            .font(RediTypography.body)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }
            }

            HStack(alignment: .top, spacing: RediSpacing.content) {
                RediIcon("warning")
                    .foregroundStyle(ColorTheme.warning)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text(viewModel.bushfireReminderTitle)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                    Text(viewModel.bushfireReminderMessage)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                }
            }
            .padding(RediSpacing.card)
            .homeInsetSurface(cornerRadius: RediRadius.card)
        }
    }

    private var priorityModeCard: some View {
        VStack(alignment: .leading, spacing: RediSpacing.card) {
                LazyVGrid(columns: priorityColumns, spacing: RediSpacing.compact) {
                    ForEach(viewModel.prioritySituationOptions) { situation in
                        Button {
                            viewModel.togglePrioritySituation(situation)
                        } label: {
                        HStack(spacing: RediSpacing.compact) {
                            RediIcon(situation.systemImage)
                                .frame(width: 15, height: 15)
                            Text(situation.title)
                                .font(RediTypography.bodyStrong)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(appState.activePrioritySituation == situation ? ColorTheme.warning : ColorTheme.text)
                        .padding(.horizontal, RediSpacing.card)
                        .padding(.vertical, RediSpacing.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .homeInsetSurface(cornerRadius: RediRadius.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                                .fill(
                                    appState.activePrioritySituation == situation
                                        ? ColorTheme.warning.opacity(0.12)
                                        : Color.clear
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                                .stroke(
                                    appState.activePrioritySituation == situation
                                        ? ColorTheme.warning.opacity(0.4)
                                        : ColorTheme.dividerStrong,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())
                }
            }

            if let summary = viewModel.priorityModeSummary {
                VStack(alignment: .leading, spacing: RediSpacing.card) {
                    HStack {
                        Text(L10n.tr("home.priority.active_label", "PRIORITY MODE ACTIVE"))
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.warning)
                        Spacer()
                        Button(L10n.tr("common.clear", "Clear")) {
                            viewModel.clearPriorityMode()
                        }
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: RediSpacing.content) {
                        ForEach(summary.actions) { action in
                            HStack(alignment: .top, spacing: RediSpacing.content) {
                                RediIcon(action.systemImage)
                                    .foregroundStyle(ColorTheme.warning)
                                    .frame(width: 16, height: 16)
                                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                                    Text(action.title)
                                        .font(RediTypography.bodyStrong)
                                        .foregroundStyle(ColorTheme.text)
                                    Text(action.detail)
                                        .font(RediTypography.body)
                                        .foregroundStyle(ColorTheme.textSecondary)
                                }
                            }
                        }
                    }

                    if !summary.resources.isEmpty {
                        Rectangle()
                            .fill(ColorTheme.divider)
                            .frame(height: 0.5)

                        VStack(alignment: .leading, spacing: RediSpacing.compact) {
                            Text(L10n.tr("home.priority.resources_label", "NEAREST RESOURCES"))
                                .font(RediTypography.label)
                                .tracking(1.2)
                                .foregroundStyle(ColorTheme.textTertiary)

                            ForEach(summary.resources) { resource in
                                HStack(alignment: .top, spacing: RediSpacing.content) {
                                    RediIcon(resource.systemImage)
                                        .foregroundStyle(ColorTheme.accent)
                                        .frame(width: 16, height: 16)
                                    VStack(alignment: .leading, spacing: RediSpacing.micro) {
                                        Text(resource.title)
                                            .font(RediTypography.bodyStrong)
                                            .foregroundStyle(ColorTheme.text)
                                        Text(resource.detail)
                                            .font(RediTypography.body)
                                            .foregroundStyle(ColorTheme.textSecondary)
                                    }
                                }
                            }
                        }
                    }

                    if !summary.evacuationOptions.isEmpty {
                        Rectangle()
                            .fill(ColorTheme.divider)
                            .frame(height: 0.5)

                        VStack(alignment: .leading, spacing: RediSpacing.compact) {
                            Text(L10n.tr("home.priority.evacuation_options_label", "EVACUATION OPTIONS"))
                                .font(RediTypography.label)
                                .tracking(1.2)
                                .foregroundStyle(ColorTheme.textTertiary)

                            ForEach(summary.evacuationOptions, id: \.self) { option in
                                HStack(alignment: .top, spacing: RediSpacing.compact) {
                                    RediIcon("route", fallbackSystemName: "arrow.triangle.turn.up.right.diamond.fill")
                                        .foregroundStyle(ColorTheme.accent)
                                        .frame(width: 14, height: 14)
                                        .padding(.top, RediSpacing.micro)
                                    Text(option)
                                        .font(RediTypography.body)
                                        .foregroundStyle(ColorTheme.textSecondary)
                                }
                            }
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: RediSpacing.content) {
                            Button(L10n.tr("home.priority.leave_now", "LEAVE NOW")) {
                                router.presentLeaveNowMode(appState: appState)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())

                            Button(L10n.tr("home.priority.emergency_screen", "Emergency Screen")) {
                                router.presentEmergencyMode(appState: appState)
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }

                        VStack(spacing: RediSpacing.content) {
                            Button(L10n.tr("home.priority.leave_now", "LEAVE NOW")) {
                                router.presentLeaveNowMode(appState: appState)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())

                            Button(L10n.tr("home.priority.emergency_screen", "Emergency Screen")) {
                                router.presentEmergencyMode(appState: appState)
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                }
            } else {
                Text(L10n.tr(
                    "home.priority.empty_state",
                    "Bushfire, flood, blackout, and remote-travel incidents each get their own action order so the app tells the user what matters first."
                ))
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)
            }
        }
    }

    private var readinessFocusAreaText: String {
        let areas = viewModel.readinessReport.focusAreas
        return areas.isEmpty
            ? L10n.tr("home.readiness_report.focus_default", "General emergency readiness")
            : areas.joined(separator: ", ")
    }

    private var waterRuntimeColor: Color {
        let estimate = viewModel.waterRuntimeEstimate
        if estimate.estimatedDays >= Double(estimate.recommendedReserveDays) {
            return ColorTheme.ready
        }
        if estimate.estimatedDays >= 3 {
            return ColorTheme.warning
        }
        return ColorTheme.danger
    }

    private var preparednessHeadlineBlock: some View {
        VStack(alignment: .leading, spacing: RediSpacing.compact) {
            Text("\(viewModel.prepScore.overall)%")
                .font(RediTypography.dataHero)
                .foregroundStyle(readinessColor(for: viewModel.prepScore.overall))
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Text(viewModel.prepScore.milestoneTitle)
                .font(RediTypography.display)
                .foregroundStyle(ColorTheme.text)

            Text(viewModel.prepScore.nextMilestoneSummary)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textSecondary)
        }
    }

    private var commandCenterNextLine: String {
        if let summary = viewModel.priorityModeSummary, let action = summary.actions.first {
            return action.title
        }

        if let suggestion = viewModel.prepScore.suggestions.first {
            return suggestion.title
        }

        if let task = viewModel.scenarioTasks.first {
            return task.title
        }

        return "Review your household plan and keep critical tools staged."
    }

    private var commandCenterStatusLine: String {
        if let safeModeSummary = viewModel.safeModeSummary {
            return "\(safeModeSummary.alert.severity.title) nearby"
        }

        switch viewModel.officialAlertSummary.tone {
        case .ready:
            return "No warnings nearby"
        case .info:
            return "Monitoring official feeds"
        case .caution, .danger:
            return viewModel.officialAlertSummary.title
        }
    }

    private var commandCenterReadinessLine: String {
        "\(viewModel.prepScore.overall)% prepared • \(viewModel.waterRuntimeEstimate.estimatedDaysText) water"
    }

    private var commandCenterStatusTint: Color {
        if viewModel.safeModeSummary != nil {
            return ColorTheme.danger
        }

        return officialAlertToneColor(viewModel.officialAlertSummary.tone)
    }

    private var commandCenterEdgeColor: Color {
        commandCenterStatusTint.opacity(viewModel.safeModeSummary == nil ? 0.14 : 0.22)
    }

    private func commandCenterDetailLine(label: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: RediSpacing.compact) {
            Text(label.uppercased())
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(tint)
                .frame(width: 74, alignment: .leading)

            Text(detail)
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, RediSpacing.card)
    }

    private func preparednessScenarioBlock(isTrailing: Bool) -> some View {
        VStack(alignment: isTrailing ? .trailing : .leading, spacing: RediSpacing.compact) {
            Text(L10n.tr("home.preparedness.scenarios_label", "SCENARIOS"))
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
            Text(L10n.format(
                "home.preparedness.tracked_count",
                "%d tracked",
                viewModel.prepScore.categoryScores.count
            ))
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: isTrailing ? .trailing : .leading)
    }

    private func preparednessCategoryTile(_ score: CategoryScore) -> some View {
        let tint = readinessColor(for: score.score)
        let progress = min(max(score.score, 0), 100)

        return VStack(alignment: .leading, spacing: RediSpacing.compact) {
            HStack(alignment: .top) {
                RediIcon(score.category.systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 18, height: 18)

                Spacer()

                Text(score.score.percentageText)
                    .font(RediTypography.data)
                    .foregroundStyle(tint)
            }

            Text(score.category.title)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)

            ReadinessMeter(value: Double(progress) / 100, tint: tint)
        }
        .padding(RediSpacing.section)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .homeInsetSurface(cornerRadius: RediRadius.card)
    }

    private func todaySnapshotMetric(
        title: String,
        value: String,
        detail: String,
        tint: Color,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: RediSpacing.tight) {
            Text(title.uppercased())
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)

            Text(value)
                .font(RediTypography.dataLarge)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(detail)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RediSpacing.card)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .homeInsetSurface(cornerRadius: RediRadius.card)
    }

    private func performTodayAction() {
        if let summary = viewModel.priorityModeSummary {
            switch summary.situation {
            case .blackout:
                router.presentBlackout(appState: appState)
            case .remoteTravel:
                router.openVehicleReadiness()
            case .bushfire, .flood:
                router.presentEmergencyMode(appState: appState)
            }
            return
        }

        if let suggestion = viewModel.prepScore.suggestions.first {
            performImprovementAction(for: suggestion)
            return
        }

        if !viewModel.scenarioTasks.isEmpty {
            router.openPlan()
            return
        }

        router.openPlan()
    }

    private func performImprovementAction(for suggestion: ImprovementSuggestion) {
        switch suggestion.category {
        case .water:
            router.openWaterRuntime()
        case .communication:
            router.openSignalNearby()
        case .food, .medical, .power, .evacuation:
            router.openPlan()
        }
    }

    private func trimmedTaskEstimate(_ estimate: String) -> String {
        estimate.replacingOccurrences(of: " task", with: "")
    }

    // MARK: - Reusable Card Builders

    private func immediateActionCard(
        iconName: String,
        title: String,
        detail: String,
        tint: Color,
        impactLine: String,
        timeLine: String,
        contextLine: String
    ) -> some View {
        VStack(alignment: .leading, spacing: RediSpacing.content) {
            HStack(alignment: .top, spacing: RediSpacing.content) {
                ZStack {
                    RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 46, height: 46)

                    RediIcon(iconName)
                        .foregroundStyle(tint)
                        .frame(width: 18, height: 18)
                }

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text(title)
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)
                    Text(detail)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: RediSpacing.tight) {
                immediateActionMetaRow(label: "Estimated Impact", value: impactLine, tint: ColorTheme.ready)
                immediateActionMetaRow(label: "Time Required", value: timeLine, tint: ColorTheme.textTertiary)
                immediateActionMetaRow(label: "Operational Context", value: contextLine, tint: tint)
            }
        }
        .padding(RediSpacing.section)
        .homeInsetSurface(cornerRadius: RediRadius.card)
    }

    private func immediateActionMetaRow(label: String, value: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: RediSpacing.compact) {
            Text(label.uppercased())
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(tint)
                .frame(width: 108, alignment: .leading)

            Text(value)
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, RediSpacing.tight)
    }

    private func featuredSuggestionCard(
        _ suggestion: ImprovementSuggestion,
        eyebrow: String? = L10n.tr("home.today.next_step.eyebrow", "Immediate Action")
    ) -> some View {
        let currentScore = scoreValue(for: suggestion.category)
        let tint = readinessColor(for: currentScore)

        return VStack(alignment: .leading, spacing: RediSpacing.section) {
            HStack(alignment: .top, spacing: RediSpacing.content) {
                ZStack {
                    RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 48, height: 48)

                    RediIcon(suggestion.category.systemImage)
                        .foregroundStyle(tint)
                        .frame(width: 20, height: 20)
                }

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    if let eyebrow {
                        Text(eyebrow.uppercased())
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                    Text(suggestion.title)
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)
                }

                Spacer(minLength: 0)

                Text("+\(suggestion.impact)%")
                    .font(RediTypography.data)
                    .foregroundStyle(ColorTheme.accent)
                    .padding(.horizontal, RediSpacing.compact)
                    .padding(.vertical, RediSpacing.tight)
                    .background(ColorTheme.accent.opacity(0.12), in: Capsule())
            }

            Text(suggestion.detail)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.textSecondary)

            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                HStack {
                    Text(suggestion.category.title.uppercased())
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Spacer()
                    Text(currentScore.percentageText)
                        .font(RediTypography.data)
                        .foregroundStyle(tint)
                }

                ReadinessMeter(value: Double(currentScore) / 100, tint: tint, height: 6)

                HStack {
                    Text("+\(suggestion.impact)% if completed")
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.accent)
                    Spacer()
                    Text(suggestion.category.quickTaskEstimate)
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
            }
            .padding(RediSpacing.card)
            .homeInsetSurface(cornerRadius: RediRadius.card)
        }
        .padding(RediSpacing.section)
        .homeInsetSurface(cornerRadius: RediRadius.card)
    }

    private func featuredActionCard(
        eyebrow: String,
        iconName: String,
        title: String,
        detail: String,
        tint: Color,
        emphasis: String,
        supporting: String?
    ) -> some View {
        return VStack(alignment: .leading, spacing: RediSpacing.content) {
            HStack(alignment: .top, spacing: RediSpacing.content) {
                ZStack {
                    RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 48, height: 48)

                    RediIcon(iconName)
                        .foregroundStyle(tint)
                        .frame(width: 20, height: 20)
                }

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text(eyebrow.uppercased())
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)
                }

                Spacer(minLength: 0)

                Text(emphasis)
                    .font(RediTypography.data)
                    .foregroundStyle(tint)
                    .padding(.horizontal, RediSpacing.compact)
                    .padding(.vertical, RediSpacing.tight)
                    .background(tint.opacity(0.14), in: Capsule())
            }

            Text(detail)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.textSecondary)

            if let supporting {
                Text(supporting)
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textTertiary)
            }
        }
        .padding(RediSpacing.section)
        .homeInsetSurface(cornerRadius: RediRadius.card)
    }

    private func nextActionRow(
        iconName: String,
        title: String,
        detail: String,
        emphasis: String?,
        supporting: String?,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: RediSpacing.content) {
            RediIcon(iconName)
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: RediSpacing.micro) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)
            }

            Spacer(minLength: RediSpacing.content)

            VStack(alignment: .trailing, spacing: RediSpacing.tight) {
                if let emphasis {
                    Text(emphasis)
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(tint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, RediSpacing.tight)
                        .background(tint.opacity(0.12), in: Capsule())
                }
                if let supporting {
                    Text(supporting)
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
            }
        }
        .padding(RediSpacing.card)
        .homeInsetSurface(cornerRadius: RediRadius.card)
    }

    private func guideLaneRow(title: String, detail: String, iconName: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: RediSpacing.content) {
            RediIcon(iconName)
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .padding(10)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))

            VStack(alignment: .leading, spacing: RediSpacing.micro) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(RediSpacing.card)
        .homeInsetSurface(cornerRadius: RediRadius.card)
    }

    private var emergencyUnlockTrustItems: [TrustPillItem] {
        let state = appState.emergencyUnlockState
        var items = [
            TrustPillItem(
                title: state.isActive
                    ? L10n.tr("home.emergency_unlock.trust.temporary_access", "Temporary access")
                    : L10n.tr("home.emergency_unlock.trust.ended", "Ended"),
                tone: state.isActive ? .verified : .info
            ),
            TrustPillItem(
                title: L10n.format(
                    "home.emergency_unlock.trust.pro_upgrades",
                    "%d Pro upgrades",
                    state.featureCount
                ),
                tone: .info
            )
        ]

        if let triggerAlert = state.triggerAlert {
            items.append(TrustPillItem(title: triggerAlert.scopeTrustLabel, tone: triggerAlert.isAreaScoped ? .verified : .caution))
            items.append(TrustPillItem(title: triggerAlert.severity.title, tone: triggerAlert.severity == .emergencyWarning ? .caution : .info))
        }

        return items
    }

    private func emergencyUnlockTimingLine(for state: EmergencyUnlockState, triggerAlert: OfficialAlert) -> String {
        if state.isActive, let accessEndsAt = state.accessEndsAt {
            return L10n.format(
                "home.emergency_unlock.timing.until",
                "%1$@ • Until %2$@",
                triggerAlert.issuer,
                DateFormatter.rediM8Short.string(from: accessEndsAt)
            )
        }
        if state.isActive {
            return L10n.format(
                "home.emergency_unlock.timing.active",
                "%@ • Active while the official warning remains listed",
                triggerAlert.issuer
            )
        }
        if let endedAt = state.endedAt {
            return L10n.format(
                "home.emergency_unlock.timing.ended",
                "%1$@ • Ended %2$@",
                triggerAlert.issuer,
                DateFormatter.rediM8Short.string(from: endedAt)
            )
        }
        return triggerAlert.issuer
    }

    private func safeModeCard(summary: SafeModeHomeSummary) -> some View {
        ModeHeroCard(
            eyebrow: L10n.tr("home.safe_mode.eyebrow", "Safe Mode"),
            title: summary.alert.severity.title,
            subtitle: summary.alert.title,
            iconName: summary.alert.kind.systemImage,
            accent: officialAlertToneColor(.danger)
        ) {
            VStack(alignment: .leading, spacing: RediSpacing.content) {
                TrustPillGroup(items: viewModel.officialAlertTrustItems)

                operationalSafeModeLine(
                    label: L10n.tr("home.safe_mode.label.shelter", "Shelter"),
                    detail: summary.nearestShelterLine
                )
                operationalSafeModeLine(
                    label: L10n.tr("home.safe_mode.label.water", "Water"),
                    detail: summary.nearestWaterLine
                )
                operationalSafeModeLine(
                    label: L10n.tr("home.safe_mode.label.route", "Route"),
                    detail: summary.routeLine
                )

                Text(summary.note)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)

                Button(L10n.tr("home.safe_mode.view_map", "View Map")) {
                    router.openMap()
                }
                .buttonStyle(PrimaryActionButtonStyle())

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: RediSpacing.content) {
                        Button(L10n.tr("home.safe_mode.send_alert", "Send Alert")) {
                            router.openSignalNearby()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())

                        Button(L10n.tr("home.safe_mode.share_location", "Share Location")) {
                            router.openSignalNearby()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }

                    VStack(spacing: RediSpacing.content) {
                        Button(L10n.tr("home.safe_mode.send_alert", "Send Alert")) {
                            router.openSignalNearby()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())

                        Button(L10n.tr("home.safe_mode.share_location", "Share Location")) {
                            router.openSignalNearby()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }
        }
    }

    private func scoreValue(for category: PrepCategory) -> Int {
        viewModel.prepScore.categoryScores.first(where: { $0.category == category })?.score ?? viewModel.prepScore.overall
    }

    private func readinessColor(for score: Int) -> Color {
        switch score {
        case ..<34:
            ColorTheme.danger
        case 34..<67:
            ColorTheme.warning
        default:
            ColorTheme.ready
        }
    }

    private func bushfireToneColor(_ tone: BushfireStatusRow.Tone) -> Color {
        switch tone {
        case .ready:
            ColorTheme.ready
        case .warning:
            ColorTheme.warning
        }
    }

    private func officialAlertToneColor(_ tone: OfficialAlertStatusTone) -> Color {
        switch tone {
        case .ready:
            ColorTheme.ready
        case .info:
            ColorTheme.accent
        case .caution:
            ColorTheme.warning
        case .danger:
            ColorTheme.danger
        }
    }

    private func operationalTone(for tone: OfficialAlertStatusTone) -> OperationalStatusTone {
        switch tone {
        case .ready:
            .ready
        case .info:
            .info
        case .caution:
            .caution
        case .danger:
            .danger
        }
    }

    private func metricStatus(for color: Color) -> MetricStatus {
        if color == ColorTheme.ready { return .ready }
        if color == ColorTheme.warning { return .warning }
        if color == ColorTheme.danger { return .danger }
        return .normal
    }

    private func alertMetricStatus(_ tone: OfficialAlertStatusTone) -> MetricStatus {
        switch tone {
        case .ready: .ready
        case .info: .normal
        case .caution: .warning
        case .danger: .danger
        }
    }

    private func alertMetaPanel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: RediSpacing.micro) {
            Text(title.uppercased())
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
            Text(value)
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.text)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RediSpacing.content)
        .homeInsetSurface(cornerRadius: RediRadius.card)
    }

    private var officialAlertJurisdictionPicker: some View {
        Menu {
            ForEach(viewModel.availableOfficialAlertJurisdictions) { jurisdiction in
                Button {
                    selectedOfficialAlertJurisdiction = jurisdiction
                } label: {
                    if jurisdiction == effectiveOfficialAlertJurisdiction {
                        Label(jurisdiction.title, systemImage: "checkmark")
                    } else {
                        Text(jurisdiction.title)
                    }
                }
            }
        } label: {
            HStack(alignment: .center, spacing: RediSpacing.content) {
                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text(L10n.tr("home.official_alerts.state_picker.label", "STATE FEED"))
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text(
                        effectiveOfficialAlertJurisdiction?.title
                            ?? L10n.tr("home.official_alerts.state_picker.placeholder", "Select a state or territory")
                    )
                    .font(RediTypography.data)
                    .foregroundStyle(ColorTheme.text)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.textTertiary)
            }
            .padding(RediSpacing.content)
            .homeInsetSurface(cornerRadius: RediRadius.card)
        }
        .buttonStyle(.plain)
    }

    private func officialAlertRow(_ alert: OfficialAlert) -> some View {
        VStack(alignment: .leading, spacing: RediSpacing.content) {
            HStack(alignment: .top, spacing: RediSpacing.content) {
                RediIcon(alert.kind.systemImage)
                    .foregroundStyle(officialAlertToneColor(selectedOfficialAlertSummary.tone))
                    .frame(width: 18, height: 18)
                    .padding(10)
                    .background(
                        officialAlertToneColor(selectedOfficialAlertSummary.tone).opacity(0.14),
                        in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text(alert.title)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                    Text("\(alert.severity.title) • \(viewModel.officialAlertScopeLine(for: alert))")
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            Text(alert.message)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let instruction = alert.instruction?.nilIfBlank {
                Text(instruction)
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(viewModel.officialAlertUpdatedLine(for: alert))
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            Text(viewModel.officialAlertSafetyNote(for: alert))
                .font(RediTypography.caption)
                .foregroundStyle(officialAlertToneColor(selectedOfficialAlertSummary.tone))
                .fixedSize(horizontal: false, vertical: true)

            if let sourceURL = alert.sourceURL {
                Button(L10n.tr("home.official_alerts.open_source", "Open Official Source")) {
                    openURL(sourceURL)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(RediSpacing.card)
        .homeInsetSurface(cornerRadius: RediRadius.card)
    }

    private func decisionToolButton(
        title: String,
        value: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RediCommandCard(
                title: title,
                detail: subtitle,
                systemImage: systemImage,
                tint: tint,
                badge: value,
                prominence: .accented,
                minHeight: 126
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func quickActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RediCommandCard(
                title: title,
                detail: subtitle,
                systemImage: systemImage,
                tint: tint,
                prominence: .neutral,
                minHeight: 96
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func operationalSafeModeLine(label: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: RediSpacing.compact) {
            Text(label.uppercased())
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
                .frame(width: 58, alignment: .leading)

            Text(detail)
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func insightRow(title: String, detail: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: RediSpacing.content) {
            RediIcon(systemImage)
                .foregroundStyle(tint)
                .frame(width: 24, height: 24, alignment: .center)

            VStack(alignment: .leading, spacing: RediSpacing.micro) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)
            }
        }
    }
}

// MARK: - Flat Panel Surface

private struct HomeInsetSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ColorTheme.graphite)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ColorTheme.divider, lineWidth: 0.5)
            )
    }
}

private extension View {
    func homeInsetSurface(cornerRadius: CGFloat) -> some View {
        modifier(HomeInsetSurfaceModifier(cornerRadius: cornerRadius))
    }
}
