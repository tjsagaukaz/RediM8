import CoreLocation
import XCTest
@testable import RediM8

final class WaterPointServiceTests: XCTestCase {
    func testWaterPointsCanBeFilteredByTypeWithinInstalledPack() {
        let service = WaterPointService(bundle: .main)

        let points = service.waterPoints(
            for: ["brisbane_region"],
            kinds: [.campgroundWater]
        )

        XCTAssertEqual(points.map(\.id), ["wivenhoe_campground_tap"])
    }

    func testNearbyWaterPointsAreSortedByDistance() {
        let service = WaterPointService(bundle: .main)
        let nearby = service.nearbyWaterPoints(
            near: CLLocationCoordinate2D(latitude: -27.284, longitude: 152.649),
            installedPackIDs: ["brisbane_region"],
            limit: 2
        )

        XCTAssertEqual(nearby.map(\.point.id), ["wivenhoe_campground_tap", "mt_glorious_rain_tank"])
    }

    func testRefreshNearbyNetworkDataReturnsEmptyInOfflineMode() async {
        let service = WaterPointService(bundle: .main)
        let coordinate = CLLocationCoordinate2D(latitude: -27.4701, longitude: 153.0210)

        let refreshed = await service.refreshNearbyNetworkData(near: coordinate)

        XCTAssertTrue(refreshed.isEmpty, "Network data refresh must return empty in offline mode")
        XCTAssertFalse(service.hasNearbyNetworkData, "hasNearbyNetworkData must be false in offline mode")
    }
}
