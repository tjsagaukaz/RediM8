import Foundation

enum PrepTier: String, Codable, Equatable {
    case notReady = "Not Ready"
    case improving = "Improving"
    case prepared = "Prepared"
    case highlyPrepared = "Highly Prepared"

    var displayTitle: String {
        switch self {
        case .notReady:
            "Starter"
        case .improving:
            "Prepared"
        case .prepared:
            "Resilient"
        case .highlyPrepared:
            "RediM8 Ready"
        }
    }

    var nextDisplayTitle: String? {
        switch self {
        case .notReady:
            "Prepared"
        case .improving:
            "Resilient"
        case .prepared:
            "RediM8 Ready"
        case .highlyPrepared:
            nil
        }
    }

    var nextTarget: Int? {
        switch self {
        case .notReady:
            50
        case .improving:
            75
        case .prepared:
            100
        case .highlyPrepared:
            nil
        }
    }

    static func from(score: Int) -> PrepTier {
        switch score {
        case ..<50:
            .notReady
        case 50..<75:
            .improving
        case 75..<100:
            .prepared
        default:
            .highlyPrepared
        }
    }
}

struct CategoryScore: Identifiable, Codable, Equatable {
    var id: PrepCategory { category }
    let category: PrepCategory
    let score: Int
}

struct ImprovementSuggestion: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let impact: Int
    let category: PrepCategory

    init(id: UUID = UUID(), title: String, detail: String, impact: Int, category: PrepCategory) {
        self.id = id
        self.title = title
        self.detail = detail
        self.impact = impact
        self.category = category
    }
}

struct PrepScore: Codable, Equatable {
    let overall: Int
    let tier: PrepTier
    let categoryScores: [CategoryScore]
    let suggestions: [ImprovementSuggestion]

    var milestoneTitle: String {
        tier.displayTitle
    }

    var nextMilestoneSummary: String {
        guard let title = tier.nextDisplayTitle, let target = tier.nextTarget else {
            return "All readiness milestones complete."
        }

        return "\(max(target - overall, 0))% to \(title)"
    }

    var milestoneCaption: String {
        guard let title = tier.nextDisplayTitle, let target = tier.nextTarget else {
            return "RediM8 Ready unlocked."
        }

        return "Next milestone: \(title) at \(target)%"
    }

    static let empty = PrepScore(overall: 0, tier: .notReady, categoryScores: [], suggestions: [])
}
