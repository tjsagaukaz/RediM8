import SwiftUI

struct MapAdvancedSectionsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: MapViewModel
    @Binding var isShowingMapPacks: Bool
    @Binding var isShowingLayers: Bool
    @Binding var isShowingLegend: Bool
    @Binding var isShowingEvacuationPoints: Bool
    @Binding var isShowingWaterPoints: Bool
    @Binding var isShowingDirtRoads: Bool
    @Binding var isShowingFireTrails: Bool
    @Binding var isShowingOfficialAlerts: Bool
    @Binding var isShowingBeacons: Bool
    @Binding var isShowingMarkers: Bool
    @Binding var isShowingResources: Bool
    @Binding var selectedOfficialAlertScope: MapOfficialAlertScope
    @Binding var selectedOfficialAlertJurisdiction: AustralianJurisdiction?

    var body: some View {
        VStack(spacing: 16) {
            CollapsiblePanelCard(
                title: "Map Packs",
                subtitle: "Install regional coverage and inspect its limits.",
                accent: ColorTheme.textTertiary,
                accessibilityIdentifier: "map.packs.toggle",
                isExpanded: $isShowingMapPacks
            ) {
                Text(viewModel.coverageLimitSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("map.packs.coverageSummary")

                ForEach(viewModel.availablePacks) { pack in
                    MapPackRow(
                        pack: pack,
                        isInstalled: viewModel.installedPackIDs.contains(pack.id),
                        trustItems: viewModel.packTrustItems(for: pack, isInstalled: viewModel.installedPackIDs.contains(pack.id)),
                        onInstall: { viewModel.installPack(pack.id) },
                        onOpen: { viewModel.focus(onPackID: pack.id) },
                        onRemove: { viewModel.removePack(pack.id) }
                    )
                }
            }

            CollapsiblePanelCard(
                title: "Map Layers",
                subtitle: "Essential layers first, support layers second.",
                accent: ColorTheme.textTertiary,
                isExpanded: $isShowingLayers
            ) {
                if !essentialLayers.isEmpty {
                    MapSectionLabel(title: "Essential")
                    ForEach(essentialLayers) { layer in
                        layerToggleRow(layer)
                    }
                }

                if !supportLayers.isEmpty {
                    MapSectionLabel(title: "Support")
                    ForEach(supportLayers) { layer in
                        layerToggleRow(layer)
                    }
                }
            }

            CollapsiblePanelCard(
                title: "Marker Legend",
                subtitle: "Color roles used on the offline map.",
                accent: ColorTheme.textTertiary,
                isExpanded: $isShowingLegend
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    markerLegendRow(
                        assetName: "shelter_marker",
                        title: "Shelters",
                        subtitle: "Evacuation points, assembly areas, and relief shelters."
                    )
                    markerLegendRow(
                        assetName: "water_marker",
                        title: "Water",
                        subtitle: "Trusted taps, tanks, and emergency water points."
                    )
                    markerLegendRow(
                        assetName: "warning_marker",
                        title: "Official Alerts",
                        subtitle: "Mirrored government warnings shown as temporary alert markers."
                    )
                    markerLegendRow(
                        assetName: "community_beacon_marker",
                        title: "Situation Reports",
                        subtitle: "Recent community situation reports and assistive mesh signals."
                    )
                }
            }

            if viewModel.isLayerEnabled(.evacuationPoints) {
                CollapsiblePanelCard(
                    title: "Evacuation Points",
                    subtitle: "Offline reference shelters plus nearby baseline facilities when live data is available.",
                    accent: ColorTheme.textTertiary,
                    isExpanded: $isShowingEvacuationPoints
                ) {
                    evacuationPointsContent
                }
            }

            if viewModel.isLayerEnabled(.waterPoints) {
                CollapsiblePanelCard(
                    title: "Water Points",
                    subtitle: "Installed offline water points plus live nearby search when available.",
                    accent: ColorTheme.textTertiary,
                    isExpanded: $isShowingWaterPoints
                ) {
                    waterPointsContent
                }
            }

            if viewModel.isLayerEnabled(.dirtRoads) {
                CollapsiblePanelCard(
                    title: "Unsealed Roads & Remote Tracks",
                    subtitle: "Unsealed roads, 4WD routes and station tracks.",
                    accent: ColorTheme.textTertiary,
                    isExpanded: $isShowingDirtRoads
                ) {
                    dirtRoadsContent
                }
            }

            if viewModel.isLayerEnabled(.fireTrails) {
                CollapsiblePanelCard(
                    title: "Fire Access Trails",
                    subtitle: "Emergency-service access routes shown with caution.",
                    accent: ColorTheme.textTertiary,
                    isExpanded: $isShowingFireTrails
                ) {
                    fireTrailsContent
                }
            }

            if viewModel.isLayerEnabled(.officialAlerts) || viewModel.hasCachedOfficialAlerts {
                CollapsiblePanelCard(
                    title: "Official Alert Layer",
                    subtitle: officialAlertLayerSubtitle,
                    accent: MapTonePalette.color(for: selectedOfficialAlertSummary.tone),
                    isExpanded: $isShowingOfficialAlerts
                ) {
                    MapOfficialAlertsContentView(
                        viewModel: viewModel,
                        selectedScope: $selectedOfficialAlertScope,
                        selectedJurisdiction: $selectedOfficialAlertJurisdiction,
                        scopeOptions: officialAlertScopeOptions,
                        selectedSummary: selectedOfficialAlertSummary,
                        selectedAlerts: selectedOfficialAlerts,
                        effectiveJurisdiction: effectiveOfficialAlertJurisdiction
                    )
                }
            }

            if !viewModel.visibleBeacons.isEmpty {
                CollapsiblePanelCard(
                    title: "Community Situation Reports",
                    subtitle: "Temporary local reports discovered over the mesh.",
                    accent: ColorTheme.textTertiary,
                    isExpanded: $isShowingBeacons
                ) {
                    communityBeaconsContent
                }
            }

            CollapsiblePanelCard(
                title: "Personal Markers",
                subtitle: "Your add-on markers and saved local references.",
                accent: ColorTheme.textTertiary,
                isExpanded: $isShowingMarkers
            ) {
                personalMarkersContent
            }

            if viewModel.isLayerEnabled(.resources) {
                CollapsiblePanelCard(
                    title: "Offline Resource List",
                    subtitle: "Critical fallback if map packs are limited.",
                    accent: ColorTheme.textTertiary,
                    isExpanded: $isShowingResources
                ) {
                    resourceListContent
                }
            }
        }
    }

    private var essentialLayers: [MapLayer] {
        viewModel.availableLayers.filter { [.waterPoints, .evacuationPoints, .officialAlerts].contains($0) }
    }

    private var supportLayers: [MapLayer] {
        viewModel.availableLayers.filter { ![.waterPoints, .evacuationPoints, .officialAlerts].contains($0) }
    }

    private var effectiveOfficialAlertJurisdiction: AustralianJurisdiction? {
        selectedOfficialAlertJurisdiction
            ?? viewModel.defaultOfficialAlertJurisdiction
            ?? viewModel.availableOfficialAlertJurisdictions.first
    }

    private var selectedOfficialAlertSummary: MapOfficialAlertSummary {
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

    private var officialAlertScopeOptions: [PremiumSegmentedControlOption<MapOfficialAlertScope>] {
        MapOfficialAlertScope.allCases.map { scope in
            PremiumSegmentedControlOption(
                segmentID: scope,
                title: scope.title,
                detail: scope.detail,
                iconName: scope.iconName,
                accent: MapTonePalette.color(for: selectedOfficialAlertSummary.tone)
            )
        }
    }

    private var officialAlertLayerSubtitle: String {
        switch selectedOfficialAlertScope {
        case .local:
            "Mirrored public warnings matched to this map area and installed coverage."
        case .state:
            "Check a state or territory feed for family, travel, or wider operational context."
        case .australia:
            "Scan the national warning picture across cached official feeds."
        }
    }

    private func layerBinding(for layer: MapLayer) -> Binding<Bool> {
        Binding(
            get: { viewModel.isLayerEnabled(layer) },
            set: { viewModel.setLayer(layer, isEnabled: $0) }
        )
    }

    private func layerToggleRow(_ layer: MapLayer) -> some View {
        Toggle(isOn: layerBinding(for: layer)) {
            HStack(alignment: .top, spacing: 12) {
                MapLayerIcon(layer, size: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(layerDisplayTitle(for: layer))
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text(layerDisplaySubtitle(for: layer))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(ColorTheme.accent)
    }

    private func layerDisplayTitle(for layer: MapLayer) -> String {
        switch layer {
        case .resources:
            "Critical Resources"
        case .dirtRoads: "Unsealed Roads"
        case .evacuationPoints:
            "Evacuation"
        default:
            layer.title
        }
    }

    private func layerDisplaySubtitle(for layer: MapLayer) -> String {
        switch layer {
        case .resources:
            "Hospitals, fuel, pharmacies, and other critical support places"
        case .dirtRoads: "4WD routes, station tracks, and remote access links."
        case .evacuationPoints:
            "Baseline evacuation centres, shelters, and assembly points"
        default:
            layer.subtitle
        }
    }

    private func markerLegendRow(assetName: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MapAssetIcon(assetName: assetName, size: 22)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var evacuationPointsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TrustLayer.shelterAvailabilityReminder)
                .font(.caption)
                .foregroundStyle(ColorTheme.warning)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let shelterPrioritySummary = viewModel.shelterPrioritySummary {
                Text(shelterPrioritySummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.featuredShelters.isEmpty {
                Text(viewModel.currentLocation == nil
                    ? "Install a regional pack to view nearby evacuation centres, community shelters and assembly points."
                    : "No nearby evacuation points or shelter candidates are available from installed packs or live nearby data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.featuredShelters.filter { $0.id != viewModel.selectedShelter?.id }.prefix(viewModel.selectedShelter == nil ? 6 : 5)), id: \.id) { shelter in
                    ShelterCard(
                        shelter: shelter,
                        distanceText: viewModel.shelterDistanceText(for: shelter),
                        tint: viewModel.shelterTint(for: shelter.type),
                        isSelected: false,
                        trustItems: viewModel.shelterTrustItems(for: shelter),
                        openNavigation: {
                            guard let url = viewModel.shelterNavigationURL(for: shelter) else {
                                return
                            }
                            openURL(url)
                        }
                    )
                }
            }
        }
    }

    private var waterPointsContent: some View {
        Group {
            if viewModel.featuredWaterPoints.isEmpty {
                Text(viewModel.currentLocation == nil
                    ? "Install a regional pack to view local tanks, taps, bores and creek access."
                    : "No nearby water sources are available from installed packs or live nearby data right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.featuredWaterPoints.prefix(6)), id: \.id) { point in
                    MapWaterPointRow(point: point, viewModel: viewModel)
                }
            }
        }
    }

    private var dirtRoadsContent: some View {
        Group {
            if viewModel.featuredDirtRoads.isEmpty {
                Text("Install a regional pack to view unsealed roads, 4WD routes and station tracks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.featuredDirtRoads.prefix(6)), id: \.id) { track in
                    MapTrackRow(track: track, viewModel: viewModel)
                }
            }
        }
    }

    private var fireTrailsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TrustLayer.fireTrailSafetyReminder)
                .font(.caption)
                .foregroundStyle(ColorTheme.warning)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.featuredFireTrails.isEmpty {
                Text("Install a regional pack to view forestry roads and fire access trails.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.featuredFireTrails.prefix(6)), id: \.id) { trail in
                    MapTrackRow(track: trail, viewModel: viewModel)
                }
            }
        }
    }

    private var communityBeaconsContent: some View {
        VStack(spacing: 12) {
            Text(TrustLayer.beaconVerificationReminder)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(viewModel.visibleBeacons) { beacon in
                MapBeaconRow(beacon: beacon, viewModel: viewModel)
            }
        }
    }

    private var personalMarkersContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Marker type", selection: $viewModel.selectedMarkerKind) {
                ForEach([MarkerKind.fuelAvailable, .waterAvailable, .shelter, .danger, .roadBlocked]) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.menu)

            TextField("Optional marker title", text: $viewModel.markerTitle)
                .textFieldStyle(TacticalTextFieldStyle())

            Button("Add Current Location Marker") {
                viewModel.addCurrentLocationMarker()
            }
            .buttonStyle(PrimaryActionButtonStyle())

            if !viewModel.userMarkers.isEmpty {
                ForEach(viewModel.userMarkers) { marker in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            MapAssetIcon(
                                assetName: marker.kind.mapMarkerAssetName,
                                fallbackSystemName: viewModel.symbolName(for: marker.kind),
                                size: 22
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(marker.title)
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)
                                Text(marker.kind.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Delete") {
                                viewModel.deleteMarker(marker.id)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ColorTheme.danger)
                        }

                        TrustPillGroup(items: viewModel.resourceTrustItems(for: marker))
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private var resourceListContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.groupedBundledResources.isEmpty {
                Text(TrustLayer.mapDataUnavailableMessage)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)
            } else {
                ForEach(viewModel.groupedBundledResources, id: \.0.rawValue) { kind, markers in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            MapAssetIcon(
                                assetName: kind.mapMarkerAssetName,
                                fallbackSystemName: viewModel.symbolName(for: kind),
                                size: 20
                            )
                            Text(kind.title)
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)
                        }
                        if let description = viewModel.categoryDescription(for: kind) {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(markers) { marker in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(marker.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(ColorTheme.text)
                                Text(marker.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TrustPillGroup(items: viewModel.resourceTrustItems(for: marker))
                                Text(marker.source)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }
        }
    }
}
