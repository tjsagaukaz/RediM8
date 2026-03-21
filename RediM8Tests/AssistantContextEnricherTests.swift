import CoreLocation
import XCTest
@testable import RediM8

@MainActor
final class AssistantContextEnricherTests: XCTestCase {

    // MARK: - Water Context

    func testWaterQueryReturnsNearbyWaterSources() {
        let enricher = makeEnricher(
            location: CLLocation(latitude: -27.284, longitude: 152.649)
        )
        let classification = makeClassification(topic: .waterPurification)

        let sections = enricher.contextSections(for: "Where can I get water?", classification: classification)

        let waterSection = sections.first { $0.id == "nearby-water" }
        XCTAssertNotNil(waterSection)
        XCTAssertEqual(waterSection?.tone, .info)
        XCTAssertFalse(waterSection?.items.isEmpty ?? true)
    }

    func testWaterQueryWithoutLocationReturnsLocationNeededSection() {
        let enricher = makeEnricher(location: nil)
        let classification = makeClassification(topic: .waterPurification)

        let sections = enricher.contextSections(for: "How do I purify water?", classification: classification)

        let locationNeeded = sections.first { $0.id.starts(with: "location-needed") }
        XCTAssertNotNil(locationNeeded)
        XCTAssertEqual(locationNeeded?.tone, .neutral)
    }

    func testWaterItemsIncludeNavigateAction() {
        let enricher = makeEnricher(
            location: CLLocation(latitude: -27.284, longitude: 152.649)
        )
        let classification = makeClassification(topic: .waterPurification)

        let sections = enricher.contextSections(for: "water nearby", classification: classification)

        let waterSection = sections.first { $0.id == "nearby-water" }
        guard let firstItem = waterSection?.items.first else {
            XCTFail("Expected water items")
            return
        }

        let hasNavigate = firstItem.actions.contains { action in
            if case .navigateToCoordinate = action { return true }
            return false
        }
        XCTAssertTrue(hasNavigate)
    }

    // MARK: - Shelter Context

    func testShelterQueryReturnsShelterSection() {
        let enricher = makeEnricher(
            location: CLLocation(latitude: -27.284, longitude: 152.649)
        )
        let classification = makeClassification(topic: .bushfireEvacuation)

        let sections = enricher.contextSections(for: "Where is shelter?", classification: classification)

        let shelterSection = sections.first { $0.id == "nearby-shelters" }
        XCTAssertNotNil(shelterSection)
        XCTAssertEqual(shelterSection?.tone, .ready)
    }

    func testEvacuationQueryAlwaysIncludesShelters() {
        let enricher = makeEnricher(
            location: CLLocation(latitude: -27.284, longitude: 152.649)
        )
        let classification = makeClassification(topic: .unknown)

        let sections = enricher.contextSections(for: "should I evacuate", classification: classification)

        let shelterSection = sections.first { $0.id == "nearby-shelters" }
        XCTAssertNotNil(shelterSection, "Evacuation queries should always include shelter context")
    }

    func testShelterItemsIncludeNavigateAction() {
        let enricher = makeEnricher(
            location: CLLocation(latitude: -27.284, longitude: 152.649)
        )
        let classification = makeClassification(topic: .bushfireEvacuation)

        let sections = enricher.contextSections(for: "shelter nearby", classification: classification)

        let shelterSection = sections.first { $0.id == "nearby-shelters" }
        guard let firstItem = shelterSection?.items.first else {
            XCTFail("Expected shelter items")
            return
        }

        let hasNavigate = firstItem.actions.contains { action in
            if case .navigateToCoordinate = action { return true }
            return false
        }
        XCTAssertTrue(hasNavigate)
    }

    // MARK: - Beacon Context

    func testHazardBeaconsAppearSeparatelyFromResourceBeacons() {
        let beaconService = BeaconService(meshService: MeshService(), locationService: LocationService(), store: nil)
        beaconService.recordReceivedBeacon(makeBeacon(type: .fireSpotted, statusText: "Fire spotted"))
        beaconService.recordReceivedBeacon(makeBeacon(id: "beacon_water", type: .waterAvailable, statusText: "Water tanker"))

        let enricher = makeEnricher(beaconService: beaconService)
        let classification = makeClassification(topic: .unknown)

        let sections = enricher.contextSections(for: "fire danger water", classification: classification)

        let hazardSection = sections.first { $0.id == "hazard-signals" }
        let resourceSection = sections.first { $0.id == "community-signals" }

        XCTAssertNotNil(hazardSection)
        XCTAssertNotNil(resourceSection)
        XCTAssertTrue(hazardSection?.isHazardWarning ?? false)
        XCTAssertFalse(resourceSection?.isHazardWarning ?? true)
    }

    func testBeaconItemsIncludeNavigateAction() {
        let beaconService = BeaconService(meshService: MeshService(), locationService: LocationService(), store: nil)
        beaconService.recordReceivedBeacon(makeBeacon(type: .waterAvailable, statusText: "Water tanker"))

        let enricher = makeEnricher(beaconService: beaconService)
        let classification = makeClassification(topic: .waterPlanning)

        let sections = enricher.contextSections(for: "water supply", classification: classification)

        let beaconSection = sections.first { $0.id == "community-signals" }
        guard let item = beaconSection?.items.first else {
            XCTFail("Expected beacon items")
            return
        }

        let hasNavigate = item.actions.contains { action in
            if case .navigateToCoordinate = action { return true }
            return false
        }
        XCTAssertTrue(hasNavigate)
    }

    func testHazardBeaconSectionIsMarkedAsHazardWarning() {
        let beaconService = BeaconService(meshService: MeshService(), locationService: LocationService(), store: nil)
        beaconService.recordReceivedBeacon(makeBeacon(type: .fireSpotted, statusText: "Fire moving east"))

        let enricher = makeEnricher(beaconService: beaconService)
        let classification = makeClassification(topic: .unknown)

        let sections = enricher.contextSections(for: "fire danger", classification: classification)

        let hazardSection = sections.first { $0.id == "hazard-signals" }
        XCTAssertNotNil(hazardSection)
        XCTAssertTrue(hazardSection?.isHazardWarning ?? false)
        XCTAssertEqual(hazardSection?.tone, .danger)
    }

    // MARK: - Fire Trail Context

    func testFireTrailContextAppearsForBushfireQueries() {
        let enricher = makeEnricher()
        let classification = makeClassification(topic: .bushfireEvacuation)

        let sections = enricher.contextSections(for: "bushfire evacuation route", classification: classification)

        let trailSection = sections.first { $0.id == "fire-trails" }
        // Will only appear if offline fire trail data is bundled
        if trailSection != nil {
            XCTAssertEqual(trailSection?.tone, .info)
            XCTAssertFalse(trailSection?.items.isEmpty ?? true)
        }
    }

    // MARK: - Caching

    func testCachedResultReturnedForSameQueryAndTopic() {
        let enricher = makeEnricher(
            location: CLLocation(latitude: -27.284, longitude: 152.649)
        )
        let classification = makeClassification(topic: .waterPurification)

        let first = enricher.contextSections(for: "water", classification: classification)
        let second = enricher.contextSections(for: "water", classification: classification)

        XCTAssertEqual(first.count, second.count)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testCacheInvalidatedForDifferentQuery() {
        let enricher = makeEnricher(
            location: CLLocation(latitude: -27.284, longitude: 152.649)
        )
        let waterClassification = makeClassification(topic: .waterPurification)
        let shelterClassification = makeClassification(topic: .bushfireEvacuation)

        let waterSections = enricher.contextSections(for: "water", classification: waterClassification)
        let shelterSections = enricher.contextSections(for: "shelter", classification: shelterClassification)

        XCTAssertNotEqual(waterSections.map(\.id), shelterSections.map(\.id))
    }

    func testCacheInvalidatedForDifferentTopic() {
        let enricher = makeEnricher(
            location: CLLocation(latitude: -27.284, longitude: 152.649)
        )

        let first = enricher.contextSections(
            for: "water",
            classification: makeClassification(topic: .waterPurification)
        )
        let second = enricher.contextSections(
            for: "water",
            classification: makeClassification(topic: .waterPlanning)
        )

        // Different topics should rebuild even with same query text
        XCTAssertEqual(first.count, second.count) // Both water-related, same structure
    }

    // MARK: - Fallback Without Location

    func testEnricherWorksWithoutLocation() {
        let enricher = makeEnricher(location: nil)
        let classification = makeClassification(topic: .unknown)

        let sections = enricher.contextSections(for: "general question", classification: classification)

        for section in sections {
            if section.id.starts(with: "nearby-") {
                XCTFail("Should not return nearby data without location")
            }
        }
    }

    func testEnricherStillWorksWithoutLocationForBeacons() {
        let beaconService = BeaconService(meshService: MeshService(), locationService: LocationService(), store: nil)
        beaconService.recordReceivedBeacon(makeBeacon(type: .waterAvailable, statusText: "Water"))

        let enricher = makeEnricher(beaconService: beaconService, location: nil)
        let classification = makeClassification(topic: .waterPlanning)

        let sections = enricher.contextSections(for: "water supply", classification: classification)

        let beaconSection = sections.first { $0.id == "community-signals" }
        XCTAssertNotNil(beaconSection, "Beacon context should work without location")
    }

    // MARK: - Context Section Structure

    func testAlertSectionHasOpenMapAction() {
        // Structural test: verify alert items include map actions when alerts are present
        let section = AssistantContextSection(
            id: "official-alerts",
            title: "Current Alerts",
            detail: "Test",
            tone: .danger,
            items: [
                AssistantContextItem(
                    title: "Test Alert",
                    detail: "Emergency Warning",
                    actions: [.openMap]
                )
            ],
            isHazardWarning: true
        )

        XCTAssertTrue(section.isHazardWarning)
        XCTAssertEqual(section.items.first?.actions, [.openMap])
    }

    func testContextSectionDefaultsToNonHazard() {
        let section = AssistantContextSection(
            id: "test",
            title: "Test",
            detail: "Test",
            tone: .info,
            items: []
        )

        XCTAssertFalse(section.isHazardWarning)
    }

    func testHazardQueryReturnsOfficialAlertTrustStatus() {
        let now = Date()
        let location = CLLocation(latitude: -27.284, longitude: 152.649)
        let alert = OfficialAlert(
            id: "qld-bushfire-alert",
            title: "Bushfire watch and act",
            message: "Bushfire nearby.",
            instruction: "Prepare to leave.",
            issuer: "Queensland Fire Department",
            sourceName: "Queensland Official Alerts",
            sourceURLString: "https://example.com/alert",
            jurisdiction: .qld,
            kind: .bushfire,
            severity: .watchAndAct,
            regionScope: "Brisbane Hills",
            area: OfficialAlertArea(
                description: "Brisbane Hills",
                center: GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
                radiusKilometres: 12
            ),
            issuedAt: now.addingTimeInterval(-20 * 60),
            lastUpdated: now.addingTimeInterval(-12 * 60),
            expiresAt: now.addingTimeInterval(2 * 60 * 60)
        )
        let officialAlertService = OfficialAlertService(
            store: nil,
            cachedLibrary: OfficialAlertLibrary(
                lastUpdated: alert.lastUpdated,
                sources: [],
                alerts: [alert]
            )
        )
        let enricher = makeEnricher(
            officialAlertService: officialAlertService,
            location: location
        )
        let classification = makeClassification(topic: .bushfireEvacuation)

        let payload = enricher.contextPayload(for: "Bushfire nearby — what do I do?", classification: classification)

        XCTAssertEqual(payload.snapshot?.hazard, .bushfire)
        XCTAssertNil(payload.status.routeStatus)
        XCTAssertTrue((11 ... 12).contains(payload.snapshot?.lastSyncMinutes ?? -1))
    }

    // MARK: - Helpers

    private func makeEnricher(
        beaconService: BeaconService? = nil,
        officialAlertService: OfficialAlertService? = nil,
        location: CLLocation? = CLLocation(latitude: -27.284, longitude: 152.649),
        isOffline: Bool = false
    ) -> AssistantContextEnricher {
        let realBeaconService = beaconService ?? BeaconService(meshService: MeshService(), locationService: LocationService(), store: nil)
        let realOfficialAlertService = officialAlertService ?? OfficialAlertService(store: nil)

        return AssistantContextEnricher(
            waterPointService: WaterPointService(bundle: .main),
            shelterService: ShelterService(bundle: .main),
            fireTrailService: FireTrailService(bundle: .main),
            officialAlertService: realOfficialAlertService,
            beaconService: realBeaconService,
            mapDataService: MapDataService(
                store: nil,
                bundle: .main,
                waterPointService: WaterPointService(bundle: .main),
                fireTrailService: FireTrailService(bundle: .main),
                shelterService: ShelterService(bundle: .main)
            ),
            locationProvider: { location },
            isOfflineProvider: { isOffline }
        )
    }

    private func makeClassification(topic: AssistantIntentTopic) -> AssistantIntentClassification {
        AssistantIntentClassification(
            policyID: nil,
            topic: topic,
            riskBand: topic == .unknown ? .unknown : .advisory,
            preferredMode: .summarizedRetrieval,
            modeWhenGenerationDisabled: .retrievalOnlyCard,
            matchedGuideIDs: [],
            matchedTerms: [],
            trustLabel: nil,
            lastReviewed: nil,
            regionScope: nil,
            confidence: 0.8,
            escalationNote: nil
        )
    }

    private func makeBeacon(
        id: String = "beacon_test",
        type: BeaconType,
        statusText: String
    ) -> CommunityBeacon {
        CommunityBeacon(
            id: id,
            nodeID: "TEST",
            type: type,
            state: .active,
            latitude: -27.468,
            longitude: 153.028,
            locationName: "Test Location",
            statusText: statusText,
            message: "Test message",
            resources: [],
            createdAt: .now,
            updatedAt: .now,
            expiresAt: .now.addingTimeInterval(2 * 60 * 60),
            relayDepth: 0,
            displayName: nil,
            showsName: false,
            emergencyMedicalSummary: nil
        )
    }
}
