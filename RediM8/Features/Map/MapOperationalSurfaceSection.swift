import SwiftUI

struct MapNextAction {
    let title: String
    let detail: String
    let buttonTitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
}

struct MapNextActionPanelView: View {
    let recommendation: MapNextAction

    var body: some View {
        CommandPanel(eyebrow: "Next Action") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: recommendation.systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(recommendation.tint)
                    .frame(width: 18, height: 18)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(ColorTheme.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(recommendation.detail)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } actions: {
            InlineActionButton(title: recommendation.buttonTitle, action: recommendation.action)
        }
    }
}

struct MapOperationalSurfaceSection: View {
    @ObservedObject var viewModel: MapViewModel
    let appState: AppState
    let officialAlertColor: Color
    let mapFailureRows: [(title: String, detail: String)]
    @Binding var surfaceMode: MapSurfaceMode
    @Binding var isShowingFullScreenMap: Bool
    @Binding var isShowingLayers: Bool
    @Binding var isShowingMapBrief: Bool
    @Binding var isShowingRouteInspector: Bool
    @Binding var isShowingNearestResource: Bool
    @Binding var isShowingRoutePlanner: Bool
    @Binding var isShowingEvacuationPlan: Bool

    private let mapQuickActionColumns = [
        GridItem(.adaptive(minimum: 148, maximum: 240), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            embeddedMapSurface
            mapQuickStatusStrip
            mapSurfaceSelector
            mapPriorityCallout
            evacuationModeCard
            mapQuickActions
        }
    }

    private var evacuationModeCard: some View {
        Button {
            isShowingEvacuationPlan = true
        } label: {
            RediCommandCard(
                title: "Evacuation Mode",
                detail: "Route, water, shelters, and terrain guidance in one operational view.",
                systemImage: "figure.run",
                tint: appState.offlineRoutingService.isGraphLoaded ? ColorTheme.danger : ColorTheme.accent,
                badge: "Mode",
                prominence: .critical,
                layout: .rail,
                minHeight: 86
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private var embeddedMapSurface: some View {
        MapSurfaceCanvasView(viewModel: viewModel)
            .frame(height: 520)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topLeading) {
                MapModeBadgeView(
                    tint: viewModel.surfaceTint,
                    title: viewModel.mapModeOverlayTitle,
                    detail: viewModel.mapModeOverlayDetail
                )
                .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        isShowingFullScreenMap = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(ColorTheme.text)
                            .padding(12)
                            .background(Color.black.opacity(0.86), in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }

                    if viewModel.currentLocation != nil {
                        MapHeadingBadgeView(text: viewModel.headingText)
                    }
                }
                .padding(12)
            }
            .overlay(alignment: .bottomLeading) {
                MapCompactSummaryView(
                    tone: MapTonePalette.color(for: viewModel.mapConfidenceTone),
                    value: viewModel.mapConfidenceValue.uppercased(),
                    detail: viewModel.mapConfidenceOverlayDetail
                )
                .padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                MapReferenceOverlayView(viewModel: viewModel)
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

            Picker("Map Surface", selection: $surfaceMode) {
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

    private var mapQuickStatusStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                MapSummaryCardView(
                    title: "Official",
                    value: viewModel.officialAlertStatusValue.uppercased(),
                    detail: viewModel.topOfficialAlert?.title ?? "Monitoring official feeds for your area.",
                    accent: officialAlertColor
                )

                MapSummaryCardView(
                    title: "Map",
                    value: viewModel.mapModeOverlayTitle,
                    detail: viewModel.mapModeOverlayDetail,
                    accent: viewModel.surfaceTint
                )

                MapSummaryCardView(
                    title: "Routes",
                    value: viewModel.savedRoutes.isEmpty ? "NO SAVED ROUTES" : "ROUTE READY",
                    detail: viewModel.savedRoutes.first ?? "Create one before conditions change.",
                    accent: viewModel.savedRoutes.isEmpty ? ColorTheme.warning : ColorTheme.ready
                )

                MapSummaryCardView(
                    title: "Confidence",
                    value: viewModel.mapConfidenceValue.uppercased(),
                    detail: viewModel.mapConfidenceDetail,
                    accent: MapTonePalette.color(for: viewModel.mapConfidenceTone)
                )
            }
            .padding(.vertical, 2)
        }
    }

    private var mapQuickActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            MapSectionLabel(title: "Primary Actions")

            LazyVGrid(columns: mapQuickActionColumns, spacing: 12) {
                Button {
                    isShowingNearestResource = true
                } label: {
                    RediCommandCard(
                        title: "Find Resources",
                        detail: "Locate nearest water, shelter, road, or town from your position.",
                        systemImage: "scope",
                        tint: ColorTheme.accent,
                        badge: "Primary",
                        prominence: .accented,
                        minHeight: 102
                    )
                }
                .buttonStyle(CardPressButtonStyle())

                Button {
                    isShowingRoutePlanner = true
                } label: {
                    RediCommandCard(
                        title: "Plan Route",
                        detail: "Compute offline evacuation routes using the routing engine.",
                        systemImage: "route",
                        tint: appState.offlineRoutingService.isGraphLoaded ? ColorTheme.ready : ColorTheme.accent,
                        badge: appState.offlineRoutingService.isGraphLoaded ? "Ready" : "Offline",
                        prominence: .accented,
                        minHeight: 102
                    )
                }
                .buttonStyle(CardPressButtonStyle())
            }

            MapSectionLabel(title: "Support")

            LazyVGrid(columns: mapQuickActionColumns, spacing: 12) {
                Button {
                    viewModel.recenter()
                } label: {
                    RediCommandCard(
                        title: "Recenter",
                        detail: "Snap back to your current location and heading reference.",
                        systemImage: "location.fill",
                        tint: ColorTheme.textTertiary,
                        badge: viewModel.currentLocation == nil ? "Waiting" : "Live",
                        prominence: .neutral,
                        minHeight: 102
                    )
                }
                .buttonStyle(CardPressButtonStyle())

                Button {
                    isShowingFullScreenMap = true
                } label: {
                    RediCommandCard(
                        title: "Full Screen",
                        detail: "Open the live map canvas with the maximum visible field area.",
                        systemImage: "arrow.up.left.and.arrow.down.right",
                        tint: ColorTheme.textTertiary,
                        badge: "Canvas",
                        prominence: .neutral,
                        minHeight: 102
                    )
                }
                .buttonStyle(CardPressButtonStyle())

                Button {
                    viewModel.toggleDistanceRings()
                } label: {
                    RediCommandCard(
                        title: viewModel.showsDistanceRings ? "Hide Rings" : "Show Rings",
                        detail: "Toggle the 1 km, 5 km, and 10 km tactical distance guides.",
                        systemImage: viewModel.showsDistanceRings ? "circle.hexagongrid.circle.fill" : "circle.hexagongrid.circle",
                        tint: ColorTheme.textTertiary,
                        badge: viewModel.showsDistanceRings ? "On" : "Off",
                        prominence: .neutral,
                        minHeight: 102
                    )
                }
                .buttonStyle(CardPressButtonStyle())

                Button {
                    withAnimation(RediMotion.reveal) {
                        isShowingLayers = true
                    }
                } label: {
                    RediCommandCard(
                        title: "Map Layers",
                        detail: "Choose water, shelters, alerts, reports, and support overlays.",
                        systemImage: "square.3.layers.3d",
                        tint: ColorTheme.textTertiary,
                        badge: "Layers",
                        prominence: .neutral,
                        minHeight: 102
                    )
                }
                .buttonStyle(CardPressButtonStyle())

                Button {
                    withAnimation(RediMotion.reveal) {
                        isShowingMapBrief = true
                        isShowingRouteInspector = true
                    }
                } label: {
                    RediCommandCard(
                        title: "Open Brief",
                        detail: "See confidence, saved routes, official warnings, and trust detail.",
                        systemImage: "slider.horizontal.3",
                        tint: ColorTheme.textTertiary,
                        badge: "Brief",
                        prominence: .neutral,
                        minHeight: 102
                    )
                }
                .buttonStyle(CardPressButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var mapPriorityCallout: some View {
        if let topOfficialAlert = viewModel.topOfficialAlert {
            MapInlineCalloutView(
                title: topOfficialAlert.isAreaScoped ? "Official warning mirrored on map" : "Official feed active",
                detail: viewModel.officialAlertSafetyNote(for: topOfficialAlert),
                accent: officialAlertColor
            )
        } else if let firstFailure = mapFailureRows.first {
            MapInlineCalloutView(
                title: firstFailure.title,
                detail: firstFailure.detail,
                accent: ColorTheme.warning
            )
        }
    }
}

struct MapSurfaceCanvasView: View {
    @ObservedObject var viewModel: MapViewModel

    var body: some View {
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
                    heading: viewModel.heading,
                    showsUserLocation: viewModel.currentLocation != nil,
                    showsDistanceRings: viewModel.showsDistanceRings,
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
                    heading: viewModel.heading,
                    showsUserLocation: viewModel.currentLocation != nil,
                    showsDistanceRings: viewModel.showsDistanceRings,
                    animatesRegionChanges: !viewModel.reducesMapAnimations,
                    onSelectShelter: viewModel.selectShelter(withID:)
                )
            }
        }
    }
}

struct MapReferenceOverlayView: View {
    @ObservedObject var viewModel: MapViewModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if viewModel.currentLocation != nil, viewModel.showsDistanceRings {
                MapDistanceRingLegendView(labels: viewModel.distanceRingLabels)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Nearest Resources")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ColorTheme.textFaint)

                MapReferenceChipView(
                    title: "Water",
                    detail: viewModel.featuredWaterPoints.first.map { viewModel.waterDistanceText(for: $0) } ?? "None",
                    iconName: "water",
                    accent: ColorTheme.textTertiary
                )

                MapReferenceChipView(
                    title: "Shelter",
                    detail: viewModel.featuredShelters.first.map { viewModel.shelterDistanceText(for: $0) } ?? "None",
                    iconName: "shelter",
                    accent: ColorTheme.textTertiary
                )

                MapReferenceChipView(
                    title: "Route",
                    detail: viewModel.savedRoutes.isEmpty ? "No saved route" : "Route ready",
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
}

struct MapFullScreenSurfaceView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var isPresented: Bool
    @Binding var isShowingMapPacks: Bool

    var body: some View {
        ZStack {
            MapSurfaceCanvasView(viewModel: viewModel)
                .ignoresSafeArea()
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    MapModeBadgeView(
                        tint: viewModel.surfaceTint,
                        title: viewModel.mapModeOverlayTitle,
                        detail: viewModel.mapModeOverlayDetail
                    )

                    Spacer(minLength: 10)

                    if viewModel.currentLocation != nil {
                        MapHeadingBadgeView(text: viewModel.headingText)
                    }

                    recenterMapButton
                    closeButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        MapModeBadgeView(
                            tint: viewModel.surfaceTint,
                            title: viewModel.mapModeOverlayTitle,
                            detail: viewModel.mapModeOverlayDetail
                        )
                        Spacer(minLength: 10)
                        if viewModel.currentLocation != nil {
                            MapHeadingBadgeView(text: viewModel.headingText)
                        }
                    }

                    HStack(spacing: 10) {
                        recenterMapButton
                        closeButton
                    }
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
                ViewThatFits(in: .horizontal) {
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
                        openPacksButton
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.surfaceMode.title)
                                .font(RediTypography.bodyStrong)
                                .foregroundStyle(ColorTheme.text)
                            Text(viewModel.workingBasemapSummary)
                                .font(.caption)
                                .foregroundStyle(ColorTheme.textMuted)
                        }

                        openPacksButton
                    }
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
                        .foregroundStyle(MapTonePalette.color(for: viewModel.officialAlertTone))
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

    private var recenterMapButton: some View {
        Button {
            viewModel.recenter()
        } label: {
            Image(systemName: "location.fill")
                .font(.headline)
                .foregroundStyle(ColorTheme.text)
                .frame(width: 42, height: 42)
                .background(Color.black.opacity(0.84), in: Circle())
        }
    }

    private var closeButton: some View {
        Button {
            isPresented = false
        } label: {
            Image(systemName: "xmark")
                .font(.headline.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .frame(width: 42, height: 42)
                .background(Color.black.opacity(0.84), in: Circle())
        }
    }

    private var openPacksButton: some View {
        Button("Open Packs") {
            isPresented = false
            isShowingMapPacks = true
        }
        .buttonStyle(SecondaryActionButtonStyle())
    }
}
