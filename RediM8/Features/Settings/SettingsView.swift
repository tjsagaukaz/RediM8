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
                "Overview"
            case .privacy:
                "Privacy"
            case .signal:
                "Signal"
            case .maps:
                "Maps"
            case .preparedness:
                "Preparedness"
            case .device:
                "Device"
            }
        }

        var detail: String {
            switch self {
            case .overview:
                "Pro, safety, profile"
            case .privacy:
                "Visibility and sharing"
            case .signal:
                "Mesh and reports"
            case .maps:
                "Offline packs and layers"
            case .preparedness:
                "Household reminders"
            case .device:
                "Battery, data, app"
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .alert(item: $viewModel.notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
        .alert("Reset Node ID?", isPresented: $viewModel.isShowingResetNodeAlert) {
            Button("Reset", role: .destructive) {
                viewModel.resetLocalNodeID()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Resetting the node ID changes the anonymous identifier RediM8 uses for this device.")
        }
        .alert("Clear Cached Data?", isPresented: $viewModel.isShowingClearCacheAlert) {
            Button("Clear", role: .destructive) {
                viewModel.clearCachedData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This keeps your preparedness data and offline packs, but clears temporary signal and community report history.")
        }
    }

    private var settingsHeroCard: some View {
        ModeHeroCard(
            eyebrow: "Device Console",
            title: "Settings",
            subtitle: "Tune privacy, offline readiness, mesh behavior, and device safeguards without losing the core emergency tools.",
            iconName: "shield",
            accent: ColorTheme.textTertiary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Local-first", tone: .verified),
                    TrustPillItem(title: "Offline aware", tone: .info),
                    TrustPillItem(title: "Emergency-safe defaults", tone: .caution)
                ])

                VStack(alignment: .leading, spacing: 8) {
                    settingsHeroLine(title: "Privacy", detail: privacySummaryLine)
                    settingsHeroLine(title: "Maps", detail: mapsSummaryLine)
                    settingsHeroLine(title: "Preparedness", detail: preparednessSummaryLine)
                }
            }
        }
    }

    private var settingsStatusItems: [OperationalStatusItem] {
        [
            OperationalStatusItem(
                iconName: "lock.shield",
                label: "Stealth",
                value: appState.isStealthModeEnabled ? "On" : "Off",
                tone: appState.isStealthModeEnabled ? .caution : .neutral
            ),
            OperationalStatusItem(
                iconName: "person.crop.circle.badge.questionmark",
                label: "Anonymous",
                value: appState.settings.privacy.isAnonymousModeEnabled ? "On" : "Off",
                tone: appState.settings.privacy.isAnonymousModeEnabled ? .info : .neutral
            ),
            OperationalStatusItem(
                iconName: "map_marker",
                label: "Offline Packs",
                value: viewModel.installedPackSummary,
                tone: .info
            ),
            OperationalStatusItem(
                iconName: "battery.100",
                label: "Battery",
                value: appState.batteryStatus.percentageText,
                tone: appState.batteryStatus.isBelowSurvivalThreshold ? .caution : .ready
            )
        ]
    }

    private var workspaceHubCard: some View {
        PanelCard(title: "Settings Areas", subtitle: "Open one workspace at a time so system controls feel like focused tools, not a long wall of toggles.") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(SettingsWorkspace.allCases) { workspace in
                    workspaceButton(workspace)
                }
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

    private func workspaceSummary(_ workspace: SettingsWorkspace) -> String {
        switch workspace {
        case .overview:
            "Pro access, safety scope, and emergency profile."
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
            return appState.emergencyUnlockState.isActive ? "Unlocked" : "Ready"
        case .privacy:
            return appState.isStealthModeEnabled ? "Hardened" : "Standard"
        case .signal:
            return appState.settings.signalDiscovery.rangeMode.title
        case .maps:
            return "\(appState.settings.maps.defaultLayers.count) on"
        case .preparedness:
            return "\(preparednessEnabledCount)/3"
        case .device:
            return appState.batteryStatus.percentageText
        }
    }

    private var privacySummaryLine: String {
        let locationTitle = appState.settings.privacy.locationShareMode.title
        let visibility = appState.isStealthModeEnabled ? "Stealth active" : "Visible by default"
        return "\(visibility), location \(locationTitle.lowercased()), device name \(appState.settings.privacy.showsDeviceName ? "shown" : "hidden")."
    }

    private var signalSummaryLine: String {
        "\(appState.settings.signalDiscovery.rangeMode.title) mesh, nearby discovery \(appState.settings.signalDiscovery.discoversNearbyUsers ? "on" : "off"), reports \(appState.settings.signalDiscovery.allowsBeaconBroadcasts ? "on" : "off")."
    }

    private var mapsSummaryLine: String {
        "\(viewModel.installedPackSummary), \(appState.settings.maps.surfaceMode.title), \(appState.settings.maps.defaultLayers.count) default layers enabled."
    }

    private var preparednessSummaryLine: String {
        "\(preparednessEnabledCount) of 3 reminder systems active for a household of \(appState.profile.household.totalPeople)."
    }

    private var deviceSummaryLine: String {
        "Battery \(appState.batteryStatus.percentageText), Survival Mode prompt \(appState.settings.battery.enablesSurvivalModeAtFifteenPercent ? "on" : "off"), app \(viewModel.appVersionText)."
    }

    private var preparednessEnabledCount: Int {
        [
            appState.settings.preparedness.prepScoreNotificationsEnabled,
            appState.settings.preparedness.seventyTwoHourPlanAlertsEnabled,
            appState.settings.preparedness.goBagRemindersEnabled
        ]
        .filter { $0 }
        .count
    }

    private var proSection: some View {
        PanelCard(title: "RediM8 Pro", subtitle: "Core safety stays free. Pro funds premium planning, maps, vault upgrades, and the offline assistant.") {
            NavigationLink {
                RediM8ProView(emergencyUnlockState: appState.emergencyUnlockState)
            } label: {
                SettingsNavigationRow(
                    title: "View Plans",
                    subtitle: proSubtitle,
                    value: proValueLabel
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            SettingsInfoRow(
                title: "Always Free",
                subtitle: monetizationCatalog.alwaysFreePromise,
                value: "Included"
            )

            SettingsDivider()

            SettingsInfoRow(
                title: "Emergency Unlock",
                subtitle: emergencyUnlockSubtitle,
                value: emergencyUnlockValue
            )
        }
    }

    private var safetySection: some View {
        PanelCard(title: "Safety", subtitle: "Scope, limitations, and data transparency for emergency use.") {
            NavigationLink {
                SafetyLimitationsView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: "Safety & Limitations",
                    subtitle: "Emergency scope, trust labels, communication limits, and data sources",
                    value: appState.profile.hasAcknowledgedSafetyNotice ? "Reviewed" : "Open"
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            SettingsInfoRow(
                title: "Acknowledged",
                subtitle: "Recorded once during onboarding and always reviewable here",
                value: safetyAcknowledgementValue
            )
        }
    }

    private var safetyAcknowledgementValue: String {
        guard let acknowledgedAt = appState.profile.lastAcknowledgedSafetyNoticeAt else {
            return "Not yet"
        }
        return DateFormatter.rediM8Short.string(from: acknowledgedAt)
    }

    private var emergencyProfileSection: some View {
        PanelCard(title: "Emergency Profile", subtitle: "Local-only contacts and critical health info for urgent help situations.") {
            NavigationLink {
                EmergencyProfileView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: "Emergency Profile",
                    subtitle: "Critical health info, blood type, medication details, and emergency contacts",
                    value: appState.profile.emergencyMedicalInfo.hasAnyContent ? "Saved" : "Optional"
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            SettingsInfoRow(
                title: "Sharing Rule",
                subtitle: TrustLayer.emergencyMedicalInfoPrivacyNotice,
                value: "Local only"
            )
        }
    }

    private var assistantSection: some View {
        PanelCard(title: "Offline Assistant", subtitle: "Keep the assistant fully local while optionally allowing safe on-device AI summaries for low-risk guide answers.") {
            SettingsToggleRow(
                title: "Offline AI Summaries",
                subtitle: "Use on-device AI to summarize guides and interpret questions. All processing stays on your device.",
                isOn: binding(\.assistant.offlineAISummariesEnabled)
            )

            SettingsDivider()

            SettingsInfoRow(
                title: "Model Status",
                subtitle: appState.assistantModel.isAvailable
                    ? "The local CoreML assistant model is available for advisory summaries."
                    : "No local model bundle is loaded in this build, so RediM8 will stay guide-only until one is bundled.",
                value: appState.settings.assistant.offlineAISummariesEnabled
                    ? (appState.assistantModel.isAvailable ? "Ready" : "Standby")
                    : "Off"
            )
        }
    }

    private var proSubtitle: String {
        if appState.emergencyUnlockState.isActive {
            return "Emergency Unlock active. Pro tools are temporarily available without billing."
        }
        if appState.emergencyUnlockState.isRecentlyEnded {
            return "Emergency access ended. Upgrade to keep Pro tools available anytime."
        }
        return "Launch pricing: \(monetizationCatalog.launchPricingSummary)"
    }

    private var proValueLabel: String {
        if appState.emergencyUnlockState.isActive {
            return "Unlocked"
        }
        if appState.emergencyUnlockState.isRecentlyEnded {
            return "Ended"
        }
        return monetizationCatalog.recommendedOffer.badge ?? "Open"
    }

    private var emergencyUnlockSubtitle: String {
        if appState.emergencyUnlockState.isVisible {
            return appState.emergencyUnlockState.calloutDetail
        }
        return monetizationCatalog.emergencyUnlockPromise
    }

    private var emergencyUnlockValue: String {
        if appState.emergencyUnlockState.isActive {
            return "Active"
        }
        if appState.emergencyUnlockState.isRecentlyEnded {
            return "Ended"
        }
        return "Standby"
    }

    private var privacySection: some View {
        PanelCard(title: "Privacy", subtitle: "Control how visible this device is to nearby RediM8 users") {
            SettingsToggleRow(
                title: "Stealth Mode",
                subtitle: "Remain hidden from nearby RediM8 devices while keeping maps, guides, and emergency tools available",
                isOn: stealthModeBinding
            )

            Text(appState.isStealthModeEnabled
                 ? "Stealth Mode is active. Advertising is off, browsing is reduced, and this device is receive-only."
                 : "Default: Off. Use Stealth Mode when you want lower visibility, fewer signals, and better battery life.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Stealth Mode hides your device from nearby users. Emergency responders may not detect your device.")
                .font(.caption)
                .foregroundStyle(ColorTheme.warning)

            SettingsDivider()

            SettingsToggleRow(
                title: "Anonymous Mode",
                subtitle: "Stay hidden from nearby RediM8 users while still listening for local updates",
                isOn: binding(\.privacy.isAnonymousModeEnabled)
            )

            SettingsDivider()

            VStack(alignment: .leading, spacing: 12) {
                SettingsRowLabel(
                    title: "Share Location",
                    subtitle: "Allow RediM8 to share your location during Signal and Community Report modes"
                )

                Picker("Share Location", selection: binding(\.privacy.locationShareMode)) {
                    ForEach(LocationShareMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .tint(ColorTheme.accent)

                Text(appState.settings.privacy.locationShareMode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SettingsDivider()

            SettingsToggleRow(
                title: "Show Device Name",
                subtitle: "Display your chosen name in mesh messages and community reports",
                isOn: binding(\.privacy.showsDeviceName)
            )

            Text(appState.settings.privacy.showsDeviceName ? "Nearby users can see your visible device name." : "Nearby users will see \(appState.beaconService.localNodeLabel) instead of a personal name.")
                .font(.caption)
                .foregroundStyle(.secondary)

            SettingsDivider()

            Button {
                viewModel.isShowingResetNodeAlert = true
            } label: {
                SettingsActionRow(
                    title: "Reset Node ID",
                    subtitle: "Generate a new anonymous node identifier for this device",
                    value: appState.beaconService.localNodeLabel,
                    tint: ColorTheme.textTertiary
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var signalSection: some View {
        PanelCard(title: "Signal & Discovery", subtitle: "Tune nearby scanning, community reports, and message handling") {
            SettingsToggleRow(
                title: "Discover Nearby Users",
                subtitle: "Allow RediM8 to scan for nearby devices",
                isOn: binding(\.signalDiscovery.discoversNearbyUsers)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: "Allow Community Reports",
                subtitle: "Let this device broadcast local situation reports when needed",
                isOn: binding(\.signalDiscovery.allowsBeaconBroadcasts)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: "Auto Accept Messages",
                subtitle: "Automatically accept nearby session requests and display their messages",
                isOn: binding(\.signalDiscovery.autoAcceptsMessages)
            )

            SettingsDivider()

            VStack(alignment: .leading, spacing: 12) {
                SettingsRowLabel(
                    title: "Signal Range Mode",
                    subtitle: "Controls how aggressively RediM8 scans and refreshes the local mesh"
                )

                Picker("Signal Range Mode", selection: binding(\.signalDiscovery.rangeMode)) {
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
        PanelCard(title: "Maps", subtitle: "Offline packs and default layer visibility") {
            NavigationLink {
                OfflineDataManagementView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: "Offline Map Packs",
                    subtitle: "Manage local pack coverage for shelters, water points, and trails",
                    value: viewModel.installedPackSummary
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            VStack(alignment: .leading, spacing: 10) {
                SettingsRowLabel(
                    title: "Map Surface",
                    subtitle: "Choose the default surface RediM8 opens with"
                )

                Picker("Map Surface", selection: binding(\.maps.surfaceMode)) {
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

            SettingsInfoRow(
                title: "Default Map Layers",
                subtitle: "Choose which layers are enabled when RediM8 opens the offline map",
                value: "\(appState.settings.maps.defaultLayers.count) enabled"
            )

            SettingsDivider()

            SettingsToggleRow(
                title: "Show Dirt Roads",
                subtitle: "Unsealed roads and remote access tracks",
                isOn: mapLayerBinding(.dirtRoads)
            )

            SettingsToggleRow(
                title: "Show Fire Trails",
                subtitle: "Emergency access routes and forestry trails",
                isOn: mapLayerBinding(.fireTrails)
            )

            SettingsToggleRow(
                title: "Show Water Points",
                subtitle: "Tanks, taps, bores, and known water sources",
                isOn: mapLayerBinding(.waterPoints)
            )

            SettingsToggleRow(
                title: "Show Shelters",
                subtitle: "Evacuation points, relief centres, and assembly locations",
                isOn: mapLayerBinding(.evacuationPoints)
            )

            SettingsToggleRow(
                title: "Show Community Reports",
                subtitle: "Nearby mesh situation reports shared by other RediM8 users",
                isOn: mapLayerBinding(.communityBeacons)
            )

            SettingsToggleRow(
                title: "Show Airstrips",
                subtitle: "Reserved for future offline airstrip datasets",
                isOn: binding(\.maps.showsAirstrips)
            )
        }
    }

    private var preparednessSection: some View {
        PanelCard(title: "Preparedness", subtitle: "Planning reminders and household setup") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SettingsRowLabel(
                        title: "Household Size",
                        subtitle: "Used for readiness targets and household planning"
                    )
                    Spacer()
                    Text("\(appState.profile.household.totalPeople)")
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.textTertiary)
                }

                Stepper(value: householdSizeBinding, in: 1...12) {
                    Text("Adjust household size")
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.text)
                }
                .tint(ColorTheme.accent)
            }

            SettingsDivider()

            SettingsToggleRow(
                title: "Prep Score Notifications",
                subtitle: "Keep readiness score review prompts enabled",
                isOn: binding(\.preparedness.prepScoreNotificationsEnabled)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: "72-Hour Plan Alerts",
                subtitle: "Keep household emergency plan review reminders active",
                isOn: binding(\.preparedness.seventyTwoHourPlanAlertsEnabled)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: "Go Bag Reminders",
                subtitle: "Monthly prompts to review evacuation bag essentials",
                isOn: binding(\.preparedness.goBagRemindersEnabled)
            )

            Text("Remind me monthly to review preparedness.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var batterySection: some View {
        PanelCard(title: "Battery", subtitle: "Preserve power during long outages and evacuations") {
            SettingsToggleRow(
                title: "Enable Survival Mode at 15%",
                subtitle: "Prompt for a simplified low-power interface when battery is low",
                isOn: binding(\.battery.enablesSurvivalModeAtFifteenPercent)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: "Disable Background Scanning",
                subtitle: "Prefer less background activity when the app is not in use",
                isOn: binding(\.battery.disablesBackgroundScanning)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: "Reduce Map Animations",
                subtitle: "Use less animated map movement to conserve power",
                isOn: binding(\.battery.reducesMapAnimations)
            )

            Text("Current battery: \(appState.batteryStatus.percentageText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dataSection: some View {
        PanelCard(title: "Data", subtitle: "Offline storage, downloads, and local exports") {
            NavigationLink {
                OfflineDataManagementView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: "Manage Offline Data",
                    subtitle: "Review map packs stored on this device",
                    value: viewModel.installedPackSummary
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            NavigationLink {
                OfflineDataManagementView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: "Download Map Packs",
                    subtitle: "Install regional coverage for offline emergencies",
                    value: "Open"
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Button {
                viewModel.isShowingClearCacheAlert = true
            } label: {
                SettingsActionRow(
                    title: "Clear Cached Data",
                    subtitle: "Remove cached reports and local signal session history",
                    value: "Clear",
                    tint: ColorTheme.textTertiary
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Button {
                viewModel.exportPreparednessReport()
            } label: {
                SettingsActionRow(
                    title: "Export Preparedness Report",
                    subtitle: "Create a PDF version of your current readiness report",
                    value: "Export",
                    tint: ColorTheme.textTertiary
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var aboutSection: some View {
        PanelCard(title: "About", subtitle: "App information, notices, and support status") {
            SettingsInfoRow(
                title: "App Version",
                subtitle: "Current build installed on this device",
                value: viewModel.appVersionText
            )

            SettingsDivider()

            NavigationLink {
                SettingsTextDetailView(
                    title: "Privacy Policy",
                    subtitle: "Local-first storage and nearby communication",
                    lines: TrustLayer.privacyTransparencyLines
                )
            } label: {
                SettingsNavigationRow(
                    title: "Privacy Policy",
                    subtitle: "How RediM8 stores data and uses location",
                    value: "Open"
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            SettingsInfoRow(
                title: "Contact Support",
                subtitle: "Support contact is not configured in this build",
                value: "Unavailable"
            )

            SettingsDivider()

            Text("RediM8 provides preparedness information. Always follow instructions from emergency authorities.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
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

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsRowLabel(title: title, subtitle: subtitle)
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
        HStack(alignment: .center, spacing: 14) {
            SettingsRowLabel(title: title, subtitle: subtitle)
            Spacer()
            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.textTertiary)
            Image(systemName: "chevron.right")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

private struct SettingsActionRow: View {
    let title: String
    let subtitle: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            SettingsRowLabel(title: title, subtitle: subtitle)
            Spacer()
            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(tint)
        }
        .contentShape(Rectangle())
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
                    eyebrow: "Emergency Profile",
                    title: "Critical health information only.",
                    subtitle: "Keep this lightweight and local. Save only the details someone may need if you ask for urgent help nearby.",
                    iconName: "first_aid",
                    accent: ColorTheme.danger
                ) {
                    TrustPillGroup(items: [
                        TrustPillItem(title: "Local only", tone: .verified),
                        TrustPillItem(title: "Optional", tone: .neutral),
                        TrustPillItem(title: "Shared only by choice", tone: .info)
                    ])
                }

                PanelCard(title: "Critical Health Information", subtitle: "Do not use this as a full medical history") {
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

                        TextField("Severe allergies", text: $draft.emergencyMedicalInfo.severeAllergies, axis: .vertical)
                            .textFieldStyle(TacticalTextFieldStyle())

                        TextField("Blood type (optional)", text: $draft.emergencyMedicalInfo.bloodType)
                            .textFieldStyle(TacticalTextFieldStyle())

                        TextField("Emergency medication or location", text: $draft.emergencyMedicalInfo.emergencyMedication, axis: .vertical)
                            .textFieldStyle(TacticalTextFieldStyle())

                        TextField("Other critical condition", text: $draft.emergencyMedicalInfo.otherCriticalCondition, axis: .vertical)
                            .textFieldStyle(TacticalTextFieldStyle())

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(ColorTheme.textTertiary)
                            Text(TrustLayer.emergencyMedicalInfoPrivacyNotice)
                                .font(.caption)
                                .foregroundStyle(ColorTheme.textSecondary)
                        }

                        Text("Store prescriptions, records, and longer medical details in Secure Vault instead.")
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                }

                PanelCard(title: "Emergency Contacts", subtitle: "Contacts stay local and remain available offline") {
                    VStack(alignment: .leading, spacing: 12) {
                        if draft.emergencyContacts.isEmpty {
                            Text("No emergency contacts saved yet.")
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.textSecondary)
                        } else {
                            ForEach($draft.emergencyContacts) { $contact in
                                VStack(alignment: .leading, spacing: 10) {
                                    TextField("Contact name", text: $contact.name)
                                        .textFieldStyle(TacticalTextFieldStyle())
                                    TextField("Phone", text: $contact.phone)
                                        .textFieldStyle(TacticalTextFieldStyle())
                                        .keyboardType(.phonePad)

                                    Button("Remove Contact") {
                                        draft.emergencyContacts.removeAll { $0.id == contact.id }
                                    }
                                    .font(RediTypography.bodyStrong)
                                    .foregroundStyle(ColorTheme.danger)
                                }
                                .padding(14)
                                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
                            }
                        }

                        Button("Add Emergency Contact") {
                            draft.emergencyContacts.append(.empty)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }

                PanelCard(title: "If You Choose To Share", subtitle: "This preview only attaches to Need Help or Medical Emergency reports when you enable it") {
                    if let broadcastSummary = draft.emergencyMedicalInfo.broadcastSummary {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("MEDICAL NOTE PREVIEW")
                                .font(RediTypography.caption)
                                .foregroundStyle(ColorTheme.danger)
                            Text(broadcastSummary)
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.text)
                        }
                    } else {
                        Text("No emergency medical info will be attached until you add some here and explicitly choose to include it from Signal.")
                            .font(RediTypography.body)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle("Emergency Profile")
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
        return "Sync once"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ModeHeroCard(
                    eyebrow: "Safety & Limitations",
                    title: "Assistive, Not Authoritative",
                    subtitle: "RediM8 supports preparedness, navigation, community awareness, and emergency reference access. It does not replace official services or professional care.",
                    iconName: "shield",
                    accent: ColorTheme.textTertiary
                ) {
                    TrustPillGroup(items: [
                        TrustPillItem(title: "Official alerts first", tone: .verified),
                        TrustPillItem(title: "Community reports unverified", tone: .info),
                        TrustPillItem(title: "Delivery not guaranteed", tone: .caution)
                    ])
                }

                PanelCard(title: "Core Safety Notice", subtitle: "Plain-language scope and limitations") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(TrustLayer.safetyLimitationsLines.enumerated()), id: \.offset) { _, line in
                            safetyBullet(line)
                        }
                    }
                }

                PanelCard(title: "Communication Limits", subtitle: "Nearby tools help, but they are not dependable replacement comms") {
                    VStack(alignment: .leading, spacing: 12) {
                        safetyBullet(TrustLayer.signalAssistiveReminder)
                        safetyBullet(TrustLayer.signalDeliveryNotice)
                        safetyBullet(TrustLayer.signalConstraintNotice)
                    }
                }

                PanelCard(title: "Data Sources", subtitle: "What RediM8 uses and how to interpret it") {
                    VStack(alignment: .leading, spacing: 14) {
                        SafetyTransparencyRow(
                            title: "Offline map packs",
                            detail: "Bundled regional data packs plus a curated basemap catalog for downloadable local map packages covering shelters, water points, routes, overlays, and offline cartography.",
                            value: "\(installedPackCount) installed"
                        )

                        SettingsDivider()

                        SafetyTransparencyRow(
                            title: "Community reports",
                            detail: "Nearby user-shared situational reports passed over local mesh. Confirm when possible.",
                            value: "Community"
                        )

                        SettingsDivider()

                        SafetyTransparencyRow(
                            title: "Government alerts",
                            detail: "Mirrored Australian public warning feeds cached for offline access when available.",
                            value: officialCoverageValue
                        )

                        SettingsDivider()

                        SafetyTransparencyRow(
                            title: "Secure Vault",
                            detail: "Emergency documents and info card stored locally on this device with local encryption.",
                            value: "Local only"
                        )
                    }
                }

                PanelCard(title: "Trust Labels", subtitle: "What the badges in RediM8 mean at a glance") {
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
        .navigationTitle("Safety")
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
