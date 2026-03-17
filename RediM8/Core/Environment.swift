import Foundation

@MainActor
struct AppServices {
    let assistantService: AssistantService
    let assistantIntentClassifier: AssistantIntentClassifier
    let assistantModel: OfflineAssistantModel
    let offlineBasemapService: OfflineBasemapService
    let officialAlertService: OfficialAlertService
    let documentVaultService: DocumentVaultService
    let preparednessDataService: PreparednessDataService
    let settingsService: SettingsService
    let familyService: FamilyService
    let guideService: GuideService
    let scenarioEngine: ScenarioEngine
    let prepService: PrepService
    let preparednessInsightsService: PreparednessInsightsService
    let decisionSupportService: DecisionSupportService
    let vehicleReadinessService: VehicleReadinessService
    let waterRuntimeService: WaterRuntimeService
    let emergencyPlanService: EmergencyPlanService
    let goBagService: GoBagService
    let readinessReportService: ReadinessReportService
    let beaconService: BeaconService
    let mapService: MapService
    let mapDataService: MapDataService
    let waterPointService: WaterPointService
    let fireTrailService: FireTrailService
    let shelterService: ShelterService
    let batteryService: BatteryService
    let meshService: MeshService
    let locationService: LocationService
    let torchService: TorchService
    let motionService: MotionService
    let tileCacheService: TileCacheService
    let offlineRoutingService: OfflineRoutingService
    let hazardIntelligenceService: HazardIntelligenceService
    let hazardFeedService: HazardFeedService
    let nearestResourceService: NearestResourceService
    let safeZoneService: SafeZoneService
}

@MainActor
struct AppEnvironment {
    let store: SQLiteStore?
    let featureFlags: AppFeatureFlags
    let permissionsManager: PermissionsManager
    let bundle: Bundle
    let notificationCenter: NotificationCenter

    static func live(
        store: SQLiteStore? = nil,
        featureFlags: AppFeatureFlags = .live,
        permissionsManager: PermissionsManager = .live,
        bundle: Bundle = .main,
        notificationCenter: NotificationCenter = .default
    ) -> AppEnvironment {
        let resolvedStore: SQLiteStore?
        if let store {
            resolvedStore = store
        } else if featureFlags.usesPersistentSQLiteStorage {
            do {
                resolvedStore = try SQLiteStore(filename: AppConstants.Storage.databaseFilename)
            } catch {
                #if DEBUG
                print("[AppEnvironment] Failed to initialise SQLite store: \(error)")
                #endif
                resolvedStore = nil
            }
        } else {
            resolvedStore = nil
        }
        return AppEnvironment(
            store: resolvedStore,
            featureFlags: featureFlags,
            permissionsManager: permissionsManager,
            bundle: bundle,
            notificationCenter: notificationCenter
        )
    }

    static func testing(
        store: SQLiteStore?,
        featureFlags: AppFeatureFlags = .testing,
        permissionsManager: PermissionsManager = .live,
        bundle: Bundle = .main,
        notificationCenter: NotificationCenter = .default
    ) -> AppEnvironment {
        AppEnvironment(
            store: store,
            featureFlags: featureFlags,
            permissionsManager: permissionsManager,
            bundle: bundle,
            notificationCenter: notificationCenter
        )
    }

    func makeServices() -> AppServices {
        let offlineBasemapService = OfflineBasemapService(bundle: bundle)
        let officialAlertService = OfficialAlertService(store: store)
        let documentVaultService = DocumentVaultService()
        let preparednessDataService = PreparednessDataService(store: store, bundle: bundle)
        let settingsService = SettingsService(store: store)
        let familyService = FamilyService(store: store)
        let guideService = GuideService(dataService: preparednessDataService)
        let assistantIntentClassifier = AssistantIntentClassifier(dataService: preparednessDataService, guideService: guideService)
        let assistantModel = OfflineAssistantModel(bundle: bundle)
        let assistantSafetyFilter = AssistantSafetyFilter()
        let guideSummarizer = GuideSummarizer()
        let assistantAnswerComposer = AssistantAnswerComposer(summarizer: guideSummarizer)
        let scenarioEngine = ScenarioEngine(dataService: preparednessDataService)
        let prepService = PrepService()
        let preparednessInsightsService = PreparednessInsightsService()
        let decisionSupportService = DecisionSupportService()
        let vehicleReadinessService = VehicleReadinessService(store: store)
        let waterRuntimeService = WaterRuntimeService(prepService: prepService)
        let meshService = MeshService()
        let locationService = LocationService(permissionsManager: permissionsManager)
        let batteryService = BatteryService(notificationCenter: notificationCenter)
        let waterPointService = WaterPointService(bundle: bundle)
        let fireTrailService = FireTrailService(bundle: bundle)
        let shelterService = ShelterService(bundle: bundle)
        let mapService = MapService(store: store, preparednessDataService: preparednessDataService, bundle: bundle)
        let mapDataService = MapDataService(
            store: store,
            bundle: bundle,
            waterPointService: waterPointService,
            fireTrailService: fireTrailService,
            shelterService: shelterService
        )
        let beaconService = BeaconService(meshService: meshService, locationService: locationService, store: store)
        let assistantContextEnricher = AssistantContextEnricher(
            waterPointService: waterPointService,
            shelterService: shelterService,
            fireTrailService: fireTrailService,
            officialAlertService: officialAlertService,
            beaconService: beaconService,
            mapDataService: mapDataService,
            locationProvider: { locationService.currentLocation }
        )
        let assistantService = AssistantService(
            classifier: assistantIntentClassifier,
            guideService: guideService,
            composer: assistantAnswerComposer,
            assistantModel: assistantModel,
            safetyFilter: assistantSafetyFilter,
            contextProvider: assistantContextEnricher
        )
        let emergencyPlanService = EmergencyPlanService(
            dataService: preparednessDataService,
            scenarioEngine: scenarioEngine,
            store: store
        )
        let goBagService = GoBagService(
            dataService: preparednessDataService,
            scenarioEngine: scenarioEngine,
            emergencyPlanService: emergencyPlanService,
            store: store
        )
        let readinessReportService = ReadinessReportService(
            prepService: prepService,
            scenarioEngine: scenarioEngine,
            emergencyPlanService: emergencyPlanService,
            goBagService: goBagService
        )
        let tileCacheService = TileCacheService()
        let offlineRoutingService = OfflineRoutingService()
        let hazardIntelligenceService = HazardIntelligenceService(store: store)
        let hazardFeedService = HazardFeedService()
        let nearestResourceService = NearestResourceService(
            waterPointService: waterPointService,
            shelterService: shelterService,
            mapService: mapService,
            mapDataService: mapDataService
        )
        let safeZoneService = SafeZoneService(
            nearestResourceService: nearestResourceService,
            offlineRoutingService: offlineRoutingService,
            hazardIntelligenceService: hazardIntelligenceService,
            shelterService: shelterService,
            installedPackIDs: { [weak mapDataService] in
                mapDataService?.loadInstalledPackIDs() ?? []
            }
        )
        let torchService = TorchService()
        let motionService = MotionService(
            permissionsManager: permissionsManager,
            isEnabled: featureFlags.enablesMotionFeatures
        )

        return AppServices(
            assistantService: assistantService,
            assistantIntentClassifier: assistantIntentClassifier,
            assistantModel: assistantModel,
            offlineBasemapService: offlineBasemapService,
            officialAlertService: officialAlertService,
            documentVaultService: documentVaultService,
            preparednessDataService: preparednessDataService,
            settingsService: settingsService,
            familyService: familyService,
            guideService: guideService,
            scenarioEngine: scenarioEngine,
            prepService: prepService,
            preparednessInsightsService: preparednessInsightsService,
            decisionSupportService: decisionSupportService,
            vehicleReadinessService: vehicleReadinessService,
            waterRuntimeService: waterRuntimeService,
            emergencyPlanService: emergencyPlanService,
            goBagService: goBagService,
            readinessReportService: readinessReportService,
            beaconService: beaconService,
            mapService: mapService,
            mapDataService: mapDataService,
            waterPointService: waterPointService,
            fireTrailService: fireTrailService,
            shelterService: shelterService,
            batteryService: batteryService,
            meshService: meshService,
            locationService: locationService,
            torchService: torchService,
            motionService: motionService,
            tileCacheService: tileCacheService,
            offlineRoutingService: offlineRoutingService,
            hazardIntelligenceService: hazardIntelligenceService,
            hazardFeedService: hazardFeedService,
            nearestResourceService: nearestResourceService,
            safeZoneService: safeZoneService
        )
    }
}
