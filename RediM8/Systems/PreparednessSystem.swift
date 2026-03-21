import Foundation

@MainActor
final class PreparednessSystem: ObservableObject, AppSystem {
    @Published private(set) var profile: UserProfile
    @Published private(set) var prepScore: PrepScore
    @Published private(set) var activePrioritySituation: PrioritySituation?

    let preparednessDataService: PreparednessDataService
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

    init(
        preparednessDataService: PreparednessDataService,
        familyService: FamilyService,
        guideService: GuideService,
        scenarioEngine: ScenarioEngine,
        prepService: PrepService,
        preparednessInsightsService: PreparednessInsightsService,
        decisionSupportService: DecisionSupportService,
        vehicleReadinessService: VehicleReadinessService,
        waterRuntimeService: WaterRuntimeService,
        emergencyPlanService: EmergencyPlanService,
        goBagService: GoBagService,
        readinessReportService: ReadinessReportService
    ) {
        self.preparednessDataService = preparednessDataService
        self.familyService = familyService
        self.guideService = guideService
        self.scenarioEngine = scenarioEngine
        self.prepService = prepService
        self.preparednessInsightsService = preparednessInsightsService
        self.decisionSupportService = decisionSupportService
        self.vehicleReadinessService = vehicleReadinessService
        self.waterRuntimeService = waterRuntimeService
        self.emergencyPlanService = emergencyPlanService
        self.goBagService = goBagService
        self.readinessReportService = readinessReportService

        let loadedProfile = familyService.loadProfile()
        profile = loadedProfile
        prepScore = PreparednessSystem.calculateScore(
            for: loadedProfile,
            scenarioEngine: scenarioEngine,
            prepService: prepService
        )
        activePrioritySituation = nil
    }

    func start() {}

    func stop() {}

    func applyProfile(_ profile: UserProfile) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let normalizedProfile = profile.withNormalizedChecklistItems()
        self.profile = normalizedProfile
        familyService.saveProfile(normalizedProfile)
        refreshScore()
        let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        RediLogger.performance.debug("Preparedness profile sync applied in \(elapsed, privacy: .public) ms")
    }

    func mutateProfile(_ update: (inout UserProfile) -> Void) {
        var draft = profile
        update(&draft)
        applyProfile(draft)
    }

    func refreshScore() {
        prepScore = Self.calculateScore(
            for: profile,
            scenarioEngine: scenarioEngine,
            prepService: prepService
        )
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

    func currentReadinessReport() -> ReadinessReport {
        readinessReportService.generateReport(profile: profile, prepScore: prepScore)
    }

    func exportPreparednessReport() throws -> URL {
        try readinessReportService.savePDF(for: currentReadinessReport())
    }

    private static func calculateScore(
        for profile: UserProfile,
        scenarioEngine: ScenarioEngine,
        prepService: PrepService
    ) -> PrepScore {
        let scenarios = scenarioEngine.selectedScenarios(for: profile.selectedScenarios)
        return prepService.calculateScore(for: profile, scenarios: scenarios, engine: scenarioEngine)
    }
}
