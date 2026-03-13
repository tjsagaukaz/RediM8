import Foundation

final class ScenarioEngine {
    private let dataService: PreparednessDataService?
    private let scenarioOverrides: [PrepScenario]?
    private let taskOverrides: [PreparednessTask]?
    private let gearOverrides: [GearItem]?

    init(bundle: Bundle = .main) {
        dataService = PreparednessDataService(store: nil, bundle: bundle)
        scenarioOverrides = nil
        taskOverrides = nil
        gearOverrides = nil
    }

    init(dataService: PreparednessDataService) {
        self.dataService = dataService
        scenarioOverrides = nil
        taskOverrides = nil
        gearOverrides = nil
    }

    init(scenarios: [PrepScenario], tasks: [PreparednessTask] = [], gear: [GearItem] = []) {
        dataService = nil
        scenarioOverrides = scenarios
        taskOverrides = tasks
        gearOverrides = gear
    }

    var scenarios: [PrepScenario] {
        scenarioOverrides ?? dataService?.scenarios() ?? []
    }

    func availableScenarios() -> [PrepScenario] {
        scenarios
    }

    func selectedScenarios(for kinds: [ScenarioKind]) -> [PrepScenario] {
        let set = Set(kinds)
        return scenarios.filter { set.contains($0.kind) }
    }

    func personalizedTasks(for profile: UserProfile) -> [PreparednessTask] {
        let taskIndex = resolvedTaskIndex()
        let orderedIDs = selectedScenarios(for: profile.selectedScenarios)
            .flatMap(\.tasks)

        var tasks = orderedUnique(orderedIDs)
            .compactMap { taskIndex[$0] }

        if let waterPointTask = waterPointReviewTask(for: profile),
           !tasks.contains(where: { $0.id == waterPointTask.id }) {
            tasks.append(waterPointTask)
        }

        if let evacuationPointTask = evacuationPointReviewTask(for: profile),
           !tasks.contains(where: { $0.id == evacuationPointTask.id }) {
            tasks.append(evacuationPointTask)
        }

        return tasks.sorted { lhs, rhs in
            if lhs.prepScoreValue == rhs.prepScoreValue {
                return lhs.title < rhs.title
            }
            return lhs.prepScoreValue > rhs.prepScoreValue
        }
    }

    private func waterPointReviewTask(for profile: UserProfile) -> PreparednessTask? {
        let scenarios = Set(profile.selectedScenarios)
        let relevantScenarios: Set<ScenarioKind> = [
            .bushfires,
            .floods,
            .extremeHeat,
            .remoteTravel,
            .campingOffGrid,
            .extendedInfrastructureDisruption
        ]

        guard !scenarios.isDisjoint(with: relevantScenarios) else {
            return nil
        }

        return PreparednessTask(
            id: "review_offline_water_points",
            title: "Review offline water points",
            description: "Check nearby tanks, taps, bores and creek access in the Water Points layer before travel or evacuation.",
            prepScoreValue: 6,
            category: .waterStorage,
            recommendedScenarios: Array(relevantScenarios).sorted { $0.title < $1.title }
        )
    }

    private func evacuationPointReviewTask(for profile: UserProfile) -> PreparednessTask? {
        let scenarios = Set(profile.selectedScenarios)
        let relevantScenarios: Set<ScenarioKind> = [
            .bushfires,
            .cyclones,
            .floods,
            .severeStorm
        ]

        guard !scenarios.isDisjoint(with: relevantScenarios) else {
            return nil
        }

        return PreparednessTask(
            id: "review_offline_evacuation_points",
            title: "Review nearby evacuation points",
            description: "Check nearby evacuation centres, shelters, and assembly points in the Evacuation Points layer before you need to move.",
            prepScoreValue: 6,
            category: .evacuationPlanning,
            recommendedScenarios: Array(relevantScenarios).sorted { $0.title < $1.title }
        )
    }

    func recommendedGear(for profile: UserProfile) -> [GearItem] {
        let gearIndex = resolvedGearIndex()
        let orderedIDs = selectedScenarios(for: profile.selectedScenarios)
            .flatMap(\.gear)

        return orderedUnique(orderedIDs)
            .compactMap { gearIndex[$0] }
            .sorted { lhs, rhs in
                if lhs.category == rhs.category {
                    return lhs.name < rhs.name
                }
                return lhs.category.title < rhs.category.title
            }
    }

    func recommendedGuideIDs(for profile: UserProfile) -> [String] {
        orderedUnique(
            selectedScenarios(for: profile.selectedScenarios)
                .flatMap(\.guides)
        )
    }

    func weightMultiplier(for category: PrepCategory, scenarios: [PrepScenario]) -> Double {
        guard !scenarios.isEmpty else {
            return 1
        }

        let matches = scenarios.filter { $0.priorityCategories.contains(category) }.count
        guard matches > 0 else {
            return 1
        }

        let pressure = Double(matches) / Double(scenarios.count)
        return 1 + pressure * 0.25
    }

    private func resolvedTaskIndex() -> [String: PreparednessTask] {
        if let taskOverrides {
            return Dictionary(uniqueKeysWithValues: taskOverrides.map { ($0.id, $0) })
        }

        return dataService?.taskIndex() ?? [:]
    }

    private func resolvedGearIndex() -> [String: GearItem] {
        if let gearOverrides {
            return Dictionary(uniqueKeysWithValues: gearOverrides.map { ($0.id, $0) })
        }

        return dataService?.gearIndex() ?? [:]
    }

    private func orderedUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        var ordered: [T] = []

        for value in values where seen.insert(value).inserted {
            ordered.append(value)
        }

        return ordered
    }
}
