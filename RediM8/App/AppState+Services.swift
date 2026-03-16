import Foundation

extension AppState {
    var assistant: AssistantService { services.assistantService }
    var assistantIntentClassifier: AssistantIntentClassifier { services.assistantIntentClassifier }
    var assistantModel: OfflineAssistantModel { services.assistantModel }
    var offlineBasemapService: OfflineBasemapService { map.offlineBasemapService }
    var officialAlertService: OfficialAlertService { map.officialAlertService }
    var documentVaultService: DocumentVaultService { vault.documentVaultService }
    var preparednessDataService: PreparednessDataService { preparedness.preparednessDataService }
    var settingsService: SettingsService { services.settingsService }
    var familyService: FamilyService { preparedness.familyService }
    var guideService: GuideService { preparedness.guideService }
    var scenarioEngine: ScenarioEngine { preparedness.scenarioEngine }
    var prepService: PrepService { preparedness.prepService }
    var preparednessInsightsService: PreparednessInsightsService { preparedness.preparednessInsightsService }
    var decisionSupportService: DecisionSupportService { preparedness.decisionSupportService }
    var vehicleReadinessService: VehicleReadinessService { preparedness.vehicleReadinessService }
    var waterRuntimeService: WaterRuntimeService { preparedness.waterRuntimeService }
    var emergencyPlanService: EmergencyPlanService { preparedness.emergencyPlanService }
    var goBagService: GoBagService { preparedness.goBagService }
    var readinessReportService: ReadinessReportService { preparedness.readinessReportService }
    var beaconService: BeaconService { signal.beaconService }
    var mapService: MapService { map.mapService }
    var mapDataService: MapDataService { map.mapDataService }
    var waterPointService: WaterPointService { map.waterPointService }
    var fireTrailService: FireTrailService { map.fireTrailService }
    var shelterService: ShelterService { map.shelterService }
    var batteryService: BatteryService { power.batteryService }
    var meshService: MeshService { signal.meshService }
    var locationService: LocationService { signal.locationService }
    var torchService: TorchService { signal.torchService }
    var motionService: MotionService { signal.motionService }
    var tileCacheService: TileCacheService { map.tileCacheService }
    var offlineRoutingService: OfflineRoutingService { map.offlineRoutingService }
}
