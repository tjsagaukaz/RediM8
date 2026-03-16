import Foundation

enum MeshMessageKind: String, Codable, Equatable {
    case direct
    case broadcastAlert
    case locationShare
    case accountabilityStatus = "accountability_status"
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

struct MeshMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let sender: String
    let recipient: String?
    let body: String
    let timestamp: Date
    let kind: MeshMessageKind
    let location: SharedLocation?
    let accountabilityStatus: AccountabilityMeshStatus?

    init(
        id: UUID = UUID(),
        sender: String,
        recipient: String? = nil,
        body: String,
        timestamp: Date = .now,
        kind: MeshMessageKind,
        location: SharedLocation? = nil,
        accountabilityStatus: AccountabilityMeshStatus? = nil
    ) {
        self.id = id
        self.sender = sender
        self.recipient = recipient
        self.body = body
        self.timestamp = timestamp
        self.kind = kind
        self.location = location
        self.accountabilityStatus = accountabilityStatus
    }
}
