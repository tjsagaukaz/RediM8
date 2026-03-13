import XCTest
@testable import RediM8

final class PreparednessInsightsServiceTests: XCTestCase {
    func testForgottenItemsSurfacePetPowerAndDocumentGaps() {
        let service = PreparednessInsightsService(calendar: utcCalendar)

        var profile = UserProfile.empty
        profile.selectedScenarios = [.bushfires, .generalEmergencies]
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 1)
        profile.supplies = Supplies(waterLitres: 12, foodDays: 3, fuelLitres: 8, batteryCapacity: 25)
        profile.emergencyContacts = [EmergencyContact(name: "ICE", phone: "000")]
        profile.bushfireReadiness.petEvacuationPlan = ""

        let items = service.forgottenItems(for: profile)

        XCTAssertTrue(items.contains(where: { $0.title == "Pet evacuation supplies" }))
        XCTAssertTrue(items.contains(where: { $0.title == "Backup batteries" }))
        XCTAssertTrue(items.contains(where: { $0.title == "Document copies" }))
    }

    func testExpiryRemindersIncludeOverdueAndUpcomingItems() {
        let service = PreparednessInsightsService(calendar: utcCalendar)
        let referenceDate = makeDate("2026-03-12")

        var profile = UserProfile.empty
        profile.supplies.trackedExpiryItems = [
            SupplyExpiryItem(
                name: "First aid kit",
                category: .medication,
                expiryDate: makeDate("2026-03-10"),
                reminderLeadDays: 60
            ),
            SupplyExpiryItem(
                name: "Water treatment tablets",
                category: .waterTreatment,
                expiryDate: makeDate("2026-04-10"),
                reminderLeadDays: 45
            ),
            SupplyExpiryItem(
                name: "Pantry food",
                category: .food,
                expiryDate: makeDate("2026-08-01"),
                reminderLeadDays: 30
            )
        ]

        let reminders = service.expiryReminders(for: profile, asOf: referenceDate)

        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(reminders.first?.itemName, "First aid kit")
        XCTAssertEqual(reminders.first?.status, .overdue)
        XCTAssertEqual(reminders.first?.title, "First aid kit expired 2 days ago")
        XCTAssertEqual(reminders.last?.itemName, "Water treatment tablets")
        XCTAssertEqual(reminders.last?.status, .expiringSoon)
    }

    func testPrimaryRoleTaskUsesPrimaryFamilyMemberAssignment() {
        let service = PreparednessInsightsService(calendar: utcCalendar)

        var profile = UserProfile.empty
        profile.evacuationRoutes = ["South via Main Road"]
        profile.familyMembers = [
            FamilyMember(name: "Thomas", phone: "", medicalNotes: "", emergencyRole: "Driver"),
            FamilyMember(name: "Sarah", phone: "", medicalNotes: "", emergencyRole: "Go Bag", isPrimaryUser: true)
        ]

        let tasks = service.familyRoleTasks(for: profile)
        let primaryTask = service.primaryRoleTask(for: profile)

        XCTAssertEqual(tasks.first?.memberName, "Sarah")
        XCTAssertEqual(primaryTask?.memberName, "Sarah")
        XCTAssertEqual(primaryTask?.taskTitle, "Grab Go Bag")
    }

    func testLegacyDecodingDefaultsNewPreparednessFields() throws {
        let suppliesJSON = """
        {
          "waterLitres": 20,
          "foodDays": 4,
          "fuelLitres": 10,
          "batteryCapacity": 50
        }
        """
        let memberJSON = """
        {
          "name": "Alex",
          "phone": "0400 123 456",
          "medicalNotes": "",
          "emergencyRole": "Documents"
        }
        """

        let supplies = try JSONDecoder.rediM8.decode(Supplies.self, from: XCTUnwrap(suppliesJSON.data(using: .utf8)))
        let member = try JSONDecoder.rediM8.decode(FamilyMember.self, from: XCTUnwrap(memberJSON.data(using: .utf8)))

        XCTAssertTrue(supplies.trackedExpiryItems.isEmpty)
        XCTAssertFalse(member.isPrimaryUser)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func makeDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: "\(value)T12:00:00Z") ?? .distantPast
    }
}
