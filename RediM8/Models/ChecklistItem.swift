import Foundation

enum ChecklistItemKind: String, CaseIterable, Codable, Identifiable {
    case firstAidKit
    case batteryRadio
    case torch
    case powerBank
    case fireBlanket

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstAidKit:
            "First aid kit"
        case .batteryRadio:
            "Battery radio"
        case .torch:
            "Torch"
        case .powerBank:
            "Power bank"
        case .fireBlanket:
            "Fire blanket"
        }
    }
}

struct ChecklistItem: Identifiable, Codable, Equatable {
    var id: ChecklistItemKind { kind }
    let kind: ChecklistItemKind
    var isChecked: Bool

    static let defaults = ChecklistItemKind.allCases.map {
        ChecklistItem(kind: $0, isChecked: false)
    }
}
