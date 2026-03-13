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
    private enum EmergencyUnlockPolicy {
        static let recentlyEndedVisibility: TimeInterval = 12 * 60 * 60
    }

    @Published private(set) var profile: UserProfile
    @Published private(set) var settings: AppSettings
    @Published private(set) var prepScore: PrepScore
    @Published var isShowingOnboarding: Bool
    @Published private(set) var pendingQuickAction: EmergencyQuickAction?
    @Published private(set) var isEmergencyAccessActive = false
    @Published private(set) var batteryStatus: BatteryStatus
    @Published private(set) var shouldPromptForSurvivalMode = false
    @Published private(set) var isLowBatterySurvivalModeEnabled = false
    @Published private(set) var isStealthModeEnabled = false
    @Published private(set) var stealthNodeID = AppState.generateEphemeralNodeID()
    @Published private(set) var activePrioritySituation: PrioritySituation?
    @Published private(set) var emergencyUnlockState: EmergencyUnlockState = .inactive

    let assistantIntentClassifier: AssistantIntentClassifier
    let featureFlags: AppFeatureFlags
    let permissionsManager: PermissionsManager
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

    private let store: SQLiteStore?
    private var cancellables = Set<AnyCancellable>()
    private var deferredSurvivalPromptDismissal = false
    private var storedScreenBrightness: CGFloat?
    private var storedIdleTimerDisabled: Bool?

    convenience init() {
        self.init(environment: .live())
    }

    convenience init(store: SQLiteStore?) {
        self.init(environment: .testing(store: store))
    }

    init(environment: AppEnvironment) {
        let services = environment.makeServices()

        store = environment.store
        assistantIntentClassifier = services.assistantIntentClassifier
        featureFlags = environment.featureFlags
        permissionsManager = environment.permissionsManager
        offlineBasemapService = services.offlineBasemapService
        officialAlertService = services.officialAlertService
        documentVaultService = services.documentVaultService

        preparednessDataService = services.preparednessDataService
        settingsService = services.settingsService
        familyService = services.familyService
        guideService = services.guideService
        scenarioEngine = services.scenarioEngine
        prepService = services.prepService
        preparednessInsightsService = services.preparednessInsightsService
        decisionSupportService = services.decisionSupportService
        vehicleReadinessService = services.vehicleReadinessService
        waterRuntimeService = services.waterRuntimeService
        emergencyPlanService = services.emergencyPlanService
        goBagService = services.goBagService
        readinessReportService = services.readinessReportService
        beaconService = services.beaconService
        mapService = services.mapService
        mapDataService = services.mapDataService
        waterPointService = services.waterPointService
        fireTrailService = services.fireTrailService
        shelterService = services.shelterService
        batteryService = services.batteryService
        meshService = services.meshService
        locationService = services.locationService
        torchService = services.torchService
        motionService = services.motionService
        batteryStatus = services.batteryService.status

        let loadedProfile = familyService.loadProfile()
        profile = loadedProfile
        if let storedSettings = settingsService.loadStoredSettings() {
            settings = storedSettings
        } else {
            var defaultSettings = AppSettings.default
            defaultSettings.maps.defaultLayers = mapDataService.loadEnabledLayers()
            settings = defaultSettings
        }
        let scenarios = scenarioEngine.selectedScenarios(for: loadedProfile.selectedScenarios)
        prepScore = prepService.calculateScore(for: loadedProfile, scenarios: scenarios, engine: scenarioEngine)
        isShowingOnboarding = !loadedProfile.isOnboardingComplete

        synchronizeSettings(settings, persist: settingsService.loadStoredSettings() == nil)

        batteryService.$status
            .sink { [weak self] status in
                self?.applyBatteryStatus(status)
            }
            .store(in: &cancellables)

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

        applyBatteryStatus(batteryStatus)
        refreshEmergencyUnlockState()
    }

    func applyProfile(_ profile: UserProfile) {
        self.profile = profile
        familyService.saveProfile(profile)
        refreshScore()
    }

    func applySettings(_ settings: AppSettings, persist: Bool = true) {
        self.settings = settings
        synchronizeSettings(settings, persist: persist)
        applyBatteryStatus(batteryStatus)
    }

    func mutateProfile(_ update: (inout UserProfile) -> Void) {
        var draft = profile
        update(&draft)
        applyProfile(draft)
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
        let scenarios = scenarioEngine.selectedScenarios(for: profile.selectedScenarios)
        prepScore = prepService.calculateScore(for: profile, scenarios: scenarios, engine: scenarioEngine)
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
        guard featureFlags.enablesLowBatterySurvivalMode else {
            shouldPromptForSurvivalMode = false
            return
        }

        isLowBatterySurvivalModeEnabled = true
        shouldPromptForSurvivalMode = false
        deferredSurvivalPromptDismissal = true
        beginEmergencyAccessSession()
    }

    func disableLowBatterySurvivalMode() {
        isLowBatterySurvivalModeEnabled = false
        torchService.setTorch(on: false)
        if !shouldPromptForSurvivalMode {
            endEmergencyAccessSession()
        }
    }

    func dismissSurvivalModePrompt() {
        shouldPromptForSurvivalMode = false
        deferredSurvivalPromptDismissal = true
    }

    func enableStealthMode() {
        guard featureFlags.enablesStealthMode else { return }
        setStealthMode(true)
    }

    func disableStealthMode() {
        setStealthMode(false)
    }

    func toggleStealthMode() {
        if isStealthModeEnabled {
            setStealthMode(false)
        } else {
            enableStealthMode()
        }
    }

    func activatePriorityMode(for situation: PrioritySituation) {
        activePrioritySituation = situation
    }

    func clearPriorityMode() {
        activePrioritySituation = nil
    }

    func togglePriorityMode(for situation: PrioritySituation) {
        if activePrioritySituation == situation {
            clearPriorityMode()
        } else {
            activatePriorityMode(for: situation)
        }
    }

    @discardableResult
    func resetLocalNodeID() -> String {
        let nodeID = beaconService.resetLocalNodeID()
        synchronizeSettings(settings, persist: false)
        return nodeID
    }

    func clearCachedData() {
        meshService.clearSessionMessages()
        beaconService.clearNearbyBeaconsCache()
    }

    func currentReadinessReport() -> ReadinessReport {
        readinessReportService.generateReport(profile: profile, prepScore: prepScore)
    }

    var stealthModeNodeLabel: String {
        "Node \(stealthNodeID)"
    }

    func exportPreparednessReport() throws -> URL {
        try readinessReportService.savePDF(for: currentReadinessReport())
    }

    func applyBatteryStatus(_ status: BatteryStatus) {
        batteryStatus = status

        guard featureFlags.enablesLowBatterySurvivalMode else {
            shouldPromptForSurvivalMode = false
            deferredSurvivalPromptDismissal = false
            return
        }

        guard settings.battery.enablesSurvivalModeAtFifteenPercent else {
            shouldPromptForSurvivalMode = false
            deferredSurvivalPromptDismissal = false
            return
        }

        guard status.isBelowSurvivalThreshold else {
            shouldPromptForSurvivalMode = false
            deferredSurvivalPromptDismissal = false
            return
        }

        guard !isLowBatterySurvivalModeEnabled else {
            shouldPromptForSurvivalMode = false
            return
        }

        if !deferredSurvivalPromptDismissal {
            shouldPromptForSurvivalMode = true
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

    private func synchronizeSettings(_ settings: AppSettings, persist: Bool) {
        if persist {
            settingsService.saveSettings(settings)
        }

        mapDataService.saveEnabledLayers(settings.maps.defaultLayers)

        let effectiveRangeMode: SignalRangeMode = isStealthModeEnabled ? .lowPower : settings.signalDiscovery.rangeMode

        meshService.updateConfiguration(
            displayName: resolvedMeshDisplayName(for: settings),
            isBrowsingEnabled: settings.signalDiscovery.discoversNearbyUsers,
            isBroadcastingEnabled: !settings.privacy.isAnonymousModeEnabled && !isStealthModeEnabled,
            autoAcceptInvitations: settings.signalDiscovery.autoAcceptsMessages,
            locationShareMode: settings.privacy.locationShareMode,
            rangeMode: effectiveRangeMode,
            allowsOutgoingInvitations: !isStealthModeEnabled,
            usesLowFrequencyBrowsing: isStealthModeEnabled && settings.signalDiscovery.discoversNearbyUsers
        )

        beaconService.updateSettings(
            BeaconRuntimeSettings(
                isStealthModeEnabled: isStealthModeEnabled,
                isAnonymousModeEnabled: settings.privacy.isAnonymousModeEnabled,
                allowsBeaconBroadcasts: settings.signalDiscovery.allowsBeaconBroadcasts,
                locationShareMode: settings.privacy.locationShareMode,
                showsDeviceName: isStealthModeEnabled ? false : settings.privacy.showsDeviceName,
                rangeMode: effectiveRangeMode
            )
        )

        locationService.updateRuntimeMode(isStealthModeEnabled ? .stealth : .standard)
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

    private func resolvedMeshDisplayName(for settings: AppSettings) -> String {
        if isStealthModeEnabled {
            return stealthModeNodeLabel
        }
        if settings.privacy.showsDeviceName {
            return String(UIDevice.current.name.prefix(20))
        }
        return beaconService.localNodeLabel
    }

    private func setStealthMode(_ isEnabled: Bool) {
        guard !isEnabled || featureFlags.enablesStealthMode else { return }
        guard isStealthModeEnabled != isEnabled else { return }

        if isEnabled {
            stealthNodeID = Self.generateEphemeralNodeID()
        }

        isStealthModeEnabled = isEnabled
        synchronizeSettings(settings, persist: false)
    }

    private static func generateEphemeralNodeID() -> String {
        let value = Int.random(in: 0...0xFFFF)
        return String(format: "%04X", value)
    }
}
