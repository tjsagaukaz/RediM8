import XCTest
@testable import RediM8

final class FireTrailServiceTests: XCTestCase {
    func testFireTrailsLoadFromDedicatedDataset() {
        let service = FireTrailService(bundle: .main)

        let trails = service.fireTrails(for: ["central_australia"])

        XCTAssertEqual(trails.map(\.id), ["ormiston_fire_trail"])
    }

    func testFireTrailMetadataSupportsResponsibleDisplay() throws {
        let service = FireTrailService(bundle: .main)

        let trail = try XCTUnwrap(service.fireTrails(for: ["brisbane_region"]).first)

        XCTAssertEqual(trail.surface, .dirt)
        XCTAssertEqual(trail.vehicleAdvice, .fourWheelDriveRecommended)
        XCTAssertEqual(trail.purpose, .emergencyAccess)
        XCTAssertTrue(trail.safetyLabels.contains(.emergencyVehicleRoute))
    }
}
