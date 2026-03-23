import SwiftUI

struct SettingsView: View {
    enum SettingsWorkspace: String, CaseIterable, Identifiable {
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
                ColorTheme.accent
            case .privacy:
                Color(hex: "B68CFF")
            case .signal:
                ColorTheme.ready
            case .maps:
                ColorTheme.info
            case .preparedness:
                ColorTheme.warning
            case .device:
                ColorTheme.textTertiary
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let appState: AppState

    @StateObject var viewModel: SettingsViewModel
    @State private var selectedWorkspace: SettingsWorkspace = .overview
    let monetizationCatalog = RediM8MonetizationCatalog.launch

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

    // MARK: - Hero Card

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

    // MARK: - Status Items

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

    // MARK: - Workspace Hub

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

    // MARK: - Workspace Routing

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

    // MARK: - Workspace Button

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

    // MARK: - Hero Line Helper

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

    // MARK: - Workspace Group Section

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

    // MARK: - Workspace Summaries

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

    // MARK: - Summary Lines

    var privacySummaryLine: String {
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

    var mapsSummaryLine: String {
        L10n.format(
            "settings.workspace.summary.maps",
            "%1$@, %2$@, %3$d default layers enabled.",
            viewModel.installedPackSummary,
            appState.settings.maps.surfaceMode.title,
            appState.settings.maps.defaultLayers.count
        )
    }

    var preparednessSummaryLine: String {
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

    // MARK: - Status Computed Properties

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

    var preparednessEnabledCount: Int {
        [
            appState.settings.preparedness.prepScoreNotificationsEnabled,
            appState.settings.preparedness.seventyTwoHourPlanAlertsEnabled,
            appState.settings.preparedness.goBagRemindersEnabled,
            appState.settings.preparedness.officialAlertNotificationsEnabled
        ]
        .filter { $0 }
        .count
    }

    var effectiveOfficialAlertNotificationJurisdiction: AustralianJurisdiction? {
        appState.settings.preparedness.officialAlertNotificationJurisdiction
            ?? viewModel.defaultOfficialAlertNotificationJurisdiction
            ?? viewModel.availableOfficialAlertNotificationJurisdictions.first
    }

    var officialAlertNotificationScopeOptions: [PremiumSegmentedControlOption<OfficialAlertNotificationScope>] {
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

    // MARK: - Bindings

    func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { appState.settings[keyPath: keyPath] },
            set: { newValue in
                appState.mutateSettings { settings in
                    settings[keyPath: keyPath] = newValue
                }
            }
        )
    }

    var officialAlertNotificationsBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.preparedness.officialAlertNotificationsEnabled },
            set: { isEnabled in
                viewModel.setOfficialAlertNotificationsEnabled(isEnabled)
            }
        )
    }

    var officialAlertNotificationScopeBinding: Binding<OfficialAlertNotificationScope> {
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

    var stealthModeBinding: Binding<Bool> {
        Binding(
            get: { appState.isStealthModeEnabled },
            set: { isEnabled in
                viewModel.toggleStealthMode(isEnabled)
            }
        )
    }

    var householdSizeBinding: Binding<Int> {
        Binding(
            get: { appState.profile.household.totalPeople },
            set: { newValue in
                appState.mutateProfile { profile in
                    profile.household.peopleCount = max(newValue, 1)
                }
            }
        )
    }

    func mapLayerBinding(_ layer: MapLayer) -> Binding<Bool> {
        Binding(
            get: { appState.settings.maps.defaultLayers.contains(layer) },
            set: { isEnabled in
                appState.setMapLayer(layer, isEnabled: isEnabled)
            }
        )
    }
}
