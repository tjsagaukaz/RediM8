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

enum AccountabilityStatus: String, CaseIterable, Codable, Identifiable, Hashable {
    case safe
    case checkingIn = "checking_in"
    case needHelp = "need_help"
    case injured
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safe:
            "Safe"
        case .checkingIn:
            "Checking In"
        case .needHelp:
            "Need Help"
        case .injured:
            "Injured"
        case .unknown:
            "Unknown"
        }
    }

    var buttonTitle: String {
        switch self {
        case .safe:
            "I Am Safe"
        case .checkingIn:
            "Checking In"
        case .needHelp:
            "Need Help"
        case .injured:
            "Injured"
        case .unknown:
            "Unknown"
        }
    }

    var summaryLabel: String {
        switch self {
        case .safe:
            "SAFE"
        case .checkingIn:
            "CHECKING IN"
        case .needHelp:
            "NEED HELP"
        case .injured:
            "INJURED"
        case .unknown:
            "UNKNOWN"
        }
    }

    var systemImage: String {
        switch self {
        case .safe:
            "checkmark.shield.fill"
        case .checkingIn:
            "clock.badge.checkmark.fill"
        case .needHelp:
            "exclamationmark.triangle.fill"
        case .injured:
            "cross.case.fill"
        case .unknown:
            "questionmark.circle.fill"
        }
    }

    var sortPriority: Int {
        switch self {
        case .needHelp:
            0
        case .injured:
            1
        case .unknown:
            2
        case .checkingIn:
            3
        case .safe:
            4
        }
    }
}

enum AccountabilityMemberSource: String, Codable, Equatable, Hashable {
    case selfUser = "self"
    case family
    case emergencyContact = "emergency_contact"
    case custom
    case mesh

    var label: String {
        switch self {
        case .selfUser:
            "This device"
        case .family:
            "Family"
        case .emergencyContact:
            "Emergency contact"
        case .custom:
            "Custom"
        case .mesh:
            "Mesh check-in"
        }
    }
}

enum AccountabilityCheckInMethod: String, Codable, Equatable, Hashable {
    case local
    case mesh
    case manual

    var label: String {
        switch self {
        case .local:
            "Local"
        case .mesh:
            "Mesh"
        case .manual:
            "Manual"
        }
    }
}

struct AccountabilityMember: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var phone: String
    var role: String
    var status: AccountabilityStatus
    var note: String
    var updatedAt: Date?
    var source: AccountabilityMemberSource
    var lastCheckInMethod: AccountabilityCheckInMethod

    init(
        id: UUID = UUID(),
        name: String,
        phone: String = "",
        role: String = "",
        status: AccountabilityStatus = .unknown,
        note: String = "",
        updatedAt: Date? = nil,
        source: AccountabilityMemberSource = .custom,
        lastCheckInMethod: AccountabilityCheckInMethod = .manual
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.role = role
        self.status = status
        self.note = note
        self.updatedAt = updatedAt
        self.source = source
        self.lastCheckInMethod = lastCheckInMethod
    }
}

struct AccountabilityCircle: Codable, Equatable, Hashable {
    var title: String
    var members: [AccountabilityMember]

    init(
        title: String = "Household Status",
        members: [AccountabilityMember] = []
    ) {
        self.title = title
        self.members = members
    }

    static let empty = AccountabilityCircle()

    var checkedInCount: Int {
        members.filter { $0.status != .unknown }.count
    }
}

enum PlanWorkspaceID: String, CaseIterable, Codable, Identifiable {
    case householdBasics = "household_basics"
    case householdSupplies = "household_supplies"
    case householdRoles = "household_roles"
    case householdScenarios = "household_scenarios"
    case vehicle = "vehicle"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .householdBasics:
            "Basics"
        case .householdSupplies:
            "Supplies"
        case .householdRoles:
            "Roles"
        case .householdScenarios:
            "Scenarios"
        case .vehicle:
            "Vehicle"
        }
    }
}

struct PlanCustomTask: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var note: String
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.isCompleted = isCompleted
    }
}

struct PlanWorkspaceCustomData: Identifiable, Codable, Equatable {
    var id: PlanWorkspaceID
    var notes: String
    var tasks: [PlanCustomTask]

    init(
        id: PlanWorkspaceID,
        notes: String = "",
        tasks: [PlanCustomTask] = []
    ) {
        self.id = id
        self.notes = notes
        self.tasks = tasks
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
    var savedGuideIDs: [String]
    var recentGuideIDs: [String]
    var customPlanningWorkspaces: [PlanWorkspaceCustomData]
    var accountabilityCircle: AccountabilityCircle
    var bushfireReadiness: BushfireReadiness
    var lastAcknowledgedSafetyNoticeAt: Date?
    var lastCompletedOnboardingAt: Date?
    var survivalProfile: SurvivalProfile

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
        savedGuideIDs: [String] = [],
        recentGuideIDs: [String] = [],
        customPlanningWorkspaces: [PlanWorkspaceCustomData] = UserProfile.defaultCustomPlanningWorkspaces,
        accountabilityCircle: AccountabilityCircle = .empty,
        bushfireReadiness: BushfireReadiness = .default,
        lastAcknowledgedSafetyNoticeAt: Date? = nil,
        lastCompletedOnboardingAt: Date?,
        survivalProfile: SurvivalProfile = .default
    ) {
        self.selectedScenarios = selectedScenarios
        self.household = household
        self.supplies = supplies
        self.checklistItems = ChecklistItem.normalized(checklistItems)
        self.familyMembers = familyMembers
        self.emergencyContacts = emergencyContacts
        self.medicalNotes = medicalNotes
        self.emergencyMedicalInfo = emergencyMedicalInfo
        self.meetingPoints = meetingPoints
        self.evacuationRoutes = evacuationRoutes
        self.savedGuideIDs = UserProfile.normalizedGuideIDs(savedGuideIDs)
        self.recentGuideIDs = UserProfile.normalizedGuideIDs(recentGuideIDs)
        self.customPlanningWorkspaces = UserProfile.normalizedCustomPlanningWorkspaces(customPlanningWorkspaces)
        self.accountabilityCircle = accountabilityCircle
        self.bushfireReadiness = bushfireReadiness
        self.lastAcknowledgedSafetyNoticeAt = lastAcknowledgedSafetyNoticeAt
        self.lastCompletedOnboardingAt = lastCompletedOnboardingAt
        self.survivalProfile = survivalProfile
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
        savedGuideIDs: [],
        recentGuideIDs: [],
        customPlanningWorkspaces: UserProfile.defaultCustomPlanningWorkspaces,
        accountabilityCircle: .empty,
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

    var profileCompletionSteps: [ProfileCompletionStep] {
        [
            ProfileCompletionStep(
                id: "household",
                title: "Household",
                detail: "Add people count, pets, and a meeting point.",
                icon: "person.2.fill",
                isComplete: household.peopleCount > 1 || household.petCount > 0 || meetingPoints.primary.nilIfBlank != nil
            ),
            ProfileCompletionStep(
                id: "contact",
                title: "Emergency Contact",
                detail: "Save one reachable person for emergencies.",
                icon: "phone.fill",
                isComplete: emergencyContacts.first?.phone.nilIfBlank != nil
            ),
            ProfileCompletionStep(
                id: "route",
                title: "Evacuation Route",
                detail: "Add a primary leave-now route.",
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                isComplete: evacuationRoutes.first?.nilIfBlank != nil
            ),
            ProfileCompletionStep(
                id: "supplies",
                title: "Supplies",
                detail: "Log water, food, fuel, and battery levels.",
                icon: "shippingbox.fill",
                isComplete: supplies.waterLitres > 0 || supplies.foodDays > 0 || supplies.fuelLitres > 0
            ),
            ProfileCompletionStep(
                id: "medical",
                title: "Health Info",
                detail: "Optional. Add details that change urgent care.",
                icon: "cross.case.fill",
                isComplete: emergencyMedicalInfo.hasAnyContent
            ),
            ProfileCompletionStep(
                id: "gear",
                title: "Grab-and-Go Gear",
                detail: "Mark the gear you already have on hand.",
                icon: "bag.fill",
                isComplete: normalizedChecklistItems.contains(where: \.isChecked)
            )
        ]
    }

    var profileCompletionFraction: Double {
        let steps = profileCompletionSteps
        guard !steps.isEmpty else { return 1 }
        return Double(steps.filter(\.isComplete).count) / Double(steps.count)
    }

    var isProfileFullyComplete: Bool {
        profileCompletionSteps.allSatisfy(\.isComplete)
    }

    var nextIncompleteProfileStep: ProfileCompletionStep? {
        profileCompletionSteps.first(where: { !$0.isComplete })
    }

    func checklistState(for kind: ChecklistItemKind) -> Bool {
        normalizedChecklistItems.first(where: { $0.kind == kind })?.isChecked ?? false
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
        case savedGuideIDs
        case recentGuideIDs
        case customPlanningWorkspaces
        case accountabilityCircle
        case bushfireReadiness
        case lastAcknowledgedSafetyNoticeAt
        case lastCompletedOnboardingAt
        case survivalProfile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedScenarios = try container.decodeIfPresent([ScenarioKind].self, forKey: .selectedScenarios) ?? [.generalEmergencies]
        household = try container.decodeIfPresent(HouseholdDetails.self, forKey: .household) ?? .default
        supplies = try container.decodeIfPresent(Supplies.self, forKey: .supplies) ?? .empty
        checklistItems = ChecklistItem.normalized(
            try container.decodeIfPresent([ChecklistItem].self, forKey: .checklistItems) ?? ChecklistItem.defaults
        )
        familyMembers = try container.decodeIfPresent([FamilyMember].self, forKey: .familyMembers) ?? []
        emergencyContacts = try container.decodeIfPresent([EmergencyContact].self, forKey: .emergencyContacts) ?? []
        medicalNotes = try container.decodeIfPresent(String.self, forKey: .medicalNotes) ?? ""
        emergencyMedicalInfo = try container.decodeIfPresent(EmergencyMedicalInfo.self, forKey: .emergencyMedicalInfo) ?? .empty
        meetingPoints = try container.decodeIfPresent(MeetingPoints.self, forKey: .meetingPoints) ?? .empty
        evacuationRoutes = try container.decodeIfPresent([String].self, forKey: .evacuationRoutes) ?? []
        savedGuideIDs = UserProfile.normalizedGuideIDs(
            try container.decodeIfPresent([String].self, forKey: .savedGuideIDs) ?? []
        )
        recentGuideIDs = UserProfile.normalizedGuideIDs(
            try container.decodeIfPresent([String].self, forKey: .recentGuideIDs) ?? []
        )
        customPlanningWorkspaces = UserProfile.normalizedCustomPlanningWorkspaces(
            try container.decodeIfPresent([PlanWorkspaceCustomData].self, forKey: .customPlanningWorkspaces)
                ?? UserProfile.defaultCustomPlanningWorkspaces
        )
        accountabilityCircle = try container.decodeIfPresent(AccountabilityCircle.self, forKey: .accountabilityCircle) ?? .empty
        bushfireReadiness = try container.decodeIfPresent(BushfireReadiness.self, forKey: .bushfireReadiness) ?? .default
        lastAcknowledgedSafetyNoticeAt = try container.decodeIfPresent(Date.self, forKey: .lastAcknowledgedSafetyNoticeAt)
        lastCompletedOnboardingAt = try container.decodeIfPresent(Date.self, forKey: .lastCompletedOnboardingAt)
        survivalProfile = try container.decodeIfPresent(SurvivalProfile.self, forKey: .survivalProfile) ?? .default
    }

    func customPlanningWorkspace(_ workspaceID: PlanWorkspaceID) -> PlanWorkspaceCustomData {
        customPlanningWorkspaces.first(where: { $0.id == workspaceID }) ?? PlanWorkspaceCustomData(id: workspaceID)
    }

    static var defaultCustomPlanningWorkspaces: [PlanWorkspaceCustomData] {
        PlanWorkspaceID.allCases.map { PlanWorkspaceCustomData(id: $0) }
    }

    func withNormalizedChecklistItems() -> UserProfile {
        var normalized = self
        normalized.checklistItems = normalizedChecklistItems
        return normalized
    }

    private var normalizedChecklistItems: [ChecklistItem] {
        ChecklistItem.normalized(checklistItems)
    }

    private static func normalizedGuideIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.compactMap { id in
            let normalized = id.nilIfBlank
            guard let normalized, seen.insert(normalized).inserted else {
                return nil
            }
            return normalized
        }
    }

    private static func normalizedCustomPlanningWorkspaces(_ workspaces: [PlanWorkspaceCustomData]) -> [PlanWorkspaceCustomData] {
        let workspaceIndex = Dictionary(uniqueKeysWithValues: workspaces.map { ($0.id, $0) })
        return PlanWorkspaceID.allCases.map { workspaceIndex[$0] ?? PlanWorkspaceCustomData(id: $0) }
    }
}
