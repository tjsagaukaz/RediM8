import Foundation

final class PreparednessInsightsService {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func forgottenItems(for profile: UserProfile) -> [ForgottenItemInsight] {
        let scenarios = Set(profile.selectedScenarios)
        let routes = profile.evacuationRoutes.compactMap(\.nilIfBlank)
        let hasMedicalNeeds = profile.medicalNotes.nilIfBlank != nil || profile.familyMembers.contains { $0.medicalNotes.nilIfBlank != nil }
        let evacuationHeavyScenarios: Set<ScenarioKind> = [.bushfires, .floods, .cyclones, .severeStorm, .remoteTravel, .extendedInfrastructureDisruption]
        let isEvacuationHeavy = !scenarios.isDisjoint(with: evacuationHeavyScenarios) || !routes.isEmpty
        let isPowerSensitive = scenarios.contains(.powerOutages) || scenarios.contains(.extendedInfrastructureDisruption) || profile.supplies.batteryCapacity < 70
        let needsExtraLighting = !profile.checklistState(for: .torch) || profile.household.peopleCount + profile.household.petCount > 1

        var items: [ForgottenItemInsight] = []

        if profile.household.petCount > 0 {
            items.append(
                ForgottenItemInsight(
                    id: "pet_evacuation_supplies",
                    title: "Pet evacuation supplies",
                    detail: profile.bushfireReadiness.petEvacuationPlan.nilIfBlank == nil
                        ? "No pet plan is saved yet. Keep carriers, leads, food, medications, and vet records together."
                        : "Keep carriers, leads, food, medications, and a copy of the pet plan packed together.",
                    systemImage: "pet",
                    priority: isEvacuationHeavy ? 98 : 84
                )
            )
        }

        if isPowerSensitive || profile.checklistState(for: .batteryRadio) || profile.checklistState(for: .torch) {
            items.append(
                ForgottenItemInsight(
                    id: "backup_batteries",
                    title: "Backup batteries",
                    detail: "Torches and radios are only useful if you can reload them after the first failure window.",
                    systemImage: "battery",
                    priority: isPowerSensitive ? 92 : 74
                )
            )
        }

        if isEvacuationHeavy || hasMedicalNeeds || !profile.emergencyContacts.isEmpty || !profile.familyMembers.isEmpty {
            items.append(
                ForgottenItemInsight(
                    id: "document_copies",
                    title: "Document copies",
                    detail: "Store IDs, insurance, scripts, and key numbers in a waterproof sleeve for fast departure.",
                    systemImage: "documents",
                    priority: hasMedicalNeeds ? 94 : 86
                )
            )
        }

        if isEvacuationHeavy || scenarios.contains(.generalEmergencies) || profile.household.peopleCount > 1 {
            items.append(
                ForgottenItemInsight(
                    id: "car_charger",
                    title: "Car charger",
                    detail: "Keep a charger and cable in the vehicle so phones stay alive while navigating, calling, or waiting.",
                    systemImage: "vehicle",
                    priority: isEvacuationHeavy ? 82 : 68
                )
            )
        }

        if needsExtraLighting {
            items.append(
                ForgottenItemInsight(
                    id: "spare_torch",
                    title: "Spare torch",
                    detail: "One light source is rarely enough if more than one person is moving at night or during a blackout.",
                    systemImage: "flashlight",
                    priority: !profile.checklistState(for: .torch) ? 90 : 72
                )
            )
        }

        if hasMedicalNeeds {
            items.append(
                ForgottenItemInsight(
                    id: "medication_backup",
                    title: "Medication backup",
                    detail: "Pack active prescriptions, a medication list, and any fast-access items like inhalers or glasses.",
                    systemImage: "first_aid",
                    priority: 96
                )
            )
        }

        if scenarios.contains(.remoteTravel) || scenarios.contains(.extendedInfrastructureDisruption) {
            items.append(
                ForgottenItemInsight(
                    id: "offline_cash",
                    title: "Offline cash",
                    detail: "Small cash reserves still matter when EFTPOS, coverage, or remote services fail unexpectedly.",
                    systemImage: "banknote.fill",
                    priority: 66
                )
            )
        }

        return items
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    return lhs.title < rhs.title
                }
                return lhs.priority > rhs.priority
            }
            .prefix(5)
            .map { $0 }
    }

    func expiryReminders(for profile: UserProfile, asOf referenceDate: Date = .now, limit: Int = 5) -> [SupplyExpiryReminder] {
        let startDate = calendar.startOfDay(for: referenceDate)

        return profile.supplies.trackedExpiryItems
            .map { item in
                let expiryDate = calendar.startOfDay(for: item.expiryDate)
                let daysUntilExpiry = calendar.dateComponents([.day], from: startDate, to: expiryDate).day ?? 0
                let status: SupplyExpiryStatus

                if daysUntilExpiry < 0 {
                    status = .overdue
                } else if daysUntilExpiry <= max(item.reminderLeadDays, 0) {
                    status = .expiringSoon
                } else {
                    status = .healthy
                }

                return SupplyExpiryReminder(
                    id: item.id,
                    itemName: item.name.nilIfBlank ?? item.category.defaultItemName,
                    categoryTitle: item.category.title,
                    expiryDate: expiryDate,
                    daysUntilExpiry: daysUntilExpiry,
                    status: status
                )
            }
            .filter { $0.status != .healthy }
            .sorted { lhs, rhs in
                if lhs.status != rhs.status {
                    return lhs.status == .overdue
                }
                if lhs.daysUntilExpiry == rhs.daysUntilExpiry {
                    return lhs.itemName < rhs.itemName
                }
                return lhs.daysUntilExpiry < rhs.daysUntilExpiry
            }
            .prefix(limit)
            .map { $0 }
    }

    func familyRoleTasks(for profile: UserProfile) -> [FamilyRoleTask] {
        profile.familyMembers
            .filter { $0.name.nilIfBlank != nil || $0.emergencyRole.nilIfBlank != nil }
            .map { member in
                let role = member.emergencyRole.nilIfBlank ?? "Household Support"
                let assignment = taskAssignment(for: role, profile: profile)

                return FamilyRoleTask(
                    id: member.id,
                    memberName: member.name.nilIfBlank ?? "Family member",
                    role: role,
                    taskTitle: assignment.title,
                    taskDetail: assignment.detail,
                    systemImage: assignment.systemImage,
                    isPrimaryUser: member.isPrimaryUser
                )
            }
            .sorted { lhs, rhs in
                if lhs.isPrimaryUser != rhs.isPrimaryUser {
                    return lhs.isPrimaryUser
                }
                return lhs.memberName < rhs.memberName
            }
    }

    func primaryRoleTask(for profile: UserProfile) -> FamilyRoleTask? {
        let tasks = familyRoleTasks(for: profile)
        return tasks.first(where: \.isPrimaryUser) ?? tasks.first
    }

    private func taskAssignment(for role: String, profile: UserProfile) -> (title: String, detail: String, systemImage: String) {
        let normalizedRole = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let routes = profile.evacuationRoutes.compactMap(\.nilIfBlank)

        if normalizedRole.contains("driver") || normalizedRole.contains("vehicle") || normalizedRole.contains("transport") {
            return (
                title: "Get Vehicle Ready",
                detail: routes.first ?? "Take keys, load people quickly, and use the safest saved route or offline map.",
                systemImage: "vehicle"
            )
        }

        if normalizedRole.contains("first aid") || normalizedRole.contains("medical") || normalizedRole.contains("medic") {
            return (
                title: "Grab First Aid + Medications",
                detail: "Take the first aid kit, prescriptions, inhalers, glasses, and the medical summary saved in RediM8.",
                systemImage: "first_aid"
            )
        }

        if normalizedRole.contains("pet") || normalizedRole.contains("animal") {
            return (
                title: "Load Pets",
                detail: "Move pets first with carriers, leads, medications, food, and water already grouped together.",
                systemImage: "pet"
            )
        }

        if normalizedRole.contains("document") || normalizedRole.contains("paper") || normalizedRole.contains("insurance") || normalizedRole.contains("id") {
            return (
                title: "Take Documents",
                detail: "Grab IDs, insurance, scripts, and printed contact details before leaving the property.",
                systemImage: "documents"
            )
        }

        if normalizedRole.contains("bag") || normalizedRole.contains("gear") || normalizedRole.contains("supply") {
            return (
                title: "Grab Go Bag",
                detail: "Take the prepared go bag first, then add any missing essentials only if there is safe time.",
                systemImage: "go_bag"
            )
        }

        if normalizedRole.contains("commun") || normalizedRole.contains("phone") || normalizedRole.contains("contact") || normalizedRole.contains("radio") {
            return (
                title: "Contact Family",
                detail: "Confirm movement with saved contacts and keep phones, chargers, and power banks together.",
                systemImage: "family"
            )
        }

        if normalizedRole.contains("water") {
            return (
                title: "Load Water",
                detail: "Move stored water, treatment tablets, and bottles into the vehicle before departure.",
                systemImage: "water"
            )
        }

        return (
            title: "Check Assigned Role",
            detail: "Stay on \(role) and confirm the next essential action before conditions speed up.",
            systemImage: "checkmark.circle.fill"
        )
    }
}
