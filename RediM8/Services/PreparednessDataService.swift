import Foundation

final class PreparednessDataService {
    private enum StorageKey {
        static let assistantPolicies = "preparedness.assistantPolicies.v1"
        static let scenarios = "preparedness.scenarios.v1"
        static let tasks = "preparedness.tasks.v1"
        static let gear = "preparedness.gear.v1"
        static let guides = "preparedness.guides.v4"
        static let noInfrastructureGuides = "preparedness.noInfrastructureGuides.v1"
        static let bushMedicineGuides = "preparedness.bushMedicineGuides.v1"
        static let foodGrowingGuides = "preparedness.foodGrowingGuides.v1"
        static let survivalSkillsGuides = "preparedness.survivalSkillsGuides.v1"
        static let emergencyPlan = "preparedness.emergency72hour.v1"
        static let goBag = "preparedness.gobag.v1"
        static let resourceCategories = "preparedness.resourceCategories.v1"
    }

    private let store: SQLiteStore?
    private let bundle: Bundle

    private var scenarioLibraryCache: ScenarioLibrary?
    private var assistantPolicyLibraryCache: AssistantPolicyLibrary?
    private var taskLibraryCache: TaskLibrary?
    private var gearLibraryCache: GearLibrary?
    private var bundledGuideLibraryCache: GuideLibrary?
    private var guideLibraryCache: GuideLibrary?
    private var bushMedicineGuideLibraryCache: AssistantKnowledgeGuideLibrary?
    private var foodGrowingGuideLibraryCache: AssistantKnowledgeGuideLibrary?
    private var survivalSkillsGuideLibraryCache: AssistantKnowledgeGuideLibrary?
    private var noInfrastructureGuideLibraryCache: GuideLibrary?
    private var emergencyPlanCache: Emergency72HourPlanBlueprint?
    private var goBagCache: GoBagLibrary?
    private var resourceCategoryLibraryCache: ResourceCategoryLibrary?

    private var taskIndexCache: [String: PreparednessTask]?
    private var gearIndexCache: [String: GearItem]?
    private var guideIndexCache: [String: Guide]?
    private var resourceCategoryIndexCache: [String: ResourceCategoryDefinition]?

    init(store: SQLiteStore?, bundle: Bundle = .main) {
        self.store = store
        self.bundle = bundle
    }

    func assistantPolicyLibrary() -> AssistantPolicyLibrary {
        load(
            cache: &assistantPolicyLibraryCache,
            filename: "AssistantPolicies.json",
            storageKey: StorageKey.assistantPolicies,
            type: AssistantPolicyLibrary.self,
            fallback: AssistantPolicyLibrary(lastUpdated: .distantPast, policies: [])
        )
    }

    func assistantPolicies() -> [AssistantPolicy] {
        assistantPolicyLibrary().policies
    }

    func scenarios() -> [PrepScenario] {
        load(
            cache: &scenarioLibraryCache,
            filename: "Scenarios.json",
            storageKey: StorageKey.scenarios,
            type: ScenarioLibrary.self,
            fallback: ScenarioLibrary(scenarios: [])
        ).scenarios
    }

    func tasks() -> [PreparednessTask] {
        load(
            cache: &taskLibraryCache,
            filename: "Tasks.json",
            storageKey: StorageKey.tasks,
            type: TaskLibrary.self,
            fallback: TaskLibrary(tasks: [])
        ).tasks
    }

    func gear() -> [GearItem] {
        load(
            cache: &gearLibraryCache,
            filename: "Gear.json",
            storageKey: StorageKey.gear,
            type: GearLibrary.self,
            fallback: GearLibrary(gear: [])
        ).gear
    }

    func guides() -> [Guide] {
        if let guideLibraryCache {
            return guideLibraryCache.guides
        }

        if let store, let stored = try? store.load(GuideLibrary.self, for: StorageKey.guides) {
            guideLibraryCache = stored
            return stored.guides
        }

        let resolved = mergedGuideLibrary()
        try? store?.save(resolved, for: StorageKey.guides)
        guideLibraryCache = resolved
        return resolved.guides
    }

    func bushMedicineGuides() -> [Guide] {
        bushMedicineGuideLibrary().guides.map { $0.asGuide() }
    }

    func foodGrowingKnowledgeGuides() -> [Guide] {
        foodGrowingGuideLibrary().guides.map { $0.asGuide() }
    }

    func survivalSkillsGuides() -> [Guide] {
        survivalSkillsGuideLibrary().guides.map { $0.asGuide() }
    }

    func noInfrastructureGuides() -> [Guide] {
        noInfrastructureGuideLibrary().guides
    }

    func emergency72HourPlanBlueprint() -> Emergency72HourPlanBlueprint {
        load(
            cache: &emergencyPlanCache,
            filename: "Emergency72HourPlan.json",
            storageKey: StorageKey.emergencyPlan,
            type: Emergency72HourPlanBlueprint.self,
            fallback: Emergency72HourPlanBlueprint(
                days: 3,
                waterPerPersonPerDayLitres: 3,
                waterPerPetPerDayLitres: 1,
                minimumFoodCaloriesPerDay: 2000,
                recommendedGear: [],
                essentialTasks: [],
                checklists: []
            )
        )
    }

    func resourceCategories() -> [ResourceCategoryDefinition] {
        load(
            cache: &resourceCategoryLibraryCache,
            filename: "ResourceCategories.json",
            storageKey: StorageKey.resourceCategories,
            type: ResourceCategoryLibrary.self,
            fallback: ResourceCategoryLibrary(categories: [])
        ).categories
    }

    func goBagBlueprint() -> GoBagLibrary {
        load(
            cache: &goBagCache,
            filename: "GoBagItems.json",
            storageKey: StorageKey.goBag,
            type: GoBagLibrary.self,
            fallback: GoBagLibrary(categories: [], evacuationChecklist: [])
        )
    }

    func taskIndex() -> [String: PreparednessTask] {
        if let taskIndexCache {
            return taskIndexCache
        }

        let resolved = Dictionary(uniqueKeysWithValues: tasks().map { ($0.id, $0) })
        taskIndexCache = resolved
        return resolved
    }

    func gearIndex() -> [String: GearItem] {
        if let gearIndexCache {
            return gearIndexCache
        }

        let resolved = Dictionary(uniqueKeysWithValues: gear().map { ($0.id, $0) })
        gearIndexCache = resolved
        return resolved
    }

    func guideIndex() -> [String: Guide] {
        if let guideIndexCache {
            return guideIndexCache
        }

        let resolved = Dictionary(uniqueKeysWithValues: guides().map { ($0.id, $0) })
        guideIndexCache = resolved
        return resolved
    }

    func resourceCategoryIndex() -> [String: ResourceCategoryDefinition] {
        if let resourceCategoryIndexCache {
            return resourceCategoryIndexCache
        }

        let resolved = Dictionary(uniqueKeysWithValues: resourceCategories().map { ($0.id, $0) })
        resourceCategoryIndexCache = resolved
        return resolved
    }

    private func load<T: Codable>(
        cache: inout T?,
        filename: String,
        storageKey: String,
        type: T.Type,
        fallback: @autoclosure () -> T
    ) -> T {
        if let cache {
            return cache
        }

        if let store, let stored = try? store.load(type, for: storageKey) {
            cache = stored
            return stored
        }

        let resolved = (try? bundle.decode(filename, as: type)) ?? fallback()
        try? store?.save(resolved, for: storageKey)
        cache = resolved
        return resolved
    }

    private func bundledGuideLibrary() -> GuideLibrary {
        load(
            cache: &bundledGuideLibraryCache,
            filename: "Guides.json",
            storageKey: StorageKey.guides + ".bundled",
            type: GuideLibrary.self,
            fallback: GuideLibrary(guides: [])
        )
    }

    private func bushMedicineGuideLibrary() -> AssistantKnowledgeGuideLibrary {
        load(
            cache: &bushMedicineGuideLibraryCache,
            filename: "BushMedicineGuides.json",
            storageKey: StorageKey.bushMedicineGuides,
            type: AssistantKnowledgeGuideLibrary.self,
            fallback: AssistantKnowledgeGuideLibrary(lastUpdated: .distantPast, guides: [])
        )
    }

    private func foodGrowingGuideLibrary() -> AssistantKnowledgeGuideLibrary {
        load(
            cache: &foodGrowingGuideLibraryCache,
            filename: "FoodGrowingGuides.json",
            storageKey: StorageKey.foodGrowingGuides,
            type: AssistantKnowledgeGuideLibrary.self,
            fallback: AssistantKnowledgeGuideLibrary(lastUpdated: .distantPast, guides: [])
        )
    }

    private func survivalSkillsGuideLibrary() -> AssistantKnowledgeGuideLibrary {
        load(
            cache: &survivalSkillsGuideLibraryCache,
            filename: "SurvivalSkillsGuides.json",
            storageKey: StorageKey.survivalSkillsGuides,
            type: AssistantKnowledgeGuideLibrary.self,
            fallback: AssistantKnowledgeGuideLibrary(lastUpdated: .distantPast, guides: [])
        )
    }

    private func noInfrastructureGuideLibrary() -> GuideLibrary {
        load(
            cache: &noInfrastructureGuideLibraryCache,
            filename: "NoInfrastructureGuides.json",
            storageKey: StorageKey.noInfrastructureGuides,
            type: GuideLibrary.self,
            fallback: GuideLibrary(guides: [])
        )
    }

    private func mergedGuideLibrary() -> GuideLibrary {
        let mergedGuides = bundledGuideLibrary().guides
            + bushMedicineGuides()
            + foodGrowingKnowledgeGuides()
            + survivalSkillsGuides()
            + noInfrastructureGuides()

        var seen = Set<String>()
        let orderedUniqueGuides = mergedGuides.filter { guide in
            seen.insert(guide.id).inserted
        }

        return GuideLibrary(guides: orderedUniqueGuides)
    }
}
