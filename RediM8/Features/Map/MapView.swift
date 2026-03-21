import SwiftUI

struct MapView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: MapViewModel
    private let appState: AppState
    private let scrollToTopRequestID: Int
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
    @State private var selectedOfficialAlertScope: MapOfficialAlertScope = .local
    @State private var selectedOfficialAlertJurisdiction: AustralianJurisdiction?
    @State private var isShowingBeacons = false
    @State private var isShowingMarkers = false
    @State private var isShowingResources = false
    @State private var isShowingMapBrief = false
    @State private var isShowingRouteInspector = false
    @State private var isShowingNearestResource = false
    @State private var isShowingRoutePlanner = false
    @State private var isShowingEvacuationPlan = false
    private let mapQuickActionColumns = [
        GridItem(.adaptive(minimum: 148, maximum: 240), spacing: 12)
    ]
    private let briefMetricColumns = [
        GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 12)
    ]

    init(appState: AppState, scrollToTopRequestID: Int = 0, openEvacuationRoutes: @escaping () -> Void = {}) {
        self.appState = appState
        self.scrollToTopRequestID = scrollToTopRequestID
        self.openEvacuationRoutes = openEvacuationRoutes
        _viewModel = StateObject(wrappedValue: MapViewModel(appState: appState))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear
                        .frame(height: 0)
                        .id(MapScrollAnchor.top)

                    if viewModel.isStealthModeEnabled {
                        StealthModeIndicatorView()
                    }

                    CinematicBanner("map_remote_track", height: 160)

                    nextActionPanel

                    mapStatusBanner

                    embeddedMapPanel

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

                    criticalNearbyPanel

                    CollapsiblePanelCard(
                        title: "Field Brief",
                        subtitle: "Surface, coverage, and fallback detail for the current map mode.",
                        accent: ColorTheme.textTertiary,
                        isExpanded: $isShowingMapBrief
                    ) {
                        mapBriefContent
                    }

                    CollapsiblePanelCard(
                        title: "Routes & Alerts",
                        subtitle: "Saved routes, official warnings, and known map failures.",
                        accent: officialAlertColor,
                        isExpanded: $isShowingRouteInspector
                    ) {
                        routeInspectorContent
                    }

                    advancedMapSections
                }
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.screen)
                .padding(.bottom, RediLayout.commandDockContentInset)
            }
            .onChange(of: scrollToTopRequestID) { _, _ in
                DispatchQueue.main.async {
                    withAnimation(RediMotion.selection) {
                        proxy.scrollTo(MapScrollAnchor.top, anchor: .top)
                    }
                }
            }
        }
        .navigationTitle("Map")
        .safeAreaInset(edge: .top, spacing: 0) {
            OperationalStatusRail(items: mapStatusItems, accent: ColorTheme.textTertiary)
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
        .sheet(isPresented: $isShowingNearestResource) {
            NavigationStack {
                NearestResourceView(
                    appState: appState,
                    currentLocation: viewModel.currentLocation
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { isShowingNearestResource = false }
                            .foregroundStyle(ColorTheme.accent)
                    }
                }
            }
            .rediSheetPresentation()
        }
        .sheet(isPresented: $isShowingRoutePlanner) {
            NavigationStack {
                RoutePlanningView(
                    appState: appState,
                    currentLocation: viewModel.currentLocation
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { isShowingRoutePlanner = false }
                            .foregroundStyle(ColorTheme.accent)
                    }
                }
            }
            .rediSheetPresentation()
        }
        .sheet(isPresented: $isShowingEvacuationPlan) {
            NavigationStack {
                EvacuationPlanView(appState: appState, currentLocation: viewModel.currentLocation)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { isShowingEvacuationPlan = false }
                                .foregroundStyle(ColorTheme.accent)
                        }
                    }
            }
            .rediSheetPresentation()
        }
    }

    private enum MapScrollAnchor {
        static let top = "map-scroll-top"
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
                accent: officialAlertToneColor(selectedOfficialAlertSummary.tone)
            )
        }
    }

    private var officialAlertLayerSubtitle: String {
        switch selectedOfficialAlertScope {
        case .local:
            return "Mirrored public warnings matched to this map area and installed coverage."
        case .state:
            return "Check a state or territory feed for family, travel, or wider operational context."
        case .australia:
            return "Scan the national warning picture across cached official feeds."
        }
    }

    private var nextActionRecommendation: MapNextAction {
        if let topOfficialAlert = viewModel.topOfficialAlert,
           topOfficialAlert.isAreaScoped,
           topOfficialAlert.severity != .advice {
            return MapNextAction(
                title: viewModel.savedRoutes.isEmpty ? "Create evacuation path" : "Review evacuation mode",
                detail: viewModel.savedRoutes.isEmpty
                    ? "A severe official warning is active and no saved route is ready on this device."
                    : viewModel.officialAlertSafetyNote(for: topOfficialAlert),
                buttonTitle: "Open Evacuation Mode",
                systemImage: "figure.run",
                tint: officialAlertColor,
                action: { isShowingEvacuationPlan = true }
            )
        }

        if viewModel.currentLocation == nil {
            return MapNextAction(
                title: "Recover location reference",
                detail: "Use saved routes, known landmarks, and offline references until GPS returns.",
                buttonTitle: "Recenter",
                systemImage: "location.slash",
                tint: ColorTheme.warning,
                action: { viewModel.recenter() }
            )
        }

        if viewModel.savedRoutes.isEmpty {
            return MapNextAction(
                title: "Create evacuation path",
                detail: "No saved route is ready on this device. Build one while conditions are stable.",
                buttonTitle: "Plan Route",
                systemImage: "route",
                tint: ColorTheme.warning,
                action: { isShowingRoutePlanner = true }
            )
        }

        if viewModel.installedPacks.isEmpty {
            return MapNextAction(
                title: "Install offline coverage",
                detail: "A regional pack keeps water, shelter, and track layers available when networks fail.",
                buttonTitle: "Open Map Packs",
                systemImage: "square.and.arrow.down",
                tint: ColorTheme.info,
                action: { isShowingMapPacks = true }
            )
        }

        if let point = viewModel.featuredWaterPoints.first {
            return MapNextAction(
                title: "Check nearest water source",
                detail: "\(point.name) is \(viewModel.waterDistanceText(for: point)). Confirm access before moving.",
                buttonTitle: "Find Resources",
                systemImage: "drop.fill",
                tint: ColorTheme.info,
                action: { isShowingNearestResource = true }
            )
        }

        return MapNextAction(
            title: "Review live map",
            detail: "Map mode and offline fallback are ready. Scan resources and route options around your position.",
            buttonTitle: "Open Full Screen Map",
            systemImage: "map.fill",
            tint: ColorTheme.textTertiary,
            action: { isShowingFullScreenMap = true }
        )
    }

    private var embeddedMapPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            embeddedMapSurface

            mapQuickStatusStrip
            mapSurfaceSelector
            if let mapPriorityCallout {
                mapPriorityCallout
            }
            evacuationModeCard
            mapQuickActions
        }
    }

    private var nextActionPanel: some View {
        let recommendation = nextActionRecommendation

        return CommandPanel(eyebrow: "Next Action") {
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
        mapSurface
            .frame(height: 520)
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

    private var mapQuickStatusStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                mapSummaryCard(
                    title: "Official",
                    value: viewModel.officialAlertStatusValue.uppercased(),
                    detail: viewModel.topOfficialAlert?.title ?? "Monitoring official feeds for your area.",
                    accent: officialAlertColor
                )

                mapSummaryCard(
                    title: "Map",
                    value: viewModel.mapModeOverlayTitle,
                    detail: viewModel.mapModeOverlayDetail,
                    accent: viewModel.surfaceTint
                )

                mapSummaryCard(
                    title: "Routes",
                    value: viewModel.savedRoutes.isEmpty ? "NO SAVED ROUTES" : "ROUTE READY",
                    detail: viewModel.savedRoutes.first ?? "Create one before conditions change.",
                    accent: viewModel.savedRoutes.isEmpty ? ColorTheme.warning : ColorTheme.ready
                )

                mapSummaryCard(
                    title: "Confidence",
                    value: viewModel.mapConfidenceValue.uppercased(),
                    detail: viewModel.mapConfidenceDetail,
                    accent: statusColor(for: viewModel.mapConfidenceTone)
                )
            }
            .padding(.vertical, 2)
        }
    }

    private var mapQuickActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            mapSectionLabel("Primary Actions")

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

            mapSectionLabel("Support")

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

    private var mapPriorityCallout: AnyView? {
        if let topOfficialAlert = viewModel.topOfficialAlert {
            return AnyView(
                mapInlineCallout(
                    title: topOfficialAlert.isAreaScoped ? "Official warning mirrored on map" : "Official feed active",
                    detail: viewModel.officialAlertSafetyNote(for: topOfficialAlert),
                    accent: officialAlertColor
                )
            )
        }

        if let firstFailure = mapFailureRows.first {
            return AnyView(
                mapInlineCallout(
                    title: firstFailure.title,
                    detail: firstFailure.detail,
                    accent: ColorTheme.warning
                )
            )
        }

        return nil
    }

    private func mapSummaryCard(title: String, value: String, detail: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(RediTypography.caption)
                .foregroundStyle(accent)

            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textMuted)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(
            minWidth: dynamicTypeSize.isAccessibilitySize ? 220 : 184,
            maxWidth: dynamicTypeSize.isAccessibilitySize ? 280 : 220,
            alignment: .leading
        )
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityHint(detail)
    }

    private func mapInlineCallout(title: String, detail: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(accent)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
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

    private var fullScreenMapView: some View {
        ZStack {
            mapSurface
                .ignoresSafeArea()
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    mapModeBadge

                    Spacer(minLength: 10)

                    if viewModel.currentLocation != nil {
                        headingBadge
                    }

                    recenterMapButton
                    closeFullScreenMapButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        mapModeBadge
                        Spacer(minLength: 10)
                        if viewModel.currentLocation != nil {
                            headingBadge
                        }
                    }

                    HStack(spacing: 10) {
                        recenterMapButton
                        closeFullScreenMapButton
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

    private func statusColor(for tone: OperationalStatusTone) -> Color {
        switch tone {
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

    private var mapModeBadge: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MAP MODE")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(viewModel.surfaceTint)

            Text(viewModel.mapModeOverlayTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(viewModel.mapModeOverlayDetail)
                .font(.caption2)
                .foregroundStyle(ColorTheme.textMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(viewModel.surfaceTint.opacity(0.28), lineWidth: 1)
        )
    }

    private var headingBadge: some View {
        HStack(spacing: 8) {
            RediIcon("compass")
                .foregroundStyle(ColorTheme.textTertiary)
                .frame(width: 16, height: 16)
            Text(viewModel.headingText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.78), in: Capsule())
        .overlay(
            Capsule()
                .stroke(ColorTheme.textTertiary.opacity(0.28), lineWidth: 1)
        )
    }

    private var compactMapSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MAP CONFIDENCE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor(for: viewModel.mapConfidenceTone))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(viewModel.mapConfidenceValue.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .lineLimit(1)
            Text(viewModel.mapConfidenceOverlayDetail)
                .font(.caption2)
                .foregroundStyle(ColorTheme.textMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
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
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ColorTheme.text)
                Text(viewModel.mapStatusDetail)
                    .font(.subheadline.weight(.medium))
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
            if viewModel.currentLocation != nil, viewModel.showsDistanceRings {
                distanceRingLegend
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Nearest Resources")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ColorTheme.textFaint)

                referenceChip(
                    title: "Water",
                    detail: viewModel.featuredWaterPoints.first.map { viewModel.waterDistanceText(for: $0) } ?? "None",
                    iconName: "water",
                    accent: ColorTheme.textTertiary
                )

                referenceChip(
                    title: "Shelter",
                    detail: viewModel.featuredShelters.first.map { viewModel.shelterDistanceText(for: $0) } ?? "None",
                    iconName: "shelter",
                    accent: ColorTheme.textTertiary
                )

                referenceChip(
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

    private var closeFullScreenMapButton: some View {
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

    private var openPacksButton: some View {
        Button("Open Packs") {
            isShowingFullScreenMap = false
            isShowingMapPacks = true
        }
        .buttonStyle(SecondaryActionButtonStyle())
    }

    private var distanceRingLegend: some View {
        HStack(spacing: 8) {
            RediIcon("compass")
                .foregroundStyle(ColorTheme.textTertiary)
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
                .stroke(ColorTheme.textTertiary.opacity(0.2), lineWidth: 1)
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

    private func mapSectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(RediTypography.label)
            .tracking(1.2)
            .foregroundStyle(ColorTheme.textTertiary)
    }

    private func briefMetricCard(title: String, value: String, detail: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(accent)

            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }

    private func bulletLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(ColorTheme.textTertiary)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(.caption)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        case .dirtRoads:
            "Unsealed Roads"
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
        case .dirtRoads:
            "Unsealed roads, 4WD tracks, and station access"
        case .evacuationPoints:
            "Baseline evacuation centres, shelters, and assembly points"
        default:
            layer.subtitle
        }
    }

    private func waterPriorityCard(_ point: WaterPoint) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.waterPriorityHeading(for: point))
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.textTertiary)

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
                        .foregroundStyle(ColorTheme.textSecondary)
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
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ColorTheme.textTertiary.opacity(0.2), lineWidth: 1)
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
                label: "Map",
                value: viewModel.basemapOperationalValue,
                tone: viewModel.basemapOperationalTone
            ),
            OperationalStatusItem(
                iconName: "route",
                label: "Routes",
                value: viewModel.savedRoutes.isEmpty ? "No saved routes" : "\(viewModel.savedRoutes.count) saved",
                tone: viewModel.savedRoutes.isEmpty ? .caution : .ready
            ),
            OperationalStatusItem(
                iconName: "scope",
                label: "Confidence",
                value: viewModel.mapConfidenceValue,
                tone: viewModel.mapConfidenceTone
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

        if let hazardFeedUnavailableMessage = viewModel.hazardFeedUnavailableMessage {
            rows.append(("Live hazard feeds degraded", hazardFeedUnavailableMessage))
        }

        if viewModel.savedRoutes.isEmpty {
            rows.append(("No saved evacuation route", "Create one in Plan when safe. Until then, use shelters, water points, and landmarks as manual fallbacks."))
        }

        return rows
    }

    private var mapBriefContent: some View {
        VStack(spacing: 14) {
            inspectorGroup(
                title: "Confidence",
                subtitle: "Fast scan of what the map can rely on right now.",
                accent: ColorTheme.textTertiary
            ) {
                TrustPillGroup(items: viewModel.mapTrustItems)
                LazyVGrid(columns: briefMetricColumns, spacing: 12) {
                    briefMetricCard(
                        title: "Confidence",
                        value: viewModel.mapConfidenceValue,
                        detail: viewModel.mapConfidenceOverlayDetail,
                        accent: statusColor(for: viewModel.mapConfidenceTone)
                    )
                    briefMetricCard(
                        title: "Basemap",
                        value: viewModel.mapStatusHeadline,
                        detail: viewModel.mapModeOverlayDetail,
                        accent: viewModel.surfaceTint
                    )
                    briefMetricCard(
                        title: "Coverage",
                        value: viewModel.coverageLimitHeadline,
                        detail: viewModel.installedPacks.isEmpty ? "Offline layers limited" : "Offline pack boundary active",
                        accent: viewModel.installedPacks.isEmpty ? ColorTheme.warning : ColorTheme.info
                    )
                    briefMetricCard(
                        title: "Position",
                        value: viewModel.currentLocation == nil ? "No live position" : "Live position",
                        detail: viewModel.currentLocation == nil ? "Waiting for GPS" : viewModel.headingText,
                        accent: viewModel.currentLocation == nil ? ColorTheme.warning : ColorTheme.ready
                    )
                    briefMetricCard(
                        title: "Hazards",
                        value: viewModel.hazardFeedStatusValue,
                        detail: viewModel.hazardFeedHeadline,
                        accent: statusColor(for: viewModel.hazardFeedTone)
                    )
                    briefMetricCard(
                        title: "Rings",
                        value: viewModel.showsDistanceRings ? "1 km / 5 km / 10 km" : "Hidden",
                        detail: viewModel.showsDistanceRings ? "Distance guides active" : "Distance guides disabled",
                        accent: viewModel.showsDistanceRings ? ColorTheme.info : ColorTheme.textTertiary
                    )
                }
            }

            inspectorGroup(
                title: "Coverage Limits",
                subtitle: "What drops away outside your installed boundary.",
                accent: viewModel.installedPacks.isEmpty ? ColorTheme.warning : ColorTheme.info
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("OFFLINE PACK")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textFaint)

                    Text(viewModel.coverageLimitHeadline)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.coverageLimitBullets, id: \.self) { bullet in
                        bulletLine(bullet)
                    }
                }

                if let surfaceAvailabilityNote = viewModel.surfaceAvailabilityNote {
                    Text(surfaceAvailabilityNote)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textMuted)
                }

                installedCoveragePreview

                Text("Offline layers last updated: \(viewModel.lastUpdatedText)")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.text)

                Text(TrustLayer.mapFreshnessNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(TrustLayer.mapCoverageNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let bushfireMapSummary = viewModel.bushfireMapSummary {
                inspectorGroup(
                    title: "Scenario Priority",
                    subtitle: "Mode-specific routing focus now in effect.",
                    accent: ColorTheme.textTertiary
                ) {
                    Text(bushfireMapSummary)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.text)
                }
            }

            if viewModel.isLayerEnabled(.fireTrails) || viewModel.isLayerEnabled(.evacuationPoints) || viewModel.isStealthModeEnabled {
                inspectorGroup(
                    title: "Operating Notes",
                    subtitle: "Extra cautions based on active layers and device mode.",
                    accent: ColorTheme.textTertiary
                ) {
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
    }

    private var routeInspectorContent: some View {
        VStack(spacing: 14) {
            savedRoutesInspector
            officialAlertsInspector

            if !mapFailureRows.isEmpty {
                failureModesInspector
            }
        }
    }

    private var savedRoutesInspector: some View {
        inspectorGroup(
            title: "Saved Evacuation Routes",
            subtitle: "Offline route notes from your plan.",
            accent: viewModel.savedRoutes.isEmpty ? ColorTheme.warning : ColorTheme.ready
        ) {
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

    private var officialAlertsInspector: some View {
        inspectorGroup(
            title: "Official Alerts",
            subtitle: officialAlertLayerSubtitle,
            accent: officialAlertToneColor(selectedOfficialAlertSummary.tone)
        ) {
            Text("Switch between local, state, and Australia-wide warning views without leaving the map.")
                .font(.caption)
                .foregroundStyle(.secondary)

            officialAlertsContent
        }
    }

    private var failureModesInspector: some View {
        inspectorGroup(
            title: "Failure Modes",
            subtitle: "What still works when a dependency drops out.",
            accent: ColorTheme.textTertiary
        ) {
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

    private var criticalNearbyPanel: some View {
        PanelCard(
            title: "Nearest Resources",
            subtitle: "Water first, then shelter and evacuation options",
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
                accent: ColorTheme.textTertiary,
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
                subtitle: "Essential layers first, support layers second.",
                accent: ColorTheme.textTertiary,
                isExpanded: $isShowingLayers
            ) {
                if !essentialLayers.isEmpty {
                    mapSectionLabel("Essential")
                    ForEach(essentialLayers) { layer in
                        layerToggleRow(layer)
                    }
                }

                if !supportLayers.isEmpty {
                    mapSectionLabel("Support")
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
                    accent: officialAlertToneColor(selectedOfficialAlertSummary.tone),
                    isExpanded: $isShowingOfficialAlerts
                ) {
                    officialAlertsContent
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

    private var officialAlertsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            PremiumSegmentedControl(items: officialAlertScopeOptions, selection: $selectedOfficialAlertScope)

            if selectedOfficialAlertScope == .state {
                officialAlertJurisdictionPicker
            }

            HStack(alignment: .top, spacing: 12) {
                RediIcon(selectedOfficialAlerts.first?.kind.systemImage ?? "warning")
                    .foregroundStyle(officialAlertToneColor(selectedOfficialAlertSummary.tone))
                    .frame(width: 18, height: 18)
                    .padding(10)
                    .background(
                        officialAlertToneColor(selectedOfficialAlertSummary.tone).opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("OFFICIAL ALERTS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(officialAlertToneColor(selectedOfficialAlertSummary.tone))
                    Text(selectedOfficialAlertSummary.title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text(selectedOfficialAlertSummary.detail)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textMuted)
                }

                Spacer(minLength: 0)
            }

            TrustPillGroup(items: viewModel.scopedOfficialAlertTrustItems(for: selectedOfficialAlertScope, jurisdiction: effectiveOfficialAlertJurisdiction))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    officialAlertMetaCard(
                        title: "Official Feed",
                        value: selectedOfficialAlerts.first?.issuer ?? "Cached mirror"
                    )
                    officialAlertMetaCard(
                        title: "Scope",
                        value: selectedOfficialAlertScope == .state
                            ? (effectiveOfficialAlertJurisdiction?.title ?? "Select a state")
                            : selectedOfficialAlertScope.title
                    )
                }

                VStack(spacing: 12) {
                    officialAlertMetaCard(
                        title: "Official Feed",
                        value: selectedOfficialAlerts.first?.issuer ?? "Cached mirror"
                    )
                    officialAlertMetaCard(
                        title: "Scope",
                        value: selectedOfficialAlertScope == .state
                            ? (effectiveOfficialAlertJurisdiction?.title ?? "Select a state")
                            : selectedOfficialAlertScope.title
                    )
                }
            }

            if let countSummary = viewModel.officialAlertCountSummary(
                for: selectedOfficialAlertScope,
                jurisdiction: effectiveOfficialAlertJurisdiction
            ) {
                Text(countSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if selectedOfficialAlerts.isEmpty {
                Text("No active alerts are currently listed for this scope.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(Array(selectedOfficialAlerts.prefix(4))) { alert in
                    officialAlertRow(alert, scope: selectedOfficialAlertScope)
                }
            }

            if selectedOfficialAlerts.count > 4 {
                Text("Showing the first 4 of \(selectedOfficialAlerts.count) alerts in this scope.")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)
            }

            Text("Official source labels remain separate from RediM8's readable summary so you can judge the warning against the issuing agency.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if selectedOfficialAlertScope == .local {
                Text("Switch to State or Australia when you need a wider family or travel view.")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STATE FEED")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ColorTheme.textMuted)
                    Text(effectiveOfficialAlertJurisdiction?.title ?? "Select a state or territory")
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.textMuted)
            }
            .padding(14)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func officialAlertMetaCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.textMuted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    private func inspectorGroup<Content: View>(
        title: String,
        subtitle: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
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

                if !beacon.signalHighlights.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(beacon.signalHighlights.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 8) {
                                Text(item.label)
                                    .font(RediTypography.caption)
                                    .foregroundStyle(ColorTheme.textFaint)
                                    .frame(width: 72, alignment: .leading)
                                Text(item.value)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(ColorTheme.text)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                Text(beacon.locationName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.textSecondary)
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

    private func officialAlertRow(_ alert: OfficialAlert, scope: MapOfficialAlertScope) -> some View {
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
                    Text("\(alert.severity.title) • \(viewModel.officialAlertScopeLine(for: alert, scope: scope))")
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

            Text(viewModel.officialAlertUpdatedLine(for: alert))
                .font(.caption)
                .foregroundStyle(ColorTheme.textMuted)

            Text(viewModel.officialAlertSafetyNote(for: alert))
                .font(.caption)
                .foregroundStyle(officialAlertToneColor(selectedOfficialAlertSummary.tone))

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

private struct MapNextAction {
    let title: String
    let detail: String
    let buttonTitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
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
        officialAlertToneColor(viewModel.officialAlertTone)
    }

    func officialAlertToneColor(_ tone: OperationalStatusTone) -> Color {
        switch tone {
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
                            .foregroundStyle(ColorTheme.textSecondary)
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
