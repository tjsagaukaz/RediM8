import SwiftUI

extension HomeView {
    var homeStatusRail: some View {
        SystemStatusRail(items: homeStatusItems, accent: ColorTheme.accent)
    }

    var todayReadinessCard: some View {
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

    var todayNextStepCard: some View {
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

    var todayLocalStatusCard: some View {
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
                        .accessibilityIdentifier("home.todayLocalStatus.title")
                }
                .accessibilityElement(children: .combine)

                Text(viewModel.officialAlertSummary.detail)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.todayLocalStatus.detail")

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
        .accessibilityIdentifier("home.todayLocalStatus.card")
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
}
