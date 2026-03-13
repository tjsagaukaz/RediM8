import Foundation

@MainActor
final class GoBagService: ObservableObject {
    private enum StorageKey {
        static let completedItems = "gobag.completedItems.v1"
    }

    @Published private(set) var completedItemIDs: Set<String>

    private let dataService: PreparednessDataService
    private let scenarioEngine: ScenarioEngine
    private let emergencyPlanService: EmergencyPlanService
    private let store: SQLiteStore?

    init(dataService: PreparednessDataService, scenarioEngine: ScenarioEngine, emergencyPlanService: EmergencyPlanService, store: SQLiteStore?) {
        self.dataService = dataService
        self.scenarioEngine = scenarioEngine
        self.emergencyPlanService = emergencyPlanService
        self.store = store
        let storedIDs: [String]
        if let store, let loadedIDs = try? store.load([String].self, for: StorageKey.completedItems) {
            storedIDs = loadedIDs
        } else {
            storedIDs = []
        }
        completedItemIDs = Set(storedIDs)
    }

    func plan(for profile: UserProfile) -> GoBagPlan {
        let blueprint = dataService.goBagBlueprint()
        let selectedScenarios = Set(profile.selectedScenarios)
        let gearIndex = dataService.gearIndex()
        let taskIndex = dataService.taskIndex()
        let emergencyPlan = emergencyPlanService.generatePlan(for: profile)

        let categories: [GoBagCategory] = blueprint.categories.compactMap { category -> GoBagCategory? in
            let items = category.items
                .filter { shouldInclude($0, for: selectedScenarios) }
                .map { item in
                    GoBagItem(
                        id: item.id,
                        title: item.title,
                        detail: item.detail,
                        supportingText: supportingText(for: item, gearIndex: gearIndex, taskIndex: taskIndex),
                        isScenarioSpecific: !item.recommendedScenarios.isEmpty
                    )
                }

            guard !items.isEmpty else {
                return nil
            }

            return GoBagCategory(id: category.id, title: category.title, items: items)
        }

        let visibleItems = categories.flatMap { $0.items }
        let visibleItemIDs = Set(visibleItems.map { $0.id })
        let visibleCompleted = completedItemIDs.intersection(visibleItemIDs)
        let readiness = GoBagReadiness(completedCount: visibleCompleted.count, totalCount: visibleItemIDs.count)

        let nextActions = visibleItems
            .filter { !visibleCompleted.contains($0.id) }
            .prefix(3)
            .map { $0.title }

        let contextLines = [
            "72-hour water target: \(emergencyPlan.waterRequiredLitres.roundedIntString)L",
            "Emergency contacts saved: \(profile.emergencyContacts.count)",
            "Evacuation routes saved: \(profile.evacuationRoutes.compactMap(\.nilIfBlank).count)"
        ]

        let evacuationChecklist: [GoBagEvacuationStep] = blueprint.evacuationChecklist.compactMap { step -> GoBagEvacuationStep? in
            guard !step.requiresPets || profile.household.petCount > 0 else {
                return nil
            }

            return GoBagEvacuationStep(id: step.id, title: step.title, detail: step.detail)
        }

        return GoBagPlan(
            readiness: readiness,
            categories: categories,
            scenarioTitles: scenarioEngine.selectedScenarios(for: profile.selectedScenarios).map { $0.name },
            contextLines: contextLines,
            nextActions: nextActions,
            evacuationChecklist: evacuationChecklist
        )
    }

    func isItemComplete(_ itemID: String) -> Bool {
        completedItemIDs.contains(itemID)
    }

    func setItem(_ itemID: String, isComplete: Bool) {
        if isComplete {
            completedItemIDs.insert(itemID)
        } else {
            completedItemIDs.remove(itemID)
        }

        saveCompletedItems()
    }

    private func saveCompletedItems() {
        try? store?.save(completedItemIDs.sorted(), for: StorageKey.completedItems)
    }

    private func shouldInclude(_ item: GoBagItemBlueprint, for selectedScenarios: Set<ScenarioKind>) -> Bool {
        item.recommendedScenarios.isEmpty || !selectedScenarios.isDisjoint(with: item.recommendedScenarios)
    }

    private func supportingText(
        for item: GoBagItemBlueprint,
        gearIndex: [String: GearItem],
        taskIndex: [String: PreparednessTask]
    ) -> String? {
        var components: [String] = []

        let scenarioText = item.recommendedScenarios
            .map(\.title)
            .joined(separator: ", ")
            .nilIfBlank
        if let scenarioText {
            components.append("Scenario: \(scenarioText)")
        }

        let gearNames = item.relatedGearIDs.compactMap { gearIndex[$0]?.name }
        if let gearText = gearNames.joined(separator: ", ").nilIfBlank {
            components.append("Gear: \(gearText)")
        }

        let taskTitles = item.relatedTaskIDs.compactMap { taskIndex[$0]?.title }
        if let taskText = taskTitles.joined(separator: ", ").nilIfBlank {
            components.append("Tasks: \(taskText)")
        }

        return components.joined(separator: " • ").nilIfBlank
    }
}
