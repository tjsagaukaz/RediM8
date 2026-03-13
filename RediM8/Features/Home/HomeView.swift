import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let appState: AppState
    private let openPlan: () -> Void
    private let openVault: () -> Void
    private let openLibrary: () -> Void
    private let openMap: () -> Void
    private let openVehicleReadiness: () -> Void
    private let openWaterRuntime: () -> Void
    private let openBlackout: () -> Void
    private let openSignalNearby: () -> Void
    private let openEmergencyGuides: () -> Void
    private let openEmergency: () -> Void
    private let openLeaveNow: () -> Void
    private let monetizationCatalog = RediM8MonetizationCatalog.launch

    @State private var isShowingReadinessReport = false
    @State private var isShowingSettings = false
    @State private var isShowingPro = false
    @State private var isShowingOperationalInsights = false
    @State private var isShowingPriorityTools = false
    @State private var isShowingBushfireReadiness = false
    @State private var isShowingReadinessSummary = false

    init(
        appState: AppState,
        openPlan: @escaping () -> Void,
        openVault: @escaping () -> Void,
        openLibrary: @escaping () -> Void,
        openMap: @escaping () -> Void,
        openVehicleReadiness: @escaping () -> Void,
        openWaterRuntime: @escaping () -> Void,
        openBlackout: @escaping () -> Void,
        openSignalNearby: @escaping () -> Void,
        openEmergencyGuides: @escaping () -> Void,
        openEmergency: @escaping () -> Void,
        openLeaveNow: @escaping () -> Void
    ) {
        self.appState = appState
        self.openPlan = openPlan
        self.openVault = openVault
        self.openLibrary = openLibrary
        self.openMap = openMap
        self.openVehicleReadiness = openVehicleReadiness
        self.openWaterRuntime = openWaterRuntime
        self.openBlackout = openBlackout
        self.openSignalNearby = openSignalNearby
        self.openEmergencyGuides = openEmergencyGuides
        self.openEmergency = openEmergency
        self.openLeaveNow = openLeaveNow
        _viewModel = StateObject(wrappedValue: HomeViewModel(appState: appState))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RediSpacing.section) {
                if appState.isStealthModeEnabled {
                    StealthModeIndicatorView()
                }

                if appState.settings.privacy.isAnonymousModeEnabled {
                    HiddenModeIndicatorView()
                }

                homeStatusRail

                if let safeModeSummary = viewModel.safeModeSummary {
                    safeModeCard(summary: safeModeSummary)
                }

                emergencyLaunchCard

                nextActionsCard

                officialAlertsCard

                if appState.emergencyUnlockState.isVisible {
                    emergencyUnlockCard
                }

                preparednessOverviewCard

                emergencyUtilitiesCard

                emergencyGuidesCard

                decisionToolsCard

                proOverviewCard

                if shouldShowOperationalInsights {
                    CollapsiblePanelCard(
                        title: "Operational Insights",
                        subtitle: "Forgotten items, expiry reminders, and nearby water guidance when reserves are running low.",
                        accent: ColorTheme.warning,
                        isExpanded: $isShowingOperationalInsights
                    ) {
                        operationalInsightsContent
                    }
                }

                CollapsiblePanelCard(
                    title: "Priority Situations",
                    subtitle: viewModel.priorityModeSummary?.subtitle ?? "Activate a live situation and RediM8 will bring the right actions forward.",
                    accent: ColorTheme.warning,
                    isExpanded: $isShowingPriorityTools
                ) {
                    priorityModeCard
                }

                if viewModel.isBushfireModeEnabled {
                    CollapsiblePanelCard(
                        title: "Bushfire Readiness",
                        subtitle: "Scenario-linked preparation for households facing bushfire season.",
                        accent: ColorTheme.warning,
                        isExpanded: $isShowingBushfireReadiness
                    ) {
                        bushfireModeCard
                    }
                }

                CollapsiblePanelCard(
                    title: "Readiness Report",
                    subtitle: "Visual household summary ready to save, share, or send to family.",
                    accent: ColorTheme.info,
                    isExpanded: $isShowingReadinessSummary
                ) {
                    readinessReportContent
                }
            }
            .padding(.horizontal, RediSpacing.screen)
            .padding(.top, RediSpacing.screen)
            .padding(.bottom, RediLayout.commandDockContentInset)
        }
        .scrollIndicators(.hidden)
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
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
        .background(Color.clear)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $isShowingReadinessReport) {
            NavigationStack {
                ReadinessReportView(
                    report: viewModel.readinessReport,
                    onShare: viewModel.shareReadinessReportItems,
                    onSavePDF: viewModel.saveReadinessReportPDF,
                    onSendToFamily: viewModel.sendToFamilyItems
                )
            }
            .rediSheetPresentation(style: .plan, accent: ColorTheme.warning)
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView(appState: appState)
            }
            .rediSheetPresentation(style: .neutral, accent: ColorTheme.premium)
        }
        .sheet(isPresented: $isShowingPro) {
            NavigationStack {
                RediM8ProView(emergencyUnlockState: appState.emergencyUnlockState)
            }
            .rediSheetPresentation(style: .pro, accent: ColorTheme.warning)
        }
    }

    private let quickActionColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let priorityColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let decisionColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let preparednessColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
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

    private var preparednessOverviewCard: some View {
        PanelCard(
            backgroundAssetName: "preparedness_flatlay"
        ) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    RediM8Wordmark(
                        iconSize: 40,
                        titleFont: .system(size: 22, weight: .black),
                        subtitle: "Preparedness dashboard",
                        subtitleColor: ColorTheme.textFaint
                    )

                    Spacer()

                    StatusBadge(tier: viewModel.prepScore.tier)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 18) {
                        preparednessHeadlineBlock

                        Spacer()

                        preparednessScenarioBlock(isTrailing: true)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        preparednessHeadlineBlock
                        preparednessScenarioBlock(isTrailing: false)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.prepScore.milestoneCaption)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTheme.text)
                    Text("Tracking \(viewModel.scenarioSummary)")
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textMuted)
                }

                Button(action: openWaterRuntime) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("WATER RUNTIME")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(waterRuntimeColor)
                                Text(viewModel.waterRuntimeEstimate.estimatedDaysText.uppercased())
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundStyle(ColorTheme.text)
                                Text("Target \(viewModel.waterRuntimeEstimate.recommendedTargetText)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(ColorTheme.textFaint)
                            }

                            Spacer()

                            RediIcon("water")
                                .foregroundStyle(waterRuntimeColor)
                                .frame(width: 24, height: 24)
                                .padding(12)
                                .background(waterRuntimeColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        Text(viewModel.waterRuntimeEstimate.statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textMuted)
                            .multilineTextAlignment(.leading)

                        HStack {
                            Text(viewModel.waterRuntimeEstimate.statusTitle.uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(waterRuntimeColor)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(ColorTheme.textFaint)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [ColorTheme.panelElevated, ColorTheme.panel],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(ColorTheme.dividerStrong, lineWidth: 1)
                    )
                }
                .buttonStyle(CardPressButtonStyle())

                LazyVGrid(columns: preparednessColumns, spacing: 12) {
                    ForEach(viewModel.prepScore.categoryScores) { score in
                        preparednessCategoryTile(score)
                    }
                }

                HStack(spacing: 12) {
                    Button("Update Supplies") {
                        viewModel.reopenSetup()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button("View Plan") {
                        openPlan()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }

    private var officialAlertsCard: some View {
        PanelCard(
            title: "Official Alerts",
            subtitle: "Mirrored Australian public warnings that stay readable when coverage drops.",
            backgroundAssetName: "community_storm_town",
            backgroundImageOffset: CGSize(width: 0, height: 8)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    RediIcon(viewModel.nearbyOfficialAlerts.first?.kind.systemImage ?? "warning")
                        .foregroundStyle(officialAlertToneColor(viewModel.officialAlertSummary.tone))
                        .frame(width: 18, height: 18)
                        .padding(10)
                        .background(
                            officialAlertToneColor(viewModel.officialAlertSummary.tone).opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("OFFICIAL ALERTS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(officialAlertToneColor(viewModel.officialAlertSummary.tone))
                        Text(viewModel.officialAlertSummary.title)
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)
                        Text(viewModel.officialAlertSummary.detail)
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textMuted)
                    }

                    Spacer(minLength: 0)
                }

                TrustPillGroup(items: viewModel.officialAlertTrustItems)

                HStack(spacing: 12) {
                    alertMetaPanel(
                        title: "Official Feed",
                        value: viewModel.nearbyOfficialAlerts.first?.issuer ?? "Cached mirror"
                    )
                    alertMetaPanel(
                        title: "RediM8",
                        value: viewModel.nearbyOfficialAlerts.isEmpty ? "Monitoring cache" : "Readable summary only"
                    )
                }

                if viewModel.nearbyOfficialAlerts.count > 1 {
                    Text("\(viewModel.nearbyOfficialAlerts.count) official alerts matched your current area or jurisdiction.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textMuted)
                }

                Text("Official source labels remain separate from RediM8's readable summary so you can judge the warning against the issuing agency.")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textFaint)

                Button("View on Map") {
                    openMap()
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }

    private var emergencyLaunchCard: some View {
        HeroPanel(
            eyebrow: "Immediate Access",
            title: "Emergency Mode",
            subtitle: "Open the high-visibility survival deck first. Leave-now flow and offline map stay staged directly underneath.",
            iconName: "emergency",
            accent: ColorTheme.danger,
            atmosphere: ColorTheme.accent.opacity(0.18),
            showsBreathing: true
        ) {
            TrustPillGroup(items: [
                TrustPillItem(title: "Action first", tone: .danger),
                TrustPillItem(title: "Offline staged", tone: .info),
                TrustPillItem(title: "High visibility", tone: .verified)
            ])

            Button("OPEN EMERGENCY MODE") {
                RediHaptics.emergency(enabled: !appState.isStealthModeEnabled)
                openEmergency()
            }
            .buttonStyle(EmergencyActionButtonStyle())

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Button("LEAVE NOW") {
                        RediHaptics.emergency(enabled: !appState.isStealthModeEnabled)
                        openLeaveNow()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button("OFFLINE MAP") {
                        openMap()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                VStack(spacing: 12) {
                    Button("LEAVE NOW") {
                        RediHaptics.emergency(enabled: !appState.isStealthModeEnabled)
                        openLeaveNow()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button("OFFLINE MAP") {
                        openMap()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }

    private var nextActionsCard: some View {
        PanelCard(
            title: "Next Actions",
            subtitle: viewModel.priorityModeSummary == nil
                ? "Highest-value tasks to lift readiness fast without hunting through menus."
                : "Priority mode is active, so RediM8 is surfacing the most urgent steps first."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let summary = viewModel.priorityModeSummary {
                    HStack {
                        Text("PRIORITY MODE ACTIVE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ColorTheme.warning)
                        Spacer()
                        Button("Clear") {
                            viewModel.clearPriorityMode()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }

                    if let featuredAction = summary.actions.first {
                        featuredActionCard(
                            eyebrow: "Now",
                            iconName: featuredAction.systemImage,
                            title: featuredAction.title,
                            detail: featuredAction.detail,
                            tint: ColorTheme.warning,
                            emphasis: "Priority",
                            supporting: "Mode-specific"
                        )
                    }

                    ForEach(Array(summary.actions.dropFirst().prefix(2))) { action in
                        nextActionRow(
                            iconName: action.systemImage,
                            title: action.title,
                            detail: action.detail,
                            emphasis: nil,
                            supporting: nil,
                            tint: ColorTheme.warning
                        )
                    }
                } else {
                    if let featuredSuggestion = viewModel.prepScore.suggestions.first {
                        featuredActionCard(
                            eyebrow: "Best Next Step",
                            iconName: featuredSuggestion.category.systemImage,
                            title: featuredSuggestion.title,
                            detail: featuredSuggestion.detail,
                            tint: readinessColor(for: scoreValue(for: featuredSuggestion.category)),
                            emphasis: "+\(featuredSuggestion.impact)%",
                            supporting: featuredSuggestion.category.quickTaskEstimate
                        )
                    }

                    ForEach(Array(viewModel.prepScore.suggestions.dropFirst().prefix(2))) { suggestion in
                        nextActionRow(
                            iconName: suggestion.category.systemImage,
                            title: suggestion.title,
                            detail: suggestion.detail,
                            emphasis: "+\(suggestion.impact)%",
                            supporting: suggestion.category.quickTaskEstimate,
                            tint: readinessColor(for: scoreValue(for: suggestion.category))
                        )
                    }

                    if let task = viewModel.scenarioTasks.first {
                        nextActionRow(
                            iconName: task.category.systemImage,
                            title: task.title,
                            detail: task.description,
                            emphasis: "+\(task.prepScoreValue)%",
                            supporting: "Scenario-linked",
                            tint: ColorTheme.info
                        )
                    }
                }
            }
        }
    }

    private var emergencyUnlockCard: some View {
        let state = appState.emergencyUnlockState
        let accent = state.isActive ? ColorTheme.warning : ColorTheme.accent
        let unlockedRows = monetizationCatalog.emergencyUnlockRows.filter { state.unlockedFeatureIDs.contains($0.id) }

        return PanelCard(title: state.calloutTitle, subtitle: state.calloutDetail) {
            VStack(alignment: .leading, spacing: 12) {
                if let triggerAlert = state.triggerAlert {
                    HStack(alignment: .top, spacing: 12) {
                        RediIcon(triggerAlert.kind.systemImage)
                            .foregroundStyle(accent)
                            .frame(width: 18, height: 18)
                            .padding(10)
                            .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(triggerAlert.title)
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)
                            Text(emergencyUnlockTimingLine(for: state, triggerAlert: triggerAlert))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                }

                TrustPillGroup(items: emergencyUnlockTrustItems)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(unlockedRows.prefix(3))) { row in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)
                                Text(row.proValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(accent)
                            }
                            Spacer()
                        }
                    }
                }

                Button(state.isActive ? "Open Pro Tools" : "See Pro Plans") {
                    isShowingPro = true
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }

    private var emergencyUtilitiesCard: some View {
        PanelCard(title: "Emergency Utilities", subtitle: "One-tap controls for privacy, local comms, and emergency access.") {
            LazyVGrid(columns: quickActionColumns, spacing: 12) {
                quickActionButton(
                    title: "Blackout Mode",
                    subtitle: "Dim tools"
                ) {
                    openBlackout()
                }

                quickActionButton(
                    title: "Signal Nearby",
                    subtitle: "Open mesh"
                ) {
                    openSignalNearby()
                }

                quickActionButton(
                    title: "Emergency Guides",
                    subtitle: "Offline help"
                ) {
                    openEmergencyGuides()
                }

                quickActionButton(
                    title: appState.isStealthModeEnabled ? "Disable Stealth" : "Stealth Mode",
                    subtitle: appState.isStealthModeEnabled ? "Receive-only on" : "Hide & conserve"
                ) {
                    appState.toggleStealthMode()
                }
            }
        }
    }

    private var emergencyGuidesCard: some View {
        PanelCard(title: "Emergency Guides", subtitle: "Start with the three lanes people look for first under stress.") {
            VStack(alignment: .leading, spacing: 12) {
                guideLaneRow(
                    title: "FIRST AID",
                    detail: "Bleeding, burns, snake bite, and emergency first-response steps.",
                    iconName: "first_aid",
                    tint: ColorTheme.danger
                )
                guideLaneRow(
                    title: "SURVIVAL",
                    detail: "Water, shelter, heat, and bushcraft guidance that stays available offline.",
                    iconName: "tent",
                    tint: ColorTheme.info
                )
                guideLaneRow(
                    title: "EVACUATION",
                    detail: "Bushfire, flood, blackout, and leave-now decision support.",
                    iconName: "route",
                    tint: ColorTheme.warning
                )

                if let topGuide = viewModel.recommendedGuides.first {
                    Text("Top offline match: \(topGuide.title)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ColorTheme.text)
                }

                HStack(spacing: 12) {
                    Button("Open Guide Library") {
                        openLibrary()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button("Emergency Guide Sheet") {
                        openEmergencyGuides()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }

    private var operationalInsightsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !viewModel.forgottenItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Often Forgotten")
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)

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
                VStack(alignment: .leading, spacing: 12) {
                    Text("Supply Expiry")
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)

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
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nearest Water Sources")
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)

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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.readinessReport.scoreSummary)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(readinessColor(for: viewModel.prepScore.overall))
                    Text(viewModel.readinessReport.householdSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                RediIcon("documents")
                    .foregroundStyle(ColorTheme.info)
                    .frame(width: 28, height: 28)
            }

            Text("Focus areas: \(readinessFocusAreaText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let firstSuggestion = viewModel.readinessReport.suggestions.first {
                Text("Next improvement: \(firstSuggestion.title)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ColorTheme.text)
            }

            Button("Generate Readiness Report") {
                isShowingReadinessReport = true
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
    }

    private var decisionToolsCard: some View {
        PanelCard(title: "Support Tools", subtitle: "Jump straight into leave-now flow, your secure documents, or vehicle readiness.") {
            VStack(alignment: .leading, spacing: 14) {
                Button("LEAVE NOW") {
                    openLeaveNow()
                }
                .buttonStyle(EmergencyActionButtonStyle())

                LazyVGrid(columns: decisionColumns, spacing: 12) {
                    decisionToolButton(
                        title: "Secure Vault",
                        value: "Offline locked",
                        subtitle: "ID, insurance, and medical docs ready without signal",
                        systemImage: "documents",
                        tint: ColorTheme.info,
                        action: openVault
                    )

                    decisionToolButton(
                        title: "Vehicle Kit",
                        value: viewModel.vehicleReadinessPlan.readiness.percentage.percentageText,
                        subtitle: "\(viewModel.vehicleReadinessPlan.readiness.completedCount) / \(viewModel.vehicleReadinessPlan.readiness.totalCount) essentials checked",
                        systemImage: "car.fill",
                        tint: readinessColor(for: viewModel.vehicleReadinessPlan.readiness.percentage),
                        action: openVehicleReadiness
                    )
                }
            }
        }
    }

    private var proOverviewCard: some View {
        PanelCard(title: "RediM8 Pro", subtitle: "Launch pricing for premium planning, expanded maps, and the offline assistant.") {
            VStack(alignment: .leading, spacing: 14) {
                if appState.emergencyUnlockState.isActive {
                    HStack(alignment: .top, spacing: 12) {
                        RediIcon(appState.emergencyUnlockState.triggerAlert?.kind.systemImage ?? "warning")
                            .foregroundStyle(ColorTheme.warning)
                            .frame(width: 18, height: 18)
                            .padding(10)
                            .background(ColorTheme.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("EMERGENCY UNLOCK ACTIVE")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(ColorTheme.warning)
                            Text("Pro tools are temporarily available without billing while the nearby official warning remains active.")
                                .font(.subheadline)
                                .foregroundStyle(ColorTheme.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(monetizationCatalog.offers) { offer in
                            VStack(alignment: .leading, spacing: 6) {
                                if let badge = offer.badge {
                                    Text(badge.uppercased())
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(offer.isRecommended ? ColorTheme.accent : ColorTheme.warning)
                                }

                                Text(offer.title)
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)
                                Text(offer.shortPriceText)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(ColorTheme.text)
                                Text(offer.interval == .lifetime ? "one-time" : offer.interval == .annual ? "per year" : "per month")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .frame(width: 138, alignment: .leading)
                            .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke((offer.isRecommended ? ColorTheme.accent : offer.isFoundingOffer ? ColorTheme.warning : ColorTheme.info).opacity(0.22), lineWidth: 1)
                            )
                        }
                    }
                }

                Text(monetizationCatalog.alwaysFreePromise)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Button("See Pro Plans") {
                    isShowingPro = true
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }

    private var bushfireModeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BUSHFIRE MODE ACTIVE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ColorTheme.warning)
                    Text("\(viewModel.bushfireReadinessPercentage)%")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(ColorTheme.text)
                    Text("Overall bushfire readiness")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                RediIcon("fire_trail")
                    .foregroundStyle(ColorTheme.warning)
                    .frame(width: 28, height: 28)
                    .padding(14)
                    .background(ColorTheme.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            VStack(spacing: 12) {
                ForEach(viewModel.bushfireStatusRows) { row in
                    HStack(spacing: 12) {
                        RediIcon(row.systemImage)
                            .foregroundStyle(bushfireToneColor(row.tone))
                            .frame(width: 22, height: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)
                            Text(row.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            Divider().background(ColorTheme.divider)

            VStack(alignment: .leading, spacing: 10) {
                Text("Bushfire Checklist")
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)

                ForEach(viewModel.bushfireChecklistItems) { item in
                    Button {
                        viewModel.toggleBushfireChecklist(item.kind)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isChecked ? ColorTheme.ready : ColorTheme.warning)
                            Text(item.kind.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(ColorTheme.text)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(CardPressButtonStyle())
                }
            }

            Divider().background(ColorTheme.divider)

            VStack(alignment: .leading, spacing: 10) {
                Text("Bushfire Approaching")
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)

                ForEach(Array(viewModel.bushfireEmergencySteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .font(.headline)
                            .foregroundStyle(ColorTheme.warning)
                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                RediIcon("warning")
                    .foregroundStyle(ColorTheme.warning)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.bushfireReminderTitle)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text(viewModel.bushfireReminderMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(ColorTheme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var priorityModeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: priorityColumns, spacing: 10) {
                    ForEach(viewModel.prioritySituationOptions) { situation in
                        Button {
                            viewModel.togglePrioritySituation(situation)
                        } label: {
                        HStack(spacing: 10) {
                            RediIcon(situation.systemImage)
                                .frame(width: 15, height: 15)
                            Text(situation.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(appState.activePrioritySituation == situation ? ColorTheme.warning : ColorTheme.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            appState.activePrioritySituation == situation
                                ? ColorTheme.warning.opacity(0.16)
                                : Color.black.opacity(0.24),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("PRIORITY MODE ACTIVE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ColorTheme.warning)
                        Spacer()
                        Button("Clear") {
                            viewModel.clearPriorityMode()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(summary.actions) { action in
                            HStack(alignment: .top, spacing: 12) {
                                RediIcon(action.systemImage)
                                    .foregroundStyle(ColorTheme.warning)
                                    .frame(width: 16, height: 16)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(action.title)
                                        .font(.headline)
                                        .foregroundStyle(ColorTheme.text)
                                    Text(action.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !summary.resources.isEmpty {
                        Divider().background(ColorTheme.divider)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Nearest Resources")
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)
                            ForEach(summary.resources) { resource in
                                HStack(alignment: .top, spacing: 12) {
                                    RediIcon(resource.systemImage)
                                        .foregroundStyle(ColorTheme.info)
                                        .frame(width: 16, height: 16)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(resource.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(ColorTheme.text)
                                        Text(resource.detail)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    if !summary.evacuationOptions.isEmpty {
                        Divider().background(ColorTheme.divider)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Evacuation Options")
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)
                            ForEach(summary.evacuationOptions, id: \.self) { option in
                                HStack(alignment: .top, spacing: 10) {
                                    RediIcon("route", fallbackSystemName: "arrow.triangle.turn.up.right.diamond.fill")
                                        .foregroundStyle(ColorTheme.info)
                                        .frame(width: 14, height: 14)
                                        .padding(.top, 4)
                                    Text(option)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button("LEAVE NOW") {
                            openLeaveNow()
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        Button("Emergency Screen") {
                            openEmergency()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            } else {
                Text("Bushfire, flood, blackout, and remote-travel incidents each get their own action order so the app tells the user what matters first.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("\(viewModel.prepScore.overall)%")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(readinessColor(for: viewModel.prepScore.overall))
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Text(viewModel.prepScore.milestoneTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(ColorTheme.text)

            Text(viewModel.prepScore.nextMilestoneSummary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorTheme.textMuted)
        }
    }

    private func preparednessScenarioBlock(isTrailing: Bool) -> some View {
        VStack(alignment: isTrailing ? .trailing : .leading, spacing: 8) {
            Text("SCENARIOS")
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.textFaint)
            Text("\(viewModel.prepScore.categoryScores.count) tracked")
                .font(.headline.weight(.bold))
                .foregroundStyle(ColorTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: isTrailing ? .trailing : .leading)
    }

    private func preparednessCategoryTile(_ score: CategoryScore) -> some View {
        let tint = readinessColor(for: score.score)
        let progress = min(max(score.score, 0), 100)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                RediIcon(score.category.systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 18, height: 18)

                Spacer()

                Text(score.score.percentageText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
            }

            Text(score.category.title)
                .font(.headline)
                .foregroundStyle(ColorTheme.text)

            ReadinessMeter(value: Double(progress) / 100, tint: tint)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(
            LinearGradient(
                colors: [ColorTheme.panelElevated, ColorTheme.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ColorTheme.dividerStrong, lineWidth: 1)
        )
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
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 48, height: 48)

                    RediIcon(iconName)
                        .foregroundStyle(tint)
                        .frame(width: 20, height: 20)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow.uppercased())
                        .font(RediTypography.metadata)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(ColorTheme.text)
                }

                Spacer(minLength: 0)

                Text(emphasis)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(tint.opacity(0.14), in: Capsule())
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textMuted)

            if let supporting {
                Text(supporting)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.textFaint)
            }
        }
        .padding(16)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 20,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: tint.opacity(0.12)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 20, edgeColor: tint.opacity(0.16), shadowColor: tint.opacity(0.06)))
    }

    private func nextActionRow(
        iconName: String,
        title: String,
        detail: String,
        emphasis: String?,
        supporting: String?,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RediIcon(iconName)
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 6) {
                if let emphasis {
                    Text(emphasis)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(tint.opacity(0.12), in: Capsule())
                }
                if let supporting {
                    Text(supporting)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ColorTheme.textFaint)
                }
            }
        }
        .padding(14)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 18,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 18, edgeColor: tint.opacity(0.12), shadowColor: tint.opacity(0.04)))
    }

    private func guideLaneRow(title: String, detail: String, iconName: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RediIcon(iconName)
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .padding(10)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 18,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 18, edgeColor: tint.opacity(0.12), shadowColor: tint.opacity(0.04)))
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
            VStack(alignment: .leading, spacing: 12) {
                TrustPillGroup(items: viewModel.officialAlertTrustItems)

                operationalSafeModeLine(label: "Shelter", detail: summary.nearestShelterLine)
                operationalSafeModeLine(label: "Water", detail: summary.nearestWaterLine)
                operationalSafeModeLine(label: "Route", detail: summary.routeLine)

                Text(summary.note)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textMuted)

                Button("View Map") {
                    openMap()
                }
                .buttonStyle(PrimaryActionButtonStyle())

                HStack(spacing: 12) {
                    Button("Send Alert") {
                        openSignalNearby()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button("Share Location") {
                        openSignalNearby()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
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
            ColorTheme.info
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

    private func alertMetaPanel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(RediTypography.metadata)
                .foregroundStyle(ColorTheme.textFaint)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 16,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: ColorTheme.info.opacity(0.06)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 16, edgeColor: ColorTheme.info.opacity(0.08), shadowColor: ColorTheme.info.opacity(0.03)))
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    RediIcon(systemImage)
                        .foregroundStyle(tint)
                        .frame(width: 18, height: 18)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text(value)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(tint)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
            .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func quickActionButton(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .padding(14)
            .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func operationalSafeModeLine(label: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.textFaint)
                .frame(width: 58, alignment: .leading)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func insightRow(title: String, detail: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RediIcon(systemImage)
                .foregroundStyle(tint)
                .frame(width: 24, height: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
