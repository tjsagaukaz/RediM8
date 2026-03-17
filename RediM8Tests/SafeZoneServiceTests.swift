import CoreLocation
import XCTest
@testable import RediM8

final class SafeZoneServiceTests: XCTestCase {

    // MARK: - Discovery Returns Empty When No Graph

    @MainActor
    func testDiscoveryReturnsEmptyWhenRoutingUnavailable() {
        // Without a loaded routing graph, all candidates will fail routing → empty results
        let service = makeService()
        let origin = CLLocationCoordinate2D(latitude: -27.47, longitude: 153.02)

        let result = service.discoverSafeZones(from: origin)

        // No routing graph = no routes = no recommendations
        XCTAssertTrue(result.recommendations.isEmpty, "Should return empty when routing is unavailable")
        XCTAssertEqual(result.candidatesRejected, result.candidatesEvaluated, "All candidates should be rejected")
    }

    // MARK: - Cache Behavior

    @MainActor
    func testResultIsCachedOnSecondCall() {
        let service = makeService()
        let origin = CLLocationCoordinate2D(latitude: -27.47, longitude: 153.02)

        let first = service.discoverSafeZones(from: origin)
        let second = service.discoverSafeZones(from: origin)

        // Same timestamp = cached
        XCTAssertEqual(first.timestamp, second.timestamp, "Second call should return cached result")
    }

    @MainActor
    func testCacheInvalidatedByExplicitCall() {
        let service = makeService()
        let origin = CLLocationCoordinate2D(latitude: -27.47, longitude: 153.02)

        let first = service.discoverSafeZones(from: origin)
        service.invalidateCache()
        let second = service.discoverSafeZones(from: origin)

        XCTAssertNotEqual(first.timestamp, second.timestamp, "Should recompute after cache invalidation")
    }

    @MainActor
    func testCacheInvalidatedByMovingOrigin() {
        let service = makeService()

        let first = service.discoverSafeZones(
            from: CLLocationCoordinate2D(latitude: -27.47, longitude: 153.02)
        )
        // Move >500m away
        let second = service.discoverSafeZones(
            from: CLLocationCoordinate2D(latitude: -27.48, longitude: 153.02)
        )

        XCTAssertNotEqual(first.timestamp, second.timestamp, "Moving >500m should invalidate cache")
    }

    // MARK: - Recommendation Model

    @MainActor
    func testRecommendationDistanceText() {
        let rec = makeRecommendation(distanceMetres: 45_000)
        XCTAssertEqual(rec.distanceText, "45 KM")

        let short = makeRecommendation(distanceMetres: 800)
        XCTAssertEqual(short.distanceText, "800 M")
    }

    @MainActor
    func testRecommendationTravelTimeText() {
        let rec = makeRecommendation(travelTimeSeconds: 5400) // 1.5 hours
        XCTAssertEqual(rec.travelTimeText, "1H 30M")

        let quick = makeRecommendation(travelTimeSeconds: 900) // 15 min
        XCTAssertEqual(quick.travelTimeText, "15 MIN")
    }

    @MainActor
    func testRecommendationHazardLevelText() {
        XCTAssertEqual(makeRecommendation(hazardExposure: 0.0).hazardLevelText, "CLEAR")
        XCTAssertEqual(makeRecommendation(hazardExposure: 0.5).hazardLevelText, "LOW RISK")
        XCTAssertEqual(makeRecommendation(hazardExposure: 2.0).hazardLevelText, "MODERATE RISK")
        XCTAssertEqual(makeRecommendation(hazardExposure: 5.0).hazardLevelText, "HIGH RISK")
    }

    @MainActor
    func testRecommendationElevationText() {
        let withElev = makeRecommendation(elevationMetres: 350)
        XCTAssertEqual(withElev.elevationText, "350M ASL")

        let noElev = makeRecommendation(elevationMetres: nil)
        XCTAssertEqual(noElev.elevationText, "N/A")
    }

    // MARK: - Discovery Result Model

    @MainActor
    func testDiscoveryResultIsEmptyWhenNoRecommendations() {
        let result = SafeZoneService.DiscoveryResult(
            recommendations: [],
            timestamp: .now,
            candidatesEvaluated: 10,
            candidatesRejected: 10,
            computeTimeMs: 5
        )

        XCTAssertTrue(result.isEmpty)
        XCTAssertNil(result.bestZone)
    }

    @MainActor
    func testDiscoveryResultBestZoneIsFirst() {
        let recs = [
            makeRecommendation(id: "zone-a", score: 5.0),
            makeRecommendation(id: "zone-b", score: 10.0)
        ]
        let result = SafeZoneService.DiscoveryResult(
            recommendations: recs,
            timestamp: .now,
            candidatesEvaluated: 20,
            candidatesRejected: 18,
            computeTimeMs: 12
        )

        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result.bestZone?.id, "zone-a")
    }

    // MARK: - Helpers

    @MainActor
    private func makeService() -> SafeZoneService {
        let waterPointService = WaterPointService(bundle: .main)
        let shelterService = ShelterService(bundle: .main)
        let mapService = MapService(store: nil, preparednessDataService: PreparednessDataService(store: nil, bundle: .main), bundle: .main)
        let mapDataService = MapDataService(
            store: nil,
            bundle: .main,
            waterPointService: waterPointService,
            fireTrailService: FireTrailService(bundle: .main),
            shelterService: shelterService
        )
        let nearestResourceService = NearestResourceService(
            waterPointService: waterPointService,
            shelterService: shelterService,
            mapService: mapService,
            mapDataService: mapDataService
        )
        let routingService = OfflineRoutingService()
        let hazardService = HazardIntelligenceService(store: nil)

        return SafeZoneService(
            nearestResourceService: nearestResourceService,
            offlineRoutingService: routingService,
            hazardIntelligenceService: hazardService,
            shelterService: shelterService
        )
    }

    private func makeRecommendation(
        id: String = "test",
        distanceMetres: CLLocationDistance = 10_000,
        travelTimeSeconds: TimeInterval = 1800,
        hazardExposure: Double = 0.0,
        elevationMetres: Int16? = 100,
        score: Double = 5.0
    ) -> SafeZoneService.SafeZoneRecommendation {
        SafeZoneService.SafeZoneRecommendation(
            id: id,
            name: "Test Zone",
            coordinate: CLLocationCoordinate2D(latitude: -27.47, longitude: 153.02),
            distanceMetres: distanceMetres,
            travelTimeSeconds: travelTimeSeconds,
            hazardExposure: hazardExposure,
            elevationMetres: elevationMetres,
            waterSourceCount: 3,
            shelterCount: 1,
            score: score,
            confidence: .moderate,
            reasons: ["Test reason"],
            routeCoordinates: []
        )
    }
}
