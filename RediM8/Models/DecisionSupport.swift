import Foundation

enum PrioritySituation: String, CaseIterable, Codable, Identifiable, Equatable {
    case bushfire
    case flood
    case blackout
    case remoteTravel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bushfire:
            "Bushfire"
        case .flood:
            "Flood"
        case .blackout:
            "Blackout"
        case .remoteTravel:
            "Remote Travel"
        }
    }

    var summaryTitle: String {
        "\(title) Priority Mode"
    }

    var systemImage: String {
        switch self {
        case .bushfire:
            "fire_trail"
        case .flood:
            "water"
        case .blackout:
            "flashlight"
        case .remoteTravel:
            "four_wd"
        }
    }

    var scenarioKind: ScenarioKind {
        switch self {
        case .bushfire:
            .bushfires
        case .flood:
            .floods
        case .blackout:
            .powerOutages
        case .remoteTravel:
            .remoteTravel
        }
    }
}

struct PriorityAction: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
}

struct PriorityResource: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
}

struct PriorityModeSummary: Equatable {
    let situation: PrioritySituation
    let title: String
    let subtitle: String
    let actions: [PriorityAction]
    let resources: [PriorityResource]
    let evacuationOptions: [String]
}

struct LeaveNowAction: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
}
