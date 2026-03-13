import Foundation

enum MeshMessageKind: String, Codable, Equatable {
    case direct
    case broadcastAlert
    case locationShare
}

struct SharedLocation: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var label: String
}

struct MeshMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let sender: String
    let recipient: String?
    let body: String
    let timestamp: Date
    let kind: MeshMessageKind
    let location: SharedLocation?

    init(
        id: UUID = UUID(),
        sender: String,
        recipient: String? = nil,
        body: String,
        timestamp: Date = .now,
        kind: MeshMessageKind,
        location: SharedLocation? = nil
    ) {
        self.id = id
        self.sender = sender
        self.recipient = recipient
        self.body = body
        self.timestamp = timestamp
        self.kind = kind
        self.location = location
    }
}
