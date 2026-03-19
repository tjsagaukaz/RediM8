import Combine
import Foundation
import UIKit

enum EmergencyQuickAction: String, Equatable {
    case blackoutMode = "blackout_mode"
    case signalNearby = "signal_nearby"
    case emergencyGuides = "emergency_guides"
    case stealthMode = "stealth_mode"
    case flashlight = "flashlight"
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var profile: UserProfile
    @Published private(set) var settings: AppSettings
    @Published private(set) var prepScore: PrepScore
    @Published var isShowingOnboarding: Bool
    @Published private(set) var pendingQuickAction: EmergencyQuickAction?
    @Published private(set) var isEmergencyAccessActive = false
    @Published private(set) var batteryStatus: BatteryStatus
    @Published private(set) var shouldPromptForSurvivalMode: Bool
    @Published private(set) var isLowBatterySurvivalModeEnabled: Bool
    @Published private(set) var isStealthModeEnabled: Bool
    @Published private(set) var stealthNodeID: String
    @Published private(set) var activePrioritySituation: PrioritySituation?
    @Published private(set) var emergencyUnlockState: EmergencyUnlockState
    @Published private(set) var proEntitlement: ProEntitlement = .free

    var isProUser: Bool { proEntitlement.isPro }

    let featureFlags: AppFeatureFlags
    let permissionsManager: PermissionsManager
    let services: AppServices
    let preparedness: PreparednessSystem
    let signal: SignalSystem
    let map: MapSystem
    let vault: VaultSystem
    let power: PowerSystem

    private let store: SQLiteStore?
    private var cancellables = Set<AnyCancellable>()
    private var storedScreenBrightness: CGFloat?
    private var storedIdleTimerDisabled: Bool?
    private var hasStartedSystems = false

    convenience init() {
        self.init(environment: .live())
    }

    convenience init(store: SQLiteStore?) {
        self.init(environment: .testing(store: store))
    }

    init(environment: AppEnvironment) {
        let services = environment.makeServices()
        let loadedSettings: AppSettings
        let hasStoredSettings = services.settingsService.loadStoredSettings() != nil
        if let storedSettings = services.settingsService.loadStoredSettings() {
            loadedSettings = storedSettings
        } else {
            var defaultSettings = AppSettings.default
            defaultSettings.maps.defaultLayers = services.mapDataService.loadEnabledLayers()
            loadedSettings = defaultSettings
        }

        let preparednessSystem = PreparednessSystem(
            preparednessDataService: services.preparednessDataService,
            familyService: services.familyService,
            guideService: services.guideService,
            scenarioEngine: services.scenarioEngine,
            prepService: services.prepService,
            preparednessInsightsService: services.preparednessInsightsService,
            decisionSupportService: services.decisionSupportService,
            vehicleReadinessService: services.vehicleReadinessService,
            waterRuntimeService: services.waterRuntimeService,
            emergencyPlanService: services.emergencyPlanService,
            goBagService: services.goBagService,
            readinessReportService: services.readinessReportService
        )

        let signalSystem = SignalSystem(
            featureFlags: environment.featureFlags,
            meshService: services.meshService,
            beaconService: services.beaconService,
            locationService: services.locationService,
            torchService: services.torchService,
            motionService: services.motionService,
            initialSettings: loadedSettings
        )

        let mapSystem = MapSystem(
            offlineBasemapService: services.offlineBasemapService,
            officialAlertService: services.officialAlertService,
            mapService: services.mapService,
            mapDataService: services.mapDataService,
            waterPointService: services.waterPointService,
            fireTrailService: services.fireTrailService,
            shelterService: services.shelterService,
            tileCacheService: services.tileCacheService,
            offlineRoutingService: services.offlineRoutingService,
            hazardIntelligenceService: services.hazardIntelligenceService,
            hazardFeedService: services.hazardFeedService,
            nearestResourceService: services.nearestResourceService,
            safeZoneService: services.safeZoneService,
            predictiveCollapseService: services.predictiveCollapseService,
            autoGuidanceService: services.autoGuidanceService,
            locationService: services.locationService
        )

        let vaultSystem = VaultSystem(documentVaultService: services.documentVaultService)
        let powerSystem = PowerSystem(
            featureFlags: environment.featureFlags,
            batteryService: services.batteryService,
            torchService: services.torchService,
            initialSettings: loadedSettings.battery
        )

        store = environment.store
        featureFlags = environment.featureFlags
        permissionsManager = environment.permissionsManager
        self.services = services
        preparedness = preparednessSystem
        signal = signalSystem
        map = mapSystem
        vault = vaultSystem
        power = powerSystem

        profile = preparednessSystem.profile
        settings = loadedSettings
        prepScore = preparednessSystem.prepScore
        isShowingOnboarding = !preparednessSystem.profile.isOnboardingComplete
        pendingQuickAction = nil
        batteryStatus = powerSystem.batteryStatus
        shouldPromptForSurvivalMode = powerSystem.shouldPromptForSurvivalMode
        isLowBatterySurvivalModeEnabled = powerSystem.isLowBatterySurvivalModeEnabled
        isStealthModeEnabled = signalSystem.isStealthModeEnabled
        stealthNodeID = signalSystem.stealthNodeID
        activePrioritySituation = preparednessSystem.activePrioritySituation
        emergencyUnlockState = mapSystem.emergencyUnlockState

        bindSystems()
        applySettings(loadedSettings, persist: !hasStoredSettings)
    }

    func applyProfile(_ profile: UserProfile) {
        preparedness.applyProfile(profile)
    }

    func applySettings(_ settings: AppSettings, persist: Bool = true) {
        self.settings = settings
        if persist {
            settingsService.saveSettings(settings)
        }

        signal.updateSettings(settings)
        map.updateSettings(settings)
        power.updateSettings(settings.battery)
    }

    func mutateProfile(_ update: (inout UserProfile) -> Void) {
        preparedness.mutateProfile(update)
    }

    func mutateSettings(_ update: (inout AppSettings) -> Void) {
        var draft = settings
        update(&draft)
        applySettings(draft)
    }

    func completeOnboarding(with profile: UserProfile) {
        let completedProfile = profile.markedOnboarded()
        applyProfile(completedProfile)
        if completedProfile.isBushfireModeEnabled {
            mutateSettings { settings in
                settings.maps.defaultLayers.formUnion([.waterPoints, .evacuationPoints])
            }
        }
        isShowingOnboarding = false
    }

    func openOnboarding() {
        isShowingOnboarding = true
    }

    func refreshScore() {
        preparedness.refreshScore()
    }

    func startIfNeeded() {
        guard !hasStartedSystems else { return }
        hasStartedSystems = true
        startSystems()
    }

    func setMapLayer(_ layer: MapLayer, isEnabled: Bool) {
        mutateSettings { settings in
            if isEnabled {
                settings.maps.defaultLayers.insert(layer)
            } else {
                settings.maps.defaultLayers.remove(layer)
            }
        }
    }

    @discardableResult
    func handleShortcut(type: String) -> Bool {
        guard let action = EmergencyQuickAction(rawValue: type) else {
            return false
        }
        guard action != .stealthMode || featureFlags.enablesStealthMode else {
            return false
        }

        beginEmergencyAccessSession()
        pendingQuickAction = action

        if action == .flashlight {
            torchService.setTorch(on: true)
        }

        return true
    }

    func consumePendingQuickAction() -> EmergencyQuickAction? {
        let action = pendingQuickAction
        pendingQuickAction = nil
        return action
    }

    func beginEmergencyAccessSession() {
        if !isEmergencyAccessActive {
            activateEmergencyDevicePresentation()
        }
        isEmergencyAccessActive = true
    }

    func endEmergencyAccessSession() {
        isEmergencyAccessActive = false
        deactivateEmergencyDevicePresentation()
    }

    func enableLowBatterySurvivalMode() {
        let wasEnabled = power.isLowBatterySurvivalModeEnabled
        power.enableLowBatterySurvivalMode()
        if !wasEnabled, power.isLowBatterySurvivalModeEnabled {
            beginEmergencyAccessSession()
        }
    }

    func disableLowBatterySurvivalMode() {
        power.disableLowBatterySurvivalMode()
        if !power.shouldPromptForSurvivalMode {
            endEmergencyAccessSession()
        }
    }

    func dismissSurvivalModePrompt() {
        power.dismissSurvivalModePrompt()
    }

    func applyBatteryStatus(_ status: BatteryStatus) {
        batteryService.simulate(status: status)
    }

    func enableStealthMode() {
        signal.enableStealthMode()
    }

    func disableStealthMode() {
        signal.disableStealthMode()
    }

    func toggleStealthMode() {
        signal.toggleStealthMode()
    }

    func activatePriorityMode(for situation: PrioritySituation) {
        preparedness.activatePriorityMode(for: situation)
    }

    func clearPriorityMode() {
        preparedness.clearPriorityMode()
    }

    func togglePriorityMode(for situation: PrioritySituation) {
        preparedness.togglePriorityMode(for: situation)
    }

    @discardableResult
    func resetLocalNodeID() -> String {
        signal.resetLocalNodeID()
    }

    func clearCachedData() {
        signal.clearCachedData()
    }

    func currentReadinessReport() -> ReadinessReport {
        preparedness.currentReadinessReport()
    }

    var stealthModeNodeLabel: String {
        signal.stealthModeNodeLabel
    }

    func exportPreparednessReport() throws -> URL {
        try preparedness.exportPreparednessReport()
    }

    private func bindSystems() {
        preparedness.$profile
            .sink { [weak self] profile in
                self?.profile = profile
            }
            .store(in: &cancellables)

        preparedness.$prepScore
            .sink { [weak self] prepScore in
                self?.prepScore = prepScore
            }
            .store(in: &cancellables)

        preparedness.$activePrioritySituation
            .sink { [weak self] situation in
                self?.activePrioritySituation = situation
            }
            .store(in: &cancellables)

        signal.$isStealthModeEnabled
            .sink { [weak self] isEnabled in
                self?.isStealthModeEnabled = isEnabled
            }
            .store(in: &cancellables)

        signal.$stealthNodeID
            .sink { [weak self] nodeID in
                self?.stealthNodeID = nodeID
            }
            .store(in: &cancellables)

        map.$emergencyUnlockState
            .sink { [weak self] state in
                self?.emergencyUnlockState = state
                if state.isActive {
                    self?.services.storeKitService.applyEmergencyUnlock()
                } else if !state.isActive {
                    self?.services.storeKitService.clearEmergencyUnlock()
                }
            }
            .store(in: &cancellables)

        power.$batteryStatus
            .sink { [weak self] status in
                self?.batteryStatus = status
            }
            .store(in: &cancellables)

        power.$shouldPromptForSurvivalMode
            .sink { [weak self] shouldPrompt in
                self?.shouldPromptForSurvivalMode = shouldPrompt
            }
            .store(in: &cancellables)

        power.$isLowBatterySurvivalModeEnabled
            .sink { [weak self] isEnabled in
                self?.isLowBatterySurvivalModeEnabled = isEnabled
            }
            .store(in: &cancellables)

        services.storeKitService.$entitlement
            .sink { [weak self] entitlement in
                self?.proEntitlement = entitlement
            }
            .store(in: &cancellables)
    }

    private func startSystems() {
        let systems: [any AppSystem] = [preparedness, signal, map, vault, power]
        systems.forEach { $0.start() }

        Task { [weak self] in
            await self?.services.storeKitService.loadProducts()
            await self?.services.storeKitService.refreshEntitlement()
        }
    }

    private func activateEmergencyDevicePresentation() {
        let application = UIApplication.shared

        if storedIdleTimerDisabled == nil {
            storedIdleTimerDisabled = application.isIdleTimerDisabled
        }

        application.isIdleTimerDisabled = true

        let currentBrightness = UIScreen.main.brightness
        if storedScreenBrightness == nil {
            storedScreenBrightness = currentBrightness
        }

        UIScreen.main.brightness = max(currentBrightness, 0.92)
    }

    private func deactivateEmergencyDevicePresentation() {
        let application = UIApplication.shared

        if let storedIdleTimerDisabled {
            application.isIdleTimerDisabled = storedIdleTimerDisabled
            self.storedIdleTimerDisabled = nil
        } else {
            application.isIdleTimerDisabled = false
        }

        if let storedScreenBrightness {
            UIScreen.main.brightness = storedScreenBrightness
            self.storedScreenBrightness = nil
        }
    }
}
