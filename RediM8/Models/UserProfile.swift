import Foundation

struct HouseholdDetails: Codable, Equatable {
    var peopleCount: Int
    var petCount: Int

    var totalPeople: Int {
        max(peopleCount, 1)
    }

    static let `default` = HouseholdDetails(peopleCount: 1, petCount: 0)
}

enum BushfireChecklistItemKind: String, CaseIterable, Codable, Identifiable {
    case clearGutters
    case removeDebris
    case prepareFireBlankets
    case checkGardenHoses
    case fillWaterTanks
    case prepareEvacuationBag

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clearGutters:
            "Clear dry leaves from gutters"
        case .removeDebris:
            "Remove debris around house"
        case .prepareFireBlankets:
            "Prepare fire blankets"
        case .checkGardenHoses:
            "Check garden hoses"
        case .fillWaterTanks:
            "Fill water tanks"
        case .prepareEvacuationBag:
            "Prepare evacuation bag"
        }
    }
}

struct BushfireChecklistItem: Identifiable, Codable, Equatable {
    var id: BushfireChecklistItemKind { kind }
    let kind: BushfireChecklistItemKind
    var isChecked: Bool

    static let defaults = BushfireChecklistItemKind.allCases.map {
        BushfireChecklistItem(kind: $0, isChecked: false)
    }
}

enum BushfirePropertyItemKind: String, CaseIterable, Codable, Identifiable {
    case defensibleSpaceCleared
    case roofCleaned
    case waterPumpReady
    case sprinklersInstalled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defensibleSpaceCleared:
            "Defensible space cleared"
        case .roofCleaned:
            "Roof cleaned"
        case .waterPumpReady:
            "Water pump ready"
        case .sprinklersInstalled:
            "Sprinklers installed"
        }
    }
}

struct BushfirePropertyItem: Identifiable, Codable, Equatable {
    var id: BushfirePropertyItemKind { kind }
    let kind: BushfirePropertyItemKind
    var isChecked: Bool

    static let defaults = BushfirePropertyItemKind.allCases.map {
        BushfirePropertyItem(kind: $0, isChecked: false)
    }
}

struct BushfireReadiness: Codable, Equatable {
    var checklist: [BushfireChecklistItem]
    var propertyItems: [BushfirePropertyItem]
    var petEvacuationPlan: String

    static let `default` = BushfireReadiness(
        checklist: BushfireChecklistItem.defaults,
        propertyItems: BushfirePropertyItem.defaults,
        petEvacuationPlan: ""
    )

    var checklistProgress: Double {
        progress(for: checklist.filter(\.isChecked).count, total: checklist.count)
    }

    var propertyProgress: Double {
        progress(for: propertyItems.filter(\.isChecked).count, total: propertyItems.count)
    }

    init(
        checklist: [BushfireChecklistItem] = BushfireChecklistItem.defaults,
        propertyItems: [BushfirePropertyItem] = BushfirePropertyItem.defaults,
        petEvacuationPlan: String = ""
    ) {
        self.checklist = BushfireReadiness.normalizedChecklist(checklist)
        self.propertyItems = BushfireReadiness.normalizedPropertyItems(propertyItems)
        self.petEvacuationPlan = petEvacuationPlan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        checklist = BushfireReadiness.normalizedChecklist(
            try container.decodeIfPresent([BushfireChecklistItem].self, forKey: .checklist) ?? BushfireChecklistItem.defaults
        )
        propertyItems = BushfireReadiness.normalizedPropertyItems(
            try container.decodeIfPresent([BushfirePropertyItem].self, forKey: .propertyItems) ?? BushfirePropertyItem.defaults
        )
        petEvacuationPlan = try container.decodeIfPresent(String.self, forKey: .petEvacuationPlan) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case checklist
        case propertyItems
        case petEvacuationPlan
    }

    private static func normalizedChecklist(_ items: [BushfireChecklistItem]) -> [BushfireChecklistItem] {
        let states = Dictionary(uniqueKeysWithValues: items.map { ($0.kind, $0.isChecked) })
        return BushfireChecklistItemKind.allCases.map {
            BushfireChecklistItem(kind: $0, isChecked: states[$0] ?? false)
        }
    }

    private static func normalizedPropertyItems(_ items: [BushfirePropertyItem]) -> [BushfirePropertyItem] {
        let states = Dictionary(uniqueKeysWithValues: items.map { ($0.kind, $0.isChecked) })
        return BushfirePropertyItemKind.allCases.map {
            BushfirePropertyItem(kind: $0, isChecked: states[$0] ?? false)
        }
    }

    private func progress(for completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

enum CriticalMedicalCondition: String, CaseIterable, Codable, Identifiable, Hashable {
    case diabetes
    case asthma
    case heartCondition
    case epilepsy
    case bloodThinnerMedication

    var id: String { rawValue }

    var title: String {
        switch self {
        case .diabetes:
            "Diabetes"
        case .asthma:
            "Asthma"
        case .heartCondition:
            "Heart condition"
        case .epilepsy:
            "Epilepsy"
        case .bloodThinnerMedication:
            "Blood thinner medication"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .diabetes:
            0
        case .asthma:
            1
        case .heartCondition:
            2
        case .epilepsy:
            3
        case .bloodThinnerMedication:
            4
        }
    }

    static func sorted(_ conditions: [CriticalMedicalCondition]) -> [CriticalMedicalCondition] {
        Array(Set(conditions)).sorted { $0.sortOrder < $1.sortOrder }
    }
}

struct EmergencyMedicalInfo: Codable, Equatable {
    var criticalConditions: [CriticalMedicalCondition]
    var severeAllergies: String
    var otherCriticalCondition: String
    var bloodType: String
    var emergencyMedication: String

    init(
        criticalConditions: [CriticalMedicalCondition] = [],
        severeAllergies: String = "",
        otherCriticalCondition: String = "",
        bloodType: String = "",
        emergencyMedication: String = ""
    ) {
        self.criticalConditions = CriticalMedicalCondition.sorted(criticalConditions)
        self.severeAllergies = severeAllergies
        self.otherCriticalCondition = otherCriticalCondition
        self.bloodType = bloodType
        self.emergencyMedication = emergencyMedication
    }

    static let empty = EmergencyMedicalInfo()

    var hasAnyContent: Bool {
        !criticalConditions.isEmpty
            || severeAllergies.nilIfBlank != nil
            || otherCriticalCondition.nilIfBlank != nil
            || bloodType.nilIfBlank != nil
            || emergencyMedication.nilIfBlank != nil
    }

    var displayLines: [String] {
        var lines = [String]()

        if !criticalConditions.isEmpty {
            lines.append(criticalConditions.map(\.title).joined(separator: ", "))
        }

        if let severeAllergies = severeAllergies.nilIfBlank {
            lines.append("Allergies: \(severeAllergies)")
        }

        if let emergencyMedication = emergencyMedication.nilIfBlank {
            lines.append("Medication: \(emergencyMedication)")
        }

        if let bloodType = bloodType.nilIfBlank {
            lines.append("Blood type: \(bloodType)")
        }

        if let otherCriticalCondition = otherCriticalCondition.nilIfBlank {
            lines.append(otherCriticalCondition)
        }

        return lines
    }

    var broadcastSummary: String? {
        let summary = displayLines.joined(separator: " • ")
        return summary.nilIfBlank
    }

    mutating func toggle(_ condition: CriticalMedicalCondition) {
        if criticalConditions.contains(condition) {
            criticalConditions.removeAll { $0 == condition }
        } else {
            criticalConditions.append(condition)
        }
        criticalConditions = CriticalMedicalCondition.sorted(criticalConditions)
    }
}

struct UserProfile: Codable, Equatable {
    var selectedScenarios: [ScenarioKind]
    var household: HouseholdDetails
    var supplies: Supplies
    var checklistItems: [ChecklistItem]
    var familyMembers: [FamilyMember]
    var emergencyContacts: [EmergencyContact]
    var medicalNotes: String
    var emergencyMedicalInfo: EmergencyMedicalInfo
    var meetingPoints: MeetingPoints
    var evacuationRoutes: [String]
    var bushfireReadiness: BushfireReadiness
    var lastAcknowledgedSafetyNoticeAt: Date?
    var lastCompletedOnboardingAt: Date?

    init(
        selectedScenarios: [ScenarioKind],
        household: HouseholdDetails,
        supplies: Supplies,
        checklistItems: [ChecklistItem],
        familyMembers: [FamilyMember],
        emergencyContacts: [EmergencyContact],
        medicalNotes: String,
        emergencyMedicalInfo: EmergencyMedicalInfo = .empty,
        meetingPoints: MeetingPoints,
        evacuationRoutes: [String],
        bushfireReadiness: BushfireReadiness = .default,
        lastAcknowledgedSafetyNoticeAt: Date? = nil,
        lastCompletedOnboardingAt: Date?
    ) {
        self.selectedScenarios = selectedScenarios
        self.household = household
        self.supplies = supplies
        self.checklistItems = checklistItems
        self.familyMembers = familyMembers
        self.emergencyContacts = emergencyContacts
        self.medicalNotes = medicalNotes
        self.emergencyMedicalInfo = emergencyMedicalInfo
        self.meetingPoints = meetingPoints
        self.evacuationRoutes = evacuationRoutes
        self.bushfireReadiness = bushfireReadiness
        self.lastAcknowledgedSafetyNoticeAt = lastAcknowledgedSafetyNoticeAt
        self.lastCompletedOnboardingAt = lastCompletedOnboardingAt
    }

    static let empty = UserProfile(
        selectedScenarios: [.generalEmergencies],
        household: .default,
        supplies: .empty,
        checklistItems: ChecklistItem.defaults,
        familyMembers: [],
        emergencyContacts: [],
        medicalNotes: "",
        emergencyMedicalInfo: .empty,
        meetingPoints: .empty,
        evacuationRoutes: [],
        bushfireReadiness: .default,
        lastAcknowledgedSafetyNoticeAt: nil,
        lastCompletedOnboardingAt: nil
    )

    var isOnboardingComplete: Bool {
        lastCompletedOnboardingAt != nil
    }

    var isBushfireModeEnabled: Bool {
        selectedScenarios.contains(.bushfires)
    }

    var hasAcknowledgedSafetyNotice: Bool {
        lastAcknowledgedSafetyNoticeAt != nil
    }

    func markedOnboarded() -> UserProfile {
        var updated = self
        updated.lastCompletedOnboardingAt = .now
        return updated
    }

    func checklistState(for kind: ChecklistItemKind) -> Bool {
        checklistItems.first(where: { $0.kind == kind })?.isChecked ?? false
    }

    func bushfireChecklistState(for kind: BushfireChecklistItemKind) -> Bool {
        bushfireReadiness.checklist.first(where: { $0.kind == kind })?.isChecked ?? false
    }

    func bushfirePropertyState(for kind: BushfirePropertyItemKind) -> Bool {
        bushfireReadiness.propertyItems.first(where: { $0.kind == kind })?.isChecked ?? false
    }

    func bushfireRoute(at index: Int) -> String {
        evacuationRoutes.indices.contains(index) ? evacuationRoutes[index] : ""
    }

    var primaryFamilyMember: FamilyMember? {
        familyMembers.first(where: \.isPrimaryUser) ?? familyMembers.first
    }

    private enum CodingKeys: String, CodingKey {
        case selectedScenarios
        case household
        case supplies
        case checklistItems
        case familyMembers
        case emergencyContacts
        case medicalNotes
        case emergencyMedicalInfo
        case meetingPoints
        case evacuationRoutes
        case bushfireReadiness
        case lastAcknowledgedSafetyNoticeAt
        case lastCompletedOnboardingAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedScenarios = try container.decodeIfPresent([ScenarioKind].self, forKey: .selectedScenarios) ?? [.generalEmergencies]
        household = try container.decodeIfPresent(HouseholdDetails.self, forKey: .household) ?? .default
        supplies = try container.decodeIfPresent(Supplies.self, forKey: .supplies) ?? .empty
        checklistItems = try container.decodeIfPresent([ChecklistItem].self, forKey: .checklistItems) ?? ChecklistItem.defaults
        familyMembers = try container.decodeIfPresent([FamilyMember].self, forKey: .familyMembers) ?? []
        emergencyContacts = try container.decodeIfPresent([EmergencyContact].self, forKey: .emergencyContacts) ?? []
        medicalNotes = try container.decodeIfPresent(String.self, forKey: .medicalNotes) ?? ""
        emergencyMedicalInfo = try container.decodeIfPresent(EmergencyMedicalInfo.self, forKey: .emergencyMedicalInfo) ?? .empty
        meetingPoints = try container.decodeIfPresent(MeetingPoints.self, forKey: .meetingPoints) ?? .empty
        evacuationRoutes = try container.decodeIfPresent([String].self, forKey: .evacuationRoutes) ?? []
        bushfireReadiness = try container.decodeIfPresent(BushfireReadiness.self, forKey: .bushfireReadiness) ?? .default
        lastAcknowledgedSafetyNoticeAt = try container.decodeIfPresent(Date.self, forKey: .lastAcknowledgedSafetyNoticeAt)
        lastCompletedOnboardingAt = try container.decodeIfPresent(Date.self, forKey: .lastCompletedOnboardingAt)
    }
}
