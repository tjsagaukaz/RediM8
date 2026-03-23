import CoreLocation
import XCTest
@testable import RediM8

final class ShelterServiceTests: XCTestCase {
    func testSheltersCanBeFilteredByTypeWithinInstalledPack() {
        let service = ShelterService(bundle: .main)

        let shelters = service.shelters(
            for: ["brisbane_region"],
            types: [.communityShelter]
        )

        XCTAssertEqual(shelters.map(\.id), ["brisbane_community_hall"])
    }

    func testNearbySheltersAreSortedByDistance() {
        let service = ShelterService(bundle: .main)
        let nearby = service.nearbyShelters(
            near: CLLocationCoordinate2D(latitude: -27.468, longitude: 153.026),
            installedPackIDs: ["brisbane_region"],
            limit: 2
        )

        XCTAssertEqual(nearby.map(\.shelter.id), ["brisbane_community_hall", "samford_showgrounds_evacuation_centre"])
    }

    func testRefreshNearbyNetworkDataReturnsEmptyInOfflineMode() async {
        let service = ShelterService(bundle: .main)
        let coordinate = CLLocationCoordinate2D(latitude: -27.4701, longitude: 153.0210)

        let refreshed = await service.refreshNearbyNetworkData(near: coordinate)

        XCTAssertTrue(refreshed.isEmpty, "Network data refresh must return empty in offline mode")
        XCTAssertFalse(service.hasNearbyNetworkData, "hasNearbyNetworkData must be false in offline mode")
    }
}
