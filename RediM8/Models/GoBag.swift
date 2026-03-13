import Foundation

struct GoBagLibrary: Codable, Equatable {
    let categories: [GoBagCategoryBlueprint]
    let evacuationChecklist: [GoBagEvacuationStepBlueprint]

    enum CodingKeys: String, CodingKey {
        case categories
        case evacuationChecklist = "evacuation_checklist"
    }
}

struct GoBagCategoryBlueprint: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let items: [GoBagItemBlueprint]
}

struct GoBagItemBlueprint: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let relatedGearIDs: [String]
    let relatedTaskIDs: [String]
    let recommendedScenarios: [ScenarioKind]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case relatedGearIDs = "related_gear_ids"
        case relatedTaskIDs = "related_task_ids"
        case recommendedScenarios = "recommended_scenarios"
    }
}

struct GoBagEvacuationStepBlueprint: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let requiresPets: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case requiresPets = "requires_pets"
    }
}

struct GoBagItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let supportingText: String?
    let isScenarioSpecific: Bool
}

struct GoBagCategory: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [GoBagItem]
}

struct GoBagReadiness: Equatable {
    let completedCount: Int
    let totalCount: Int

    var progress: Double {
        guard totalCount > 0 else {
            return 0
        }

        return Double(completedCount) / Double(totalCount)
    }

    var percentage: Int {
        Int((progress * 100).rounded())
    }
}

struct GoBagEvacuationStep: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
}

struct GoBagPlan: Equatable {
    let readiness: GoBagReadiness
    let categories: [GoBagCategory]
    let scenarioTitles: [String]
    let contextLines: [String]
    let nextActions: [String]
    let evacuationChecklist: [GoBagEvacuationStep]
}
