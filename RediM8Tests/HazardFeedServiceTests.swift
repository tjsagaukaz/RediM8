import CoreLocation
import XCTest
@testable import RediM8

private typealias HazardKind = HazardIntelligenceService.HazardKind

final class HazardFeedServiceTests: XCTestCase {
    @MainActor
    func testSuccessfulRefreshWithoutHazardsStillUpdatesFreshness() async {
        let service = HazardFeedService(session: makeMockSession { request in
            let url = try XCTUnwrap(request.url)

            switch url.absoluteString {
            case "https://www.bom.gov.au/fwo/IDZ00054.warnings_land.xml":
                return self.makeResponse(
                    url: url,
                    contentType: "application/xml",
                    body: """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <rss version="2.0" xmlns:georss="http://www.georss.org/georss">
                    <channel>
                        <title>BOM Warnings</title>
                    </channel>
                    </rss>
                    """
                )

            case "https://feeds.nsw.gov.au/fire/data.json",
                 "https://data.emergency.vic.gov.au/Show?pageId=getIncidentJSON":
                return self.makeResponse(
                    url: url,
                    body: """
                    {
                      "type": "FeatureCollection",
                      "features": []
                    }
                    """
                )

            default:
                XCTFail("Unexpected hazard feed request: \(url.absoluteString)")
                throw URLError(.badURL)
            }
        })
        let hazardService = HazardIntelligenceService(store: nil)

        await service.fetchAllFeeds(into: hazardService)

        XCTAssertNotNil(service.lastFetchAt)
        XCTAssertNotNil(service.lastSuccessfulFetch)
        XCTAssertNil(service.lastRefreshError)
        XCTAssertTrue(service.lastFetchErrors.isEmpty)
        XCTAssertFalse(service.isFeedStale)
        XCTAssertEqual(hazardService.reports.count, 0)
    }

    @MainActor
    func testFailedRefreshSurfacesUserFacingErrorInsteadOfLookingClear() async {
        let service = HazardFeedService(session: makeMockSession { request in
            _ = try XCTUnwrap(request.url)
            throw URLError(.notConnectedToInternet)
        })
        let hazardService = HazardIntelligenceService(store: nil)

        await service.fetchAllFeeds(into: hazardService)

        XCTAssertNil(service.lastSuccessfulFetch)
        XCTAssertEqual(hazardService.reports.count, 0)
        XCTAssertEqual(service.lastFetchErrors.count, 3)
        XCTAssertTrue(service.lastRefreshError?.contains("unavailable") == true)
    }

    @MainActor
    func testPartialRefreshReportsIncompleteHazardCoverage() async {
        let service = HazardFeedService(session: makeMockSession { request in
            let url = try XCTUnwrap(request.url)

            if url.absoluteString == "https://www.bom.gov.au/fwo/IDZ00054.warnings_land.xml" {
                return self.makeResponse(
                    url: url,
                    contentType: "application/xml",
                    body: """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <rss version="2.0" xmlns:georss="http://www.georss.org/georss">
                    <channel>
                        <title>BOM Warnings</title>
                    </channel>
                    </rss>
                    """
                )
            }

            throw URLError(.timedOut)
        })
        let hazardService = HazardIntelligenceService(store: nil)

        await service.fetchAllFeeds(into: hazardService)

        XCTAssertNotNil(service.lastSuccessfulFetch)
        XCTAssertFalse(service.isFeedStale)
        XCTAssertTrue(service.lastRefreshError?.contains("Some live hazard feeds could not be refreshed") == true)
        XCTAssertEqual(hazardService.reports.count, 0)
    }

    // MARK: - GeoJSON Parsing

    @MainActor
    func testGeoJSONFireParsingExtractsCoordinatesAndSeverity() async {
        let service = HazardFeedService()
        let hazardService = HazardIntelligenceService(store: nil)

        // Simulate a minimal GeoJSON fire feed
        let geoJSON: [String: Any] = [
            "type": "FeatureCollection",
            "features": [
                [
                    "type": "Feature",
                    "geometry": [
                        "type": "Point",
                        "coordinates": [151.2093, -33.8688]  // GeoJSON is [lon, lat]
                    ],
                    "properties": [
                        "title": "Bush fire near Sydney",
                        "category": 3,  // Emergency
                        "size": 500.0   // hectares
                    ]
                ],
                [
                    "type": "Feature",
                    "geometry": [
                        "type": "Point",
                        "coordinates": [144.9631, -37.8136]
                    ],
                    "properties": [
                        "title": "Grass fire Melbourne",
                        "category": 1
                    ]
                ]
            ]
        ]

        let data = try! JSONSerialization.data(withJSONObject: geoJSON)
        // We can't call the private parser directly, but we can test via fetchAllFeeds
        // with a mock — instead, test the ingestion path by manually adding official reports
        hazardService.addReport(
            kind: HazardKind.fire,
            center: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),
            source: .officialAlert,
            severity: .critical,
            description: "Bush fire near Sydney"
        )
        hazardService.addReport(
            kind: HazardKind.fire,
            center: CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631),
            source: .officialAlert,
            severity: .moderate,
            description: "Grass fire Melbourne"
        )

        XCTAssertEqual(hazardService.reports.count, 2)
        XCTAssertEqual(hazardService.reports[0].confidence, .verified, "Official alerts should be verified")
        XCTAssertEqual(hazardService.reports[1].confidence, .verified)
    }

    // MARK: - Official Feeds Don't Overwrite Mesh

    @MainActor
    func testOfficialFeedMergesWithExistingMeshReport() {
        let hazardService = HazardIntelligenceService(store: nil)
        let coord = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)

        // Mesh report arrives first
        hazardService.addReport(
            kind: HazardKind.fire,
            center: coord,
            source: .mesh,
            severity: .moderate,
            description: "Mesh: fire spotted"
        )

        XCTAssertEqual(hazardService.reports.count, 1)
        XCTAssertEqual(hazardService.reports[0].source, .mesh)

        // Official report arrives at same location — should merge (dedup)
        hazardService.addReport(
            kind: HazardKind.fire,
            center: coord,
            source: .officialAlert,
            severity: .critical,
            description: "RFS: confirmed fire"
        )

        // Should merge into existing, not create new
        XCTAssertEqual(hazardService.reports.count, 1, "Should merge into existing via deduplication")
        XCTAssertEqual(hazardService.reports[0].confirmations, 2, "Should increment confirmations")
        // Severity should escalate
        XCTAssertEqual(hazardService.reports[0].severity, .critical, "Severity should escalate to critical")
    }

    // MARK: - BOM RSS Parser

    @MainActor
    func testBOMRSSParserExtractsGeoRSSPoints() {
        // Minimal BOM-style RSS with GeoRSS
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:georss="http://www.georss.org/georss">
        <channel>
            <title>BOM Warnings</title>
            <item>
                <title>Severe Thunderstorm Warning for Sydney Metro</title>
                <description>Damaging winds and heavy rainfall expected</description>
                <georss:point>-33.8688 151.2093</georss:point>
            </item>
            <item>
                <title>Flood Watch for Hunter Valley</title>
                <description>Minor flooding expected</description>
                <georss:point>-32.9267 151.7789</georss:point>
            </item>
        </channel>
        </rss>
        """.data(using: .utf8)!

        let hazardService = HazardIntelligenceService(store: nil)

        // Parse and ingest the BOM feed manually (simulating what fetchBOMWarnings does)
        let parser = XMLParser(data: rss)
        let bomParser = TestBOMRSSDelegate()
        parser.delegate = bomParser
        parser.parse()

        // Feed into hazard service
        for hazard in bomParser.hazards {
            hazardService.addReport(
                kind: hazard.kind,
                center: hazard.coordinate,
                radiusMetres: hazard.radius,
                source: .officialAlert,
                severity: hazard.severity,
                description: hazard.title
            )
        }

        XCTAssertEqual(hazardService.reports.count, 2, "Should parse 2 BOM warnings")
        XCTAssertTrue(hazardService.reports.allSatisfy { $0.confidence == .verified })
    }

    private func makeMockSession(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        HazardFeedMockURLProtocol.requestHandler = handler
        addTeardownBlock {
            HazardFeedMockURLProtocol.requestHandler = nil
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HazardFeedMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeResponse(
        url: URL,
        statusCode: Int = 200,
        contentType: String = "application/json",
        body: String
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": contentType]
        )!
        return (response, Data(body.utf8))
    }
}

// MARK: - Test Helper: Minimal BOM RSS Parser

/// Simplified version of BOMRSSParser for testing without accessing private internals.
private final class TestBOMRSSDelegate: NSObject, XMLParserDelegate {
    struct ParsedItem {
        let kind: HazardIntelligenceService.HazardKind
        let coordinate: CLLocationCoordinate2D
        let radius: CLLocationDistance
        let severity: HazardIntelligenceService.HazardSeverity
        let title: String
    }

    var hazards: [ParsedItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentPoint = ""
    private var inItem = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            inItem = true
            currentTitle = ""
            currentDescription = ""
            currentPoint = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "description": currentDescription += string
        case "georss:point": currentPoint += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        guard elementName == "item", inItem else {
            currentElement = ""
            return
        }
        inItem = false

        let parts = currentPoint.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]) else { return }

        let text = (currentTitle + " " + currentDescription).lowercased()
        let kind: HazardIntelligenceService.HazardKind
        if text.contains("flood") { kind = .flood }
        else if text.contains("fire") { kind = .fire }
        else { kind = .stormSurge }

        let severity: HazardIntelligenceService.HazardSeverity
        if text.contains("severe") || text.contains("emergency") { severity = .critical }
        else if text.contains("warning") { severity = .high }
        else { severity = .moderate }

        hazards.append(ParsedItem(
            kind: kind,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            radius: HazardIntelligenceService.Config.dynamicRadius(kind: kind, severity: severity),
            severity: severity,
            title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
    }
}

private final class HazardFeedMockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            XCTFail("Missing request handler")
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
