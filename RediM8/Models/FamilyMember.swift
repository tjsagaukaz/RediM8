import Foundation

struct FamilyMember: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var phone: String
    var medicalNotes: String
    var emergencyRole: String
    var isPrimaryUser: Bool

    init(
        id: UUID = UUID(),
        name: String,
        phone: String,
        medicalNotes: String,
        emergencyRole: String,
        isPrimaryUser: Bool = false
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.medicalNotes = medicalNotes
        self.emergencyRole = emergencyRole
        self.isPrimaryUser = isPrimaryUser
    }

    static let empty = FamilyMember(name: "", phone: "", medicalNotes: "", emergencyRole: "", isPrimaryUser: false)

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case phone
        case medicalNotes
        case emergencyRole
        case isPrimaryUser
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        medicalNotes = try container.decodeIfPresent(String.self, forKey: .medicalNotes) ?? ""
        emergencyRole = try container.decodeIfPresent(String.self, forKey: .emergencyRole) ?? ""
        isPrimaryUser = try container.decodeIfPresent(Bool.self, forKey: .isPrimaryUser) ?? false
    }
}

struct EmergencyContact: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var phone: String

    static let empty = EmergencyContact(name: "", phone: "")
}

struct MeetingPoints: Codable, Equatable {
    var primary: String
    var secondary: String
    var fallback: String

    static let empty = MeetingPoints(primary: "", secondary: "", fallback: "")
}
