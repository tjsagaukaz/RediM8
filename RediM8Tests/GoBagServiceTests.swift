import XCTest
@testable import RediM8

final class GoBagServiceTests: XCTestCase {
    @MainActor
    func testBushfirePlanIncludesBushfireSpecificItems() {
        let service = makeService()
        var profile = UserProfile.empty
        profile.selectedScenarios = [.bushfires]

        let plan = service.plan(for: profile)
        let itemIDs = Set(plan.categories.flatMap(\.items).map(\.id))

        XCTAssertTrue(itemIDs.contains("p2_masks"))
        XCTAssertTrue(itemIDs.contains("fire_blanket_item"))
        XCTAssertFalse(itemIDs.contains("rubber_boots"))
    }

    @MainActor
    func testReadinessIgnoresCompletedItemsHiddenByScenarioSelection() {
        let service = makeService()
        service.setItem("id_copies", isComplete: true)
        service.setItem("p2_masks", isComplete: true)

        var profile = UserProfile.empty
        profile.selectedScenarios = [.floods]

        let plan = service.plan(for: profile)
        let itemIDs = Set(plan.categories.flatMap(\.items).map(\.id))

        XCTAssertTrue(itemIDs.contains("id_copies"))
        XCTAssertFalse(itemIDs.contains("p2_masks"))
        XCTAssertEqual(plan.readiness.completedCount, 1)
    }

    @MainActor
    private func makeService() -> GoBagService {
        let dataService = PreparednessDataService(store: nil, bundle: .main)
        let scenarioEngine = ScenarioEngine(dataService: dataService)
        let emergencyPlanService = EmergencyPlanService(dataService: dataService, scenarioEngine: scenarioEngine, store: nil)
        return GoBagService(
            dataService: dataService,
            scenarioEngine: scenarioEngine,
            emergencyPlanService: emergencyPlanService,
            store: nil
        )
    }
}
