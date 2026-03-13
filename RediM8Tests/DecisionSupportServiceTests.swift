import XCTest
@testable import RediM8

final class DecisionSupportServiceTests: XCTestCase {
    func testBushfirePrioritySummarySurfacesCoreActionsAndRoutes() {
        let service = DecisionSupportService()
        var profile = UserProfile.empty
        profile.emergencyContacts = [EmergencyContact(name: "Alex", phone: "000")]
        profile.evacuationRoutes = ["North Ridge Road", "West Creek Exit"]

        let summary = service.prioritySummary(
            for: .bushfire,
            profile: profile,
            goBagPlan: GoBagPlan(
                readiness: GoBagReadiness(completedCount: 6, totalCount: 8),
                categories: [],
                scenarioTitles: [],
                contextLines: [],
                nextActions: [],
                evacuationChecklist: []
            ),
            waterEstimate: WaterRuntimeEstimate(
                storedWaterLitres: 24,
                dailyUseLitres: 4,
                estimatedDays: 6,
                recommendedTargetLitres: 28,
                recommendedReserveDays: 7
            ),
            nearbyWaterSources: [],
            nearbyShelters: []
        )

        XCTAssertEqual(summary.title, "Bushfire Priority Mode")
        XCTAssertEqual(summary.actions.prefix(3).map(\.title), ["Grab Go Bag", "Contact Family", "Check Evacuation Route"])
        XCTAssertTrue(summary.evacuationOptions.contains("North Ridge Road"))
    }

    func testLeaveNowActionsIncludePetsOnlyWhenNeeded() {
        let service = DecisionSupportService()
        var profile = UserProfile.empty
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 1)

        let withPets = service.leaveNowActions(
            for: profile,
            goBagPlan: GoBagPlan(
                readiness: GoBagReadiness(completedCount: 4, totalCount: 8),
                categories: [],
                scenarioTitles: [],
                contextLines: [],
                nextActions: [],
                evacuationChecklist: []
            )
        )
        XCTAssertTrue(withPets.contains(where: { $0.title == "Load Pets" }))
        XCTAssertEqual(withPets.prefix(2).map(\.title), ["Grab Go Bag", "Grab Folder"])

        profile.household = HouseholdDetails(peopleCount: 2, petCount: 0)
        let withoutPets = service.leaveNowActions(
            for: profile,
            goBagPlan: GoBagPlan(
                readiness: GoBagReadiness(completedCount: 4, totalCount: 8),
                categories: [],
                scenarioTitles: [],
                contextLines: [],
                nextActions: [],
                evacuationChecklist: []
            )
        )
        XCTAssertFalse(withoutPets.contains(where: { $0.title == "Load Pets" }))
        XCTAssertFalse(withoutPets.contains(where: { $0.title == "Take Documents" }))
        XCTAssertFalse(withoutPets.contains(where: { $0.title == "Take Medications" }))
        XCTAssertTrue(withoutPets.contains(where: { $0.title == "Grab Folder" }))
    }
}
