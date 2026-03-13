import XCTest
@testable import RediM8

@MainActor
final class MapDataServiceTests: XCTestCase {
    func testDefaultLayerSelectionKeepsEmergencyMapFocusedOnSheltersWaterAndOfficialWarnings() {
        let service = MapDataService(store: nil, bundle: .main)

        let layers = service.loadEnabledLayers()

        XCTAssertTrue(layers.contains(.waterPoints))
        XCTAssertTrue(layers.contains(.evacuationPoints))
        XCTAssertTrue(layers.contains(.officialAlerts))
        XCTAssertFalse(layers.contains(.resources))
        XCTAssertFalse(layers.contains(.dirtRoads))
        XCTAssertFalse(layers.contains(.fireTrails))
        XCTAssertFalse(layers.contains(.communityBeacons))
    }

    func testDefaultInstalledPacksIncludeBundledStarterRegion() {
        let service = MapDataService(store: nil, bundle: .main)

        let installedPackIDs = service.loadInstalledPackIDs()

        XCTAssertEqual(installedPackIDs, ["brisbane_region"])
    }

    func testRegionalFilteringReturnsOnlyInstalledTrackAndWaterData() {
        let service = MapDataService(store: nil, bundle: .main)

        let installedPackIDs: Set<String> = ["central_australia"]
        let dirtRoads = service.dirtRoads(for: installedPackIDs)
        let fireTrails = service.fireTrails(for: installedPackIDs)
        let waterPoints = service.waterPoints(for: installedPackIDs)
        let shelters = service.shelters(for: installedPackIDs)

        XCTAssertEqual(dirtRoads.map(\.id), ["mereenie_loop"])
        XCTAssertEqual(fireTrails.map(\.id), ["ormiston_fire_trail"])
        XCTAssertEqual(Set(waterPoints.map(\.id)), ["ormiston_gorge_tank", "mereenie_bore"])
        XCTAssertEqual(Set(shelters.map(\.id)), ["alice_springs_relief_centre", "west_macdonnell_community_hall"])
    }
}
