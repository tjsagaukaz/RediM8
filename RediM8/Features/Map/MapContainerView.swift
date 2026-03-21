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

                    MapNextActionPanelView(recommendation: nextActionRecommendation)

                    MapStatusBannerView(
                        tone: MapTonePalette.color(for: viewModel.mapStatusTone),
                        headline: viewModel.mapStatusHeadline,
                        detail: viewModel.mapStatusDetail
                    )

                    MapOperationalSurfaceSection(
                        viewModel: viewModel,
                        appState: appState,
                        officialAlertColor: officialAlertColor,
                        mapFailureRows: mapFailureRows,
                        surfaceMode: surfaceModeBinding,
                        isShowingFullScreenMap: $isShowingFullScreenMap,
                        isShowingLayers: $isShowingLayers,
                        isShowingMapBrief: $isShowingMapBrief,
                        isShowingRouteInspector: $isShowingRouteInspector,
                        isShowingNearestResource: $isShowingNearestResource,
                        isShowingRoutePlanner: $isShowingRoutePlanner,
                        isShowingEvacuationPlan: $isShowingEvacuationPlan
                    )

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
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.screen)
                .padding(.bottom, RediLayout.commandDockContentInset)
            }
            .accessibilityIdentifier("map.root")
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
}
