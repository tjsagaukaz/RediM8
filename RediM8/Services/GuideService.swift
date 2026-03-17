import Foundation

enum GuideCollection: String, CaseIterable, Identifiable {
    case emergency
    case illustrated
    case bushcraft
    case food
    case growing
    case survivalWater
    case survivalFire
    case survivalShelter
    case survivalFood
    case survivalField

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emergency:
            "Emergency Cards"
        case .illustrated:
            "Illustrated Skills"
        case .bushcraft:
            "Bushcraft Skills"
        case .food:
            "Field Cooking"
        case .growing:
            "Grow Food"
        case .survivalWater:
            "Find Water"
        case .survivalFire:
            "Make Fire"
        case .survivalShelter:
            "Build Shelter"
        case .survivalFood:
            "Find Food"
        case .survivalField:
            "Field Survival"
        }
    }

    var subtitle: String {
        switch self {
        case .emergency:
            "Short action lists for the highest-stress moments."
        case .illustrated:
            "Visual step guides and diagrams that stay offline."
        case .bushcraft:
            "Shelter, knots, navigation, and fieldcraft."
        case .food:
            "Simple pantry, camp, and blackout cooking."
        case .growing:
            "Fast-growing staples and practical garden setup."
        case .survivalWater:
            "Finding and sourcing water with nothing."
        case .survivalFire:
            "Starting and maintaining fire without tools."
        case .survivalShelter:
            "Extended shelter from natural materials."
        case .survivalFood:
            "Trapping, foraging, and insect protein."
        case .survivalField:
            "Comms, navigation, sanitation, and psychology."
        }
    }

    /// True for collections in the no-infrastructure survival library.
    var isSurvivalCollection: Bool {
        switch self {
        case .survivalWater, .survivalFire, .survivalShelter, .survivalFood, .survivalField:
            true
        default:
            false
        }
    }
}

final class GuideService {
    private let dataService: PreparednessDataService

    private static let baseEmergencyCardIDs = [
        "snake_bite_first_aid",
        "cpr_basics",
        "major_bleeding_control",
        "household_evacuation_quick_start",
        "official_warning_monitoring"
    ]

    private static let scenarioEmergencyCardIDs: [ScenarioKind: [String]] = [
        .bushfires: ["bushfire_leave_early_plan", "burns_first_aid"],
        .cyclones: ["cyclone_pre_landfall_actions", "severe_storm_room_setup"],
        .floods: ["flood_evacuation_timing", "turn_around_dont_drown"],
        .severeStorm: ["severe_storm_room_setup", "downed_powerline_safety"],
        .extremeHeat: ["heat_exhaustion_vs_heatstroke", "prevent_dehydration_in_extreme_heat"],
        .generalEmergencies: ["shelter_in_place_steps"]
    ]

    init(dataService: PreparednessDataService) {
        self.dataService = dataService
    }

    convenience init(bundle: Bundle = .main) {
        self.init(dataService: PreparednessDataService(store: nil, bundle: bundle))
    }

    func allGuides() -> [Guide] {
        dataService.guides().sorted { $0.title < $1.title }
    }

    func guides(ids: [String]) -> [Guide] {
        let guideIndex = dataService.guideIndex()
        return orderedUnique(ids).compactMap { guideIndex[$0] }
    }

    func guide(id: String) -> Guide? {
        dataService.guideIndex()[id]
    }

    func emergencyCards(for scenarioKinds: [ScenarioKind], limit: Int = 4) -> [Guide] {
        let scenarioSpecific = orderedUnique(
            scenarioKinds.flatMap { Self.scenarioEmergencyCardIDs[$0] ?? [] }
        )

        let orderedIDs = orderedUnique(scenarioSpecific + Self.baseEmergencyCardIDs)
        return orderedUnique(orderedIDs)
            .compactMap { dataService.guideIndex()[$0] }
            .prefix(limit)
            .map { $0 }
    }

    func allEmergencyCards() -> [Guide] {
        let orderedIDs = orderedUnique(
            Array(Self.scenarioEmergencyCardIDs.values.joined()) + Self.baseEmergencyCardIDs
        )
        let guideIndex = dataService.guideIndex()
        return orderedIDs.compactMap { guideIndex[$0] }
    }

    func guides(in category: GuideCategory) -> [Guide] {
        allGuides().filter { $0.category == category }
    }

    func illustratedGuides() -> [Guide] {
        allGuides().filter(\.isIllustrated)
    }

    func featuredCollection(_ collection: GuideCollection, limit: Int = 8) -> [Guide] {
        let guides: [Guide]

        switch collection {
        case .emergency:
            guides = allEmergencyCards()
        case .illustrated:
            guides = illustratedGuides()
        case .bushcraft:
            guides = allGuides().filter { [.bushcraft, .navigation, .waterSafety].contains($0.category) }
        case .food:
            guides = allGuides().filter { [.foodCooking, .waterSafety].contains($0.category) }
        case .growing:
            guides = allGuides().filter { $0.category == .foodGrowing }
        case .survivalWater:
            guides = allGuides().filter { $0.category == .waterSourcing }
        case .survivalFire:
            guides = allGuides().filter { $0.category == .firecraft }
        case .survivalShelter:
            guides = allGuides().filter { $0.category == .shelterBuilding }
        case .survivalFood:
            guides = allGuides().filter { $0.category == .trapping }
        case .survivalField:
            guides = allGuides().filter {
                [.fieldComms, .navigationAdvanced, .sanitation, .psychology, .vehicleSurvival].contains($0.category)
            }
        }

        return Array(guides.prefix(limit))
    }

    /// All guides from survival primitive categories.
    func survivalGuides() -> [Guide] {
        allGuides().filter { $0.category.isSurvivalPrimitive }
    }

    func searchGuides(query: String, category: GuideCategory? = nil) -> [Guide] {
        let normalized = normalizedTokens(for: query)
        let scoped = category.map(guides(in:)) ?? allGuides()

        guard !normalized.isEmpty else {
            return scoped
        }

        return scoped
            .map { guide in
                (guide, score(for: guide, tokens: normalized))
            }
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.title < rhs.0.title
                }
                return lhs.1 > rhs.1
            }
            .map(\.0)
    }

    private func normalizedTokens(for query: String) -> Set<String> {
        Set(
            query
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { $0.count > 1 }
        )
    }

    private func score(for guide: Guide, tokens: Set<String>) -> Int {
        guard !tokens.isEmpty else {
            return 0
        }

        let searchTerms = guide.searchTerms
        var score = 0

        for token in tokens {
            if guide.title.lowercased().contains(token) {
                score += 5
            }
            if guide.summary.lowercased().contains(token) {
                score += 3
            }
            if searchTerms.contains(token) {
                score += 1
            }
        }

        return score
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
