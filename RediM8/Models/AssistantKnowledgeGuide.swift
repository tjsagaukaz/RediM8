import Foundation

struct AssistantKnowledgeGuideLibrary: Codable, Equatable {
    let lastUpdated: Date
    let guides: [AssistantKnowledgeGuide]

    enum CodingKeys: String, CodingKey {
        case lastUpdated = "last_updated"
        case guides
    }
}

struct AssistantKnowledgeGuide: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let category: GuideCategory
    let region: GuideRegionScope
    let riskLevel: AssistantIntentRiskBand
    let steps: [String]
    let summary: String
    let notes: String
    let sources: [GuideSource]
    let lastReviewed: String
    let tags: [String]
    let estimatedReadMinutes: Int
    let relatedGuideIDs: [String]
    let heroIconName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case region
        case riskLevel = "risk_level"
        case steps
        case summary
        case notes
        case sources
        case lastReviewed = "last_reviewed"
        case tags
        case estimatedReadMinutes = "estimated_read_minutes"
        case relatedGuideIDs = "related_guide_ids"
        case heroIconName = "hero_icon_name"
    }

    func asGuide() -> Guide {
        Guide(
            id: id,
            title: title,
            category: category,
            summary: summary,
            steps: steps,
            notes: notes,
            tags: tags + [riskLevel.rawValue, region.rawValue],
            estimatedReadMinutes: max(1, estimatedReadMinutes),
            difficulty: riskLevel == .critical ? .quickStart : .standard,
            lastReviewed: lastReviewed,
            regionScope: region,
            sections: [],
            diagrams: [],
            sources: sources,
            relatedGuideIDs: relatedGuideIDs,
            heroIconName: heroIconName
        )
    }
}
