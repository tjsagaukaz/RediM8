import SwiftUI

struct SettingsView: View {
    private enum SettingsWorkspace: String, CaseIterable, Identifiable {
        case overview
        case privacy
        case signal
        case maps
        case preparedness
        case device

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview:
                L10n.tr("settings.workspace.overview.title", "Overview")
            case .privacy:
                L10n.tr("settings.workspace.privacy.title", "Privacy")
            case .signal:
                L10n.tr("settings.workspace.signal.title", "Signal")
            case .maps:
                L10n.tr("settings.workspace.maps.title", "Maps")
            case .preparedness:
                L10n.tr("settings.workspace.preparedness.title", "Preparedness")
            case .device:
                L10n.tr("settings.workspace.device.title", "Device")
            }
        }

        var detail: String {
            switch self {
            case .overview:
                L10n.tr("settings.workspace.overview.detail", "Pro, safety, profile")
            case .privacy:
                L10n.tr("settings.workspace.privacy.detail", "Visibility and sharing")
            case .signal:
                L10n.tr("settings.workspace.signal.detail", "Mesh and reports")
            case .maps:
                L10n.tr("settings.workspace.maps.detail", "Offline packs and layers")
            case .preparedness:
                L10n.tr("settings.workspace.preparedness.detail", "Household reminders")
            case .device:
                L10n.tr("settings.workspace.device.detail", "Battery, data, app")
            }
        }

        var iconName: String {
            switch self {
            case .overview:
                "shield"
            case .privacy:
                "lock.shield"
            case .signal:
                "signal"
            case .maps:
                "map_marker"
            case .preparedness:
                "checklist"
            case .device:
                "battery.100"
            }
        }

        var accent: Color {
            switch self {
            case .overview:
                ColorTheme.textTertiary
            case .privacy:
                ColorTheme.textTertiary
            case .signal:
                ColorTheme.textTertiary
            case .maps:
                ColorTheme.textTertiary
            case .preparedness:
                ColorTheme.textTertiary
            case .device:
                ColorTheme.textTertiary
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let appState: AppState

    @StateObject private var viewModel: SettingsViewModel
    @State private var selectedWorkspace: SettingsWorkspace = .overview
    private let monetizationCatalog = RediM8MonetizationCatalog.launch

    init(appState: AppState) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: SettingsViewModel(appState: appState))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if appState.isStealthModeEnabled {
                    StealthModeIndicatorView()
                }

                if appState.settings.privacy.isAnonymousModeEnabled {
                    HiddenModeIndicatorView()
                }

                settingsHeroCard
                SystemStatusRail(items: settingsStatusItems, accent: ColorTheme.textTertiary)
                workspaceHubCard
                activeWorkspaceContent
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("settings.navigation.title", "System Control"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.tr("common.done", "Done")) {
                    dismiss()
                }
            }
        }
        .alert(item: $viewModel.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text(L10n.tr("common.ok", "OK")))
            )
        }
        .alert(L10n.tr("settings.alert.reset_node.title", "Reset Node ID?"), isPresented: $viewModel.isShowingResetNodeAlert) {
            Button(L10n.tr("common.reset", "Reset"), role: .destructive) {
                viewModel.resetLocalNodeID()
            }
            Button(L10n.tr("common.cancel", "Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr(
                "settings.alert.reset_node.message",
                "Resetting the node ID changes the anonymous identifier RediM8 uses for this device."
            ))
        }
        .alert(L10n.tr("settings.alert.clear_cache.title", "Clear Cached Data?"), isPresented: $viewModel.isShowingClearCacheAlert) {
            Button(L10n.tr("common.clear", "Clear"), role: .destructive) {
                viewModel.clearCachedData()
            }
            Button(L10n.tr("common.cancel", "Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr(
                "settings.alert.clear_cache.message",
                "This keeps your preparedness data and offline packs, but clears temporary signal and community report history."
            ))
        }
        .alert(L10n.tr("settings.alert.safe_defaults.title", "Reset to Emergency-Safe Defaults?"), isPresented: $viewModel.isShowingEmergencySafeDefaultsAlert) {
            Button(L10n.tr("settings.alert.safe_defaults.confirm", "Reset"), role: .destructive) {
                viewModel.resetToEmergencySafeDefaults()
            }
            Button(L10n.tr("common.cancel", "Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr(
                "settings.alert.safe_defaults.message",
                "This restores approximate location sharing, balanced signal behavior, critical map layers, and turns Stealth Mode off."
            ))
        }
    }

    private var settingsHeroCard: some View {
        ModeHeroCard(
            eyebrow: L10n.tr("settings.hero.eyebrow", "Device Console"),
            title: L10n.tr("settings.hero.title", "System Control"),
            subtitle: L10n.tr(
                "settings.hero.subtitle",
                "Control how this device behaves when normal systems fail."
            ),
            iconName: "shield",
            accent: ColorTheme.textTertiary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TrustPillGroup(items: [
                    TrustPillItem(title: L10n.tr("settings.hero.trust.local_first", "Works without internet"), tone: .verified),
                    TrustPillItem(title: L10n.tr("settings.hero.trust.offline_aware", "Safe by default"), tone: .info),
                    TrustPillItem(title: L10n.tr("settings.hero.trust.emergency_defaults", "Designed for emergencies"), tone: .caution)
                ])

                VStack(alignment: .leading, spacing: 8) {
                    settingsHeroLine(title: L10n.tr("settings.hero.line.privacy", "Privacy"), detail: privacySummaryLine)
                    settingsHeroLine(title: L10n.tr("settings.hero.line.maps", "Maps"), detail: mapsSummaryLine)
                    settingsHeroLine(title: L10n.tr("settings.hero.line.preparedness", "Preparedness"), detail: preparednessSummaryLine)
                }
            }
        }
    }

    private var settingsStatusItems: [OperationalStatusItem] {
        [
            OperationalStatusItem(
                iconName: "lock.shield",
                label: L10n.tr("settings.status.stealth", "Stealth"),
                value: appState.isStealthModeEnabled
                    ? L10n.tr("settings.status.stealth.value.reduced", "Reduced")
                    : L10n.tr("settings.status.stealth.value.standard", "Standard"),
                tone: appState.isStealthModeEnabled ? .caution : .ready
            ),
            OperationalStatusItem(
                iconName: "compass",
                label: L10n.tr("settings.status.location", "Location"),
                value: locationStatusValue,
                tone: locationStatusTone
            ),
            OperationalStatusItem(
                iconName: "signal",
                label: L10n.tr("settings.status.signal", "Signal"),
                value: signalStatusValue,
                tone: signalStatusTone
            ),
            OperationalStatusItem(
                iconName: "map_marker",
                label: L10n.tr("settings.status.offline_packs", "Offline Packs"),
                value: viewModel.installedPackSummary,
                tone: installedPackCount == 0 ? .caution : .info
            )
        ]
    }

    private var workspaceHubCard: some View {
        PanelCard(
            title: L10n.tr("settings.workspace_hub.title", "System Control"),
            subtitle: L10n.tr(
                "settings.workspace_hub.subtitle",
                "Critical systems first. Personal setup second."
            )
        ) {
            VStack(alignment: .leading, spacing: 18) {
                workspaceGroupSection(
                    title: L10n.tr("settings.workspace_group.overview.title", "System Overview"),
                    subtitle: L10n.tr(
                        "settings.workspace_group.overview.subtitle",
                        "Start here for Pro status, safety scope, and device-wide control."
                    ),
                    workspaces: [.overview]
                )

                workspaceGroupSection(
                    title: L10n.tr("settings.workspace_group.critical.title", "Critical Systems"),
                    subtitle: L10n.tr(
                        "settings.workspace_group.critical.subtitle",
                        "Visibility, communication, and map behavior under pressure."
                    ),
                    workspaces: [.privacy, .signal, .maps]
                )

                workspaceGroupSection(
                    title: L10n.tr("settings.workspace_group.personal.title", "Personal Setup"),
                    subtitle: L10n.tr(
                        "settings.workspace_group.personal.subtitle",
                        "Readiness targets, reminders, and device maintenance."
                    ),
                    workspaces: [.preparedness, .device]
                )
            }
        }
    }

    @ViewBuilder
    private var activeWorkspaceContent: some View {
        switch selectedWorkspace {
        case .overview:
            overviewWorkspace
        case .privacy:
            privacyWorkspace
        case .signal:
            signalWorkspace
        case .maps:
            mapsWorkspace
        case .preparedness:
            preparednessWorkspace
        case .device:
            deviceWorkspace
        }
    }

    private func workspaceButton(_ workspace: SettingsWorkspace) -> some View {
        let isSelected = selectedWorkspace == workspace

        return Button {
            withAnimation(RediMotion.selection) {
                selectedWorkspace = workspace
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    RediIcon(workspace.iconName)
                        .foregroundStyle(isSelected ? workspace.accent : ColorTheme.textTertiary)
                        .frame(width: 18, height: 18)
                    Spacer(minLength: 0)
                    Text(workspaceValueLabel(workspace))
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(isSelected ? workspace.accent : ColorTheme.textSecondary)
                        .multilineTextAlignment(.trailing)
                }

                Text(workspace.title)
                    .font(RediTypography.heading)
                    .foregroundStyle(ColorTheme.text)

                Text(workspaceSummary(workspace))
                    .font(.caption)
                    .foregroundStyle(isSelected ? workspace.accent : ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .background(
                (isSelected ? workspace.accent.opacity(0.16) : Color.black.opacity(0.22)),
                in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .stroke((isSelected ? workspace.accent : ColorTheme.dividerStrong).opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private var overviewWorkspace: some View {
        VStack(spacing: 18) {
            systemDefaultsSection
            proSection
            safetySection
            emergencyProfileSection
            assistantSection
        }
    }

    private var privacyWorkspace: some View {
        VStack(spacing: 18) {
            privacySection
        }
    }

    private var signalWorkspace: some View {
        VStack(spacing: 18) {
            signalSection
        }
    }

    private var mapsWorkspace: some View {
        VStack(spacing: 18) {
            mapsSection
        }
    }

    private var preparednessWorkspace: some View {
        VStack(spacing: 18) {
            preparednessSection
        }
    }

    private var deviceWorkspace: some View {
        VStack(spacing: 18) {
            batterySection
            dataSection
            aboutSection
        }
    }

    private func settingsHeroLine(title: String, detail: String) -> some View {
        HStack(alignment: .top) {
            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)
                .frame(width: 92, alignment: .leading)
            Text(detail)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func workspaceGroupSection(
        title: String,
        subtitle: String,
        workspaces: [SettingsWorkspace]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(workspaces) { workspace in
                    workspaceButton(workspace)
                }
            }
        }
    }

    private func workspaceSummary(_ workspace: SettingsWorkspace) -> String {
        switch workspace {
        case .overview:
            L10n.tr("settings.workspace.summary.overview", "Pro access, safety scope, and emergency profile.")
        case .privacy:
            privacySummaryLine
        case .signal:
            signalSummaryLine
        case .maps:
            mapsSummaryLine
        case .preparedness:
            preparednessSummaryLine
        case .device:
            deviceSummaryLine
        }
    }

    private func workspaceValueLabel(_ workspace: SettingsWorkspace) -> String {
        switch workspace {
        case .overview:
            return appState.emergencyUnlockState.isActive
                ? L10n.tr("settings.workspace.value.overview.unlocked", "Unlocked")
                : L10n.tr("settings.workspace.value.overview.ready", "Ready")
        case .privacy:
            return appState.isStealthModeEnabled
                ? L10n.tr("settings.workspace.value.privacy.hardened", "Hardened")
                : L10n.tr("settings.workspace.value.privacy.standard", "Standard")
        case .signal:
            return appState.settings.signalDiscovery.rangeMode.title
        case .maps:
            return L10n.format(
                "settings.workspace.value.maps.layers_enabled",
                "%d on",
                appState.settings.maps.defaultLayers.count
            )
        case .preparedness:
            return L10n.format(
                "settings.workspace.value.preparedness.progress",
                "%1$d/%2$d",
                preparednessEnabledCount,
                4
            )
        case .device:
            return appState.batteryStatus.percentageText
        }
    }

    private var privacySummaryLine: String {
        let locationTitle = appState.settings.privacy.locationShareMode.title
        let visibility = appState.isStealthModeEnabled
            ? L10n.tr("settings.workspace.summary.privacy.visibility_stealth", "Stealth active")
            : L10n.tr("settings.workspace.summary.privacy.visibility_visible", "Visible by default")
        let deviceNameState = appState.settings.privacy.showsDeviceName
            ? L10n.tr("settings.workspace.summary.privacy.device_name_shown", "shown")
            : L10n.tr("settings.workspace.summary.privacy.device_name_hidden", "hidden")
        return L10n.format(
            "settings.workspace.summary.privacy",
            "%1$@, location %2$@, device name %3$@.",
            visibility,
            locationTitle.lowercased(),
            deviceNameState
        )
    }

    private var signalSummaryLine: String {
        L10n.format(
            "settings.workspace.summary.signal",
            "%1$@ mesh, nearby discovery %2$@, reports %3$@.",
            appState.settings.signalDiscovery.rangeMode.title,
            appState.settings.signalDiscovery.discoversNearbyUsers ? L10n.tr("common.on", "On").lowercased() : L10n.tr("common.off", "Off").lowercased(),
            appState.settings.signalDiscovery.allowsBeaconBroadcasts ? L10n.tr("common.on", "On").lowercased() : L10n.tr("common.off", "Off").lowercased()
        )
    }

    private var mapsSummaryLine: String {
        L10n.format(
            "settings.workspace.summary.maps",
            "%1$@, %2$@, %3$d default layers enabled.",
            viewModel.installedPackSummary,
            appState.settings.maps.surfaceMode.title,
            appState.settings.maps.defaultLayers.count
        )
    }

    private var preparednessSummaryLine: String {
        L10n.format(
            "settings.workspace.summary.preparedness",
            "%1$d of 4 reminder systems active for a household of %2$d.",
            preparednessEnabledCount,
            appState.profile.household.totalPeople
        )
    }

    private var deviceSummaryLine: String {
        L10n.format(
            "settings.workspace.summary.device",
            "Battery %1$@, Survival Mode prompt %2$@, app %3$@.",
            appState.batteryStatus.percentageText,
            appState.settings.battery.enablesSurvivalModeAtFifteenPercent ? L10n.tr("common.on", "On").lowercased() : L10n.tr("common.off", "Off").lowercased(),
            viewModel.appVersionText
        )
    }

    private var locationStatusValue: String {
        switch appState.settings.privacy.locationShareMode {
        case .off:
            return L10n.tr("settings.status.location.value.off", "Off")
        case .approximate:
            return L10n.tr("settings.status.location.value.approximate", "Approximate")
        case .precise:
            return L10n.tr("settings.status.location.value.precise", "Precise")
        }
    }

    private var locationStatusTone: OperationalStatusTone {
        switch appState.settings.privacy.locationShareMode {
        case .off:
            return .caution
        case .approximate:
            return .ready
        case .precise:
            return .info
        }
    }

    private var signalStatusValue: String {
        appState.settings.signalDiscovery.discoversNearbyUsers
            ? L10n.tr("settings.status.signal.value.ready", "Ready")
            : L10n.tr("settings.status.signal.value.off", "Off")
    }

    private var signalStatusTone: OperationalStatusTone {
        appState.settings.signalDiscovery.discoversNearbyUsers ? .ready : .danger
    }

    private var installedPackCount: Int {
        appState.mapDataService.loadInstalledPackIDs().count
    }

    private var preparednessEnabledCount: Int {
        [
            appState.settings.preparedness.prepScoreNotificationsEnabled,
            appState.settings.preparedness.seventyTwoHourPlanAlertsEnabled,
            appState.settings.preparedness.goBagRemindersEnabled,
            appState.settings.preparedness.officialAlertNotificationsEnabled
        ]
        .filter { $0 }
        .count
    }

    private var effectiveOfficialAlertNotificationJurisdiction: AustralianJurisdiction? {
        appState.settings.preparedness.officialAlertNotificationJurisdiction
            ?? viewModel.defaultOfficialAlertNotificationJurisdiction
            ?? viewModel.availableOfficialAlertNotificationJurisdictions.first
    }

    private var officialAlertNotificationScopeOptions: [PremiumSegmentedControlOption<OfficialAlertNotificationScope>] {
        OfficialAlertNotificationScope.allCases.map { scope in
            PremiumSegmentedControlOption(
                segmentID: scope,
                title: scope.title,
                detail: scope.subtitle,
                iconName: {
                    switch scope {
                    case .local:
                        "map_marker"
                    case .state:
                        "map"
                    case .australia:
                        "warning"
                    }
                }(),
                accent: ColorTheme.accent
            )
        }
    }

    private var systemDefaultsSection: some View {
        PanelCard(
            title: L10n.tr("settings.defaults.title", "Emergency-Safe Defaults"),
            subtitle: L10n.tr(
                "settings.defaults.subtitle",
                "Reset this device to the recommended emergency behavior in one step."
            )
        ) {
            SettingsInfoRow(
                title: L10n.tr("settings.defaults.summary.title", "What This Resets"),
                subtitle: L10n.tr(
                    "settings.defaults.summary.subtitle",
                    "Approximate location sharing, balanced signal mode, critical map layers, and Stealth Mode off."
                ),
                value: L10n.tr("settings.defaults.summary.value", "Recommended")
            )

            SettingsDivider()

            Button {
                viewModel.isShowingEmergencySafeDefaultsAlert = true
            } label: {
                SettingsActionRow(
                    title: L10n.tr("settings.defaults.action.title", "Reset to Emergency-Safe Settings"),
                    subtitle: L10n.tr(
                        "settings.defaults.action.subtitle",
                        "Use this when you need fast, predictable system behavior under pressure."
                    ),
                    value: L10n.tr("common.reset", "Reset"),
                    tint: ColorTheme.warning
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var proSection: some View {
        PanelCard(
            title: L10n.tr("settings.overview.pro.title", "RediM8 Pro"),
            subtitle: L10n.tr(
                "settings.overview.pro.subtitle",
                "Core safety stays free. Pro funds premium planning, maps, vault upgrades, and the offline assistant."
            )
        ) {
            NavigationLink {
                RediM8ProView(storeKitService: appState.storeKitService, emergencyUnlockState: appState.emergencyUnlockState)
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.overview.pro.view_plans", "Unlock Advanced Planning Tools"),
                    subtitle: proSubtitle,
                    value: proValueLabel
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            SettingsInfoRow(
                title: L10n.tr("settings.overview.pro.always_free", "Always Free"),
                subtitle: monetizationCatalog.alwaysFreePromise,
                value: L10n.tr("paywall.matrix.value.included", "Included")
            )

            SettingsDivider()

            SettingsInfoRow(
                title: L10n.tr("settings.overview.pro.emergency_unlock", "Emergency Unlock"),
                subtitle: emergencyUnlockSubtitle,
                value: emergencyUnlockValue
            )

            SettingsDivider()

            Button {
                Task { await appState.storeKitService.restorePurchases() }
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.overview.pro.restore_purchases", "Restore Purchases"),
                    subtitle: L10n.tr(
                        "settings.overview.pro.restore_subtitle",
                        "Recover previous Pro purchases from your Apple ID"
                    ),
                    value: L10n.tr("common.restore", "Restore")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                SettingsNavigationRow(
                    title: L10n.tr("settings.overview.pro.manage_subscription", "Manage Subscription"),
                    subtitle: L10n.tr(
                        "settings.overview.pro.manage_subtitle",
                        "Change or cancel your plan in App Store settings"
                    ),
                    value: L10n.tr("common.open", "Open")
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var safetySection: some View {
        PanelCard(
            title: L10n.tr("settings.overview.safety.title", "Safety"),
            subtitle: L10n.tr(
                "settings.overview.safety.subtitle",
                "Scope, limitations, and data transparency for emergency use."
            )
        ) {
            NavigationLink {
                SafetyLimitationsView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.overview.safety.link_title", "Safety & Limitations"),
                    subtitle: L10n.tr(
                        "settings.overview.safety.link_subtitle",
                        "Emergency scope, trust labels, communication limits, and data sources"
                    ),
                    value: appState.profile.hasAcknowledgedSafetyNotice
                        ? L10n.tr("settings.overview.safety.value.reviewed", "Reviewed")
                        : L10n.tr("common.open", "Open")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            SettingsInfoRow(
                title: L10n.tr("settings.overview.safety.acknowledged", "Acknowledged"),
                subtitle: L10n.tr(
                    "settings.overview.safety.acknowledged_subtitle",
                    "Recorded once during onboarding and always reviewable here"
                ),
                value: safetyAcknowledgementValue
            )
        }
    }

    private var safetyAcknowledgementValue: String {
        guard let acknowledgedAt = appState.profile.lastAcknowledgedSafetyNoticeAt else {
            return L10n.tr("settings.overview.safety.value.not_yet", "Not yet")
        }
        return DateFormatter.rediM8Short.string(from: acknowledgedAt)
    }

    private var emergencyProfileSection: some View {
        PanelCard(
            title: L10n.tr("settings.overview.emergency_profile.title", "Emergency Profile"),
            subtitle: L10n.tr(
                "settings.overview.emergency_profile.subtitle",
                "Local-only contacts and critical health info for urgent help situations."
            )
        ) {
            NavigationLink {
                EmergencyProfileView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.overview.emergency_profile.link_title", "Emergency Profile"),
                    subtitle: L10n.tr(
                        "settings.overview.emergency_profile.link_subtitle",
                        "Critical health info, blood type, medication details, and emergency contacts"
                    ),
                    value: appState.profile.emergencyMedicalInfo.hasAnyContent
                        ? L10n.tr("settings.overview.emergency_profile.value.saved", "Saved")
                        : L10n.tr("settings.overview.emergency_profile.value.optional", "Optional")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            SettingsInfoRow(
                title: L10n.tr("settings.overview.emergency_profile.sharing_rule", "Sharing Rule"),
                subtitle: TrustLayer.emergencyMedicalInfoPrivacyNotice,
                value: L10n.tr("settings.overview.emergency_profile.value.local_only", "Local only")
            )
        }
    }

    private var assistantSection: some View {
        PanelCard(
            title: L10n.tr("settings.overview.assistant.title", "On-Device AI"),
            subtitle: L10n.tr(
                "settings.overview.assistant.subtitle",
                "On-device AI for low-risk guide summaries and question support, with no internet required."
            )
        ) {
            SettingsToggleRow(
                title: L10n.tr("settings.overview.assistant.toggle_title", "On-Device AI Summaries"),
                subtitle: appState.isProUser
                    ? L10n.tr(
                        "settings.overview.assistant.toggle_subtitle.pro",
                        "Use on-device AI to summarize guides and interpret questions. All processing stays on this device."
                    )
                    : L10n.tr(
                        "settings.overview.assistant.toggle_subtitle.free",
                        "Upgrade to RediM8 Pro to enable on-device AI with no internet required."
                    ),
                isOn: appState.isProUser ? binding(\.assistant.offlineAISummariesEnabled) : .constant(false)
            )
            .disabled(!appState.isProUser)

            SettingsDivider()

            SettingsInfoRow(
                title: L10n.tr("settings.overview.assistant.model_status", "Model Status"),
                subtitle: appState.assistantModel.isAvailable
                    ? L10n.tr(
                        "settings.overview.assistant.model_status.available",
                        "The local CoreML assistant model is available for advisory summaries."
                    )
                    : L10n.tr(
                        "settings.overview.assistant.model_status.unavailable",
                        "No local model bundle is loaded in this build, so RediM8 will stay guide-only until one is bundled."
                    ),
                value: appState.settings.assistant.offlineAISummariesEnabled
                    ? (appState.assistantModel.isAvailable
                        ? L10n.tr("settings.overview.assistant.value.ready", "Ready")
                        : L10n.tr("settings.overview.assistant.value.standby", "Standby"))
                    : L10n.tr("common.off", "Off")
            )
        }
    }

    private var proSubtitle: String {
        if appState.isProUser, case .pro = appState.proEntitlement {
            return L10n.tr(
                "settings.pro.subtitle.active",
                "RediM8 Pro is active. Thank you for supporting the project."
            )
        }
        if appState.emergencyUnlockState.isActive {
            return L10n.tr(
                "settings.pro.subtitle.unlocked",
                "Emergency Unlock active. Pro tools are temporarily available."
            )
        }
        if appState.emergencyUnlockState.isRecentlyEnded {
            return L10n.tr(
                "settings.pro.subtitle.ended",
                "Emergency access ended. Upgrade to keep Pro tools available anytime."
            )
        }
        return L10n.tr(
            "settings.pro.subtitle.default",
            "Unlock expanded maps, deeper planning tools, vault upgrades, and on-device AI."
        )
    }

    private var proValueLabel: String {
        if case .pro = appState.proEntitlement {
            return L10n.tr("settings.pro.value.active", "Active")
        }
        if appState.emergencyUnlockState.isActive {
            return L10n.tr("settings.pro.value.unlocked", "Unlocked")
        }
        if appState.emergencyUnlockState.isRecentlyEnded {
            return L10n.tr("settings.pro.value.ended", "Ended")
        }
        return L10n.tr("settings.pro.value.upgrade", "Upgrade")
    }

    private var emergencyUnlockSubtitle: String {
        if appState.emergencyUnlockState.isVisible {
            return appState.emergencyUnlockState.calloutDetail
        }
        return L10n.tr(
            "settings.emergency_unlock.subtitle.default",
            "Activates automatically during severe official events so payment is not the first decision."
        )
    }

    private var emergencyUnlockValue: String {
        if appState.emergencyUnlockState.isActive {
            return L10n.tr("settings.emergency_unlock.value.active", "Active")
        }
        if appState.emergencyUnlockState.isRecentlyEnded {
            return L10n.tr("settings.emergency_unlock.value.ended", "Ended")
        }
        return L10n.tr("settings.emergency_unlock.value.standby", "Standby")
    }

    private var privacySection: some View {
        PanelCard(
            title: L10n.tr("settings.privacy.title", "Privacy"),
            subtitle: L10n.tr(
                "settings.privacy.subtitle",
                "Control how visible this device is, and what it shares, when networks fail."
            )
        ) {
            SettingsCallout(
                title: L10n.tr(
                    "settings.privacy.callout.title",
                    "Recommended: Stay visible during evacuation"
                ),
                detail: L10n.tr(
                    "settings.privacy.callout.detail",
                    "Leave Stealth Mode off and use approximate or precise location when being found matters more than hiding."
                ),
                tone: .ready,
                iconName: "location.viewfinder"
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.privacy.stealth.title", "Stealth Mode"),
                subtitle: L10n.tr(
                    "settings.privacy.stealth.subtitle",
                    "Use when hiding is more important than being found."
                ),
                isOn: stealthModeBinding
            )

            SettingsCallout(
                title: L10n.tr(
                    "settings.privacy.stealth.warning_title",
                    "Stealth Mode reduces your visibility to rescuers"
                ),
                detail: appState.isStealthModeEnabled
                    ? L10n.tr(
                        "settings.privacy.stealth.active_note",
                        "Advertising is off, browsing is reduced, and this device is receive-only until you turn Stealth Mode off."
                    )
                    : L10n.tr(
                        "settings.privacy.stealth.default_note",
                        "Default: Off. Leave this off during evacuation unless hiding is more important than being found."
                    ),
                tone: .caution,
                iconName: "eye.slash"
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.privacy.anonymous.title", "Anonymous Mode"),
                subtitle: L10n.tr(
                    "settings.privacy.anonymous.subtitle",
                    "Hide personal identity while still listening for nearby updates."
                ),
                isOn: binding(\.privacy.isAnonymousModeEnabled)
            )

            SettingsDivider()

            VStack(alignment: .leading, spacing: 12) {
                SettingsRowLabel(
                    title: L10n.tr("settings.privacy.share_location.title", "Share Location"),
                    subtitle: L10n.tr(
                        "settings.privacy.share_location.subtitle",
                        "Allow RediM8 to share your location during Signal and Community Report modes"
                    )
                )

                Picker(L10n.tr("settings.privacy.share_location.title", "Share Location"), selection: binding(\.privacy.locationShareMode)) {
                    ForEach(LocationShareMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .tint(ColorTheme.accent)

                Text(appState.settings.privacy.locationShareMode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(L10n.tr(
                    "settings.privacy.share_location.recommended",
                    "Recommended during evacuation: Approximate or Precise when being found matters."
                ))
                .font(.caption)
                .foregroundStyle(ColorTheme.textTertiary)
            }

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.privacy.device_name.title", "Show Device Name"),
                subtitle: L10n.tr(
                    "settings.privacy.device_name.subtitle",
                    "Display your chosen name in mesh messages and community reports"
                ),
                footnote: appState.settings.privacy.showsDeviceName
                    ? L10n.tr(
                        "settings.privacy.device_name.visible_note",
                        "Nearby users can see your visible device name."
                    )
                    : L10n.format(
                        "settings.privacy.device_name.hidden_note",
                        "Nearby users will see %@ instead of a personal name.",
                        appState.beaconService.localNodeLabel
                    ),
                isOn: binding(\.privacy.showsDeviceName)
            )

            SettingsDivider()

            Button {
                viewModel.isShowingResetNodeAlert = true
            } label: {
                SettingsActionRow(
                    title: L10n.tr("settings.privacy.reset_node.title", "Reset Node ID"),
                    subtitle: L10n.tr(
                        "settings.privacy.reset_node.subtitle",
                        "Generate a new anonymous node identifier for this device"
                    ),
                    value: appState.beaconService.localNodeLabel,
                    tint: ColorTheme.textTertiary
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var signalSection: some View {
        PanelCard(
            title: L10n.tr("settings.signal.title", "Signal & Discovery"),
            subtitle: L10n.tr(
                "settings.signal.subtitle",
                "Controls how this device connects to nearby people when networks fail."
            )
        ) {
            SettingsCallout(
                title: L10n.tr(
                    "settings.signal.callout.title",
                    "Recommended: Nearby discovery on during evacuation"
                ),
                detail: L10n.tr(
                    "settings.signal.callout.detail",
                    "Turn this off only when hiding matters more than being found."
                ),
                tone: .ready,
                iconName: "antenna.radiowaves.left.and.right"
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.signal.discover.title", "Discover Nearby Users"),
                subtitle: L10n.tr(
                    "settings.signal.discover.subtitle",
                    "Allow RediM8 to scan for nearby devices and make this device discoverable."
                ),
                badge: L10n.tr("settings.signal.discover.badge", "Recommended"),
                badgeTint: ColorTheme.ready,
                isOn: binding(\.signalDiscovery.discoversNearbyUsers)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.signal.community.title", "Broadcast Community Reports"),
                subtitle: L10n.tr(
                    "settings.signal.community.subtitle",
                    "Let this device send local situation reports when urgent conditions need to be shared."
                ),
                footnote: L10n.tr(
                    "settings.signal.community.footnote",
                    "Use for urgent local conditions. Other users see these reports as community data, not official warnings."
                ),
                isOn: binding(\.signalDiscovery.allowsBeaconBroadcasts)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.signal.auto_accept.title", "Auto Accept Messages"),
                subtitle: L10n.tr(
                    "settings.signal.auto_accept.subtitle",
                    "Automatically accept nearby session requests and display their messages"
                ),
                footnote: L10n.tr(
                    "settings.signal.auto_accept.footnote",
                    "Recommended when you want faster relay and less manual screening."
                ),
                isOn: binding(\.signalDiscovery.autoAcceptsMessages)
            )

            SettingsDivider()

            VStack(alignment: .leading, spacing: 12) {
                SettingsRowLabel(
                    title: L10n.tr("settings.signal.range.title", "Signal Range Mode"),
                    subtitle: L10n.tr(
                        "settings.signal.range.subtitle",
                        "Choose how aggressively RediM8 scans and relays when nearby systems fail."
                    )
                )

                Picker(L10n.tr("settings.signal.range.title", "Signal Range Mode"), selection: binding(\.signalDiscovery.rangeMode)) {
                    ForEach(SignalRangeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .tint(ColorTheme.accent)

                Text(appState.settings.signalDiscovery.rangeMode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mapsSection: some View {
        PanelCard(
            title: L10n.tr("settings.maps.title", "Maps"),
            subtitle: L10n.tr(
                "settings.maps.subtitle",
                "Offline packs, critical layers, and default map behavior under pressure."
            )
        ) {
            NavigationLink {
                OfflineDataManagementView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.maps.offline_packs.title", "Offline Map Packs"),
                    subtitle: L10n.tr(
                        "settings.maps.offline_packs.subtitle",
                        "Manage local pack coverage for shelters, water points, and trails"
                    ),
                    value: viewModel.installedPackSummary
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            VStack(alignment: .leading, spacing: 10) {
                SettingsRowLabel(
                    title: L10n.tr("settings.maps.surface.title", "Map Surface"),
                    subtitle: L10n.tr("settings.maps.surface.subtitle", "Choose the default surface RediM8 opens with")
                )

                Picker(L10n.tr("settings.maps.surface.title", "Map Surface"), selection: binding(\.maps.surfaceMode)) {
                    ForEach(MapSurfaceMode.allCases) { mode in
                        Text(mode.shortTitle).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .tint(ColorTheme.accent)

                Text(appState.settings.maps.surfaceMode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SettingsDivider()

            SettingsCallout(
                title: L10n.tr(
                    "settings.maps.callout.title",
                    "Recommended layers focus on survival references"
                ),
                detail: L10n.tr(
                    "settings.maps.callout.detail",
                    "Water points, shelters, and official alerts should stay enabled for faster decisions during outages."
                ),
                tone: .ready,
                iconName: "map"
            )

            SettingsDivider()

            SettingsInfoRow(
                title: L10n.tr("settings.maps.default_layers.title", "Default Map Layers"),
                subtitle: L10n.tr(
                    "settings.maps.default_layers.subtitle",
                    "Choose which layers are enabled when RediM8 opens the map under pressure"
                ),
                value: L10n.format(
                    "settings.maps.default_layers.value",
                    "%d enabled",
                    appState.settings.maps.defaultLayers.count
                )
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.maps.layer.dirt_roads.title", "Show Unsealed Roads"),
                subtitle: L10n.tr("settings.maps.layer.dirt_roads.subtitle", "Unsealed roads and remote access tracks"),
                badge: L10n.tr("settings.maps.layer.dirt_roads.badge", "Support"),
                isOn: mapLayerBinding(.dirtRoads)
            )

            SettingsToggleRow(
                title: L10n.tr("settings.maps.layer.fire_trails.title", "Show Fire Trails"),
                subtitle: L10n.tr("settings.maps.layer.fire_trails.subtitle", "Emergency access routes and forestry trails"),
                badge: L10n.tr("settings.maps.layer.fire_trails.badge", "Access"),
                isOn: mapLayerBinding(.fireTrails)
            )

            SettingsToggleRow(
                title: L10n.tr("settings.maps.layer.water_points.title", "Show Water Points"),
                subtitle: L10n.tr("settings.maps.layer.water_points.subtitle", "Tanks, taps, bores, and known water sources"),
                badge: L10n.tr("settings.maps.layer.water_points.badge", "Critical"),
                badgeTint: ColorTheme.ready,
                footnote: L10n.tr(
                    "settings.maps.layer.water_points.footnote",
                    "Critical during outages and heat events."
                ),
                isOn: mapLayerBinding(.waterPoints)
            )

            SettingsToggleRow(
                title: L10n.tr("settings.maps.layer.shelters.title", "Show Shelters"),
                subtitle: L10n.tr(
                    "settings.maps.layer.shelters.subtitle",
                    "Evacuation points, relief centres, and assembly locations"
                ),
                badge: L10n.tr("settings.maps.layer.shelters.badge", "Evacuation"),
                badgeTint: ColorTheme.warning,
                footnote: L10n.tr(
                    "settings.maps.layer.shelters.footnote",
                    "Used during evacuation and relief movement."
                ),
                isOn: mapLayerBinding(.evacuationPoints)
            )

            SettingsToggleRow(
                title: L10n.tr("settings.maps.layer.community_reports.title", "Show Community Reports"),
                subtitle: L10n.tr(
                    "settings.maps.layer.community_reports.subtitle",
                    "Nearby mesh situation reports shared by other RediM8 users"
                ),
                badge: L10n.tr("settings.maps.layer.community_reports.badge", "Unverified"),
                badgeTint: ColorTheme.warning,
                footnote: L10n.tr(
                    "settings.maps.layer.community_reports.footnote",
                    "Useful for awareness, but not treated as official."
                ),
                isOn: mapLayerBinding(.communityBeacons)
            )

            SettingsToggleRow(
                title: L10n.tr("settings.maps.layer.airstrips.title", "Show Airstrips"),
                subtitle: L10n.tr("settings.maps.layer.airstrips.subtitle", "Reserved for future offline airstrip datasets"),
                isOn: binding(\.maps.showsAirstrips)
            )
        }
    }

    private var preparednessSection: some View {
        PanelCard(
            title: L10n.tr("settings.preparedness.title", "Preparedness"),
            subtitle: L10n.tr(
                "settings.preparedness.subtitle",
                "Controls your readiness targets and reminders."
            )
        ) {
            SettingsCallout(
                title: L10n.tr("settings.preparedness.callout.title", "Affects"),
                detail: L10n.tr(
                    "settings.preparedness.callout.detail",
                    "Water, food, evacuation planning, and readiness reminders."
                ),
                tone: .info,
                iconName: "list.bullet.rectangle.portrait"
            )

            SettingsDivider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SettingsRowLabel(
                        title: L10n.tr("settings.preparedness.household_size.title", "Household Size"),
                        subtitle: L10n.tr(
                            "settings.preparedness.household_size.subtitle",
                            "Used for water, food, and evacuation planning."
                        )
                    )
                    Spacer()
                    Text("\(appState.profile.household.totalPeople)")
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.textTertiary)
                }

                Stepper(value: householdSizeBinding, in: 1...12) {
                    Text(L10n.tr("settings.preparedness.household_size.adjust", "Adjust household size"))
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.text)
                }
                .tint(ColorTheme.accent)
            }

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.preparedness.prep_notifications.title", "Prep Score Notifications"),
                subtitle: L10n.tr(
                    "settings.preparedness.prep_notifications.subtitle",
                    "Keep readiness score review prompts enabled"
                ),
                isOn: binding(\.preparedness.prepScoreNotificationsEnabled)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.preparedness.plan_alerts.title", "72-Hour Plan Alerts"),
                subtitle: L10n.tr(
                    "settings.preparedness.plan_alerts.subtitle",
                    "Keep household emergency plan review reminders active"
                ),
                isOn: binding(\.preparedness.seventyTwoHourPlanAlertsEnabled)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.preparedness.go_bag.title", "Go Bag Reminders"),
                subtitle: L10n.tr(
                    "settings.preparedness.go_bag.subtitle",
                    "Monthly prompts to review evacuation bag essentials"
                ),
                isOn: binding(\.preparedness.goBagRemindersEnabled)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.preparedness.official_alert_notifications.title", "Official Alert Notifications"),
                subtitle: L10n.tr(
                    "settings.preparedness.official_alert_notifications.subtitle",
                    "Get notification banners when new official alerts match your chosen scope"
                ),
                footnote: L10n.tr(
                    "settings.preparedness.official_alert_notifications.footnote",
                    "Use Local for your area, State for family context, or Australia for a wider watch."
                ),
                isOn: officialAlertNotificationsBinding
            )

            if appState.settings.preparedness.officialAlertNotificationsEnabled {
                SettingsDivider()

                VStack(alignment: .leading, spacing: 12) {
                    SettingsRowLabel(
                        title: L10n.tr("settings.preparedness.official_alert_notifications.scope_title", "Notification Scope"),
                        subtitle: L10n.tr(
                            "settings.preparedness.official_alert_notifications.scope_subtitle",
                            "Choose which official warning view can trigger notifications"
                        )
                    )

                    PremiumSegmentedControl(
                        items: officialAlertNotificationScopeOptions,
                        selection: officialAlertNotificationScopeBinding
                    )

                    if appState.settings.preparedness.officialAlertNotificationScope == .state {
                        officialAlertNotificationJurisdictionPicker
                    }
                }
            }

            Text(L10n.tr(
                "settings.preparedness.go_bag.note",
                "Recommended monthly for households that may need to leave quickly."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var batterySection: some View {
        PanelCard(
            title: L10n.tr("settings.battery.title", "Battery"),
            subtitle: L10n.tr("settings.battery.subtitle", "Preserve power during long outages and evacuations")
        ) {
            SettingsToggleRow(
                title: L10n.tr("settings.battery.survival_mode.title", "Enable Survival Mode at 15%"),
                subtitle: L10n.tr(
                    "settings.battery.survival_mode.subtitle",
                    "Prompt for a simplified low-power interface when battery is low"
                ),
                isOn: binding(\.battery.enablesSurvivalModeAtFifteenPercent)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.battery.disable_background.title", "Disable Background Scanning"),
                subtitle: L10n.tr(
                    "settings.battery.disable_background.subtitle",
                    "Prefer less background activity when the app is not in use"
                ),
                isOn: binding(\.battery.disablesBackgroundScanning)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.battery.reduce_animations.title", "Reduce Map Animations"),
                subtitle: L10n.tr(
                    "settings.battery.reduce_animations.subtitle",
                    "Use less animated map movement to conserve power"
                ),
                isOn: binding(\.battery.reducesMapAnimations)
            )

            Text(L10n.format(
                "settings.battery.current",
                "Current battery: %@",
                appState.batteryStatus.percentageText
            ))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dataSection: some View {
        PanelCard(
            title: L10n.tr("settings.data.title", "Data"),
            subtitle: L10n.tr("settings.data.subtitle", "Offline storage, downloads, and local exports")
        ) {
            NavigationLink {
                OfflineDataManagementView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.data.manage.title", "Manage Offline Data"),
                    subtitle: L10n.tr("settings.data.manage.subtitle", "Review map packs stored on this device"),
                    value: viewModel.installedPackSummary
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            NavigationLink {
                OfflineDataManagementView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.data.download.title", "Download Map Packs"),
                    subtitle: L10n.tr("settings.data.download.subtitle", "Install regional coverage for offline emergencies"),
                    value: L10n.tr("common.open", "Open")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Button {
                viewModel.isShowingClearCacheAlert = true
            } label: {
                SettingsActionRow(
                    title: L10n.tr("settings.data.clear_cache.title", "Clear Cached Data"),
                    subtitle: L10n.tr(
                        "settings.data.clear_cache.subtitle",
                        "Remove cached reports and local signal session history"
                    ),
                    value: L10n.tr("common.clear", "Clear"),
                    tint: ColorTheme.textTertiary
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Button {
                viewModel.exportPreparednessReport()
            } label: {
                SettingsActionRow(
                    title: L10n.tr("settings.data.export_report.title", "Export Preparedness Report"),
                    subtitle: L10n.tr(
                        "settings.data.export_report.subtitle",
                        "Create a PDF version of your current readiness report"
                    ),
                    value: L10n.tr("settings.data.export_report.value", "Export"),
                    tint: ColorTheme.textTertiary
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var aboutSection: some View {
        PanelCard(
            title: L10n.tr("settings.about.title", "About"),
            subtitle: L10n.tr("settings.about.subtitle", "App information, notices, and support status")
        ) {
            SettingsInfoRow(
                title: L10n.tr("settings.about.app_version.title", "App Version"),
                subtitle: L10n.tr("settings.about.app_version.subtitle", "Current build installed on this device"),
                value: viewModel.appVersionText
            )

            SettingsDivider()

            NavigationLink {
                PrivacyPolicyView()
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.about.privacy_policy.title", "Privacy Policy"),
                    subtitle: L10n.tr(
                        "settings.about.privacy_policy.subtitle",
                        "How RediM8 stores data and uses permissions"
                    ),
                    value: L10n.tr("common.open", "Open")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Link(destination: TrustLayer.termsOfUseURL) {
                SettingsNavigationRow(
                    title: L10n.tr("settings.about.terms.title", "Terms of Use"),
                    subtitle: L10n.tr("settings.about.terms.subtitle", "Subscription terms and service conditions"),
                    value: L10n.tr("common.open", "Open")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            NavigationLink {
                SettingsReferenceSectionsView(
                    title: L10n.tr("settings.about.attributions.title", "Attributions & Licenses"),
                    subtitle: L10n.tr(
                        "settings.about.attributions.detail_subtitle",
                        "Map data, public warning feeds, and bundled software used in RediM8"
                    ),
                    sections: TrustLayer.attributionSections
                )
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.about.attributions.title", "Attributions & Licenses"),
                    subtitle: L10n.tr(
                        "settings.about.attributions.subtitle",
                        "Third-party software, open data, and source notices"
                    ),
                    value: L10n.tr("common.open", "Open")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Link(destination: TrustLayer.supportURL) {
                SettingsNavigationRow(
                    title: L10n.tr("settings.about.support.title", "Contact Support"),
                    subtitle: "support@redim8.com.au",
                    value: L10n.tr("settings.about.support.value", "Email")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Text(L10n.tr(
                "settings.about.disclaimer",
                "RediM8 provides preparedness information. Always follow instructions from emergency authorities."
            ))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var officialAlertNotificationJurisdictionPicker: some View {
        Menu {
            ForEach(viewModel.availableOfficialAlertNotificationJurisdictions) { jurisdiction in
                Button {
                    appState.mutateSettings { settings in
                        settings.preparedness.officialAlertNotificationJurisdiction = jurisdiction
                    }
                } label: {
                    if jurisdiction == effectiveOfficialAlertNotificationJurisdiction {
                        Label(jurisdiction.title, systemImage: "checkmark")
                    } else {
                        Text(jurisdiction.title)
                    }
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("settings.preparedness.official_alert_notifications.state_picker.label", "STATE FEED"))
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text(
                        effectiveOfficialAlertNotificationJurisdiction?.title
                            ?? L10n.tr(
                                "settings.preparedness.official_alert_notifications.state_picker.placeholder",
                                "Select a state or territory"
                            )
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
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { appState.settings[keyPath: keyPath] },
            set: { newValue in
                appState.mutateSettings { settings in
                    settings[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private var officialAlertNotificationsBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.preparedness.officialAlertNotificationsEnabled },
            set: { isEnabled in
                viewModel.setOfficialAlertNotificationsEnabled(isEnabled)
            }
        )
    }

    private var officialAlertNotificationScopeBinding: Binding<OfficialAlertNotificationScope> {
        Binding(
            get: { appState.settings.preparedness.officialAlertNotificationScope },
            set: { newScope in
                appState.mutateSettings { settings in
                    settings.preparedness.officialAlertNotificationScope = newScope
                    if newScope == .state,
                       settings.preparedness.officialAlertNotificationJurisdiction == nil {
                        settings.preparedness.officialAlertNotificationJurisdiction = effectiveOfficialAlertNotificationJurisdiction
                    }
                }
            }
        )
    }

    private var stealthModeBinding: Binding<Bool> {
        Binding(
            get: { appState.isStealthModeEnabled },
            set: { isEnabled in
                viewModel.toggleStealthMode(isEnabled)
            }
        )
    }

    private var householdSizeBinding: Binding<Int> {
        Binding(
            get: { appState.profile.household.totalPeople },
            set: { newValue in
                appState.mutateProfile { profile in
                    profile.household.peopleCount = max(newValue, 1)
                }
            }
        )
    }

    private func mapLayerBinding(_ layer: MapLayer) -> Binding<Bool> {
        Binding(
            get: { appState.settings.maps.defaultLayers.contains(layer) },
            set: { isEnabled in
                appState.setMapLayer(layer, isEnabled: isEnabled)
            }
        )
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(RediTypography.heading)
                .foregroundStyle(ColorTheme.text)
            Text(subtitle)
                .font(RediTypography.body)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsCallout: View {
    let title: String
    let detail: String
    let tone: OperationalStatusTone
    let iconName: String

    private var tint: Color {
        switch tone {
        case .ready:
            ColorTheme.ready
        case .info:
            ColorTheme.accent
        case .caution:
            ColorTheme.warning
        case .danger:
            ColorTheme.danger
        case .neutral:
            ColorTheme.textTertiary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let badge: String?
    let badgeTint: Color
    let footnote: String?
    @Binding var isOn: Bool

    init(
        title: String,
        subtitle: String,
        badge: String? = nil,
        badgeTint: Color = ColorTheme.textTertiary,
        footnote: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.badgeTint = badgeTint
        self.footnote = footnote
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    SettingsRowLabel(title: title, subtitle: subtitle)

                    if let badge {
                        Spacer(minLength: 0)
                        Text(badge.uppercased())
                            .font(RediTypography.caption)
                            .foregroundStyle(badgeTint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(badgeTint.opacity(0.14), in: Capsule())
                    }
                }

                if let footnote {
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(ColorTheme.accent)
    }
}

private struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SettingsRowLabel(title: title, subtitle: subtitle)
            Spacer()
            HStack(alignment: .center, spacing: 8) {
                Text(value)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.textTertiary)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityValue(value)
        .accessibilityHint("Opens \(title).")
    }
}

private struct SettingsActionRow: View {
    let title: String
    let subtitle: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SettingsRowLabel(title: title, subtitle: subtitle)
            Spacer()
            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(tint)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityValue(value)
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SettingsRowLabel(title: title, subtitle: subtitle)
            Spacer()
            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.textTertiary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityValue(value)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .overlay(ColorTheme.divider)
    }
}

private struct SettingsTextDetailView: View {
    let title: String
    let subtitle: String
    let lines: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PanelCard(title: title, subtitle: subtitle) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.text)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ModeHeroCard(
                    eyebrow: L10n.tr("settings.privacy_policy.hero.eyebrow", "Privacy Policy"),
                    title: L10n.tr("settings.privacy_policy.hero.title", "Privacy at a glance"),
                    subtitle: L10n.tr(
                        "settings.privacy_policy.hero.subtitle",
                        "We built RediM8 so you can rely on it without worrying about your data."
                    ),
                    iconName: "lock.shield",
                    accent: ColorTheme.ready
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        TrustPillGroup(items: [
                            TrustPillItem(title: L10n.tr("settings.privacy_policy.trust.local_only", "On-device data"), tone: .verified),
                            TrustPillItem(title: L10n.tr("settings.privacy_policy.trust.no_analytics", "No analytics"), tone: .info),
                            TrustPillItem(title: L10n.tr("settings.privacy_policy.trust.offline_first", "Offline first"), tone: .caution)
                        ])

                        Text(L10n.tr("settings.about.privacy_policy.effective", "Effective 18 March 2026"))
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.privacy_policy.glance.title", "Privacy at a glance"),
                    subtitle: L10n.tr(
                        "settings.privacy_policy.glance.subtitle",
                        "Quick summary of how RediM8 handles your data."
                    )
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(TrustLayer.privacyAtAGlanceLines.enumerated()), id: \.offset) { _, line in
                            PolicyBulletRow(systemImage: "checkmark.shield", text: line, tint: ColorTheme.ready)
                        }
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.privacy_policy.why.title", "Why RediM8 is different"),
                    subtitle: L10n.tr(
                        "settings.privacy_policy.why.subtitle",
                        "Privacy by default is part of the product, not hidden legal fine print."
                    )
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(TrustLayer.privacyWhyDifferentLines.enumerated()), id: \.offset) { _, line in
                            PolicyBulletRow(systemImage: "shield.lefthalf.filled", text: line, tint: ColorTheme.accent)
                        }
                    }
                }

                ForEach(TrustLayer.privacyPolicySections) { section in
                    PanelCard(title: section.title, subtitle: section.subtitle) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                                PolicyBulletRow(systemImage: section.systemImage, text: line, tint: ColorTheme.textTertiary)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("settings.about.privacy_policy.title", "Privacy Policy"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PolicyBulletRow: View {
    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            Text(text)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsReferenceSectionsView: View {
    let title: String
    let subtitle: String
    let sections: [TrustReferenceSection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PanelCard(title: title, subtitle: subtitle) {
                    Text(L10n.tr(
                        "settings.references.intro",
                        "Review third-party software, public data sources, and attribution notices used throughout RediM8."
                    ))
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.text)
                }

                ForEach(sections) { section in
                    PanelCard(title: section.title, subtitle: section.subtitle) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(RediTypography.body)
                                    .foregroundStyle(ColorTheme.text)
                            }

                            if let linkTitle = section.linkTitle,
                               let linkURL = section.linkURL {
                                Link(linkTitle, destination: linkURL)
                                    .font(RediTypography.bodyStrong)
                                    .foregroundStyle(ColorTheme.accent)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EmergencyProfileView: View {
    let appState: AppState

    @State private var draft: UserProfile

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 10)
    ]

    init(appState: AppState) {
        self.appState = appState
        _draft = State(initialValue: appState.profile)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ModeHeroCard(
                    eyebrow: L10n.tr("settings.emergency_profile.hero.eyebrow", "Emergency Profile"),
                    title: L10n.tr("settings.emergency_profile.hero.title", "Critical health information only."),
                    subtitle: L10n.tr(
                        "settings.emergency_profile.hero.subtitle",
                        "Keep this lightweight and local. Save only the details someone may need if you ask for urgent help nearby."
                    ),
                    iconName: "first_aid",
                    accent: ColorTheme.danger
                ) {
                    TrustPillGroup(items: [
                        TrustPillItem(title: L10n.tr("settings.emergency_profile.trust.local_only", "Local only"), tone: .verified),
                        TrustPillItem(title: L10n.tr("settings.emergency_profile.trust.optional", "Optional"), tone: .neutral),
                        TrustPillItem(title: L10n.tr("settings.emergency_profile.trust.shared_by_choice", "Shared only by choice"), tone: .info)
                    ])
                }

                PanelCard(
                    title: L10n.tr("settings.emergency_profile.health.title", "Critical Health Information"),
                    subtitle: L10n.tr("settings.emergency_profile.health.subtitle", "Do not use this as a full medical history")
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(TrustLayer.emergencyMedicalInfoScopeNotice)
                            .font(RediTypography.body)
                            .foregroundStyle(ColorTheme.textSecondary)

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                            ForEach(CriticalMedicalCondition.allCases) { condition in
                                Button {
                                    draft.emergencyMedicalInfo.toggle(condition)
                                } label: {
                                    Text(condition.title)
                                        .font(RediTypography.bodyStrong)
                                        .foregroundStyle(ColorTheme.text)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            draft.emergencyMedicalInfo.criticalConditions.contains(condition)
                                                ? ColorTheme.danger.opacity(0.18)
                                                : Color.black.opacity(0.2),
                                            in: Capsule()
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    (draft.emergencyMedicalInfo.criticalConditions.contains(condition) ? ColorTheme.danger : ColorTheme.divider).opacity(0.28),
                                                    lineWidth: 1
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        TextField(
                            L10n.tr("settings.emergency_profile.placeholder.allergies", "Severe allergies"),
                            text: $draft.emergencyMedicalInfo.severeAllergies,
                            axis: .vertical
                        )
                            .textFieldStyle(TacticalTextFieldStyle())

                        TextField(
                            L10n.tr("settings.emergency_profile.placeholder.blood_type", "Blood type (optional)"),
                            text: $draft.emergencyMedicalInfo.bloodType
                        )
                            .textFieldStyle(TacticalTextFieldStyle())

                        TextField(
                            L10n.tr("settings.emergency_profile.placeholder.medication", "Emergency medication or location"),
                            text: $draft.emergencyMedicalInfo.emergencyMedication,
                            axis: .vertical
                        )
                            .textFieldStyle(TacticalTextFieldStyle())

                        TextField(
                            L10n.tr("settings.emergency_profile.placeholder.other_condition", "Other critical condition"),
                            text: $draft.emergencyMedicalInfo.otherCriticalCondition,
                            axis: .vertical
                        )
                            .textFieldStyle(TacticalTextFieldStyle())

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(ColorTheme.textTertiary)
                            Text(TrustLayer.emergencyMedicalInfoPrivacyNotice)
                                .font(.caption)
                                .foregroundStyle(ColorTheme.textSecondary)
                        }

                        Text(L10n.tr(
                            "settings.emergency_profile.vault_note",
                            "Store prescriptions, records, and longer medical details in Secure Vault instead."
                        ))
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.emergency_profile.contacts.title", "Emergency Contacts"),
                    subtitle: L10n.tr("settings.emergency_profile.contacts.subtitle", "Contacts stay local and remain available offline")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        if draft.emergencyContacts.isEmpty {
                            Text(L10n.tr("settings.emergency_profile.contacts.empty", "No emergency contacts saved yet."))
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.textSecondary)
                        } else {
                            ForEach($draft.emergencyContacts) { $contact in
                                VStack(alignment: .leading, spacing: 10) {
                                    TextField(
                                        L10n.tr("settings.emergency_profile.contacts.name_placeholder", "Contact name"),
                                        text: $contact.name
                                    )
                                        .textFieldStyle(TacticalTextFieldStyle())
                                    TextField(
                                        L10n.tr("settings.emergency_profile.contacts.phone_placeholder", "Phone"),
                                        text: $contact.phone
                                    )
                                        .textFieldStyle(TacticalTextFieldStyle())
                                        .keyboardType(.phonePad)

                                    Button(L10n.tr("settings.emergency_profile.contacts.remove", "Remove Contact")) {
                                        draft.emergencyContacts.removeAll { $0.id == contact.id }
                                    }
                                    .font(RediTypography.bodyStrong)
                                    .foregroundStyle(ColorTheme.danger)
                                }
                                .padding(14)
                                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
                            }
                        }

                        Button(L10n.tr("settings.emergency_profile.contacts.add", "Add Emergency Contact")) {
                            draft.emergencyContacts.append(.empty)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.emergency_profile.share.title", "If You Choose To Share"),
                    subtitle: L10n.tr(
                        "settings.emergency_profile.share.subtitle",
                        "This preview only attaches to Need Help or Medical Emergency reports when you enable it"
                    )
                ) {
                    if let broadcastSummary = draft.emergencyMedicalInfo.broadcastSummary {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.tr("settings.emergency_profile.share.preview_label", "MEDICAL NOTE PREVIEW"))
                                .font(RediTypography.caption)
                                .foregroundStyle(ColorTheme.danger)
                            Text(broadcastSummary)
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.text)
                        }
                    } else {
                        Text(L10n.tr(
                            "settings.emergency_profile.share.empty",
                            "No emergency medical info will be attached until you add some here and explicitly choose to include it from Signal."
                        ))
                            .font(RediTypography.body)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("settings.emergency_profile.navigation_title", "Emergency Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: draft) { _, newValue in
            if appState.profile != newValue {
                appState.applyProfile(newValue)
            }
        }
    }
}

private struct SafetyTransparencyRow: View {
    let title: String
    let detail: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SettingsRowLabel(title: title, subtitle: detail)
            Spacer()
            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.textTertiary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SafetyLimitationsView: View {
    let appState: AppState

    private var installedPackCount: Int {
        appState.mapDataService.loadInstalledPackIDs().count
    }

    private var officialCoverageValue: String {
        let coverage = appState.officialAlertService.coverageSummary
        if appState.officialAlertService.hasCachedData {
            return coverage
        }
        return L10n.tr("settings.safety.data_sources.government_alerts.sync_once", "Sync once")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ModeHeroCard(
                    eyebrow: L10n.tr("settings.safety.hero.eyebrow", "Safety & Limitations"),
                    title: L10n.tr("settings.safety.hero.title", "Assistive, Not Authoritative"),
                    subtitle: L10n.tr(
                        "settings.safety.hero.subtitle",
                        "RediM8 supports preparedness, navigation, community awareness, and emergency reference access. It does not replace official services or professional care."
                    ),
                    iconName: "shield",
                    accent: ColorTheme.textTertiary
                ) {
                    TrustPillGroup(items: [
                        TrustPillItem(title: L10n.tr("settings.safety.trust.official_first", "Official alerts first"), tone: .verified),
                        TrustPillItem(title: L10n.tr("settings.safety.trust.community_unverified", "Community reports unverified"), tone: .info),
                        TrustPillItem(title: L10n.tr("settings.safety.trust.delivery_not_guaranteed", "Delivery not guaranteed"), tone: .caution)
                    ])
                }

                PanelCard(
                    title: L10n.tr("settings.safety.core_notice.title", "Core Safety Notice"),
                    subtitle: L10n.tr("settings.safety.core_notice.subtitle", "Plain-language scope and limitations")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(TrustLayer.safetyLimitationsLines.enumerated()), id: \.offset) { _, line in
                            safetyBullet(line)
                        }
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.safety.communication.title", "Communication Limits"),
                    subtitle: L10n.tr(
                        "settings.safety.communication.subtitle",
                        "Nearby tools help, but they are not dependable replacement comms"
                    )
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        safetyBullet(TrustLayer.signalAssistiveReminder)
                        safetyBullet(TrustLayer.signalDeliveryNotice)
                        safetyBullet(TrustLayer.signalConstraintNotice)
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.safety.data_sources.title", "Data Sources"),
                    subtitle: L10n.tr("settings.safety.data_sources.subtitle", "What RediM8 uses and how to interpret it")
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        SafetyTransparencyRow(
                            title: L10n.tr("settings.safety.data_sources.map_packs.title", "Offline map packs"),
                            detail: L10n.tr(
                                "settings.safety.data_sources.map_packs.detail",
                                "Bundled regional data packs plus a curated basemap catalog for downloadable local map packages covering shelters, water points, routes, overlays, and offline cartography."
                            ),
                            value: L10n.format(
                                "settings.safety.data_sources.map_packs.value",
                                "%d installed",
                                installedPackCount
                            )
                        )

                        SettingsDivider()

                        SafetyTransparencyRow(
                            title: L10n.tr("settings.safety.data_sources.community_reports.title", "Community reports"),
                            detail: L10n.tr(
                                "settings.safety.data_sources.community_reports.detail",
                                "Nearby user-shared situational reports passed over local mesh. Confirm when possible."
                            ),
                            value: L10n.tr("settings.safety.data_sources.community_reports.value", "Community")
                        )

                        SettingsDivider()

                        SafetyTransparencyRow(
                            title: L10n.tr("settings.safety.data_sources.government_alerts.title", "Government alerts"),
                            detail: L10n.tr(
                                "settings.safety.data_sources.government_alerts.detail",
                                "Mirrored Australian public warning feeds cached for offline access when available."
                            ),
                            value: officialCoverageValue
                        )

                        SettingsDivider()

                        SafetyTransparencyRow(
                            title: L10n.tr("settings.safety.data_sources.vault.title", "Secure Vault"),
                            detail: L10n.tr(
                                "settings.safety.data_sources.vault.detail",
                                "Emergency documents and info card stored locally on this device with local encryption."
                            ),
                            value: L10n.tr("settings.safety.data_sources.vault.value", "Local only")
                        )
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.safety.trust_labels.title", "Trust Labels"),
                    subtitle: L10n.tr("settings.safety.trust_labels.subtitle", "What the badges in RediM8 mean at a glance")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(TrustLayer.trustLabelLegendLines.enumerated()), id: \.offset) { _, line in
                            safetyBullet(line)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("settings.safety.navigation_title", "Safety"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func safetyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ColorTheme.warning)
                .padding(.top, 2)
            Text(text)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
