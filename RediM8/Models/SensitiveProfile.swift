import Foundation

struct SensitiveProfile: Codable, Equatable {
    var familyMembers: [FamilyMember]
    var emergencyContacts: [EmergencyContact]
    var medicalNotes: String
    var emergencyMedicalInfo: EmergencyMedicalInfo
    var meetingPoints: MeetingPoints
    var evacuationRoutes: [String]
    var accountabilityCircle: AccountabilityCircle

    init(
        familyMembers: [FamilyMember] = [],
        emergencyContacts: [EmergencyContact] = [],
        medicalNotes: String = "",
        emergencyMedicalInfo: EmergencyMedicalInfo = .empty,
        meetingPoints: MeetingPoints = .empty,
        evacuationRoutes: [String] = [],
        accountabilityCircle: AccountabilityCircle = .empty
    ) {
        self.familyMembers = familyMembers
        self.emergencyContacts = emergencyContacts
        self.medicalNotes = medicalNotes
        self.emergencyMedicalInfo = emergencyMedicalInfo
        self.meetingPoints = meetingPoints
        self.evacuationRoutes = evacuationRoutes
        self.accountabilityCircle = accountabilityCircle
    }

    static let empty = SensitiveProfile()

    var hasAnyContent: Bool {
        !familyMembers.isEmpty
            || !emergencyContacts.isEmpty
            || medicalNotes.nilIfBlank != nil
            || emergencyMedicalInfo.hasAnyContent
            || meetingPoints != .empty
            || evacuationRoutes.contains { $0.nilIfBlank != nil }
            || !accountabilityCircle.members.isEmpty
            || accountabilityCircle.title != AccountabilityCircle.empty.title
    }
}

extension UserProfile {
    var sensitiveProfile: SensitiveProfile {
        SensitiveProfile(
            familyMembers: familyMembers,
            emergencyContacts: emergencyContacts,
            medicalNotes: medicalNotes,
            emergencyMedicalInfo: emergencyMedicalInfo,
            meetingPoints: meetingPoints,
            evacuationRoutes: evacuationRoutes,
            accountabilityCircle: accountabilityCircle
        )
    }

    var redactedForStandardStorage: UserProfile {
        var redacted = self
        redacted.familyMembers = []
        redacted.emergencyContacts = []
        redacted.medicalNotes = ""
        redacted.emergencyMedicalInfo = .empty
        redacted.meetingPoints = .empty
        redacted.evacuationRoutes = []
        redacted.accountabilityCircle = .empty
        return redacted
    }

    var hasSensitiveProfileData: Bool {
        sensitiveProfile.hasAnyContent
    }

    func merged(with sensitiveProfile: SensitiveProfile) -> UserProfile {
        var merged = self
        merged.familyMembers = sensitiveProfile.familyMembers
        merged.emergencyContacts = sensitiveProfile.emergencyContacts
        merged.medicalNotes = sensitiveProfile.medicalNotes
        merged.emergencyMedicalInfo = sensitiveProfile.emergencyMedicalInfo
        merged.meetingPoints = sensitiveProfile.meetingPoints
        merged.evacuationRoutes = sensitiveProfile.evacuationRoutes
        merged.accountabilityCircle = sensitiveProfile.accountabilityCircle
        return merged
    }
}
