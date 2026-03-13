import Foundation

enum GuideCategory: String, CaseIterable, Codable, Identifiable {
    case firstAid
    case disasterResponse
    case bushcraft
    case navigation
    case waterSafety
    case fireSafety
    case medical
    case heatSafety
    case stormSafety
    case floodSafety
    case foodCooking
    case foodGrowing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstAid:
            "First Aid"
        case .disasterResponse:
            "Disaster Response"
        case .bushcraft:
            "Bushcraft"
        case .navigation:
            "Navigation"
        case .waterSafety:
            "Water Safety"
        case .fireSafety:
            "Fire Safety"
        case .medical:
            "Medical"
        case .heatSafety:
            "Heat Safety"
        case .stormSafety:
            "Storm Safety"
        case .floodSafety:
            "Flood Safety"
        case .foodCooking:
            "Food & Cooking"
        case .foodGrowing:
            "Growing Food"
        }
    }

    var systemImage: String {
        switch self {
        case .firstAid:
            "first_aid"
        case .disasterResponse:
            "warning"
        case .bushcraft:
            "tent"
        case .navigation:
            "compass"
        case .waterSafety:
            "water"
        case .fireSafety:
            "fire_trail"
        case .medical:
            "medical"
        case .heatSafety:
            "warning"
        case .stormSafety:
            "warning"
        case .floodSafety:
            "flood"
        case .foodCooking:
            "food"
        case .foodGrowing:
            "camp"
        }
    }
}

enum GuideDifficulty: String, Codable, Equatable {
    case quickStart
    case standard
    case advanced

    var title: String {
        switch self {
        case .quickStart:
            "Quick Start"
        case .standard:
            "Core Skill"
        case .advanced:
            "Extended Skill"
        }
    }
}

enum GuideRegionScope: String, Codable, Equatable {
    case australia
    case general
    case regional

    var title: String {
        switch self {
        case .australia:
            "Australia-focused"
        case .general:
            "General guidance"
        case .regional:
            "Region-specific"
        }
    }
}

enum GuideSourceKind: String, Codable, Equatable {
    case official
    case publicDomain
    case originalDiagram
    case redim8

    var title: String {
        switch self {
        case .official:
            "Official source"
        case .publicDomain:
            "Public-domain reference"
        case .originalDiagram:
            "Original diagram"
        case .redim8:
            "RediM8 guide"
        }
    }
}

enum GuideDiagramKind: String, Codable, Equatable {
    case pressureBandage
    case recoveryPosition
    case bowline
    case cloveHitch
    case reefKnot
    case tarpRidgeline
    case compassBearing
    case damperMethod
    case skilletBread
    case sconeMethod
    case raisedBedLayout
    case seedTray
    case potatoBag
    case waterFilter
}

struct GuideSection: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let summary: String?
    let steps: [String]

    init(id: String, title: String, summary: String? = nil, steps: [String]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.steps = steps
    }
}

struct GuideDiagram: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let caption: String
    let kind: GuideDiagramKind

    init(id: String, title: String, caption: String, kind: GuideDiagramKind) {
        self.id = id
        self.title = title
        self.caption = caption
        self.kind = kind
    }
}

struct GuideSource: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let publisher: String
    let url: String
    let kind: GuideSourceKind
    let license: String?

    init(
        id: String,
        title: String,
        publisher: String,
        url: String,
        kind: GuideSourceKind,
        license: String? = nil
    ) {
        self.id = id
        self.title = title
        self.publisher = publisher
        self.url = url
        self.kind = kind
        self.license = license
    }
}

struct Guide: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let category: GuideCategory
    let summary: String
    let steps: [String]
    let notes: String
    let tags: [String]
    let estimatedReadMinutes: Int
    let difficulty: GuideDifficulty
    let lastReviewed: String
    let regionScope: GuideRegionScope
    let sections: [GuideSection]
    let diagrams: [GuideDiagram]
    let sources: [GuideSource]
    let relatedGuideIDs: [String]
    let heroIconName: String

    init(
        id: String,
        title: String,
        category: GuideCategory,
        summary: String,
        steps: [String],
        notes: String,
        tags: [String] = [],
        estimatedReadMinutes: Int = 3,
        difficulty: GuideDifficulty = .standard,
        lastReviewed: String = "Bundled offline guide",
        regionScope: GuideRegionScope = .australia,
        sections: [GuideSection] = [],
        diagrams: [GuideDiagram] = [],
        sources: [GuideSource] = [],
        relatedGuideIDs: [String] = [],
        heroIconName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.summary = summary
        self.steps = steps
        self.notes = notes
        self.tags = tags
        self.estimatedReadMinutes = estimatedReadMinutes
        self.difficulty = difficulty
        self.lastReviewed = lastReviewed
        self.regionScope = regionScope
        self.sections = sections
        self.diagrams = diagrams
        self.sources = sources
        self.relatedGuideIDs = relatedGuideIDs
        self.heroIconName = heroIconName ?? category.systemImage
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case summary
        case steps
        case notes
        case tags
        case estimatedReadMinutes
        case difficulty
        case lastReviewed
        case regionScope
        case sections
        case diagrams
        case sources
        case relatedGuideIDs
        case heroIconName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let title = try container.decode(String.self, forKey: .title)
        let category = try container.decode(GuideCategory.self, forKey: .category)
        let summary = try container.decode(String.self, forKey: .summary)
        let steps = try container.decode([String].self, forKey: .steps)
        let notes = try container.decode(String.self, forKey: .notes)

        self.init(
            id: id,
            title: title,
            category: category,
            summary: summary,
            steps: steps,
            notes: notes,
            tags: try container.decodeIfPresent([String].self, forKey: .tags) ?? [],
            estimatedReadMinutes: max(1, try container.decodeIfPresent(Int.self, forKey: .estimatedReadMinutes) ?? 3),
            difficulty: try container.decodeIfPresent(GuideDifficulty.self, forKey: .difficulty) ?? .standard,
            lastReviewed: try container.decodeIfPresent(String.self, forKey: .lastReviewed) ?? "Bundled offline guide",
            regionScope: try container.decodeIfPresent(GuideRegionScope.self, forKey: .regionScope) ?? .australia,
            sections: try container.decodeIfPresent([GuideSection].self, forKey: .sections) ?? [],
            diagrams: try container.decodeIfPresent([GuideDiagram].self, forKey: .diagrams) ?? [],
            sources: try container.decodeIfPresent([GuideSource].self, forKey: .sources) ?? [],
            relatedGuideIDs: try container.decodeIfPresent([String].self, forKey: .relatedGuideIDs) ?? [],
            heroIconName: try container.decodeIfPresent(String.self, forKey: .heroIconName)
        )
    }

    var contentSections: [GuideSection] {
        if !sections.isEmpty {
            return sections
        }

        return [
            GuideSection(
                id: "\(id)-actions",
                title: "Action Steps",
                summary: nil,
                steps: steps
            )
        ]
    }

    var isIllustrated: Bool {
        !diagrams.isEmpty
    }

    var readingTimeText: String {
        "\(estimatedReadMinutes) min"
    }

    var sourceKinds: [GuideSourceKind] {
        var seen = Set<GuideSourceKind>()
        return sources.compactMap { source in
            guard seen.insert(source.kind).inserted else {
                return nil
            }
            return source.kind
        }
    }

    var searchTerms: [String] {
        ([title, summary] + tags + steps + sections.flatMap(\.steps))
            .joined(separator: " ")
            .lowercased()
            .split(separator: " ")
            .map(String.init)
    }
}

struct GuideLibrary: Codable, Equatable {
    let guides: [Guide]
}
