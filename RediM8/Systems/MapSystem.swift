import Combine
import CoreLocation
import Foundation

@MainActor
final class MapSystem: ObservableObject, AppSystem {
    private enum EmergencyUnlockPolicy {
        static let recentlyEndedVisibility: TimeInterval = 12 * 60 * 60
    }

    @Published private(set) var emergencyUnlockState: EmergencyUnlockState = .inactive

    let offlineBasemapService: OfflineBasemapService
    let officialAlertService: OfficialAlertService
    let mapService: MapService
    let mapDataService: MapDataService
    let waterPointService: WaterPointService
    let fireTrailService: FireTrailService
    let shelterService: ShelterService
    let tileCacheService: TileCacheService
    let offlineRoutingService: OfflineRoutingService
    let hazardIntelligenceService: HazardIntelligenceService
    let hazardFeedService: HazardFeedService
    let nearestResourceService: NearestResourceService
    let safeZoneService: SafeZoneService
    let predictiveCollapseService: PredictiveCollapseService
    let autoGuidanceService: AutoGuidanceService

    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()

    init(
        offlineBasemapService: OfflineBasemapService,
        officialAlertService: OfficialAlertService,
        mapService: MapService,
        mapDataService: MapDataService,
        waterPointService: WaterPointService,
        fireTrailService: FireTrailService,
        shelterService: ShelterService,
        tileCacheService: TileCacheService,
        offlineRoutingService: OfflineRoutingService,
        hazardIntelligenceService: HazardIntelligenceService,
        hazardFeedService: HazardFeedService,
        nearestResourceService: NearestResourceService,
        safeZoneService: SafeZoneService,
        predictiveCollapseService: PredictiveCollapseService,
        autoGuidanceService: AutoGuidanceService,
        locationService: LocationService
    ) {
        self.offlineBasemapService = offlineBasemapService
        self.officialAlertService = officialAlertService
        self.mapService = mapService
        self.mapDataService = mapDataService
        self.waterPointService = waterPointService
        self.fireTrailService = fireTrailService
        self.shelterService = shelterService
        self.tileCacheService = tileCacheService
        self.offlineRoutingService = offlineRoutingService
        self.hazardIntelligenceService = hazardIntelligenceService
        self.hazardFeedService = hazardFeedService
        self.nearestResourceService = nearestResourceService
        self.safeZoneService = safeZoneService
        self.predictiveCollapseService = predictiveCollapseService
        self.autoGuidanceService = autoGuidanceService
        self.locationService = locationService

        officialAlertService.$library
            .sink { [weak self] _ in
                self?.refreshEmergencyUnlockState()
            }
            .store(in: &cancellables)

        officialAlertService.$lastRefreshError
            .sink { [weak self] _ in
                self?.refreshEmergencyUnlockState()
            }
            .store(in: &cancellables)

        locationService.$currentLocation
            .sink { [weak self] _ in
                self?.refreshEmergencyUnlockState()
            }
            .store(in: &cancellables)

        refreshEmergencyUnlockState()
    }

    func start() {
        refreshEmergencyUnlockState()
        hazardIntelligenceService.startMonitoring()
        hazardFeedService.startPeriodicFetch(into: hazardIntelligenceService)
    }

    func stop() {
        hazardIntelligenceService.stopMonitoring()
        hazardFeedService.stopPeriodicFetch()
    }

    func updateSettings(_ settings: AppSettings) {
        mapDataService.saveEnabledLayers(settings.maps.defaultLayers)
    }

    private func refreshEmergencyUnlockState(referenceDate: Date = .now) {
        let installedPackIDs = mapDataService.loadInstalledPackIDs()
        let installedPacks = mapDataService.packs(withIDs: installedPackIDs)
        let unlockedFeatureIDs = RediM8MonetizationCatalog.launch.emergencyUnlockFeatureIDs

        if let triggerAlert = officialAlertService.safeModeAlert(
            currentLocation: locationService.currentLocation,
            installedPacks: installedPacks
        ) {
            let activationDate: Date
            if emergencyUnlockState.isActive,
               emergencyUnlockState.triggerAlert?.id == triggerAlert.id,
               let existingActivation = emergencyUnlockState.activatedAt {
                activationDate = existingActivation
            } else {
                activationDate = referenceDate
            }

            emergencyUnlockState = .active(
                alert: triggerAlert,
                activatedAt: activationDate,
                accessEndsAt: triggerAlert.expiresAt,
                unlockedFeatureIDs: unlockedFeatureIDs
            )
            return
        }

        if emergencyUnlockState.isActive {
            emergencyUnlockState = .recentlyEnded(
                triggerAlert: emergencyUnlockState.triggerAlert,
                activatedAt: emergencyUnlockState.activatedAt,
                endedAt: referenceDate,
                unlockedFeatureIDs: unlockedFeatureIDs
            )
            return
        }

        if emergencyUnlockState.isRecentlyEnded,
           let endedAt = emergencyUnlockState.endedAt,
           referenceDate.timeIntervalSince(endedAt) <= EmergencyUnlockPolicy.recentlyEndedVisibility {
            return
        }

        emergencyUnlockState = .inactive
    }
}
