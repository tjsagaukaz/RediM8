import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let appState: AppState
    @ObservedObject private var router: NavigationRouter
    private let scrollToTopRequestID: Int
    private let monetizationCatalog = RediM8MonetizationCatalog.launch

    @State private var activeSheet: HomeSheet?
    @State private var isShowingOperationalInsights = false
    @State private var isShowingPriorityTools = false
    @State private var isShowingBushfireReadiness = false
    @State private var isShowingQuickAccess = false

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

                    // MARK: — TAP ZONE (primary actions)

                    quickAccessHubCard

                    // MARK: — BROWSE ZONE (progressive detail)

                    homeStatusRail

                    if appState.emergencyUnlockState.isVisible {
                        emergencyUnlockCard
                    }

                    if shouldShowOperationalInsights {
                        CollapsiblePanelCard(
                            title: "Operational Insights",
                            subtitle: "Forgotten items, expiry reminders, and water guidance.",
                            accent: ColorTheme.textTertiary,
                            isExpanded: $isShowingOperationalInsights
                        ) {
                            operationalInsightsContent
                        }
                    }

                    CollapsiblePanelCard(
                        title: "Priority Situations",
                        subtitle: viewModel.priorityModeSummary?.subtitle ?? "Activate a live situation to surface the right actions.",
                        accent: ColorTheme.textTertiary,
                        isExpanded: $isShowingPriorityTools
                    ) {
                        priorityModeCard
                    }

                    if viewModel.isBushfireModeEnabled {
                        CollapsiblePanelCard(
                            title: "Bushfire Readiness",
                            subtitle: "Bushfire scenario preparation and checklists.",
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
                    RediM8ProView(emergencyUnlockState: appState.emergencyUnlockState)
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

    private var homeStatusRail: some View {
        SystemStatusRail(items: homeStatusItems, accent: ColorTheme.accent)
    }

    private var homeStatusItems: [OperationalStatusItem] {
        [
            OperationalStatusItem(
                iconName: "warning",
                label: "Official Alerts",
                value: officialAlertRailValue,
                tone: operationalTone(for: viewModel.officialAlertSummary.tone)
            ),
            OperationalStatusItem(
                iconName: "eye.slash.fill",
                label: "Hidden Mode",
                value: appState.settings.privacy.isAnonymousModeEnabled ? "On" : "Off",
                tone: appState.settings.privacy.isAnonymousModeEnabled ? .info : .neutral
            ),
            OperationalStatusItem(
                iconName: "documents",
                label: "Vault",
                value: appState.documentVaultService.isUnlocked ? "Ready" : "Locked",
                tone: appState.documentVaultService.isUnlocked ? .info : .neutral
            ),
            OperationalStatusItem(
                iconName: "map_marker",
                label: "Maps",
                value: appState.mapDataService.loadInstalledPackIDs().isEmpty ? "Limited" : "Offline ready",
                tone: appState.mapDataService.loadInstalledPackIDs().isEmpty ? .caution : .ready
            ),
            OperationalStatusItem(
                iconName: "signal",
                label: "Signal",
                value: signalRailValue,
                tone: signalRailTone
            )
        ]
    }

    private var officialAlertRailValue: String {
        if viewModel.nearbyOfficialAlerts.isEmpty {
            return viewModel.officialAlertSummary.tone == .ready ? "Clear" : "Monitoring"
        }

        return viewModel.nearbyOfficialAlerts.count == 1 ? "1 active" : "\(viewModel.nearbyOfficialAlerts.count) active"
    }

    private var signalRailValue: String {
        if appState.isStealthModeEnabled || appState.settings.privacy.isAnonymousModeEnabled {
            return "Receive-only"
        }

        return "Standby"
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
            "No alerts nearby"
        case .info:
            "Monitoring local conditions"
        case .caution, .danger:
            viewModel.officialAlertSummary.title
        }
    }

    private var signalEnvironmentValue: String {
        let peerCount = viewModel.connectedMeshPeerCount
        return peerCount == 1 ? "1 node" : "\(peerCount) nodes"
    }

    private var signalEnvironmentDetail: String {
        if appState.isStealthModeEnabled || appState.settings.privacy.isAnonymousModeEnabled {
            return "Hidden mode keeps Signal receive-only"
        }

        if viewModel.connectedMeshPeerCount == 0 {
            return "No nearby RediM8 mesh links yet"
        }

        return viewModel.connectedMeshPeerCount == 1
            ? "One nearby mesh connection is active"
            : "\(viewModel.connectedMeshPeerCount) nearby mesh connections are active"
    }

    private var signalEnvironmentTint: Color {
        if appState.isStealthModeEnabled || appState.settings.privacy.isAnonymousModeEnabled {
            return ColorTheme.accent
        }

        return viewModel.connectedMeshPeerCount == 0 ? ColorTheme.warning : ColorTheme.ready
    }

    private var mapCoverageValue: String {
        installedMapPackCount == 0 ? "Limited" : "Ready"
    }

    private var mapCoverageDetail: String {
        installedMapPackCount == 0
            ? "Install regional packs for richer offline detail"
            : installedMapPackCount == 1
                ? "1 offline map pack installed"
                : "\(installedMapPackCount) offline map packs installed"
    }

    private var mapCoverageTint: Color {
        installedMapPackCount == 0 ? ColorTheme.warning : ColorTheme.ready
    }

    // MARK: - Today Cards

    private var todayReadinessCard: some View {
        let readinessTint = readinessColor(for: viewModel.prepScore.overall)

        return CinematicCommandPanel(assetName: "preparedness_flatlay", eyebrow: "Home Readiness") {
            // Hero score
            HStack(alignment: .top, spacing: RediSpacing.content) {
                VStack(alignment: .leading, spacing: RediSpacing.tight) {
                    Text("\(viewModel.prepScore.overall)%")
                        .font(RediTypography.dataHero)
                        .foregroundStyle(readinessTint)

                    Text(viewModel.prepScore.nextMilestoneSummary)
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                }

                Spacer(minLength: 0)

                StatusBadge(tier: viewModel.prepScore.tier)
            }

            ReadinessMeter(
                value: Double(viewModel.prepScore.overall) / 100,
                tint: readinessTint,
                height: 6
            )

            // Supply metrics as dense label:value rows
            MetricGrid(items: [
                MetricItem(
                    label: "Water",
                    value: viewModel.waterRuntimeEstimate.estimatedDaysText,
                    status: metricStatus(for: waterRuntimeColor)
                ),
                MetricItem(
                    label: "Food",
                    value: foodDaysSummary,
                    status: metricStatus(for: foodSupplyTint)
                ),
                MetricItem(
                    label: "Power",
                    value: "\(appState.profile.supplies.batteryCapacity.roundedIntString)%",
                    status: metricStatus(for: powerReserveTint)
                )
            ])
        }
    }

    private var todayNextStepCard: some View {
        CommandPanel(eyebrow: "Best Next Step") {
            VStack(alignment: .leading, spacing: RediSpacing.content) {
                if let summary = viewModel.priorityModeSummary,
                   let action = summary.actions.first {
                    featuredActionCard(
                        eyebrow: "Today's readiness action",
                        iconName: action.systemImage,
                        title: action.title,
                        detail: action.detail,
                        tint: ColorTheme.warning,
                        emphasis: "Priority",
                        supporting: summary.situation.title
                    )
                } else if let suggestion = viewModel.prepScore.suggestions.first {
                    featuredSuggestionCard(suggestion, eyebrow: nil)
                } else if let task = viewModel.scenarioTasks.first {
                    featuredActionCard(
                        eyebrow: "Today's readiness action",
                        iconName: task.category.systemImage,
                        title: task.title,
                        detail: task.description,
                        tint: ColorTheme.accent,
                        emphasis: "+\(task.prepScoreValue)%",
                        supporting: "Scenario-linked"
                    )
                } else {
                    Text("Main readiness actions covered. Open Plan to keep routes, supplies, and family tasks current.")
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                }

                Button {
                    performTodayAction()
                } label: {
                    RediCommandCard(
                        title: "Do This Now",
                        detail: viewModel.priorityModeSummary == nil
                            ? "Open the fastest path to today's highest-value improvement."
                            : "Jump straight into the live priority workflow.",
                        systemImage: "arrow.forward.circle.fill",
                        tint: viewModel.priorityModeSummary == nil ? ColorTheme.accent : ColorTheme.danger,
                        badge: viewModel.priorityModeSummary == nil ? "Today" : "Live",
                        prominence: .accented,
                        layout: .rail
                    )
                }
                .buttonStyle(CardPressButtonStyle())
            }
        }
    }

    private var todayLocalStatusCard: some View {
        CinematicCommandPanel(assetName: "community_storm_town", eyebrow: "Local Status", bannerHeight: 140) {
            VStack(alignment: .leading, spacing: RediSpacing.content) {
                HStack(alignment: .center, spacing: RediSpacing.compact) {
                    Circle()
                        .fill(officialAlertToneColor(viewModel.officialAlertSummary.tone))
                        .frame(width: 8, height: 8)

                    Text(todayLocalStatusTitle)
                        .font(RediTypography.heading)
                        .foregroundStyle(officialAlertToneColor(viewModel.officialAlertSummary.tone))
                }

                Text(viewModel.officialAlertSummary.detail)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)

                MetricGrid(items: [
                    MetricItem(
                        label: "Alerts",
                        value: officialAlertRailValue,
                        status: alertMetricStatus(viewModel.officialAlertSummary.tone)
                    ),
                    MetricItem(
                        label: "Signal",
                        value: signalEnvironmentValue,
                        status: metricStatus(for: signalEnvironmentTint)
                    ),
                    MetricItem(
                        label: "Maps",
                        value: mapCoverageValue,
                        status: metricStatus(for: mapCoverageTint)
                    )
                ])
            }
        }
    }

    private var officialAlertsCardContent: some View {
        VStack(alignment: .leading, spacing: RediSpacing.content) {
            HStack(alignment: .top, spacing: RediSpacing.content) {
                RediIcon(viewModel.nearbyOfficialAlerts.first?.kind.systemImage ?? "warning")
                    .foregroundStyle(officialAlertToneColor(viewModel.officialAlertSummary.tone))
                    .frame(width: 18, height: 18)
                    .padding(10)
                    .background(
                        officialAlertToneColor(viewModel.officialAlertSummary.tone).opacity(0.14),
                        in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text("OFFICIAL ALERTS")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(officialAlertToneColor(viewModel.officialAlertSummary.tone))
                    Text(viewModel.officialAlertSummary.title)
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)
                    Text(viewModel.officialAlertSummary.detail)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            TrustPillGroup(items: viewModel.officialAlertTrustItems)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: RediSpacing.content) {
                    alertMetaPanel(
                        title: "Official Feed",
                        value: viewModel.nearbyOfficialAlerts.first?.issuer ?? "Cached mirror"
                    )
                    alertMetaPanel(
                        title: "RediM8",
                        value: viewModel.nearbyOfficialAlerts.isEmpty ? "Monitoring cache" : "Readable summary only"
                    )
                }

                VStack(spacing: RediSpacing.content) {
                    alertMetaPanel(
                        title: "Official Feed",
                        value: viewModel.nearbyOfficialAlerts.first?.issuer ?? "Cached mirror"
                    )
                    alertMetaPanel(
                        title: "RediM8",
                        value: viewModel.nearbyOfficialAlerts.isEmpty ? "Monitoring cache" : "Readable summary only"
                    )
                }
            }

            if viewModel.nearbyOfficialAlerts.count > 1 {
                Text("\(viewModel.nearbyOfficialAlerts.count) official alerts matched your current area or jurisdiction.")
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
            }

            Text("Official source labels remain separate from RediM8's readable summary so you can judge the warning against the issuing agency.")
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            Button("View on Map") {
                router.openMap()
            }
            .buttonStyle(SecondaryActionButtonStyle())
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
                        title: state.isActive ? "Open Pro Tools" : "See Pro Plans",
                        detail: state.isActive
                            ? "Emergency access is already active. Jump into the unlocked toolkit."
                            : "See the premium tools that open during real incidents or with Pro.",
                        systemImage: "sparkles",
                        tint: accent,
                        badge: state.isActive ? "Live" : "Explore",
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
            title: "Quick Access",
            subtitle: "Map, vault, blackout, guides, and vehicle tools.",
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
                Text("EMERGENCY")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                LazyVGrid(columns: decisionColumns, spacing: RediSpacing.content) {
                    Button {
                        RediHaptics.emergency(enabled: !appState.isStealthModeEnabled)
                        router.presentEmergencyMode(appState: appState)
                    } label: {
                        RediCommandCard(
                            title: "Emergency Mode",
                            detail: "Official alerts, hazard actions, and command tools.",
                            systemImage: "exclamationmark.triangle.fill",
                            tint: ColorTheme.danger,
                            badge: "Critical",
                            prominence: .critical
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())

                    Button {
                        RediHaptics.emergency(enabled: !appState.isStealthModeEnabled)
                        router.presentLeaveNowMode(appState: appState)
                    } label: {
                        RediCommandCard(
                            title: "Leave Now",
                            detail: "Evacuation steps, routes, and go-time checks.",
                            systemImage: "figure.run",
                            tint: ColorTheme.warning,
                            badge: "Evacuate",
                            prominence: .critical
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())
                }
            }

            // Tools grid
            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text("TOOLS")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                LazyVGrid(columns: quickActionColumns, spacing: RediSpacing.content) {
                    quickActionButton(
                        title: "Blackout Mode",
                        subtitle: "Dim tools",
                        systemImage: "lightbulb.slash.fill",
                        tint: ColorTheme.textTertiary
                    ) {
                        router.presentBlackout(appState: appState)
                    }

                    quickActionButton(
                        title: "Signal Nearby",
                        subtitle: "Open mesh",
                        systemImage: "antenna.radiowaves.left.and.right",
                        tint: ColorTheme.accent
                    ) {
                        router.openSignalNearby()
                    }

                    quickActionButton(
                        title: "Emergency Guides",
                        subtitle: "Offline help",
                        systemImage: "books.vertical.fill",
                        tint: ColorTheme.textTertiary
                    ) {
                        router.presentEmergencyGuides(appState: appState)
                    }

                    quickActionButton(
                        title: appState.isStealthModeEnabled ? "Disable Stealth" : "Stealth Mode",
                        subtitle: appState.isStealthModeEnabled ? "Receive-only on" : "Hide & conserve",
                        systemImage: "eye.slash.fill",
                        tint: ColorTheme.textSecondary
                    ) {
                        appState.toggleStealthMode()
                    }
                }
            }

            // Readiness tools
            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text("READINESS")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                LazyVGrid(columns: decisionColumns, spacing: RediSpacing.content) {
                    decisionToolButton(
                        title: "Secure Vault",
                        value: appState.documentVaultService.isUnlocked ? "Ready" : "Locked",
                        subtitle: "ID, insurance, and medical docs",
                        systemImage: "documents",
                        tint: appState.documentVaultService.isUnlocked ? ColorTheme.ready : ColorTheme.accent,
                        action: { router.openVault() }
                    )

                    decisionToolButton(
                        title: "Vehicle Kit",
                        value: viewModel.vehicleReadinessPlan.readiness.percentage.percentageText,
                        subtitle: "\(viewModel.vehicleReadinessPlan.readiness.completedCount) / \(viewModel.vehicleReadinessPlan.readiness.totalCount) essentials checked",
                        systemImage: "car.fill",
                        tint: readinessColor(for: viewModel.vehicleReadinessPlan.readiness.percentage),
                        action: { router.openVehicleReadiness() }
                    )
                }

                Button {
                    activeSheet = .readinessReport
                } label: {
                    RediCommandCard(
                        title: "Readiness Report",
                        detail: "Generate a PDF summary to save, share, or send to family.",
                        systemImage: "doc.richtext.fill",
                        tint: ColorTheme.accent,
                        badge: "PDF",
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
                    Text("OFTEN FORGOTTEN")
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
                    Text("SUPPLY EXPIRY")
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
                    Text("NEAREST WATER SOURCES")
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

            Text("Focus areas: \(readinessFocusAreaText)")
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.textSecondary)

            if let firstSuggestion = viewModel.readinessReport.suggestions.first {
                Text("Next improvement: \(firstSuggestion.title)")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
            }

            Button {
                activeSheet = .readinessReport
            } label: {
                RediCommandCard(
                    title: "Generate Readiness Report",
                    detail: "Create a PDF summary of score, focus areas, and next improvements.",
                    systemImage: "doc.richtext.fill",
                    tint: readinessColor(for: viewModel.prepScore.overall),
                    badge: "PDF",
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

                Text("REDIM8 PRO")
                    .font(RediTypography.display)
                    .foregroundStyle(ColorTheme.text)

                Text("Prepared when networks fail.")
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
                        Text("EMERGENCY UNLOCK ACTIVE")
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.warning)
                        Text("Pro tools are temporarily available without billing while the nearby official warning remains active.")
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

            Text(monetizationCatalog.launchPricingSummary)
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
                    title: appState.emergencyUnlockState.isActive ? "Open Pro Tools" : "Upgrade to Pro",
                    detail: appState.emergencyUnlockState.isActive
                        ? "Emergency access is active. Open the expanded planning and map tools."
                        : "Unlock offline AI, survival maps, and advanced planning tools.",
                    systemImage: "sparkles.rectangle.stack.fill",
                    tint: ColorTheme.textSecondary,
                    badge: appState.emergencyUnlockState.isActive ? "Unlocked" : "Pro",
                    prominence: .accented,
                    layout: .rail
                )
            }
            .buttonStyle(CardPressButtonStyle())
        }
    }

    private var proFeatureHighlights: [String] {
        [
            "Offline assistant safe summaries",
            "Expanded survival maps",
            "Advanced planning tools"
        ]
    }

    private func proFeatureRow(title: String) -> some View {
        HStack(alignment: .center, spacing: RediSpacing.content) {
            Circle()
                .fill(ColorTheme.textSecondary)
                .frame(width: 6, height: 6)

            Text(title)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)

            Spacer()
        }
        .padding(RediSpacing.card)
        .homeInsetSurface(cornerRadius: RediRadius.card)
    }

    private func proOfferCard(_ offer: RediM8ProOffer) -> some View {
        VStack(alignment: .leading, spacing: RediSpacing.compact) {
            if let badge = offer.badge {
                Text(badge.uppercased())
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(offer.isRecommended ? ColorTheme.accent : ColorTheme.textSecondary)
            }

            Text(offer.title)
                .font(RediTypography.heading)
                .foregroundStyle(ColorTheme.text)

            Text(offer.shortPriceText)
                .font(RediTypography.dataLarge)
                .foregroundStyle(ColorTheme.text)

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
                    Text("RediM8 Pro")
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                    Text(appState.emergencyUnlockState.isActive
                         ? "Emergency access active"
                         : "Offline AI, survival maps, advanced tools")
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .lineLimit(1)
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
    }

    // MARK: - Bushfire & Priority Modes

    private var bushfireModeCard: some View {
        VStack(alignment: .leading, spacing: RediSpacing.section) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: RediSpacing.tight) {
                    Text("BUSHFIRE MODE ACTIVE")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.warning)
                    Text("\(viewModel.bushfireReadinessPercentage)%")
                        .font(RediTypography.dataHero)
                        .foregroundStyle(ColorTheme.text)
                    Text("Overall bushfire readiness")
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
                Text("BUSHFIRE CHECKLIST")
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
                Text("BUSHFIRE APPROACHING")
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
                        Text("PRIORITY MODE ACTIVE")
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.warning)
                        Spacer()
                        Button("Clear") {
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
                            Text("NEAREST RESOURCES")
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
                            Text("EVACUATION OPTIONS")
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
                            Button("LEAVE NOW") {
                                router.presentLeaveNowMode(appState: appState)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())

                            Button("Emergency Screen") {
                                router.presentEmergencyMode(appState: appState)
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }

                        VStack(spacing: RediSpacing.content) {
                            Button("LEAVE NOW") {
                                router.presentLeaveNowMode(appState: appState)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())

                            Button("Emergency Screen") {
                                router.presentEmergencyMode(appState: appState)
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                }
            } else {
                Text("Bushfire, flood, blackout, and remote-travel incidents each get their own action order so the app tells the user what matters first.")
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)
            }
        }
    }

    private var readinessFocusAreaText: String {
        let areas = viewModel.readinessReport.focusAreas
        return areas.isEmpty ? "General emergency readiness" : areas.joined(separator: ", ")
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
            Text("SCENARIOS")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
            Text("\(viewModel.prepScore.categoryScores.count) tracked")
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

    // MARK: - Reusable Card Builders

    private func featuredSuggestionCard(_ suggestion: ImprovementSuggestion, eyebrow: String? = "BEST NEXT STEP") -> some View {
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
            TrustPillItem(title: state.isActive ? "Temporary access" : "Ended", tone: state.isActive ? .verified : .info),
            TrustPillItem(title: "\(state.featureCount) Pro upgrades", tone: .info)
        ]

        if let triggerAlert = state.triggerAlert {
            items.append(TrustPillItem(title: triggerAlert.scopeTrustLabel, tone: triggerAlert.isAreaScoped ? .verified : .caution))
            items.append(TrustPillItem(title: triggerAlert.severity.title, tone: triggerAlert.severity == .emergencyWarning ? .caution : .info))
        }

        return items
    }

    private func emergencyUnlockTimingLine(for state: EmergencyUnlockState, triggerAlert: OfficialAlert) -> String {
        if state.isActive, let accessEndsAt = state.accessEndsAt {
            return "\(triggerAlert.issuer) • Until \(DateFormatter.rediM8Short.string(from: accessEndsAt))"
        }
        if state.isActive {
            return "\(triggerAlert.issuer) • Active while the official warning remains listed"
        }
        if let endedAt = state.endedAt {
            return "\(triggerAlert.issuer) • Ended \(DateFormatter.rediM8Short.string(from: endedAt))"
        }
        return triggerAlert.issuer
    }

    private func safeModeCard(summary: SafeModeHomeSummary) -> some View {
        ModeHeroCard(
            eyebrow: "Safe Mode",
            title: summary.alert.severity.title,
            subtitle: summary.alert.title,
            iconName: summary.alert.kind.systemImage,
            accent: officialAlertToneColor(.danger)
        ) {
            VStack(alignment: .leading, spacing: RediSpacing.content) {
                TrustPillGroup(items: viewModel.officialAlertTrustItems)

                operationalSafeModeLine(label: "Shelter", detail: summary.nearestShelterLine)
                operationalSafeModeLine(label: "Water", detail: summary.nearestWaterLine)
                operationalSafeModeLine(label: "Route", detail: summary.routeLine)

                Text(summary.note)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)

                Button("View Map") {
                    router.openMap()
                }
                .buttonStyle(PrimaryActionButtonStyle())

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: RediSpacing.content) {
                        Button("Send Alert") {
                            router.openSignalNearby()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())

                        Button("Share Location") {
                            router.openSignalNearby()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }

                    VStack(spacing: RediSpacing.content) {
                        Button("Send Alert") {
                            router.openSignalNearby()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())

                        Button("Share Location") {
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
