import Foundation

enum MeshMessageKind: String, Codable, Equatable {
    case direct
    case broadcastAlert
    case locationShare
    case accountabilityStatus = "accountability_status"
    case routeShare = "route_share"
    case hazardReport = "hazard_report"
}

struct SharedLocation: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var label: String
}

struct AccountabilityMeshStatus: Codable, Equatable {
    var circleTitle: String
    var memberName: String
    var status: AccountabilityStatus
    var note: String
    var updatedAt: Date

    init(
        circleTitle: String,
        memberName: String,
        status: AccountabilityStatus,
        note: String = "",
        updatedAt: Date = .now
    ) {
        self.circleTitle = circleTitle
        self.memberName = memberName
        self.status = status
        self.note = note
        self.updatedAt = updatedAt
    }
}

/// Shared evacuation route data sent over mesh network.
struct SharedRouteData: Codable, Equatable {
    let destination: String
    let distanceMetres: Double
    let durationSeconds: Double
    let profile: String // vehicle, 4wd, foot, emergency
    let waterSourceCount: Int
    let shelterCount: Int
    let hazardExposure: Double
    /// Simplified waypoints (max 20) for map display — not full polyline.
    let waypoints: [SharedLocation]
    let computedAt: Date
}

/// Shared hazard report sent over mesh network.
struct SharedHazardReport: Codable, Equatable {
    let kind: String // flood, fire, storm_surge, road_closure
    let latitude: Double
    let longitude: Double
    let radiusMetres: Double
    let severity: String // low, moderate, high, critical
    let description: String
    let reportedAt: Date
}

struct MeshMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let sender: String
    let recipient: String?
    let body: String
    let timestamp: Date
    let kind: MeshMessageKind
    let location: SharedLocation?
    let accountabilityStatus: AccountabilityMeshStatus?
    let routeData: SharedRouteData?
    let hazardReport: SharedHazardReport?

    init(
        id: UUID = UUID(),
        sender: String,
        recipient: String? = nil,
        body: String,
        timestamp: Date = .now,
        kind: MeshMessageKind,
        location: SharedLocation? = nil,
        accountabilityStatus: AccountabilityMeshStatus? = nil,
        routeData: SharedRouteData? = nil,
        hazardReport: SharedHazardReport? = nil
    ) {
        self.id = id
        self.sender = sender
        self.recipient = recipient
        self.body = body
        self.timestamp = timestamp
        self.kind = kind
        self.location = location
        self.accountabilityStatus = accountabilityStatus
        self.routeData = routeData
        self.hazardReport = hazardReport
    }
}
