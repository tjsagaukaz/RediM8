import XCTest
@testable import RediM8

final class VehicleReadinessServiceTests: XCTestCase {
    @MainActor
    func testCompletedItemsContributeToVehicleReadinessScore() {
        let service = VehicleReadinessService(store: nil)
        service.setItem("vehicle_water", isComplete: true)
        service.setItem("vehicle_first_aid", isComplete: true)

        let plan = service.plan(for: UserProfile.empty)

        XCTAssertEqual(plan.readiness.completedCount, 2)
        XCTAssertEqual(plan.readiness.totalCount, 9)
    }

    @MainActor
    func testRemoteTravelMarksVehicleMapsAsCritical() {
        let service = VehicleReadinessService(store: nil)
        var profile = UserProfile.empty
        profile.selectedScenarios = [.remoteTravel]

        let plan = service.plan(for: profile)

        XCTAssertTrue(plan.items.contains(where: { $0.id == "vehicle_maps" && $0.isCritical }))
        XCTAssertTrue(plan.items.contains(where: { $0.id == "vehicle_fuel" && $0.isCritical }))
    }
}
