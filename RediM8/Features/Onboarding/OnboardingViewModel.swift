import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome
        case safety
        case scenarios
        case household
        case medicalProfile
        case supplies
        case trust
        case result

        var nextTitle: String {
            switch self {
            case .welcome:
                "Start Setup"
            case .safety:
                "I Understand"
            case .scenarios:
                "Plan My Risks"
            case .household:
                "Review Emergency Health"
            case .medicalProfile:
                "Save Health Info"
            case .supplies:
                "Set Safe Defaults"
            case .trust:
                "Review Launch Summary"
            case .result:
                "Launch RediM8"
            }
        }
    }

    @Published var currentStep: Step = .welcome
    @Published var selectedScenarios: Set<ScenarioKind>
    @Published var peopleCount: Int
    @Published var petCount: Int
    @Published var primaryMeetingPoint: String
    @Published var primaryEvacuationRoute: String
    @Published var emergencyContactName: String
    @Published var emergencyContactPhone: String
    @Published var medicalNotes: String
    @Published var emergencyMedicalConditions: Set<CriticalMedicalCondition>
    @Published var severeAllergies: String
    @Published var otherCriticalCondition: String
    @Published var bloodType: String
    @Published var emergencyMedication: String
    @Published var supplies: Supplies
    @Published var checklistItems: [ChecklistItem]
    @Published var hasAcknowledgedSafetyNotice: Bool
    @Published var isAnonymousModeEnabled: Bool
    @Published var locationShareMode: LocationShareMode
    @Published var enablesSurvivalModeAtFifteenPercent: Bool
    @Published var reducesMapAnimations: Bool
    let availableScenarios: [PrepScenario]

    private let baseProfile: UserProfile
    private let baseSettings: AppSettings
    private let appState: AppState
    private var safetyAcknowledgedAt: Date?

    init(appState: AppState) {
        self.appState = appState
        baseProfile = appState.profile
        baseSettings = appState.settings
        let selectedScenarios = Set(appState.profile.selectedScenarios)
        self.selectedScenarios = selectedScenarios
        peopleCount = appState.profile.household.peopleCount
        petCount = appState.profile.household.petCount
        primaryMeetingPoint = appState.profile.meetingPoints.primary
        primaryEvacuationRoute = appState.profile.evacuationRoutes.first ?? ""
        emergencyContactName = appState.profile.emergencyContacts.first?.name ?? ""
        emergencyContactPhone = appState.profile.emergencyContacts.first?.phone ?? ""
        medicalNotes = appState.profile.medicalNotes
        emergencyMedicalConditions = Set(appState.profile.emergencyMedicalInfo.criticalConditions)
        severeAllergies = appState.profile.emergencyMedicalInfo.severeAllergies
        otherCriticalCondition = appState.profile.emergencyMedicalInfo.otherCriticalCondition
        bloodType = appState.profile.emergencyMedicalInfo.bloodType
        emergencyMedication = appState.profile.emergencyMedicalInfo.emergencyMedication
        supplies = appState.profile.supplies
        checklistItems = appState.profile.checklistItems
        hasAcknowledgedSafetyNotice = appState.profile.hasAcknowledgedSafetyNotice
        isAnonymousModeEnabled = appState.settings.privacy.isAnonymousModeEnabled
        locationShareMode = appState.settings.privacy.locationShareMode
        enablesSurvivalModeAtFifteenPercent = appState.settings.battery.enablesSurvivalModeAtFifteenPercent
        reducesMapAnimations = appState.settings.battery.reducesMapAnimations
        availableScenarios = appState.scenarioEngine.availableScenarios()
        safetyAcknowledgedAt = appState.profile.lastAcknowledgedSafetyNoticeAt
    }

    var canGoBack: Bool {
        currentStep != .welcome
    }

    var canDismiss: Bool {
        baseProfile.isOnboardingComplete
    }

    var currentStepNumber: Int {
        currentStep.rawValue + 1
    }

    var progressValue: Double {
        Double(currentStepNumber) / Double(Step.allCases.count)
    }

    var currentStepActionTitle: String {
        if currentStep == .safety, hasAcknowledgedSafetyNotice {
            return "Continue Setup"
        }
        if currentStep == .medicalProfile {
            return hasEmergencyMedicalInfo ? "Save Health Info" : "Skip for Now"
        }
        return currentStep.nextTitle
    }

    var hasEmergencyMedicalInfo: Bool {
        buildEmergencyMedicalInfo().hasAnyContent
    }

    var selectedScenariosOrFallback: [ScenarioKind] {
        let resolvedScenarios = selectedScenarios.subtracting([.generalEmergencies])
        if resolvedScenarios.isEmpty {
            return [.generalEmergencies]
        }

        return resolvedScenarios.sorted { $0.title < $1.title }
    }

    var selectedScenarioModels: [PrepScenario] {
        appState.scenarioEngine.selectedScenarios(for: selectedScenariosOrFallback)
    }

    var prepTargets: PrepTargets {
        appState.prepService.recommendedTargets(for: buildProfile(), scenarios: selectedScenarioModels)
    }

    var livePreviewScore: PrepScore {
        appState.prepService.calculateScore(
            for: buildProfile(),
            scenarios: selectedScenarioModels,
            engine: appState.scenarioEngine
        )
    }

    var launchSuggestions: [ImprovementSuggestion] {
        Array(livePreviewScore.suggestions.prefix(3))
    }

    var highlightedPrioritySituation: PrioritySituation? {
        let scenarios = Set(selectedScenariosOrFallback)

        if scenarios.contains(.bushfires) {
            return .bushfire
        }
        if !scenarios.isDisjoint(with: [.floods, .cyclones, .severeStorm]) {
            return .flood
        }
        if !scenarios.isDisjoint(with: [.powerOutages, .extendedInfrastructureDisruption, .fuelShortages, .extremeHeat]) {
            return .blackout
        }
        if !scenarios.isDisjoint(with: [.remoteTravel, .campingOffGrid]) {
            return .remoteTravel
        }

        return nil
    }

    func toggle(_ scenario: ScenarioKind) {
        if scenario == .generalEmergencies {
            selectedScenarios = [.generalEmergencies]
            return
        }

        selectedScenarios.remove(.generalEmergencies)

        if selectedScenarios.contains(scenario) {
            selectedScenarios.remove(scenario)
        } else {
            selectedScenarios.insert(scenario)
        }

        if selectedScenarios.isEmpty {
            selectedScenarios.insert(.generalEmergencies)
        }
    }

    func next() {
        if currentStep == .safety {
            acknowledgeSafetyNoticeIfNeeded()
        }
        guard let nextStep = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextStep
    }

    func back() {
        guard let previousStep = Step(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previousStep
    }

    func finish() {
        acknowledgeSafetyNoticeIfNeeded()
        let profile = buildProfile()
        let settings = buildSettings(for: profile)
        appState.completeOnboarding(with: profile)
        appState.applySettings(settings)
    }

    private func buildProfile() -> UserProfile {
        var profile = baseProfile
        profile.selectedScenarios = selectedScenariosOrFallback
        profile.household = HouseholdDetails(peopleCount: max(peopleCount, 1), petCount: max(petCount, 0))
        profile.supplies = supplies
        profile.checklistItems = checklistItems
        profile.meetingPoints.primary = primaryMeetingPoint
        profile.medicalNotes = medicalNotes
        profile.emergencyMedicalInfo = buildEmergencyMedicalInfo()
        profile.evacuationRoutes = mergedRoutes()
        profile.emergencyContacts = mergedEmergencyContacts()
        profile.lastAcknowledgedSafetyNoticeAt = safetyAcknowledgedAt ?? profile.lastAcknowledgedSafetyNoticeAt
        return profile
    }

    private func buildSettings(for profile: UserProfile) -> AppSettings {
        var settings = baseSettings
        settings.privacy.isAnonymousModeEnabled = isAnonymousModeEnabled
        settings.privacy.locationShareMode = locationShareMode
        settings.battery.enablesSurvivalModeAtFifteenPercent = enablesSurvivalModeAtFifteenPercent
        settings.battery.reducesMapAnimations = reducesMapAnimations

        if profile.selectedScenarios.contains(.bushfires) {
            settings.maps.defaultLayers.formUnion([.waterPoints, .evacuationPoints])
        }

        return settings
    }

    private func mergedRoutes() -> [String] {
        let trimmedRoute = primaryEvacuationRoute.nilIfBlank
        let remainingRoutes = Array(baseProfile.evacuationRoutes.dropFirst()).compactMap(\.nilIfBlank)

        if let trimmedRoute {
            return [trimmedRoute] + remainingRoutes
        }

        return remainingRoutes
    }

    private func mergedEmergencyContacts() -> [EmergencyContact] {
        let name = emergencyContactName.nilIfBlank
        let phone = emergencyContactPhone.nilIfBlank
        let remainingContacts = Array(baseProfile.emergencyContacts.dropFirst())

        guard name != nil || phone != nil else {
            return remainingContacts
        }

        return [
            EmergencyContact(name: name ?? "Emergency Contact", phone: phone ?? "")
        ] + remainingContacts
    }

    private func buildEmergencyMedicalInfo() -> EmergencyMedicalInfo {
        EmergencyMedicalInfo(
            criticalConditions: Array(emergencyMedicalConditions),
            severeAllergies: severeAllergies,
            otherCriticalCondition: otherCriticalCondition,
            bloodType: bloodType,
            emergencyMedication: emergencyMedication
        )
    }

    private func acknowledgeSafetyNoticeIfNeeded() {
        guard !hasAcknowledgedSafetyNotice else { return }
        let acknowledgedAt = Date.now
        hasAcknowledgedSafetyNotice = true
        safetyAcknowledgedAt = acknowledgedAt
        appState.mutateProfile { profile in
            profile.lastAcknowledgedSafetyNoticeAt = profile.lastAcknowledgedSafetyNoticeAt ?? acknowledgedAt
        }
    }
}
