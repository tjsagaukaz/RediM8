import SwiftUI

extension SettingsView {

    // MARK: - Privacy Workspace

    var privacyWorkspace: some View {
        VStack(spacing: 18) {
            privacySection
        }
    }

    // MARK: - Signal Workspace

    var signalWorkspace: some View {
        VStack(spacing: 18) {
            signalSection
        }
    }

    // MARK: - Maps Workspace

    var mapsWorkspace: some View {
        VStack(spacing: 18) {
            mapsSection
        }
    }

    // MARK: - Privacy Section

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

    // MARK: - Signal Section

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

    // MARK: - Maps Section

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
}
