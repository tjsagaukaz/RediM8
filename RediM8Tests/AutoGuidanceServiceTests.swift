import CoreLocation
import XCTest
@testable import RediM8

final class AutoGuidanceServiceTests: XCTestCase {

    // MARK: - Initial State

    @MainActor
    func testInitialStateIsMonitoring() {
        let service = makeService()
        XCTAssertEqual(service.state, .monitoring)
        XCTAssertNil(service.lastUpdate)
        XCTAssertNil(service.activeRecommendation)
    }

    // MARK: - Evaluation

    @MainActor
    func testEvaluateReturnsMonitoringWithNoHazards() {
        let service = makeService()
        let origin = CLLocationCoordinate2D(latitude: -27.47, longitude: 153.02)

        let update = service.evaluate(userLocation: origin)

        XCTAssertEqual(update.state, .monitoring)
        XCTAssertNil(update.recommendation)
        XCTAssertNotNil(update.assessment)
        XCTAssertEqual(service.state, .monitoring)
    }

    @MainActor
    func testEvaluatePublishesLastUpdate() {
        let service = makeService()
        let origin = CLLocationCoordinate2D(latitude: -27.47, longitude: 153.02)

        let update = service.evaluate(userLocation: origin)

        XCTAssertNotNil(service.lastUpdate)
        XCTAssertEqual(service.lastUpdate?.state, update.state)
    }

    // MARK: - Accept / Dismiss

    @MainActor
    func testAcceptRecommendationTransitionsToNavigating() {
        let service = makeService()
        let rec = makeRecommendation()

        service.acceptRecommendation(rec)

        XCTAssertEqual(service.state, .navigating)
        XCTAssertEqual(service.activeRecommendation?.id, rec.id)
    }

    @MainActor
    func testDismissRecommendationReturnsToMonitoring() {
        let service = makeService()
        let rec = makeRecommendation()

        service.acceptRecommendation(rec)
        service.dismissRecommendation()

        XCTAssertEqual(service.state, .monitoring)
    }

    // MARK: - Reset

    @MainActor
    func testResetClearsAllState() {
        let service = makeService()
        let rec = makeRecommendation()

        service.acceptRecommendation(rec)
        _ = service.evaluate(userLocation: CLLocationCoordinate2D(latitude: -27.47, longitude: 153.02))
        service.reset()

        XCTAssertEqual(service.state, .monitoring)
        XCTAssertNil(service.activeRecommendation)
        XCTAssertNil(service.lastUpdate)
    }

    // MARK: - Guidance State

    @MainActor
    func testGuidanceStateIsActiveProperty() {
        XCTAssertFalse(AutoGuidanceService.GuidanceState.monitoring.isActive)
        XCTAssertTrue(AutoGuidanceService.GuidanceState.elevated.isActive)
        XCTAssertTrue(AutoGuidanceService.GuidanceState.recommending.isActive)
        XCTAssertTrue(AutoGuidanceService.GuidanceState.navigating.isActive)
        XCTAssertTrue(AutoGuidanceService.GuidanceState.routeCompromised.isActive)
    }

    // MARK: - Helpers

    @MainActor
    private func makeService() -> AutoGuidanceService {
        let hazardService = HazardIntelligenceService(store: nil)
        let feedService = HazardFeedService()
        let predictiveService = PredictiveCollapseService(
            hazardIntelligenceService: hazardService,
            hazardFeedService: feedService
        )
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
        let safeZoneService = SafeZoneService(
            nearestResourceService: nearestResourceService,
            offlineRoutingService: routingService,
            hazardIntelligenceService: hazardService,
            shelterService: shelterService,
            hazardFeedService: feedService
        )

        return AutoGuidanceService(
            predictiveCollapseService: predictiveService,
            safeZoneService: safeZoneService,
            hazardIntelligenceService: hazardService,
            offlineRoutingService: routingService
        )
    }

    private func makeRecommendation() -> SafeZoneService.SafeZoneRecommendation {
        SafeZoneService.SafeZoneRecommendation(
            id: "test-zone",
            name: "Test Zone",
            coordinate: CLLocationCoordinate2D(latitude: -27.47, longitude: 153.02),
            distanceMetres: 10_000,
            travelTimeSeconds: 1800,
            hazardExposure: 0.0,
            elevationMetres: 100,
            waterSourceCount: 3,
            shelterCount: 1,
            score: 5.0,
            confidence: .moderate,
            reasons: ["Test reason"],
            routeCoordinates: []
        )
    }
}
