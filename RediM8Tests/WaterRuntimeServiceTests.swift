import XCTest
@testable import RediM8

final class WaterRuntimeServiceTests: XCTestCase {
    func testEstimateReflectsHouseholdSizeAndStoredWater() {
        let service = WaterRuntimeService(prepService: PrepService())
        var profile = UserProfile.empty
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 1)
        profile.supplies.waterLitres = 24

        let estimate = service.estimate(
            for: profile,
            scenarios: [
                PrepScenario(
                    kind: .remoteTravel,
                    name: "Remote Travel",
                    description: "Remote travel",
                    tasks: [],
                    gear: [],
                    guides: [],
                    priorityCategories: [.water, .evacuation]
                )
            ]
        )

        XCTAssertEqual(estimate.recommendedTargetLitres, 48, accuracy: 0.001)
        XCTAssertEqual(estimate.estimatedDays, 3.5, accuracy: 0.001)
        XCTAssertEqual(estimate.statusTitle, "Below Target")
    }
}
