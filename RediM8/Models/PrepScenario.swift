import Foundation

enum ScenarioKind: String, CaseIterable, Codable, Identifiable {
    case bushfires
    case floods
    case cyclones
    case powerOutages
    case extremeHeat
    case fuelShortages
    case remoteTravel
    case campingOffGrid
    case severeStorm
    case earthquake
    case extendedInfrastructureDisruption
    case generalEmergencies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bushfires:
            "Bushfire"
        case .floods:
            "Flood"
        case .cyclones:
            "Cyclone"
        case .powerOutages:
            "Power Outage"
        case .extremeHeat:
            "Extreme Heat"
        case .fuelShortages:
            "Fuel Shortage"
        case .remoteTravel:
            "Remote Travel"
        case .campingOffGrid:
            "Camping / Off-Grid"
        case .severeStorm:
            "Severe Storm"
        case .earthquake:
            "Earthquake"
        case .extendedInfrastructureDisruption:
            "Extended Infrastructure Disruption"
        case .generalEmergencies:
            "General Emergency"
        }
    }
}

enum PrepCategory: String, CaseIterable, Codable, Identifiable {
    case water
    case food
    case medical
    case power
    case communication
    case evacuation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water:
            "Water"
        case .food:
            "Food"
        case .medical:
            "Medical"
        case .power:
            "Power"
        case .communication:
            "Communication"
        case .evacuation:
            "Evacuation"
        }
    }

    var systemImage: String {
        switch self {
        case .water:
            "drop.fill"
        case .food:
            "fork.knife"
        case .medical:
            "cross.case.fill"
        case .power:
            "battery.100"
        case .communication:
            "antenna.radiowaves.left.and.right"
        case .evacuation:
            "figure.walk.motion"
        }
    }

    var quickTaskEstimate: String {
        switch self {
        case .water:
            "~10 min task"
        case .food:
            "~15 min task"
        case .medical:
            "~10 min task"
        case .power:
            "~15 min task"
        case .communication:
            "~5 min task"
        case .evacuation:
            "~12 min task"
        }
    }
}

enum PreparednessTaskCategory: String, CaseIterable, Codable, Identifiable {
    case waterStorage
    case foodStorage
    case medicalPreparedness
    case communication
    case powerBackup
    case evacuationPlanning
    case fireSafety
    case floodSafety
    case vehiclePreparedness
    case familyCoordination

    var id: String { rawValue }

    var title: String {
        switch self {
        case .waterStorage:
            "Water Storage"
        case .foodStorage:
            "Food Storage"
        case .medicalPreparedness:
            "Medical Preparedness"
        case .communication:
            "Communication"
        case .powerBackup:
            "Power Backup"
        case .evacuationPlanning:
            "Evacuation Planning"
        case .fireSafety:
            "Fire Safety"
        case .floodSafety:
            "Flood Safety"
        case .vehiclePreparedness:
            "Vehicle Preparedness"
        case .familyCoordination:
            "Family Coordination"
        }
    }

    var scoreCategory: PrepCategory {
        switch self {
        case .waterStorage:
            .water
        case .foodStorage:
            .food
        case .medicalPreparedness:
            .medical
        case .communication, .familyCoordination:
            .communication
        case .powerBackup:
            .power
        case .evacuationPlanning, .fireSafety, .floodSafety, .vehiclePreparedness:
            .evacuation
        }
    }

    var systemImage: String {
        switch self {
        case .waterStorage:
            "drop.fill"
        case .foodStorage:
            "fork.knife"
        case .medicalPreparedness:
            "cross.case.fill"
        case .communication:
            "antenna.radiowaves.left.and.right"
        case .powerBackup:
            "battery.100"
        case .evacuationPlanning:
            "figure.walk.motion"
        case .fireSafety:
            "flame.fill"
        case .floodSafety:
            "water.waves"
        case .vehiclePreparedness:
            "car.fill"
        case .familyCoordination:
            "person.2.fill"
        }
    }

    var quickTaskEstimate: String {
        switch self {
        case .waterStorage:
            "~10 min task"
        case .foodStorage:
            "~15 min task"
        case .medicalPreparedness:
            "~10 min task"
        case .communication:
            "~5 min task"
        case .powerBackup:
            "~15 min task"
        case .evacuationPlanning:
            "~12 min task"
        case .fireSafety:
            "~10 min task"
        case .floodSafety:
            "~10 min task"
        case .vehiclePreparedness:
            "~8 min task"
        case .familyCoordination:
            "~6 min task"
        }
    }
}

enum GearCategory: String, CaseIterable, Codable, Identifiable {
    case water
    case food
    case medical
    case power
    case communication
    case fireSafety
    case tools
    case vehicle
    case lighting
    case navigation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water:
            "Water"
        case .food:
            "Food"
        case .medical:
            "Medical"
        case .power:
            "Power"
        case .communication:
            "Communication"
        case .fireSafety:
            "Fire Safety"
        case .tools:
            "Tools"
        case .vehicle:
            "Vehicle"
        case .lighting:
            "Lighting"
        case .navigation:
            "Navigation"
        }
    }
}

struct PreparednessTask: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let prepScoreValue: Int
    let category: PreparednessTaskCategory
    let recommendedScenarios: [ScenarioKind]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case prepScoreValue = "prep_score_value"
        case category
        case recommendedScenarios = "recommended_scenarios"
    }
}

struct GearItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let category: GearCategory
    let description: String
    let recommendedScenarios: [ScenarioKind]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case description
        case recommendedScenarios = "recommended_scenarios"
    }
}

struct PrepScenario: Identifiable, Codable, Equatable {
    var id: ScenarioKind { kind }
    let kind: ScenarioKind
    let name: String
    let description: String
    let tasks: [String]
    let gear: [String]
    let guides: [String]
    let priorityCategories: [PrepCategory]

    enum CodingKeys: String, CodingKey {
        case kind = "id"
        case name
        case description
        case tasks
        case gear
        case guides
        case priorityCategories = "priority_categories"
    }
}

struct TaskLibrary: Codable, Equatable {
    let tasks: [PreparednessTask]
}

struct GearLibrary: Codable, Equatable {
    let gear: [GearItem]
}

struct ScenarioLibrary: Codable, Equatable {
    let scenarios: [PrepScenario]
}

struct Emergency72HourPlanBlueprint: Codable, Equatable {
    let days: Int
    let waterPerPersonPerDayLitres: Double
    let waterPerPetPerDayLitres: Double
    let minimumFoodCaloriesPerDay: Int
    let recommendedGear: [String]
    let essentialTasks: [String]
    let checklists: [EmergencyPlanChecklistBlueprint]

    enum CodingKeys: String, CodingKey {
        case days
        case waterPerPersonPerDayLitres = "water_per_person_per_day_litres"
        case waterPerPetPerDayLitres = "water_per_pet_per_day_litres"
        case minimumFoodCaloriesPerDay = "minimum_food_calories_per_day"
        case recommendedGear = "recommended_gear"
        case essentialTasks = "essential_tasks"
        case checklists
    }
}

struct EmergencyPlanChecklistBlueprint: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let items: [EmergencyPlanChecklistItemBlueprint]
}

struct EmergencyPlanChecklistItemBlueprint: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
}

struct ResourceCategoryDefinition: Codable, Identifiable, Equatable {
    let id: String
    let icon: String
    let color: String
    let description: String
}

struct ResourceCategoryLibrary: Codable, Equatable {
    let categories: [ResourceCategoryDefinition]
}
