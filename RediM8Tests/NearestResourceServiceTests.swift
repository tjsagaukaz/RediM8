import CoreLocation
import XCTest
@testable import RediM8

@MainActor
final class NearestResourceServiceTests: XCTestCase {
    func testNearestWaterUsesOfflinePackFilteringAndDistanceOrdering() {
        let service = makeService()

        let results = service.nearest(
            .water,
            to: CLLocationCoordinate2D(latitude: -27.284, longitude: 152.649),
            installedPackIDs: ["brisbane_region"],
            limit: 2
        )

        XCTAssertEqual(results.map(\.id), [
            "water-wivenhoe_campground_tap",
            "water-mt_glorious_rain_tank",
        ])
        XCTAssertEqual(results.map(\.category), [.water, .water])
        XCTAssertEqual(results.first?.subtitle, "Campground Water")
        XCTAssertLessThan(results[0].distanceMetres, results[1].distanceMetres)
    }

    func testNearestSheltersReturnBundledLocationsForInstalledPack() {
        let service = makeService()

        let results = service.nearest(
            .shelter,
            to: CLLocationCoordinate2D(latitude: -23.724, longitude: 132.347),
            installedPackIDs: ["central_australia"],
            limit: 2
        )

        XCTAssertEqual(results.map(\.id), [
            "shelter-west_macdonnell_community_hall",
            "shelter-alice_springs_relief_centre",
        ])
        XCTAssertEqual(results.first?.subtitle, "Community Shelter")
        XCTAssertLessThan(results[0].distanceMetres, results[1].distanceMetres)
    }

    func testNearestRoadsIncludeFireTrailsAndRespectPackAvailability() {
        let service = makeService()

        let results = service.nearest(
            .road,
            to: CLLocationCoordinate2D(latitude: -23.623, longitude: 132.741),
            installedPackIDs: ["central_australia"],
            limit: 2
        )

        XCTAssertEqual(results.map(\.id), [
            "road-ormiston_fire_trail",
            "road-mereenie_loop",
        ])
        XCTAssertEqual(results.first?.subtitle, "Fire Access Trail · 4WD Recommended")
        XCTAssertEqual(results.last?.subtitle, "Unsealed Road · 4WD Recommended")
    }

    func testNearestTownFiltersToCriticalTownResourceKinds() {
        let service = makeService()

        let results = service.nearest(
            .town,
            to: CLLocationCoordinate2D(latitude: -27.4701, longitude: 153.0210),
            installedPackIDs: [],
            limit: 2
        )

        XCTAssertEqual(results.map(\.name), [
            "Ampol Brisbane Central",
            "Royal Brisbane and Women's Hospital",
        ])
        XCTAssertEqual(results.map(\.subtitle), ["Fuel", "Hospital"])
        XCTAssertEqual(results.map(\.category), [.town, .town])
    }

    func testNearestAllReturnsOnePerCategorySortedByDistance() {
        let service = makeService()

        let results = service.nearestAll(
            to: CLLocationCoordinate2D(latitude: -23.724, longitude: 132.347),
            installedPackIDs: ["central_australia"],
            limitPerCategory: 1
        )

        XCTAssertEqual(results.count, 4)
        XCTAssertEqual(Set(results.map(\.category)), Set(NearestResourceService.ResourceCategory.allCases))
        XCTAssertEqual(results.first?.id, "water-mereenie_bore")
        XCTAssertEqual(results.last?.category, .town)
        XCTAssertTrue(zip(results, results.dropFirst()).allSatisfy { lhs, rhs in
            lhs.distanceMetres <= rhs.distanceMetres
        })
    }

    private func makeService() -> NearestResourceService {
        let waterPointService = WaterPointService(bundle: .main)
        let shelterService = ShelterService(bundle: .main)
        let preparednessDataService = PreparednessDataService(store: nil, bundle: .main)
        let mapService = MapService(
            store: nil,
            preparednessDataService: preparednessDataService,
            bundle: .main
        )
        let mapDataService = MapDataService(
            store: nil,
            bundle: .main,
            waterPointService: waterPointService,
            fireTrailService: FireTrailService(bundle: .main),
            shelterService: shelterService
        )

        return NearestResourceService(
            waterPointService: waterPointService,
            shelterService: shelterService,
            mapService: mapService,
            mapDataService: mapDataService
        )
    }
}
