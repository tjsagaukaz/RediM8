import SwiftUI

enum PlanSection: String, CaseIterable, Identifiable {
    case household
    case vehicleKit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .household:
            "Household"
        case .vehicleKit:
            "Vehicle"
        }
    }

    var detail: String {
        switch self {
        case .household:
            "Go bag, water, family"
        case .vehicleKit:
            "Fuel, recovery, route"
        }
    }

    var iconName: String {
        switch self {
        case .household:
            "checklist"
        case .vehicleKit:
            "vehicle"
        }
    }

    var accent: Color {
        ColorTheme.textTertiary
    }
}

enum HouseholdWorkspace: String, CaseIterable, Identifiable {
    case prepare
    case basics
    case supplies
    case roles
    case scenarios

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prepare:
            "Prepare"
        case .basics:
            "Core Setup"
        case .supplies:
            "Supplies & Storage"
        case .roles:
            "People & Contacts"
        case .scenarios:
            "Risk Scenarios"
        }
    }

    var detail: String {
        switch self {
        case .prepare:
            "Readiness hub"
        case .basics:
            "Routes, kit, go bag"
        case .supplies:
            "Water, food, reserves"
        case .roles:
            "Household, contacts, tasks"
        case .scenarios:
            "Hazard-driven priorities"
        }
    }

    var iconName: String {
        switch self {
        case .prepare, .basics:
            "checklist"
        case .supplies:
            "water"
        case .roles:
            "family"
        case .scenarios:
            "warning"
        }
    }

    var accent: Color {
        ColorTheme.textTertiary
    }

    var planWorkspaceID: PlanWorkspaceID {
        switch self {
        case .prepare, .basics:
            .householdBasics
        case .supplies:
            .householdSupplies
        case .roles:
            .householdRoles
        case .scenarios:
            .householdScenarios
        }
    }
}

enum PrepareDestination: Identifiable {
    case scenario(PrepareScenario)

    var id: String {
        switch self {
        case let .scenario(scenario):
            "scenario:\(scenario.rawValue)"
        }
    }
}

enum PrepareScenario: String, CaseIterable, Identifiable {
    case blackout
    case bushfire
    case flood
    case household

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blackout:
            "Blackout Readiness"
        case .bushfire:
            "Bushfire Preparation"
        case .flood:
            "Flood Readiness"
        case .household:
            "Household Preparedness"
        }
    }

    var subtitle: String {
        switch self {
        case .blackout:
            "Stay operational when power and networks fail."
        case .bushfire:
            "Prepare early and reduce risk before conditions escalate."
        case .flood:
            "Protect critical items and move safely if water rises."
        case .household:
            "Build a baseline level of safety for everyday emergencies."
        }
    }

    var iconName: String {
        switch self {
        case .blackout:
            "battery"
        case .bushfire:
            "fire_trail"
        case .flood:
            "flood"
        case .household:
            "checklist"
        }
    }

    var overview: String {
        switch self {
        case .blackout:
            "Power outages can disrupt lighting, communication, refrigeration, and access to essential services. Prepare the basics before the next outage starts."
        case .bushfire:
            "Bushfire preparation works best before smoke, traffic, and warnings compress your decision window. Focus on leave-ready basics and protective gear early."
        case .flood:
            "Flood readiness is about moving early, protecting essential items, and avoiding routes that can become dangerous quickly once water starts rising."
        case .household:
            "A simple baseline across water, first aid, communication, and documents makes every other emergency easier to handle calmly."
        }
    }

    var coreNeeds: [String] {
        switch self {
        case .blackout:
            ["Lighting", "Backup power", "Communication", "Water supply"]
        case .bushfire:
            ["Leave-ready kit", "Protective masks", "Communication", "Documents and essentials"]
        case .flood:
            ["Waterproof storage", "Safe drinking water", "Communication", "Higher-ground readiness"]
        case .household:
            ["Water", "First aid", "Communication", "Documents and family contacts"]
        }
    }

    var gearTypes: [GearType] {
        switch self {
        case .blackout:
            [.lighting, .backupPower, .communicationRadio, .waterStorage]
        case .bushfire:
            [.goBagBundle, .respiratoryMasks, .communicationRadio, .documentProtection, .fireBlanket]
        case .flood:
            [.waterproofStorage, .waterPurification, .communicationRadio, .waterStorage]
        case .household:
            [.goBagBundle, .waterStorage, .firstAid, .communicationRadio, .documentProtection]
        }
    }

    var scenarioOverrides: [ScenarioKind] {
        switch self {
        case .blackout:
            [.powerOutages]
        case .bushfire:
            [.bushfires]
        case .flood:
            [.floods]
        case .household:
            [.generalEmergencies]
        }
    }

    var guideIDs: [String] {
        switch self {
        case .blackout:
            ["generator_safety_after_storm", "shelter_in_place_steps", "household_evacuation_quick_start"]
        case .bushfire:
            ["bushfire_leave_early_plan", "smoke_exposure_reduction", "household_evacuation_quick_start"]
        case .flood:
            ["flood_evacuation_timing", "boil_filter_disinfect_water", "shelter_in_place_steps"]
        case .household:
            ["household_evacuation_quick_start", "shelter_in_place_steps", "boil_filter_disinfect_water"]
        }
    }
}
