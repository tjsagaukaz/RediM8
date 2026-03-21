import SwiftUI

extension HomeView {
    var officialAlertsPanel: some View {
        CollapsiblePanelCard(
            title: L10n.tr("home.official_alerts.panel.title", "Official Alerts"),
            subtitle: officialAlertsPanelSubtitle,
            accent: officialAlertToneColor(selectedOfficialAlertSummary.tone),
            isExpanded: $isShowingOfficialAlerts
        ) {
            officialAlertsCardContent
        }
    }

    var emergencyUnlockCard: some View {
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

    func safeModeCard(summary: SafeModeHomeSummary) -> some View {
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
}
