import Combine
import CoreLocation
import Foundation
import MapKit
import SwiftUI

enum MapOfficialAlertScope: String, CaseIterable, Hashable, Identifiable {
    case local
    case state
    case australia

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local:
            "Local"
        case .state:
            "State"
        case .australia:
            "Australia"
        }
    }

    var detail: String {
        switch self {
        case .local:
            "Map match"
        case .state:
            "Jurisdiction feed"
        case .australia:
            "National view"
        }
    }

    var iconName: String {
        switch self {
        case .local:
            "map_marker"
        case .state:
            "map"
        case .australia:
            "warning"
        }
    }
}

struct MapOfficialAlertSummary: Equatable {
    let title: String
    let detail: String
    let tone: OperationalStatusTone
}

@MainActor
final class MapViewModel: ObservableObject {
    @Published private(set) var bundledResources: [ResourceMarker]
    @Published var userMarkers: [ResourceMarker]
    @Published var selectedMarkerKind: MarkerKind = .shelter
    @Published var markerTitle = ""
    @Published var viewportRegion: MKCoordinateRegion
    @Published var viewportRevision = 0
    @Published var lastUpdatedText: String
    @Published var resourceDataStatusMessage: String?
    @Published private(set) var nearbyBeacons: [CommunityBeacon] = []
    @Published private(set) var activeBeacon: CommunityBeacon?
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var heading: CLLocationDirection = 0
    @Published private(set) var selectedScenarios: [ScenarioKind]
    @Published private(set) var savedRoutes: [String]
    @Published private(set) var enabledLayers: Set<MapLayer>
    @Published private(set) var surfaceMode: MapSurfaceMode
    @Published private(set) var showsDistanceRings: Bool
    @Published private(set) var reducesMapAnimations: Bool
    @Published private(set) var isStealthModeEnabled: Bool
    @Published private(set) var availableLayers: [MapLayer]
    @Published var availablePacks: [OfflineMapPack]
    @Published var installedPackIDs: Set<String>
    @Published var dirtRoads: [TrackSegment] = []
    @Published var fireTrails: [TrackSegment] = []
    @Published var waterPoints: [WaterPoint] = []
    @Published var shelters: [ShelterLocation] = []
    @Published var selectedShelterID: String?
    @Published var nearbyOfficialAlerts: [OfficialAlert] = []
    @Published private(set) var basemapStyleURL: URL
    @Published private(set) var isPremiumBasemapActive: Bool
    @Published private(set) var hazardFeedLastSuccessfulFetch: Date?
    @Published private(set) var hazardFeedLastRefreshError: String?
    @Published private(set) var hazardFeedIsFetching: Bool
    @Published private(set) var lastError: AppError?
    @Published private(set) var systemState: SystemState = .healthy
    @Published var networkFallbackMessage: String?
    @Published var routeCompromisedWarning: String?
    @Published var selectedFeature: MapSelectedFeature?

    /// The surface mode the user chose before an automatic network fallback.
    /// When non-nil, the map auto-switched to tactical and will restore this mode when network returns.
    var preferredSurfaceModeBeforeFallback: MapSurfaceMode?

    let appState: AppState
    let officialAlertService: OfficialAlertService
    let hazardFeedService: HazardFeedService
    let mapService: MapService
    let mapDataService: MapDataService
    let offlineDataController: MapOfflineDataController
    let renderController: MapRenderController
    let waterPointService: WaterPointService
    let shelterService: ShelterService
    let beaconService: BeaconService
    let locationService: LocationService
    let disablesAutomaticRuntimeActivity: Bool
    let resourceCategoryIndex: [String: ResourceCategoryDefinition]
    let resourceDatasetLastUpdated: Date
    var offlineLayerLastUpdated: Date
    var offlineBasemapStatusMessage: String
    var offlineReloadGeneration = 0

    init(appState: AppState, disablesAutomaticRuntimeActivity: Bool = false) {
        self.appState = appState
        officialAlertService = appState.officialAlertService
        hazardFeedService = appState.hazardFeedService
        mapService = appState.mapService
        mapDataService = appState.mapDataService
        offlineDataController = MapOfflineDataController(mapDataService: appState.mapDataService)
        renderController = MapRenderController(mapService: appState.mapService)
        waterPointService = appState.waterPointService
        shelterService = appState.shelterService
        beaconService = appState.beaconService
        locationService = appState.locationService
        self.disablesAutomaticRuntimeActivity = disablesAutomaticRuntimeActivity
        resourceCategoryIndex = Dictionary(uniqueKeysWithValues: appState.mapService.resourceCategories.map { ($0.id, $0) })
        resourceDatasetLastUpdated = appState.mapService.lastUpdated
        offlineLayerLastUpdated = appState.mapDataService.lastUpdated
        let basemapConfiguration = appState.offlineBasemapService.configuration
        basemapStyleURL = basemapConfiguration.styleURL
        offlineBasemapStatusMessage = basemapConfiguration.statusMessage
        isPremiumBasemapActive = basemapConfiguration.isPremiumActive
        hazardFeedLastSuccessfulFetch = appState.hazardFeedService.lastSuccessfulFetch
        hazardFeedLastRefreshError = appState.hazardFeedService.lastRefreshError
        hazardFeedIsFetching = appState.hazardFeedService.isFetching
        bundledResources = appState.mapService.bundledResources
        userMarkers = appState.mapService.loadUserMarkers()
        viewportRegion = appState.mapService.fallbackRegion()
        selectedScenarios = appState.profile.selectedScenarios
        savedRoutes = appState.profile.evacuationRoutes.compactMap(\.nilIfBlank)
        enabledLayers = appState.settings.maps.defaultLayers
        surfaceMode = appState.settings.maps.surfaceMode
        showsDistanceRings = appState.settings.maps.showsDistanceRings
        isStealthModeEnabled = appState.isStealthModeEnabled
        reducesMapAnimations = appState.settings.battery.reducesMapAnimations || appState.isStealthModeEnabled
        availableLayers = Self.orderedLayers(for: appState.profile.selectedScenarios)
        availablePacks = appState.mapDataService.availablePacks
        installedPackIDs = appState.mapDataService.loadInstalledPackIDs()

        let latestOfflineDate = max(resourceDatasetLastUpdated, offlineLayerLastUpdated)
        let hasAnyOfflineData = appState.mapService.didLoadBundledResources || appState.mapDataService.didLoadOfflineData
        lastUpdatedText = hasAnyOfflineData ? DateFormatter.rediM8MonthYear.string(from: latestOfflineDate) : "Unavailable"
        resourceDataStatusMessage = appState.mapDataService.didLoadOfflineData ? nil : TrustLayer.mapDataUnavailableMessage
        reloadOfflineMapFeatures()
        reloadOfficialAlerts()

        beaconService.$nearbyBeacons
            .assign(to: &$nearbyBeacons)

        beaconService.$activeBeacon
            .assign(to: &$activeBeacon)

        locationService.$currentLocation
            .sink { [weak self] location in
                guard let self else { return }
                self.currentLocation = location
                self.reloadOfflineMapFeatures(useBackgroundQueue: true)
                self.reloadOfficialAlerts()
                guard let coordinate = location?.coordinate else {
                    return
                }
                guard !self.disablesAutomaticRuntimeActivity else {
                    return
                }
                Task { @MainActor [weak self] in
                    await self?.refreshNearbyNetworkResources(near: coordinate)
                    self?.recalculateSystemState()
                }
            }
            .store(in: &cancellables)

        locationService.$heading
            .assign(to: &$heading)

        appState.$profile
            .sink { [weak self] profile in
                self?.selectedScenarios = profile.selectedScenarios
                self?.savedRoutes = profile.evacuationRoutes.compactMap(\.nilIfBlank)
                self?.availableLayers = Self.orderedLayers(for: profile.selectedScenarios)
            }
            .store(in: &cancellables)

        appState.$settings
            .sink { [weak self] settings in
                guard let self else { return }
                self.enabledLayers = settings.maps.defaultLayers
                self.surfaceMode = settings.maps.surfaceMode
                self.showsDistanceRings = settings.maps.showsDistanceRings
                self.reducesMapAnimations = settings.battery.reducesMapAnimations || self.isStealthModeEnabled
                if !settings.maps.defaultLayers.contains(.evacuationPoints) {
                    self.selectedShelterID = nil
                }
            }
            .store(in: &cancellables)

        appState.$isStealthModeEnabled
            .sink { [weak self] isEnabled in
                guard let self else { return }
                self.isStealthModeEnabled = isEnabled
                self.reducesMapAnimations = self.appState.settings.battery.reducesMapAnimations || isEnabled
            }
            .store(in: &cancellables)

        officialAlertService.$library
            .sink { [weak self] _ in
                self?.reloadOfficialAlerts()
            }
            .store(in: &cancellables)

        officialAlertService.$lastRefreshError
            .sink { [weak self] _ in
                self?.reloadOfficialAlerts()
            }
            .store(in: &cancellables)

        hazardFeedService.$lastSuccessfulFetch
            .assign(to: &$hazardFeedLastSuccessfulFetch)

        hazardFeedService.$lastRefreshError
            .assign(to: &$hazardFeedLastRefreshError)

        hazardFeedService.$isFetching
            .assign(to: &$hazardFeedIsFetching)

        appState.offlineBasemapService.$configuration
            .sink { [weak self] configuration in
                guard let self else { return }
                self.basemapStyleURL = configuration.styleURL
                self.isPremiumBasemapActive = configuration.isPremiumActive
                self.offlineBasemapStatusMessage = configuration.statusMessage
            }
            .store(in: &cancellables)

        appState.$isNetworkOffline
            .removeDuplicates()
            .sink { [weak self] isOffline in
                guard let self else { return }
                self.handleNetworkStatusChange(isOffline: isOffline)
            }
            .store(in: &cancellables)

        appState.hazardIntelligenceService.$reports
            .sink { [weak self] _ in
                self?.checkRouteCompromised()
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
    var isVisible = false

    // MARK: - Lifecycle

    func onAppear() {
        let startTime = CFAbsoluteTimeGetCurrent()
        isVisible = true
        recenter(requestAccessIfNeeded: false)
        guard !disablesAutomaticRuntimeActivity else {
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            RediLogger.performance.debug("Map screen activation prepared in \(elapsed, privacy: .public) ms")
            return
        }
        syncCommunityMonitoring()
        locationService.start(requestAccess: false)
        Task { @MainActor [weak self] in
            await self?.officialAlertService.refreshIfNeeded()
            self?.recalculateSystemState()
        }
        let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        RediLogger.performance.debug("Map screen activation prepared in \(elapsed, privacy: .public) ms")
    }

    func onDisappear() {
        isVisible = false
        beaconService.stopMonitoring()
        locationService.stop()
    }

    func recalculateSystemState() {
        var reasons: [String] = []

        if let alertError = hazardFeedLastRefreshError {
            reasons.append("Hazard feed: \(alertError)")
        }
        if currentLocation == nil {
            reasons.append("Location unavailable")
        }
        if resourceDataStatusMessage != nil {
            reasons.append("Offline map data limited")
        }

        if reasons.isEmpty {
            systemState = .healthy
            lastError = nil
        } else {
            let combined = reasons.joined(separator: ". ")
            systemState = .degraded(reason: combined)
            lastError = .serviceUnavailable(service: combined)
        }
    }

    func recenter(requestAccessIfNeeded: Bool = true) {
        if requestAccessIfNeeded,
           locationService.currentLocation == nil,
           !locationService.authorizationStatus.isAuthorizedForRediM8 {
            locationService.requestAccess()
        }
        viewportRegion = renderController.preferredRegion(
            currentLocation: currentLocation,
            installedPacks: installedPacks
        )
        viewportRevision += 1
    }
}
