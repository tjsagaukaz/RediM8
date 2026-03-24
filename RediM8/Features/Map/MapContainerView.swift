import SwiftUI

struct MapContainerView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: MapViewModel
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

    init(
        viewModel: MapViewModel,
        appState: AppState,
        scrollToTopRequestID: Int = 0,
        openEvacuationRoutes: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.appState = appState
        self.scrollToTopRequestID = scrollToTopRequestID
        self.openEvacuationRoutes = openEvacuationRoutes
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // MARK: Pinned map surface — always visible, top ~48% of screen
                pinnedMapSurface(height: geometry.size.height * 0.48)

                // MARK: Scrollable controls and data below the map
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Color.clear
                                .frame(height: 0)
                                .id(MapScrollAnchor.top)

                            if viewModel.isStealthModeEnabled {
                                StealthModeIndicatorView()
                            }

                            MapNextActionPanelView(recommendation: nextActionRecommendation)

                            if let hazardError = viewModel.hazardFeedLastRefreshError {
                                OfflineFallbackBanner(reason: hazardError)
                            }

                            if let feature = viewModel.selectedFeature {
                                MapFeatureDetailSheet(
                                    feature: feature,
                                    currentLocation: viewModel.currentLocation,
                                    onDismiss: { viewModel.selectFeature(nil) }
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .animation(.easeInOut(duration: 0.25), value: viewModel.selectedFeature?.id)
                            }

                            mapControlsSection

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

                            MapInspectorSectionsView(
                                viewModel: viewModel,
                                mapFailureRows: mapFailureRows,
                                openEvacuationRoutes: openEvacuationRoutes,
                                isShowingMapBrief: $isShowingMapBrief,
                                isShowingRouteInspector: $isShowingRouteInspector,
                                selectedOfficialAlertScope: $selectedOfficialAlertScope,
                                selectedOfficialAlertJurisdiction: $selectedOfficialAlertJurisdiction
                            )

                            if !appState.isElevatedThreat {
                                MapAdvancedSectionsView(
                                    viewModel: viewModel,
                                    isShowingMapPacks: $isShowingMapPacks,
                                    isShowingLayers: $isShowingLayers,
                                    isShowingLegend: $isShowingLegend,
                                    isShowingEvacuationPoints: $isShowingEvacuationPoints,
                                    isShowingWaterPoints: $isShowingWaterPoints,
                                    isShowingDirtRoads: $isShowingDirtRoads,
                                    isShowingFireTrails: $isShowingFireTrails,
                                    isShowingOfficialAlerts: $isShowingOfficialAlerts,
                                    isShowingBeacons: $isShowingBeacons,
                                    isShowingMarkers: $isShowingMarkers,
                                    isShowingResources: $isShowingResources,
                                    selectedOfficialAlertScope: $selectedOfficialAlertScope,
                                    selectedOfficialAlertJurisdiction: $selectedOfficialAlertJurisdiction
                                )
                            }
                        }
                        .padding(.horizontal, RediSpacing.screen)
                        .padding(.top, 10)
                        .padding(.bottom, RediLayout.commandDockContentInset)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: scrollToTopRequestID) { _, _ in
                        DispatchQueue.main.async {
                            withAnimation(RediMotion.selection) {
                                proxy.scrollTo(MapScrollAnchor.top, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("map.root")
        .navigationTitle("Map")
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
            MapFullScreenSurfaceView(
                viewModel: viewModel,
                isPresented: $isShowingFullScreenMap,
                isShowingMapPacks: $isShowingMapPacks
            )
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

    // MARK: - Pinned Map Surface

    private func pinnedMapSurface(height: CGFloat) -> some View {
        MapSurfaceCanvasView(viewModel: viewModel)
            .frame(height: height)
            .clipped()
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
                            .padding(10)
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
                Button {
                    viewModel.recenter()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(viewModel.currentLocation != nil ? ColorTheme.accent : ColorTheme.textTertiary)
                        .padding(10)
                        .background(Color.black.opacity(0.86), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .padding(12)
            }
            .overlay(alignment: .top) {
                if let fallbackMessage = viewModel.networkFallbackMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.caption2.weight(.bold))
                        Text(fallbackMessage)
                            .font(RediTypography.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ColorTheme.warning.opacity(0.92), in: Capsule())
                    .padding(.top, 48)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.networkFallbackMessage != nil)
                }
            }
    }

    // MARK: - Map Controls (Below Pinned Map)

    private var mapControlsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MapOperationalSurfaceSection(
                viewModel: viewModel,
                appState: appState,
                officialAlertColor: officialAlertColor,
                mapFailureRows: mapFailureRows,
                surfaceMode: surfaceModeBinding,
                isShowingLayers: $isShowingLayers,
                isShowingMapBrief: $isShowingMapBrief,
                isShowingRouteInspector: $isShowingRouteInspector,
                isShowingNearestResource: $isShowingNearestResource,
                isShowingRoutePlanner: $isShowingRoutePlanner,
                isShowingEvacuationPlan: $isShowingEvacuationPlan
            )
        }
    }

    private enum MapScrollAnchor {
        static let top = "map-scroll-top"
    }

    private var surfaceModeBinding: Binding<MapSurfaceMode> {
        Binding(
            get: { viewModel.surfaceMode },
            set: { viewModel.setSurfaceMode($0) }
        )
    }

    private var officialAlertColor: Color {
        MapTonePalette.color(for: viewModel.officialAlertTone)
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
}
