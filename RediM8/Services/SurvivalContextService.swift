import CoreLocation
import Foundation

// MARK: - Survival Risk Model

enum SurvivalRiskLevel: Int, Comparable {
    case low = 0
    case moderate = 1
    case high = 2
    case critical = 3

    static func < (lhs: SurvivalRiskLevel, rhs: SurvivalRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .low: "LOW"
        case .moderate: "MODERATE"
        case .high: "ACTION REQUIRED"
        case .critical: "IMMEDIATE ACTION REQUIRED"
        }
    }
}

struct SurvivalContextState {
    let waterRisk: SurvivalRiskLevel
    let shelterRisk: SurvivalRiskLevel
    let navigationRisk: SurvivalRiskLevel
    let isolationRisk: SurvivalRiskLevel
    let powerRisk: SurvivalRiskLevel

    let waterDetail: String?
    let shelterDetail: String?
    let navigationDetail: String?
    let isolationDetail: String?
    let powerDetail: String?

    var highestRisk: SurvivalRiskLevel {
        [waterRisk, shelterRisk, navigationRisk, isolationRisk, powerRisk].max() ?? .low
    }

    /// Returns risk categories at or above a given threshold, sorted by severity descending.
    func risks(atOrAbove threshold: SurvivalRiskLevel) -> [(category: String, level: SurvivalRiskLevel, detail: String?)] {
        let all: [(String, SurvivalRiskLevel, String?)] = [
            ("water", waterRisk, waterDetail),
            ("shelter", shelterRisk, shelterDetail),
            ("navigation", navigationRisk, navigationDetail),
            ("isolation", isolationRisk, isolationDetail),
            ("power", powerRisk, powerDetail),
        ]
        return all
            .filter { $0.1 >= threshold }
            .sorted { $0.1 > $1.1 }
            .map { (category: $0.0, level: $0.1, detail: $0.2) }
    }
}

// MARK: - Survival Context Service

@MainActor
final class SurvivalContextService {
    private let waterPointService: WaterPointService
    private let shelterService: ShelterService
    private let waterRuntimeService: WaterRuntimeService
    private let meshService: MeshService
    private let batteryService: BatteryService
    private let mapDataService: MapDataService
    private let guideService: GuideService
    private let profileProvider: () -> UserProfile
    private let scenarioProvider: () -> [PrepScenario]
    private let locationProvider: () -> CLLocation?

    init(
        waterPointService: WaterPointService,
        shelterService: ShelterService,
        waterRuntimeService: WaterRuntimeService,
        meshService: MeshService,
        batteryService: BatteryService,
        mapDataService: MapDataService,
        guideService: GuideService,
        profileProvider: @escaping () -> UserProfile,
        scenarioProvider: @escaping () -> [PrepScenario],
        locationProvider: @escaping () -> CLLocation?
    ) {
        self.waterPointService = waterPointService
        self.shelterService = shelterService
        self.waterRuntimeService = waterRuntimeService
        self.meshService = meshService
        self.batteryService = batteryService
        self.mapDataService = mapDataService
        self.guideService = guideService
        self.profileProvider = profileProvider
        self.scenarioProvider = scenarioProvider
        self.locationProvider = locationProvider
    }

    // MARK: - Compute State

    func computeState() -> SurvivalContextState {
        let location = locationProvider()
        let profile = profileProvider()
        let survival = profile.survivalProfile
        let installedPackIDs = mapDataService.loadInstalledPackIDs()

        return SurvivalContextState(
            waterRisk: assessWaterRisk(profile: profile, survival: survival, location: location, installedPackIDs: installedPackIDs),
            shelterRisk: assessShelterRisk(survival: survival, location: location, installedPackIDs: installedPackIDs),
            navigationRisk: assessNavigationRisk(location: location),
            isolationRisk: assessIsolationRisk(survival: survival),
            powerRisk: assessPowerRisk(),
            waterDetail: waterDetailText(profile: profile),
            shelterDetail: shelterDetailText(location: location, installedPackIDs: installedPackIDs),
            navigationDetail: navigationDetailText(location: location),
            isolationDetail: isolationDetailText(),
            powerDetail: powerDetailText()
        )
    }

    // MARK: - Proactive Guides

    /// Returns guide recommendations based on current survival risk state.
    /// Max 2 categories, 5 guides total — avoids spamming the user.
    func proactiveGuides(for state: SurvivalContextState) -> [Guide] {
        let highRisks = state.risks(atOrAbove: .high)
        guard !highRisks.isEmpty else { return [] }

        var guides: [Guide] = []
        var seenIDs = Set<String>()

        for risk in highRisks.prefix(2) {
            let categoryGuides = guidesForRisk(risk.category)
            for guide in categoryGuides where !seenIDs.contains(guide.id) {
                seenIDs.insert(guide.id)
                guides.append(guide)
            }
        }

        return Array(guides.prefix(5))
    }

    /// Builds context sections for survival warnings to inject into assistant responses.
    /// Sections are numbered by priority (1 = most urgent) to reduce decision fatigue.
    func contextSections(for state: SurvivalContextState) -> [AssistantContextSection] {
        let risks = state.risks(atOrAbove: .high)
        guard !risks.isEmpty else { return [] }

        var sections: [AssistantContextSection] = []

        for (index, risk) in risks.prefix(2).enumerated() {
            let tone: AssistantContextTone = risk.level == .critical ? .danger : .warning
            let guides = guidesForRisk(risk.category)

            let items = guides.prefix(3).map { guide in
                AssistantContextItem(
                    title: guide.title,
                    detail: String(guide.summary.prefix(120)) + (guide.summary.count > 120 ? "…" : ""),
                    actions: [.openGuide(guideID: guide.id)]
                )
            }

            let priorityPrefix = risks.count > 1 ? "\(index + 1). " : ""
            let title = "\(priorityPrefix)\(sectionTitle(for: risk.category, level: risk.level))"

            // Combine current state detail with predictive estimate if available
            let predictiveNote = predictiveWarning(for: risk.category, state: state)
            let detail: String
            if let current = risk.detail, let predicted = predictiveNote {
                detail = "\(current) \(predicted)"
            } else if let predicted = predictiveNote {
                detail = predicted
            } else {
                detail = risk.detail ?? "Survival risk detected based on current conditions."
            }

            sections.append(AssistantContextSection(
                id: "survival-\(risk.category)",
                title: title,
                detail: detail,
                tone: tone,
                items: items
            ))
        }

        return sections
    }

    // MARK: - Risk Assessment

    private func assessWaterRisk(
        profile: UserProfile,
        survival: SurvivalProfile,
        location: CLLocation?,
        installedPackIDs: Set<String>
    ) -> SurvivalRiskLevel {
        let estimate = waterRuntimeService.estimate(for: profile, scenarios: scenarioProvider())

        // Remote regions escalate water risk faster — less chance of resupply
        let remoteMultiplier: Double = survival.regionType.isRemote ? 1.5 : 1.0
        let adjustedDays = estimate.estimatedDays / remoteMultiplier

        if adjustedDays < 1 {
            return .critical
        }
        if adjustedDays < 3 {
            if let coordinate = location?.coordinate {
                let nearbyWater = waterPointService.nearbyWaterPoints(
                    near: coordinate,
                    installedPackIDs: installedPackIDs,
                    limit: 1
                )
                return nearbyWater.isEmpty ? .critical : .high
            }
            return .high
        }
        if adjustedDays < 5 {
            return .moderate
        }
        return .low
    }

    private func assessShelterRisk(
        survival: SurvivalProfile,
        location: CLLocation?,
        installedPackIDs: Set<String>
    ) -> SurvivalRiskLevel {
        let hour = Calendar.current.component(.hour, from: Date())
        let isNightApproaching = hour >= 16 || hour < 6

        // If user has a vehicle, shelter risk is lower — they have a mobile shelter
        if survival.hasVehicle {
            return isNightApproaching && survival.regionType.isRemote ? .moderate : .low
        }

        guard let coordinate = location?.coordinate else {
            return isNightApproaching ? .moderate : .low
        }

        let nearbyShelters = shelterService.nearbyShelters(
            near: coordinate,
            installedPackIDs: installedPackIDs,
            limit: 1
        )

        if nearbyShelters.isEmpty && isNightApproaching {
            return .high
        }
        if nearbyShelters.isEmpty {
            return .moderate
        }
        return .low
    }

    private func assessNavigationRisk(location: CLLocation?) -> SurvivalRiskLevel {
        guard let location else {
            // No location at all — can't navigate
            return .high
        }

        // Check GPS accuracy
        if location.horizontalAccuracy > 500 {
            return .high
        }
        if location.horizontalAccuracy > 100 {
            return .moderate
        }
        return .low
    }

    private func assessIsolationRisk(survival: SurvivalProfile) -> SurvivalRiskLevel {
        let peerCount = meshService.connectedPeers.count + meshService.nearbyPeers.count

        if peerCount == 0 && survival.regionType.isRemote {
            return .high
        }
        if peerCount == 0 {
            return .moderate
        }
        return .low
    }

    private func assessPowerRisk() -> SurvivalRiskLevel {
        let status = batteryService.status

        guard let level = status.level else {
            return .low
        }

        if level <= 0.05 {
            return .critical
        }
        if status.isBelowSurvivalThreshold {
            return .high
        }
        if level <= 0.30 {
            return .moderate
        }
        return .low
    }

    // MARK: - Detail Text

    private func waterDetailText(profile: UserProfile) -> String? {
        let estimate = waterRuntimeService.estimate(for: profile, scenarios: scenarioProvider())
        if estimate.estimatedDays < 1 {
            return "Less than 1 day of water remaining at current usage. Finding water is your top priority."
        }
        if estimate.estimatedDays < 3 {
            return "Only \(estimate.estimatedDaysText) of water remaining. Consider sourcing additional water now."
        }
        return nil
    }

    private func shelterDetailText(location: CLLocation?, installedPackIDs: Set<String>) -> String? {
        let hour = Calendar.current.component(.hour, from: Date())
        let isNightApproaching = hour >= 16 || hour < 6

        if let coordinate = location?.coordinate {
            let nearbyShelters = shelterService.nearbyShelters(
                near: coordinate,
                installedPackIDs: installedPackIDs,
                limit: 1
            )
            if nearbyShelters.isEmpty && isNightApproaching {
                return "Night approaching with no known shelters nearby. Consider building or finding shelter before dark."
            }
        } else if isNightApproaching {
            return "Night approaching. Enable location to find nearby shelters, or prepare to build one."
        }
        return nil
    }

    private func navigationDetailText(location: CLLocation?) -> String? {
        guard let location else {
            return "No GPS signal. Use sun position, terrain features, or the Southern Cross to establish direction."
        }
        if location.horizontalAccuracy > 500 {
            return "GPS accuracy is poor (\(Int(location.horizontalAccuracy))m). Consider terrain-based navigation as backup."
        }
        return nil
    }

    private func isolationDetailText() -> String? {
        let peerCount = meshService.connectedPeers.count + meshService.nearbyPeers.count
        if peerCount == 0 {
            return "No nearby devices detected. Consider signal fires or ground signals if you need rescue."
        }
        return nil
    }

    private func powerDetailText() -> String? {
        guard let level = batteryService.status.level else { return nil }
        if level <= 0.05 {
            return "Battery critical (\(Int(level * 100))%). Conserve power — disable non-essential features."
        }
        if batteryService.status.isBelowSurvivalThreshold {
            return "Battery low (\(Int(level * 100))%). Consider reducing screen brightness and enabling stealth mode."
        }
        return nil
    }

    // MARK: - Guide Mapping

    private func guidesForRisk(_ category: String) -> [Guide] {
        switch category {
        case "water":
            return guideService.guides(ids: [
                "find_water_from_terrain",
                "solar_still_construction",
                "morning_condensation_collection",
                "water_rationing_survival"
            ])
        case "shelter":
            return guideService.guides(ids: [
                "debris_hut_shelter",
                "lean_to_shelter",
                "ground_insulation_critical"
            ])
        case "navigation":
            return guideService.guides(ids: [
                "sun_navigation_southern",
                "terrain_based_navigation",
                "dont_get_lost_protocols"
            ])
        case "isolation":
            return guideService.guides(ids: [
                "signal_fires",
                "ground_signals_air_rescue",
                "radio_basics_uhf_cb"
            ])
        case "power":
            return guideService.guides(ids: [
                "vehicle_battery_survival"
            ])
        default:
            return []
        }
    }

    private func sectionTitle(for category: String, level: SurvivalRiskLevel) -> String {
        let urgency = level == .critical ? "IMMEDIATE ACTION REQUIRED" : "ACTION REQUIRED"
        switch category {
        case "water": return "\(urgency) — WATER"
        case "shelter": return "\(urgency) — SHELTER"
        case "navigation": return "\(urgency) — NAVIGATION"
        case "isolation": return "\(urgency) — ISOLATION"
        case "power": return "\(urgency) — POWER"
        default: return urgency
        }
    }

    // MARK: - Predictive Warnings

    /// Estimates time until a risk becomes critical based on current consumption/state.
    private func predictiveWarning(for category: String, state: SurvivalContextState) -> String? {
        switch category {
        case "water":
            return predictiveWaterWarning(currentLevel: state.waterRisk)
        case "power":
            return predictivePowerWarning(currentLevel: state.powerRisk)
        default:
            return nil
        }
    }

    private func predictiveWaterWarning(currentLevel: SurvivalRiskLevel) -> String? {
        guard currentLevel < .critical else { return nil }

        let profile = profileProvider()
        let estimate = waterRuntimeService.estimate(for: profile, scenarios: scenarioProvider())

        guard estimate.estimatedDays.isFinite, estimate.estimatedDays > 0 else { return nil }

        // Time until critical (< 1 day remaining)
        let daysUntilCritical = max(estimate.estimatedDays - 1, 0)

        if daysUntilCritical < 0.25 {
            return "Water will be critical in ~\(Int(daysUntilCritical * 24)) hours at current usage."
        }
        if daysUntilCritical < 1 {
            let hours = Int(daysUntilCritical * 24)
            return "Water will be critical in ~\(hours) hour\(hours == 1 ? "" : "s") at current usage."
        }
        if daysUntilCritical < 3 {
            return "Water will be critical in ~\(String(format: "%.1f", daysUntilCritical)) days at current usage."
        }

        return nil
    }

    private func predictivePowerWarning(currentLevel: SurvivalRiskLevel) -> String? {
        guard currentLevel < .critical else { return nil }
        guard let level = batteryService.status.level, level > 0.05 else { return nil }

        // Rough estimate: if battery is draining and below 30%, warn
        if level <= 0.20 {
            return "Battery approaching critical levels. Reduce usage to extend device life."
        }

        return nil
    }
}
