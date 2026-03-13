import SwiftUI

struct MapView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: MapViewModel
    private let openEvacuationRoutes: () -> Void
    @State private var isShowingFullScreenMap = false
    @State private var isShowingLayers = false
    @State private var isShowingLegend = false
    @State private var isShowingMapPacks = false
    @State private var isShowingEvacuationPoints = false
    @State private var isShowingWaterPoints = false
    @State private var isShowingDirtRoads = false
    @State private var isShowingFireTrails = false
    @State private var isShowingOfficialAlerts = false
    @State private var isShowingBeacons = false
    @State private var isShowingMarkers = false
    @State private var isShowingResources = false

    init(appState: AppState, openEvacuationRoutes: @escaping () -> Void = {}) {
        self.openEvacuationRoutes = openEvacuationRoutes
        _viewModel = StateObject(wrappedValue: MapViewModel(appState: appState))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if viewModel.isStealthModeEnabled {
                    StealthModeIndicatorView()
                }

                mapStatusBanner

                ModeHeroCard(
                    eyebrow: "Field Navigation",
                    title: "Offline Map",
                    subtitle: "Start with the map and nearest verified fallbacks. Expand the rest only when you need more detail.",
                    iconName: "map_marker",
                    accent: ColorTheme.info,
                    backgroundAssetName: "map_forest_route",
                    backgroundImageOffset: CGSize(width: -22, height: 0)
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        TrustPillGroup(items: viewModel.mapTrustItems)
                        operationalLine(label: "Basemap", detail: viewModel.workingBasemapSummary)
                        operationalLine(label: "Routes", detail: viewModel.savedRouteSummary)
                        operationalLine(label: "Coverage", detail: viewModel.workingCoverageSummary)
                        operationalLine(label: "Position", detail: viewModel.workingPositionSummary)
                    }
                }

                if !mapFailureRows.isEmpty {
                    PanelCard(title: "Failure Modes", subtitle: "What still works right now") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(mapFailureRows.enumerated()), id: \.offset) { _, row in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(row.title)
                                        .font(RediTypography.bodyStrong)
                                        .foregroundStyle(ColorTheme.text)
                                    Text(row.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(ColorTheme.textMuted)
                                }
                            }
                        }
                    }
                }

                savedRoutesPanel

                officialAlertsPanel

                if let bushfireMapSummary = viewModel.bushfireMapSummary {
                    PanelCard(title: "Bushfire Map Priorities", subtitle: "Mode-specific offline routing focus") {
                        Text(bushfireMapSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                embeddedMapPanel

                criticalNearbyPanel

                if viewModel.isLayerEnabled(.evacuationPoints), let selectedShelter = viewModel.selectedShelter {
                    PanelCard(title: "Selected Evacuation Point", subtitle: "Tapped directly from the offline map") {
                        ShelterCard(
                            shelter: selectedShelter,
                            distanceText: viewModel.distanceText(to: selectedShelter.coordinate),
                            tint: viewModel.shelterTint(for: selectedShelter.type),
                            isSelected: true,
                            trustItems: viewModel.shelterTrustItems(for: selectedShelter),
                            openNavigation: {
                                guard let url = viewModel.shelterNavigationURL(for: selectedShelter) else {
                                    return
                                }
                                openURL(url)
                            }
                        )
                    }
                }

                advancedMapSections
            }
            .padding(.horizontal, RediSpacing.screen)
            .padding(.top, RediSpacing.screen)
            .padding(.bottom, RediLayout.commandDockContentInset)
        }
        .navigationTitle("Map")
        .safeAreaInset(edge: .top, spacing: 0) {
            OperationalStatusRail(items: mapStatusItems, accent: ColorTheme.info)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.03, green: 0.08, blue: 0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .fullScreenCover(isPresented: $isShowingFullScreenMap) {
            fullScreenMapView
        }
    }

    private func layerBinding(for layer: MapLayer) -> Binding<Bool> {
        Binding(
            get: { viewModel.isLayerEnabled(layer) },
            set: { viewModel.setLayer(layer, isEnabled: $0) }
        )
    }

    private var surfaceModeBinding: Binding<MapSurfaceMode> {
        Binding(
            get: { viewModel.surfaceMode },
            set: { viewModel.setSurfaceMode($0) }
        )
    }

    private var embeddedMapPanel: some View {
        PanelCard(title: "Offline Emergency Map", subtitle: "Local packs first, tactical fallback second") {
            embeddedMapSurface

            VStack(alignment: .leading, spacing: 10) {
                mapSurfaceSelector

                TrustPillGroup(items: viewModel.mapTrustItems)

                HStack(alignment: .center, spacing: 12) {
                    Label("\(viewModel.installedPacks.count) map pack(s) installed", systemImage: "externaldrive.fill.badge.checkmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Full Screen") {
                        isShowingFullScreenMap = true
                    }
                    .font(.subheadline.weight(.semibold))
                    Button("Recenter") {
                        viewModel.recenter()
                    }
                    .font(.subheadline.weight(.semibold))
                }

                Text("Offline layers last updated: \(viewModel.lastUpdatedText)")
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)

                Text(viewModel.basemapStatusMessage)
                    .font(.caption)
                    .foregroundStyle(viewModel.surfaceTint)

                Text(viewModel.coverageLimitSummary)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.text)

                if let surfaceAvailabilityNote = viewModel.surfaceAvailabilityNote {
                    Text(surfaceAvailabilityNote)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textMuted)
                }

                installedCoveragePreview

                Text(TrustLayer.mapFreshnessNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(TrustLayer.mapCoverageNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.isLayerEnabled(.fireTrails) {
                    Text(TrustLayer.fireTrailSafetyReminder)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                }

                if viewModel.isLayerEnabled(.evacuationPoints) {
                    Text(TrustLayer.shelterAvailabilityReminder)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                }

                if viewModel.isStealthModeEnabled {
                    Text("Stealth Mode reduces location accuracy and map motion to conserve battery while keeping offline maps readable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var embeddedMapSurface: some View {
        mapSurface
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topLeading) {
                mapModeBadge
                    .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        isShowingFullScreenMap = true
                    } label: {
                        Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ColorTheme.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.82), in: Capsule())
                    }

                    if viewModel.currentLocation != nil {
                        headingBadge
                    }
                }
                .padding(12)
            }
            .overlay(alignment: .bottomLeading) {
                compactMapSummary
                    .padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                mapReferenceOverlay
                    .padding(12)
            }
    }

    private var mapSurfaceSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Map Surface")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ColorTheme.textFaint)
                Spacer()
                Text(viewModel.surfaceMode.shortTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(viewModel.surfaceTint)
            }

            Picker("Map Surface", selection: surfaceModeBinding) {
                ForEach(MapSurfaceMode.allCases) { mode in
                    Text(mode.shortTitle).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .tint(ColorTheme.accent)

            Text(viewModel.surfaceMode.subtitle)
                .font(.caption)
                .foregroundStyle(ColorTheme.textMuted)
        }
        .padding(14)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(viewModel.surfaceTint.opacity(0.18), lineWidth: 1)
        )
    }

    private var mapSurface: some View {
        Group {
            if viewModel.surfaceMode.usesAppleTiles {
                AppleEmergencyMapView(
                    surfaceMode: viewModel.surfaceMode,
                    region: viewModel.viewportRegion,
                    regionRevision: viewModel.viewportRevision,
                    availablePacks: viewModel.availablePacks,
                    installedPackIDs: viewModel.installedPackIDs,
                    resourceMarkers: viewModel.visibleResourceMarkers,
                    dirtRoads: viewModel.visibleDirtRoads,
                    fireTrails: viewModel.visibleFireTrails,
                    waterPoints: viewModel.visibleWaterPoints,
                    shelters: viewModel.visibleShelters,
                    officialAlerts: viewModel.visibleOfficialAlerts,
                    beacons: viewModel.visibleBeacons,
                    currentLocation: viewModel.currentLocation,
                    showsUserLocation: viewModel.currentLocation != nil,
                    animatesRegionChanges: !viewModel.reducesMapAnimations,
                    onSelectShelter: viewModel.selectShelter(withID:)
                )
            } else {
                MapLibreEmergencyMapView(
                    styleURL: viewModel.basemapStyleURL,
                    region: viewModel.viewportRegion,
                    regionRevision: viewModel.viewportRevision,
                    availablePacks: viewModel.availablePacks,
                    installedPackIDs: viewModel.installedPackIDs,
                    contextDirtRoads: viewModel.dirtRoads,
                    contextFireTrails: viewModel.fireTrails,
                    resourceMarkers: viewModel.visibleResourceMarkers,
                    dirtRoads: viewModel.visibleDirtRoads,
                    fireTrails: viewModel.visibleFireTrails,
                    waterPoints: viewModel.visibleWaterPoints,
                    shelters: viewModel.visibleShelters,
                    officialAlerts: viewModel.visibleOfficialAlerts,
                    beacons: viewModel.visibleBeacons,
                    currentLocation: viewModel.currentLocation,
                    showsUserLocation: viewModel.currentLocation != nil,
                    animatesRegionChanges: !viewModel.reducesMapAnimations,
                    onSelectShelter: viewModel.selectShelter(withID:)
                )
            }
        }
    }

    private var mapSummarySubtitle: String {
        if viewModel.installedPacks.isEmpty {
            return viewModel.surfaceMode.usesAppleTiles ? "Live tiles with fallback overlays" : "Fallback only"
        }

        return viewModel.installedPacks.first?.name ?? "Coverage installed"
    }

    private var fullScreenMapView: some View {
        ZStack {
            mapSurface
                .ignoresSafeArea()
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                mapModeBadge

                Spacer(minLength: 10)

                if viewModel.currentLocation != nil {
                    headingBadge
                }

                Button {
                    viewModel.recenter()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.84), in: Circle())
                }

                Button {
                    isShowingFullScreenMap = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(ColorTheme.text)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.84), in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.84), Color.black.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.surfaceMode.title)
                            .font(RediTypography.bodyStrong)
                            .foregroundStyle(ColorTheme.text)
                        Text(viewModel.workingBasemapSummary)
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textMuted)
                    }
                    Spacer()
                    Button("Open Packs") {
                        isShowingFullScreenMap = false
                        isShowingMapPacks = true
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                TrustPillGroup(items: viewModel.mapTrustItems)

                Text(viewModel.coverageLimitSummary)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.text)

                if let surfaceAvailabilityNote = viewModel.surfaceAvailabilityNote {
                    Text(surfaceAvailabilityNote)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textMuted)
                }

                if viewModel.isTacticalSurfaceActive && !viewModel.isPremiumBasemapActive {
                    Text("This full-screen view is the offline tactical surface. Install a verified tile package later if you want full road or topographic cartography without live tiles.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                }

                if let officialAlertBannerText = viewModel.officialAlertBannerText {
                    Text(officialAlertBannerText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(officialAlertColor)
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .statusBarHidden()
    }

    private var mapModeBadge: some View {
        Text(viewModel.surfaceBadgeTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(viewModel.surfaceTint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.82), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(viewModel.surfaceTint.opacity(0.28), lineWidth: 1)
            )
    }

    private var headingBadge: some View {
        HStack(spacing: 8) {
            RediIcon("compass")
                .foregroundStyle(ColorTheme.ready)
                .frame(width: 16, height: 16)
            Text(viewModel.headingText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.78), in: Capsule())
        .overlay(
            Capsule()
                .stroke(ColorTheme.ready.opacity(0.28), lineWidth: 1)
        )
    }

    private var compactMapSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.surfaceMode.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
            Text(mapSummarySubtitle)
                .font(.caption2)
                .foregroundStyle(ColorTheme.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var installedCoveragePreview: some View {
        Group {
            if let highlightedPack = viewModel.installedPacks.first ?? viewModel.availablePacks.first {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(viewModel.installedPacks.isEmpty ? "Coverage Preview" : "Installed Pack Boundary")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ColorTheme.textFaint)
                        Spacer()
                        Text(highlightedPack.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(viewModel.installedPacks.isEmpty ? ColorTheme.warning : ColorTheme.ready)
                    }

                    MapPackCoveragePreview(
                        pack: highlightedPack,
                        isInstalled: viewModel.installedPackIDs.contains(highlightedPack.id),
                        accent: viewModel.installedPackIDs.contains(highlightedPack.id) ? ColorTheme.ready : ColorTheme.info
                    )

                    Text(viewModel.installedPacks.isEmpty
                         ? "No regional pack is installed yet. This preview shows how pack boundaries limit offline water, shelter, and track coverage."
                         : "Coverage stops at this boundary. Outside it, RediM8 falls back to the basemap and saved markers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var mapStatusBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            RediIcon("map_marker")
                .foregroundStyle(mapStatusColor)
                .frame(width: 18, height: 18)
                .padding(10)
                .background(mapStatusColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("MAP STATUS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(mapStatusColor)
                Text(viewModel.mapStatusHeadline)
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
                Text(viewModel.mapStatusDetail)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(mapStatusColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var mapStatusColor: Color {
        switch viewModel.mapStatusTone {
        case .ready:
            ColorTheme.ready
        case .info:
            ColorTheme.info
        case .caution:
            ColorTheme.warning
        case .danger:
            ColorTheme.danger
        case .neutral:
            ColorTheme.textFaint
        }
    }

    private var mapReferenceOverlay: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if viewModel.currentLocation != nil, viewModel.isTacticalSurfaceActive {
                distanceRingLegend
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Nearest On Map")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ColorTheme.textFaint)

                referenceChip(
                    title: "Water",
                    detail: viewModel.featuredWaterPoints.first.map { viewModel.waterDistanceText(for: $0) } ?? "None",
                    iconName: "water",
                    accent: ColorTheme.info
                )

                referenceChip(
                    title: "Shelter",
                    detail: viewModel.featuredShelters.first.map { viewModel.shelterDistanceText(for: $0) } ?? "None",
                    iconName: "shelter",
                    accent: ColorTheme.ready
                )

                referenceChip(
                    title: "Route",
                    detail: viewModel.savedRoutes.isEmpty ? "None saved" : "Saved",
                    iconName: "route",
                    accent: viewModel.savedRoutes.isEmpty ? ColorTheme.warning : ColorTheme.info
                )
            }
            .padding(12)
            .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .frame(maxWidth: 180)
    }

    private var distanceRingLegend: some View {
        HStack(spacing: 8) {
            RediIcon("compass")
                .foregroundStyle(ColorTheme.ready)
                .frame(width: 14, height: 14)

            Text(viewModel.distanceRingLabels.joined(separator: " • "))
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.82), in: Capsule())
        .overlay(
            Capsule()
                .stroke(ColorTheme.ready.opacity(0.2), lineWidth: 1)
        )
    }

    private func referenceChip(title: String, detail: String, iconName: String, accent: Color) -> some View {
        HStack(alignment: .center, spacing: 10) {
            RediIcon(iconName)
                .foregroundStyle(accent)
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.textFaint)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.text)
            }

            Spacer(minLength: 0)
        }
    }

    private func operationalLine(label: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textFaint)
                .frame(width: 70, alignment: .leading)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func waterPriorityCard(_ point: WaterPoint) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.waterPriorityHeading(for: point))
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.info)

            HStack(alignment: .top, spacing: 14) {
                MapAssetIcon(assetName: point.kind.mapMarkerAssetName, size: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text(point.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(ColorTheme.text)
                    Text(point.kind.title)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textMuted)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.waterDistanceText(for: point))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(ColorTheme.info)
                    Text(viewModel.waterReferenceLabel(for: point))
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textFaint)
                }
            }

            TrustPillGroup(items: viewModel.waterTrustItems(for: point))

            Text(point.notes)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            Text(point.source)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(ColorTheme.info.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ColorTheme.info.opacity(0.2), lineWidth: 1)
        )
    }

    private var mapStatusItems: [OperationalStatusItem] {
        [
            OperationalStatusItem(
                iconName: "warning",
                label: "Official",
                value: viewModel.officialAlertStatusValue,
                tone: viewModel.officialAlertTone
            ),
            OperationalStatusItem(
                iconName: "map_marker",
                label: "Basemap",
                value: viewModel.basemapOperationalValue,
                tone: viewModel.basemapOperationalTone
            ),
            OperationalStatusItem(
                iconName: "route",
                label: "Routes",
                value: viewModel.savedRoutes.isEmpty ? "None saved" : "\(viewModel.savedRoutes.count) saved",
                tone: viewModel.savedRoutes.isEmpty ? .caution : .ready
            ),
            OperationalStatusItem(
                iconName: "compass",
                label: "Position",
                value: viewModel.currentLocation == nil ? "Unavailable" : "Live",
                tone: viewModel.currentLocation == nil ? .caution : .ready
            ),
            OperationalStatusItem(
                iconName: "documents",
                label: "Coverage",
                value: viewModel.installedPacks.isEmpty ? "Fallback only" : "\(viewModel.installedPacks.count) packs",
                tone: viewModel.installedPacks.isEmpty ? .caution : .info
            )
        ]
    }

    private var mapFailureRows: [(title: String, detail: String)] {
        var rows: [(String, String)] = []

        if viewModel.currentLocation == nil {
            rows.append(("Location unavailable", viewModel.locationFailureSummary))
        }

        if viewModel.installedPacks.isEmpty {
            rows.append(("Offline map pack not installed", viewModel.offlineFallbackSummary))
        }

        if let resourceDataStatusMessage = viewModel.resourceDataStatusMessage {
            rows.append(("Offline layer data limited", resourceDataStatusMessage))
        }

        if let officialAlertUnavailableMessage = viewModel.officialAlertUnavailableMessage {
            rows.append(("Official warnings unavailable", officialAlertUnavailableMessage))
        }

        if viewModel.savedRoutes.isEmpty {
            rows.append(("No saved evacuation route", "Create one in Plan when safe. Until then, use shelters, water points, and landmarks as manual fallbacks."))
        }

        return rows
    }

    private var savedRoutesPanel: some View {
        PanelCard(title: "Saved Evacuation Routes", subtitle: "Offline route notes from your plan") {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.savedRouteSummary)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)

                TrustPillGroup(items: viewModel.savedRouteTrustItems)

                if viewModel.savedRoutes.isEmpty {
                    Button {
                        openEvacuationRoutes()
                    } label: {
                        Label("Create Evacuation Route", systemImage: "route")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Text("No route has been saved on this device yet.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                } else {
                    Button {
                        openEvacuationRoutes()
                    } label: {
                        Label("Edit Routes", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    ForEach(Array(viewModel.savedRoutes.prefix(3).enumerated()), id: \.offset) { index, route in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(index == 0 ? "Primary route" : "Backup route \(index)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ColorTheme.textFaint)
                            Text(route)
                                .font(RediTypography.bodyStrong)
                                .foregroundStyle(ColorTheme.text)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    private var officialAlertsPanel: some View {
        PanelCard(title: "Official Alerts", subtitle: "Mirrored Australian public warnings cached for offline map use") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    RediIcon(viewModel.topOfficialAlert?.kind.systemImage ?? "warning")
                        .foregroundStyle(officialAlertColor)
                        .frame(width: 18, height: 18)
                        .padding(10)
                        .background(officialAlertColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("OFFICIAL ALERTS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(officialAlertColor)
                        Text(viewModel.officialAlertHeadline)
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)
                        Text(viewModel.officialAlertDetail)
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textMuted)
                    }

                    Spacer(minLength: 0)
                }

                TrustPillGroup(items: viewModel.officialAlertOverviewTrustItems)

                if let topOfficialAlert = viewModel.topOfficialAlert {
                    Text(viewModel.officialAlertSafetyNote(for: topOfficialAlert))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("RediM8 mirrors public warnings when a recent snapshot is available. It does not replace official emergency alerts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var criticalNearbyPanel: some View {
        PanelCard(
            title: "Nearest Survival References",
            subtitle: "Water first, then shelter and evacuation fallback",
            backgroundAssetName: "community_shelter_hub",
            backgroundImageOffset: CGSize(width: 0, height: 0)
        ) {
            VStack(spacing: 12) {
                if viewModel.featuredShelters.isEmpty, viewModel.featuredWaterPoints.isEmpty {
                    Text(viewModel.currentLocation == nil
                        ? "No nearby shelters or water points are available from the current offline coverage. Install a regional pack or use saved routes and landmarks as fallback references."
                        : "No nearby shelters or water points are available from installed offline coverage or live nearby data right now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let point = viewModel.featuredWaterPoints.first {
                    waterPriorityCard(point)
                }

                if let shelter = viewModel.featuredShelters.first {
                    nearbySummaryCard(
                        title: shelter.name,
                        subtitle: "Evacuation point • \(viewModel.shelterDistanceText(for: shelter))",
                        detail: shelter.notes,
                        iconName: shelter.type.mapMarkerAssetName,
                        accent: viewModel.shelterTint(for: shelter.type),
                        trustItems: viewModel.shelterTrustItems(for: shelter),
                        actionTitle: "Navigate",
                        action: {
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

    private var advancedMapSections: some View {
        VStack(spacing: 16) {
            CollapsiblePanelCard(
                title: "Map Packs",
                subtitle: "Install regional coverage and inspect its limits.",
                accent: ColorTheme.info,
                isExpanded: $isShowingMapPacks
            ) {
                Text(viewModel.coverageLimitSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
                subtitle: "Advanced layer toggles for the offline map.",
                accent: ColorTheme.info,
                isExpanded: $isShowingLayers
            ) {
                ForEach(viewModel.availableLayers) { layer in
                    Toggle(isOn: layerBinding(for: layer)) {
                        HStack(alignment: .top, spacing: 12) {
                            MapLayerIcon(layer, size: 22)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(layer.title)
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)
                                Text(layer.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(ColorTheme.info)
                }
            }

            CollapsiblePanelCard(
                title: "Marker Legend",
                subtitle: "Color roles used on the offline map.",
                accent: ColorTheme.info,
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
                    accent: ColorTheme.ready,
                    isExpanded: $isShowingEvacuationPoints
                ) {
                    evacuationPointsContent
                }
            }

            if viewModel.isLayerEnabled(.waterPoints) {
                CollapsiblePanelCard(
                    title: "Water Points",
                    subtitle: "Installed offline water points plus live nearby search when available.",
                    accent: ColorTheme.info,
                    isExpanded: $isShowingWaterPoints
                ) {
                    waterPointsContent
                }
            }

            if viewModel.isLayerEnabled(.dirtRoads) {
                CollapsiblePanelCard(
                    title: "Dirt Roads & Remote Tracks",
                    subtitle: "Unsealed roads, 4WD routes and station tracks.",
                    accent: ColorTheme.info,
                    isExpanded: $isShowingDirtRoads
                ) {
                    dirtRoadsContent
                }
            }

            if viewModel.isLayerEnabled(.fireTrails) {
                CollapsiblePanelCard(
                    title: "Fire Access Trails",
                    subtitle: "Emergency-service access routes shown with caution.",
                    accent: ColorTheme.warning,
                    isExpanded: $isShowingFireTrails
                ) {
                    fireTrailsContent
                }
            }

            if viewModel.isLayerEnabled(.officialAlerts) || !viewModel.nearbyOfficialAlerts.isEmpty {
                CollapsiblePanelCard(
                    title: "Official Alert Layer",
                    subtitle: "Mirrored public warnings for your current area.",
                    accent: officialAlertColor,
                    isExpanded: $isShowingOfficialAlerts
                ) {
                    officialAlertsContent
                }
            }

            if !viewModel.visibleBeacons.isEmpty {
                CollapsiblePanelCard(
                    title: "Community Situation Reports",
                    subtitle: "Temporary local reports discovered over the mesh.",
                    accent: ColorTheme.warning,
                    isExpanded: $isShowingBeacons
                ) {
                    communityBeaconsContent
                }
            }

            CollapsiblePanelCard(
                title: "Personal Markers",
                subtitle: "Your add-on markers and saved local references.",
                accent: ColorTheme.accent,
                isExpanded: $isShowingMarkers
            ) {
                personalMarkersContent
            }

            if viewModel.isLayerEnabled(.resources) {
                CollapsiblePanelCard(
                    title: "Offline Resource List",
                    subtitle: "Critical fallback if map packs are limited.",
                    accent: ColorTheme.info,
                    isExpanded: $isShowingResources
                ) {
                    resourceListContent
                }
            }
        }
    }

    private var officialAlertsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Official warning issued by emergency authorities. RediM8 mirrors this information and keeps it visible offline after the last successful refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.nearbyOfficialAlerts.isEmpty {
                Text(viewModel.officialAlertDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.nearbyOfficialAlerts) { alert in
                    officialAlertRow(alert)
                }
            }
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
                    waterPointRow(point)
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
                    trackRow(track)
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
                    trackRow(trail)
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
                beaconRow(beacon)
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

    private func nearbySummaryCard(
        title: String,
        subtitle: String,
        detail: String,
        iconName: String,
        accent: Color,
        trustItems: [TrustPillItem],
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                MapAssetIcon(assetName: iconName, size: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
            }

            TrustPillGroup(items: trustItems)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }

    private func waterPointRow(_ point: WaterPoint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                MapAssetIcon(assetName: point.kind.mapMarkerAssetName, size: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(point.name)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text("\(point.kind.title) • \(viewModel.waterDistanceText(for: point))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                WaterQualityPill(
                    title: point.quality.title,
                    tint: point.quality == .drinkingWater ? ColorTheme.water : (point.quality == .nonPotable ? ColorTheme.warning : ColorTheme.info)
                )
            }

            TrustPillGroup(items: viewModel.waterTrustItems(for: point))

            Text(point.notes)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            Text(point.source)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func trackRow(_ track: TrackSegment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                MapAssetIcon(assetName: track.kind.mapMarkerAssetName, size: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text("\(track.kind.title) • \(viewModel.distanceText(to: track.midpoint))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if track.kind == .fireTrail {
                Text("Surface: \(track.surface.title)")
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)
                Text("Vehicle: \(track.vehicleAdvice?.title ?? "Check locally")")
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)
                Text("Purpose: \(track.purpose?.title ?? "Emergency Access")")
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)
            } else {
                Text("Surface: \(track.surface.title) • Vehicle: \(track.vehicleAdvice?.title ?? "Check locally")")
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)
            }

            TrustPillGroup(items: viewModel.trackTrustItems(for: track))

            if !track.safetyLabels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(track.safetyLabels) { label in
                            TrustBadge(
                                title: label.title,
                                tint: viewModel.trackSafetyColor(for: label)
                            )
                        }
                    }
                }
            }

            Text(track.notes)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            Text(track.source)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func beaconRow(_ beacon: CommunityBeacon) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MapAssetIcon(
                assetName: beacon.type.mapMarkerAssetName,
                fallbackSystemName: beacon.type.symbolName,
                size: 24
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(beacon.type.title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    if beacon.id == viewModel.activeBeacon?.id {
                        Text("This device")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ColorTheme.ready)
                    }
                    if beacon.type.isPriorityReport {
                        Text("Priority")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ColorTheme.danger)
                    }
                }
                Text("\(beacon.displayLabel) • \(viewModel.beaconDistanceText(for: beacon))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TrustPillGroup(items: viewModel.beaconTrustItems(for: beacon))

                Text(beacon.statusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ColorTheme.text)
                Text(beacon.locationName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.info)
                if let message = beacon.message.nilIfBlank {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let sharedEmergencyMedicalSummary = beacon.sharedEmergencyMedicalSummary {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MEDICAL NOTE SHARED")
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.danger)
                        Text(sharedEmergencyMedicalSummary)
                            .font(.caption)
                            .foregroundStyle(ColorTheme.text)
                    }
                    .padding(.top, 2)
                }
                Text("Expires \(beacon.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let staleWarning = viewModel.beaconStaleWarning(for: beacon) {
                    Text(staleWarning)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                } else if let relayDelayNotice = beacon.relayDelayNotice {
                    Text(relayDelayNotice)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func officialAlertRow(_ alert: OfficialAlert) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                MapAssetIcon(
                    assetName: alert.kind.mapMarkerAssetName,
                    fallbackSystemName: alert.kind.systemImage,
                    size: 24
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text("\(alert.severity.title) • \(viewModel.officialAlertDistanceText(for: alert))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                TrustBadge(title: alert.kind.title, tint: officialAlertColor)
            }

            TrustPillGroup(items: viewModel.officialAlertTrustItems(for: alert))

            Text(alert.regionScope)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ColorTheme.text)

            Text(alert.message)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            if let instruction = alert.instruction {
                Text(instruction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(viewModel.officialAlertSafetyNote(for: alert))
                .font(.caption)
                .foregroundStyle(officialAlertColor)

            if let sourceURL = alert.sourceURL {
                Button("Open Official Source") {
                    openURL(sourceURL)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MapPackRow: View {
    let pack: OfflineMapPack
    let isInstalled: Bool
    let trustItems: [TrustPillItem]
    let onInstall: () -> Void
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.name)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text(pack.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(isInstalled ? "Installed" : pack.kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isInstalled ? ColorTheme.ready : ColorTheme.info)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((isInstalled ? ColorTheme.ready : ColorTheme.info).opacity(0.14), in: Capsule())
            }

            MapPackCoveragePreview(pack: pack, isInstalled: isInstalled, accent: isInstalled ? ColorTheme.ready : ColorTheme.info)

            Text(pack.coverageSummary)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            TrustPillGroup(items: trustItems)

            HStack(spacing: 14) {
                Label("\(pack.sizeMB) MB", systemImage: "internaldrive.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(DateFormatter.rediM8MonthYear.string(from: pack.lastUpdated), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Layers: \(pack.supportedLayerSummary)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Coverage stops at this pack boundary. Outside it, RediM8 falls back to the basemap and any saved markers.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if isInstalled {
                    Button("Open") {
                        onOpen()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    if !pack.isBundledByDefault {
                        Button("Remove") {
                            onRemove()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                } else {
                    Button("Install") {
                        onInstall()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private extension MapView {
    var officialAlertColor: Color {
        switch viewModel.officialAlertTone {
        case .ready:
            ColorTheme.ready
        case .info:
            ColorTheme.info
        case .caution:
            ColorTheme.warning
        case .danger:
            ColorTheme.danger
        case .neutral:
            ColorTheme.textFaint
        }
    }
}

private struct TrustBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

private struct ShelterCard: View {
    let shelter: ShelterLocation
    let distanceText: String
    let tint: Color
    let isSelected: Bool
    let trustItems: [TrustPillItem]
    let openNavigation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                MapAssetIcon(assetName: shelter.type.mapMarkerAssetName, fallbackSystemName: "shelter", size: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(shelter.name)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)

                    if isSelected {
                        Text("Selected on map")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ColorTheme.info)
                    }
                }

                Spacer()

                TrustBadge(title: shelter.type.title, tint: tint)
            }

            TrustPillGroup(items: trustItems)

            Text("Capacity: \(shelter.capacityText)")
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            Text("Distance: \(distanceText)")
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            Text("Note: \(shelter.notes)")
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            Text(shelter.source)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Navigate") {
                openNavigation()
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
