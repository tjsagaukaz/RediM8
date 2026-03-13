import Foundation

struct VehicleKitItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let isCritical: Bool
}

struct VehicleReadinessPlan: Equatable {
    let readiness: GoBagReadiness
    let items: [VehicleKitItem]
    let scenarioTitles: [String]
    let contextLines: [String]
    let nextActions: [String]
}
