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

    func testEmptyPackIDsReturnsNoTrails() {
        let service = FireTrailService(bundle: .main)

        let trails = service.fireTrails(for: [])

        XCTAssertTrue(trails.isEmpty)
    }

    func testUnknownPackIDReturnsNoTrails() {
        let service = FireTrailService(bundle: .main)

        let trails = service.fireTrails(for: ["nonexistent_pack_id_xyz"])

        XCTAssertTrue(trails.isEmpty)
    }

    func testServiceIndicatesOfflineDataIsLoaded() {
        let service = FireTrailService(bundle: .main)

        XCTAssertTrue(service.didLoadOfflineData)
    }

    func testMultiplePackIDsReturnTrailsFromAllMatchingPacks() {
        let service = FireTrailService(bundle: .main)

        let centralTrails = service.fireTrails(for: ["central_australia"])
        let brisbaneTrails = service.fireTrails(for: ["brisbane_region"])
        let combinedTrails = service.fireTrails(for: ["central_australia", "brisbane_region"])

        XCTAssertFalse(combinedTrails.isEmpty)
        XCTAssertGreaterThanOrEqual(combinedTrails.count, centralTrails.count + brisbaneTrails.count)
    }
}
