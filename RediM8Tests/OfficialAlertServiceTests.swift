import CoreLocation
import UserNotifications
import XCTest
@testable import RediM8

@MainActor
final class OfficialAlertServiceTests: XCTestCase {
    func testParseCAPFeedBuildsOfficialAlertFromCircleAndMetadata() throws {
        let source = OfficialAlertSource(
            id: "qld_cap_warnings",
            name: "Queensland Official Warnings",
            jurisdiction: .qld,
            urlString: "https://example.com/cap.xml"
        )

        let alerts = try OfficialAlertService.parseCAPFeed(Self.sampleCAPFeed.data(using: .utf8)!, source: source)
        let alert = try XCTUnwrap(alerts.first)

        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alert.jurisdiction, .qld)
        XCTAssertEqual(alert.kind, .flood)
        XCTAssertEqual(alert.severity, .watchAndAct)
        XCTAssertEqual(alert.issuer, "Queensland Fire and Emergency Services")
        let area = try XCTUnwrap(alert.area)
        XCTAssertEqual(area.description, "Brisbane Hinterland")
        XCTAssertEqual(area.center.latitude, -27.4, accuracy: 0.001)
        XCTAssertEqual(area.center.longitude, 152.9, accuracy: 0.001)
        XCTAssertEqual(area.radiusKilometres, 18, accuracy: 0.001)
    }

    func testNearbyAlertsUsesCurrentLocationAndSafeModeSeverity() {
        let alert = OfficialAlert(
            id: "warning_1",
            title: "Bushfire warning",
            message: "Leave now if unsafe to stay.",
            instruction: "Follow emergency services.",
            issuer: "Queensland Fire and Emergency Services",
            sourceName: "Queensland Official Warnings",
            sourceURLString: nil,
            jurisdiction: .qld,
            kind: .bushfire,
            severity: .emergencyWarning,
            regionScope: "Mount Glorious",
            area: OfficialAlertArea(
                description: "Mount Glorious",
                center: GeoPoint(latitude: -27.33, longitude: 152.75),
                radiusKilometres: 15
            ),
            issuedAt: .now,
            lastUpdated: .now,
            expiresAt: Calendar.current.date(byAdding: .hour, value: 6, to: .now)
        )

        let service = OfficialAlertService(
            store: nil,
            feedSources: [],
            cachedLibrary: OfficialAlertLibrary(lastUpdated: .now, sources: [], alerts: [alert])
        )

        let nearby = service.nearbyAlerts(
            currentLocation: CLLocation(latitude: -27.35, longitude: 152.82),
            installedPacks: []
        )

        XCTAssertEqual(nearby.map(\.id), ["warning_1"])
        XCTAssertEqual(service.safeModeAlert(
            currentLocation: CLLocation(latitude: -27.35, longitude: 152.82),
            installedPacks: []
        )?.id, "warning_1")
    }

    func testParseRSSFeedBuildsJurisdictionWideAlert() throws {
        let source = OfficialAlertSource(
            id: "tas_bom_warnings",
            name: "Tasmania Official Weather Warnings",
            jurisdiction: .tas,
            urlString: "https://example.com/tas.xml"
        )

        let alerts = try OfficialAlertService.parseRSSFeed(Self.sampleRSSFeed.data(using: .utf8)!, source: source)
        let alert = try XCTUnwrap(alerts.first)

        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alert.jurisdiction, .tas)
        XCTAssertNil(alert.area)
        XCTAssertEqual(alert.scopeTrustLabel, "Statewide feed")
        XCTAssertEqual(alert.issuer, "Bureau of Meteorology")
        XCTAssertEqual(alert.severity, .watchAndAct)
    }

    func testNearbyAlertsMatchesJurisdictionWideFeedsButDoesNotTriggerSafeMode() {
        let tasAlert = OfficialAlert(
            id: "tas_warning",
            title: "Tasmania Flood Warning",
            message: "Major flood warning for parts of Tasmania.",
            instruction: nil,
            issuer: "Bureau of Meteorology",
            sourceName: "Tasmania Official Weather Warnings",
            sourceURLString: "https://example.com/tas",
            jurisdiction: .tas,
            kind: .flood,
            severity: .emergencyWarning,
            regionScope: "Tasmania",
            area: nil,
            issuedAt: .now,
            lastUpdated: .now,
            expiresAt: Calendar.current.date(byAdding: .hour, value: 6, to: .now)
        )

        let qldAlert = OfficialAlert(
            id: "qld_warning",
            title: "Queensland Flood Warning",
            message: "Major flood warning for parts of Queensland.",
            instruction: nil,
            issuer: "Bureau of Meteorology",
            sourceName: "Queensland Official Weather Warnings",
            sourceURLString: "https://example.com/qld",
            jurisdiction: .qld,
            kind: .flood,
            severity: .watchAndAct,
            regionScope: "Queensland",
            area: nil,
            issuedAt: .now,
            lastUpdated: .now,
            expiresAt: Calendar.current.date(byAdding: .hour, value: 6, to: .now)
        )

        let service = OfficialAlertService(
            store: nil,
            feedSources: [],
            cachedLibrary: OfficialAlertLibrary(lastUpdated: .now, sources: [], alerts: [tasAlert, qldAlert])
        )

        let nearby = service.nearbyAlerts(
            currentLocation: CLLocation(latitude: -42.88, longitude: 147.32),
            installedPacks: []
        )

        XCTAssertEqual(nearby.map(\.id), ["tas_warning"])
        XCTAssertNil(service.safeModeAlert(
            currentLocation: CLLocation(latitude: -42.88, longitude: 147.32),
            installedPacks: []
        ))
    }

    func testJurisdictionAlertsReturnAllActiveAlertsForSelectedState() {
        let qldAreaAlert = OfficialAlert(
            id: "qld_area",
            title: "Brisbane Bushfire Warning",
            message: "Watch and act.",
            instruction: nil,
            issuer: "Queensland Fire and Emergency Services",
            sourceName: "Queensland Official Warnings",
            sourceURLString: nil,
            jurisdiction: .qld,
            kind: .bushfire,
            severity: .watchAndAct,
            regionScope: "Brisbane",
            area: OfficialAlertArea(
                description: "Brisbane",
                center: GeoPoint(latitude: -27.47, longitude: 153.02),
                radiusKilometres: 10
            ),
            issuedAt: .now,
            lastUpdated: .now,
            expiresAt: .now.addingTimeInterval(3600)
        )
        let qldFeedAlert = OfficialAlert(
            id: "qld_feed",
            title: "Queensland Flood Warning",
            message: "Statewide flood warning.",
            instruction: nil,
            issuer: "Bureau of Meteorology",
            sourceName: "Queensland Official Weather Warnings",
            sourceURLString: nil,
            jurisdiction: .qld,
            kind: .flood,
            severity: .advice,
            regionScope: "Queensland",
            area: nil,
            issuedAt: .now,
            lastUpdated: .now,
            expiresAt: .now.addingTimeInterval(3600)
        )
        let nswAlert = OfficialAlert(
            id: "nsw_feed",
            title: "New South Wales Flood Warning",
            message: "Statewide flood warning.",
            instruction: nil,
            issuer: "Bureau of Meteorology",
            sourceName: "NSW Official Weather Warnings",
            sourceURLString: nil,
            jurisdiction: .nsw,
            kind: .flood,
            severity: .watchAndAct,
            regionScope: "New South Wales",
            area: nil,
            issuedAt: .now,
            lastUpdated: .now,
            expiresAt: .now.addingTimeInterval(3600)
        )

        let service = OfficialAlertService(
            store: nil,
            feedSources: [],
            cachedLibrary: OfficialAlertLibrary(lastUpdated: .now, sources: [], alerts: [qldAreaAlert, qldFeedAlert, nswAlert])
        )

        XCTAssertEqual(service.alerts(for: .qld).map(\.id), ["qld_area", "qld_feed"])
        XCTAssertEqual(service.australiaWideAlerts().map(\.id), ["qld_area", "nsw_feed", "qld_feed"])
    }

    func testPreferredJurisdictionPrefersCurrentLocationThenInstalledPackThenCache() {
        let service = OfficialAlertService(
            store: nil,
            feedSources: [],
            cachedLibrary: OfficialAlertLibrary(
                lastUpdated: .now,
                sources: [
                    OfficialAlertSource(
                        id: "tas_feed",
                        name: "Tasmania Official Weather Warnings",
                        jurisdiction: .tas,
                        urlString: "https://example.com/tas"
                    )
                ],
                alerts: []
            )
        )

        let qldLocation = CLLocation(latitude: -27.47, longitude: 153.02)
        let nswPack = try! JSONDecoder().decode(
            OfflineMapPack.self,
            from: Data(Self.sampleNSWPack.utf8)
        )

        XCTAssertEqual(
            service.preferredJurisdiction(currentLocation: qldLocation, installedPacks: [nswPack]),
            .qld
        )
        XCTAssertEqual(
            service.preferredJurisdiction(currentLocation: nil, installedPacks: [nswPack]),
            .nsw
        )
        XCTAssertEqual(
            service.preferredJurisdiction(currentLocation: nil, installedPacks: []),
            .tas
        )
    }

    func testParseWAWarningsFeedBuildsOfficialAlertFromGeoJSON() throws {
        let source = OfficialAlertSource(
            id: "wa_warnings",
            name: "Western Australia Official Warnings",
            jurisdiction: .wa,
            urlString: "https://example.com/wa.json"
        )

        let alerts = try OfficialAlertService.parseWAWarningsFeed(Self.sampleWAWarnings.data(using: .utf8)!, source: source)
        let alert = try XCTUnwrap(alerts.first)

        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alert.jurisdiction, .wa)
        XCTAssertEqual(alert.kind, .bushfire)
        XCTAssertEqual(alert.severity, .watchAndAct)
        XCTAssertEqual(alert.regionScope, "Chidlow, Western Australia")
        XCTAssertNotNil(alert.area)
    }

    // MARK: - Offline Refresh Behavior

    func testRefreshIsNoOpInOfflineMode() async {
        let service = OfficialAlertService(
            store: nil,
            feedSources: [],
            cachedLibrary: .empty
        )

        await service.refresh()

        // refresh() is now a no-op — should not crash or set errors
        XCTAssertTrue(service.library.alerts.isEmpty)
    }

    // MARK: - Notification Service

    func testOfficialAlertNotificationServiceUsesExistingAlertsAsBaseline() {
        let alert = OfficialAlert(
            id: "tas_existing",
            title: "Tasmania Warning",
            message: "Existing cached warning.",
            instruction: nil,
            issuer: "Bureau of Meteorology",
            sourceName: "Tasmania Official Weather Warnings",
            sourceURLString: "https://example.com/tas-warning",
            jurisdiction: .tas,
            kind: .flood,
            severity: .watchAndAct,
            regionScope: "Tasmania",
            area: nil,
            issuedAt: .now,
            lastUpdated: .now,
            expiresAt: .now.addingTimeInterval(3600)
        )
        let officialAlertService = OfficialAlertService(
            store: nil,
            feedSources: [],
            cachedLibrary: OfficialAlertLibrary(lastUpdated: .now, sources: [], alerts: [alert])
        )
        let notificationCenter = OfficialAlertNotificationCenterMock()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        _ = OfficialAlertNotificationService(
            officialAlertService: officialAlertService,
            locationService: LocationService(permissionsManager: .live),
            mapDataService: makeMapDataService(),
            settings: PreparednessSettings(
                prepScoreNotificationsEnabled: true,
                seventyTwoHourPlanAlertsEnabled: true,
                goBagRemindersEnabled: true,
                officialAlertNotificationsEnabled: true,
                officialAlertNotificationScope: .state,
                officialAlertNotificationJurisdiction: .tas
            ),
            notificationCenter: notificationCenter,
            userDefaults: defaults
        )

        XCTAssertTrue(notificationCenter.requests.isEmpty)
    }

    // MARK: - Helpers

    private func makeMapDataService() -> MapDataService {
        let bundle = Bundle.main
        let waterPointService = WaterPointService(bundle: bundle)
        let fireTrailService = FireTrailService(bundle: bundle)
        let shelterService = ShelterService(bundle: bundle)
        return MapDataService(
            store: nil,
            bundle: bundle,
            waterPointService: waterPointService,
            fireTrailService: fireTrailService,
            shelterService: shelterService
        )
    }

    private static let sampleNSWPack = """
    {
      "id": "nsw_pack",
      "name": "NSW Regional",
      "subtitle": "New South Wales",
      "kind": "regional",
      "sizeMB": 120,
      "center": {
        "latitude": -33.86,
        "longitude": 151.20
      },
      "latitudeDelta": 2,
      "longitudeDelta": 2,
      "coverageSummary": "NSW",
      "supportedLayers": ["officialAlerts"],
      "isBundledByDefault": false,
      "lastUpdated": 0,
      "routingGraphFilename": null
    }
    """

    private static let sampleCAPFeed = """
    <?xml version="1.0" ?>
    <EDXLDistribution xmlns="urn:oasis:names:tc:emergency:EDXL:DE:1.0">
      <contentObject xmlns="urn:oasis:names:tc:emergency:cap:1.2">
        <xmlContent xmlns:cap="urn:oasis:names:tc:emergency:cap:1.2">
          <embeddedXMLContent>
            <cap:alert>
              <cap:identifier>TEST_001</cap:identifier>
              <cap:sent>2026-03-12T03:08:16+10:00</cap:sent>
              <cap:info>
                <cap:language>en-AU</cap:language>
                <cap:event>Flood</cap:event>
                <cap:responseType>Prepare</cap:responseType>
                <cap:severity>Severe</cap:severity>
                <cap:senderName>Queensland Police</cap:senderName>
                <cap:headline>Flood warning for Brisbane Hinterland</cap:headline>
                <cap:description>Creeks are rising and roads may become cut.</cap:description>
                <cap:instruction>Move to higher ground if needed.</cap:instruction>
                <cap:web>https://example.com</cap:web>
                <cap:expires>2026-03-12T09:08:16+10:00</cap:expires>
                <cap:parameter>
                  <cap:valueName>AlertLevel</cap:valueName>
                  <cap:value>Watch and Act</cap:value>
                </cap:parameter>
                <cap:parameter>
                  <cap:valueName>ControlAuthority</cap:valueName>
                  <cap:value>Queensland Fire and Emergency Services</cap:value>
                </cap:parameter>
                <cap:parameter>
                  <cap:valueName>Location</cap:valueName>
                  <cap:value>Brisbane Hinterland</cap:value>
                </cap:parameter>
                <cap:parameter>
                  <cap:valueName>Hazard</cap:valueName>
                  <cap:value>Flood</cap:value>
                </cap:parameter>
                <cap:area>
                  <cap:areaDesc>Brisbane Hinterland</cap:areaDesc>
                  <cap:circle>-27.4,152.9 18</cap:circle>
                </cap:area>
              </cap:info>
            </cap:alert>
          </embeddedXMLContent>
        </xmlContent>
      </contentObject>
    </EDXLDistribution>
    """

    private static let sampleRSSFeed = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Tasmania Warnings</title>
        <item>
          <title>Flood Warning for Tasmania</title>
          <link>https://example.com/tas-warning</link>
          <description><![CDATA[Major flooding is possible in parts of Tasmania.]]></description>
          <pubDate>Thu, 12 Mar 2026 14:20:00 +1100</pubDate>
        </item>
      </channel>
    </rss>
    """

    private static let sampleWAWarnings = """
    {
      "warnings": [
        {
          "id": "wa_001",
          "publishing-status": "Published",
          "warning-type": "Bushfire Advice",
          "title": "MONITOR CONDITIONS - BEECHINA, CHIDLOW, AND WOOROLOO",
          "headline": "BEECHINA, CHIDLOW, and WOOROLOO",
          "alert-line": "<p>A Bushfire Advice is in place for people in parts of CHIDLOW.</p>",
          "what-to-do-note": "<ul><li>Monitor conditions.</li></ul>",
          "cap-event-type": ["Bushfire"],
          "cap-severity": "Minor - minimal threat",
          "action-statement": "Monitor conditions",
          "issued-date-time": "2026-03-12T10:27:00.855+08:00",
          "updatedAt": "2026-03-12T02:27:02.394Z",
          "location": {
            "value": "Chidlow, Western Australia",
            "latitude": -31.862436,
            "longitude": 116.26864
          },
          "geo-source": {
            "features": [
              {
                "geometry": {
                  "type": "Point",
                  "coordinates": [116.31020378812315, -31.840650693894204]
                }
              },
              {
                "geometry": {
                  "type": "Polygon",
                  "coordinates": [[[116.3180746994538, -31.8187269622453], [116.32444230763406, -31.82416556581962], [116.32755664626933, -31.847753828641196], [116.3185707784416, -31.86257442554311], [116.30053742561961, -31.828913298304094], [116.3180746994538, -31.8187269622453]]]
                }
              }
            ]
          }
        }
      ]
    }
    """
}

private final class OfficialAlertNotificationCenterMock: OfficialAlertNotificationCentering {
    var authorizationState: UNAuthorizationStatus = .authorized
    private(set) var requests: [UNNotificationRequest] = []

    func requestAuthorization(options _: UNAuthorizationOptions) async throws -> Bool {
        authorizationState = .authorized
        return true
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationState
    }

    func add(_ request: UNNotificationRequest) async throws {
        requests.append(request)
    }
}
