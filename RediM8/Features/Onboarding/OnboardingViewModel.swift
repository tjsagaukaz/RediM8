import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome
        case safety
        case scenarios
        case launch

        var nextTitle: String {
            switch self {
            case .welcome:
                "Continue"
            case .safety:
                "I Understand"
            case .scenarios:
                "Continue"
            case .launch:
                "Activate System"
            }
        }
    }

    @Published var currentStep: Step = .welcome
    @Published var selectedScenarios: Set<ScenarioKind>
    @Published var hasAcknowledgedSafetyNotice: Bool
    let availableScenarios: [PrepScenario]

    private let baseProfile: UserProfile
    private let appState: AppState
    private var safetyAcknowledgedAt: Date?

    init(appState: AppState) {
        self.appState = appState
        baseProfile = appState.profile
        let selectedScenarios = Set(appState.profile.selectedScenarios)
        self.selectedScenarios = selectedScenarios
        hasAcknowledgedSafetyNotice = appState.profile.hasAcknowledgedSafetyNotice
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
            return "Continue"
        }
        return currentStep.nextTitle
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
        profile.lastAcknowledgedSafetyNoticeAt = safetyAcknowledgedAt ?? profile.lastAcknowledgedSafetyNoticeAt
        return profile
    }

    private func buildSettings(for profile: UserProfile) -> AppSettings {
        var settings = appState.settings

        if profile.selectedScenarios.contains(.bushfires) {
            settings.maps.defaultLayers.formUnion([.waterPoints, .evacuationPoints])
        }

        return settings
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
