import Foundation

struct EmergencySupplyTarget: Identifiable, Equatable {
    let id: String
    let title: String
    let required: Double
    let current: Double
    let unit: String

    var gap: Double {
        max(required - current, 0)
    }
}

struct EmergencyChecklistItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
}

struct EmergencyChecklistSection: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [EmergencyChecklistItem]
}

struct Emergency72HourPlan: Equatable {
    let days: Int
    let waterPerPersonPerDayLitres: Double
    let foodCaloriesPerPersonPerDay: Int
    let waterRequiredLitres: Double
    let foodRequiredCalories: Int
    let supplyTargets: [EmergencySupplyTarget]
    let recommendedGear: [GearItem]
    let essentialTasks: [PreparednessTask]
    let checklists: [EmergencyChecklistSection]
}

final class EmergencyPlanService {
    private enum StorageKey {
        static let completedChecklist = "emergency72hour.completedChecklist.v1"
    }

    private let dataService: PreparednessDataService
    private let scenarioEngine: ScenarioEngine
    private let store: SQLiteStore?

    init(dataService: PreparednessDataService, scenarioEngine: ScenarioEngine, store: SQLiteStore?) {
        self.dataService = dataService
        self.scenarioEngine = scenarioEngine
        self.store = store
    }

    func generatePlan(for profile: UserProfile) -> Emergency72HourPlan {
        let blueprint = dataService.emergency72HourPlanBlueprint()
        let householdSize = Double(max(profile.household.peopleCount, 1))
        let pets = Double(max(profile.household.petCount, 0))
        let days = max(blueprint.days, 3)

        let waterRequired = householdSize * blueprint.waterPerPersonPerDayLitres * Double(days)
            + pets * blueprint.waterPerPetPerDayLitres * Double(days)
        let foodRequiredCalories = Int(householdSize) * blueprint.minimumFoodCaloriesPerDay * days

        let scenarioTaskIDs = scenarioEngine.personalizedTasks(for: profile).prefix(8).map(\.id)
        let scenarioGearIDs = scenarioEngine.recommendedGear(for: profile).prefix(8).map(\.id)
        let taskIndex = dataService.taskIndex()
        let gearIndex = dataService.gearIndex()

        let essentialTasks = orderedUnique(blueprint.essentialTasks + scenarioTaskIDs)
            .compactMap { taskIndex[$0] }
        let recommendedGear = orderedUnique(blueprint.recommendedGear + scenarioGearIDs)
            .compactMap { gearIndex[$0] }

        return Emergency72HourPlan(
            days: days,
            waterPerPersonPerDayLitres: blueprint.waterPerPersonPerDayLitres,
            foodCaloriesPerPersonPerDay: blueprint.minimumFoodCaloriesPerDay,
            waterRequiredLitres: waterRequired,
            foodRequiredCalories: foodRequiredCalories,
            supplyTargets: buildSupplyTargets(for: profile, waterRequired: waterRequired),
            recommendedGear: recommendedGear,
            essentialTasks: essentialTasks,
            checklists: blueprint.checklists.map { section in
                EmergencyChecklistSection(
                    id: section.id,
                    title: section.title,
                    items: section.items.map { item in
                        EmergencyChecklistItem(id: item.id, title: item.title, detail: item.detail)
                    }
                )
            }
        )
    }

    func loadCompletedChecklistItemIDs() -> Set<String> {
        guard let store else {
            return []
        }

        let stored = (try? store.load([String].self, for: StorageKey.completedChecklist)) ?? []
        return Set(stored)
    }

    func saveCompletedChecklistItemIDs(_ ids: Set<String>) {
        try? store?.save(ids.sorted(), for: StorageKey.completedChecklist)
    }

    private func buildSupplyTargets(for profile: UserProfile, waterRequired: Double) -> [EmergencySupplyTarget] {
        let selected = Set(profile.selectedScenarios)
        let fuelTarget: Double
        if selected.contains(.fuelShortages) || selected.contains(.remoteTravel) {
            fuelTarget = 40
        } else if selected.contains(.bushfires) || selected.contains(.cyclones) || selected.contains(.severeStorm) {
            fuelTarget = 25
        } else {
            fuelTarget = 15
        }

        let batteryTarget: Double
        if selected.contains(.powerOutages) || selected.contains(.cyclones) || selected.contains(.severeStorm) || selected.contains(.extendedInfrastructureDisruption) {
            batteryTarget = 80
        } else {
            batteryTarget = 60
        }

        return [
            EmergencySupplyTarget(
                id: "water",
                title: "Water",
                required: waterRequired,
                current: profile.supplies.waterLitres,
                unit: "L"
            ),
            EmergencySupplyTarget(
                id: "food",
                title: "Food",
                required: 3,
                current: profile.supplies.foodDays,
                unit: "days"
            ),
            EmergencySupplyTarget(
                id: "fuel",
                title: "Fuel",
                required: fuelTarget,
                current: profile.supplies.fuelLitres,
                unit: "L"
            ),
            EmergencySupplyTarget(
                id: "battery",
                title: "Battery",
                required: batteryTarget,
                current: profile.supplies.batteryCapacity,
                unit: "%"
            )
        ]
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
