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

    @MainActor
    func testNearbyWaterPointsCanUseLiveNearbyDataWithoutInstalledPacks() async {
        let session = makeMockSession(responseBody: Self.liveWaterResponse)
        let service = WaterPointService(bundle: .main, session: session)
        let coordinate = CLLocationCoordinate2D(latitude: -27.4701, longitude: 153.0210)

        let refreshed = await service.refreshNearbyNetworkData(near: coordinate)
        let nearby = service.nearbyWaterPoints(
            near: coordinate,
            installedPackIDs: [],
            limit: 1
        )

        XCTAssertEqual(refreshed.count, 1)
        XCTAssertEqual(nearby.first?.point.name, "Test Drinking Water")
        XCTAssertEqual(nearby.first?.point.availability, .networkNearby)
        XCTAssertEqual(nearby.first?.point.sourceKind, .openMapData)
        XCTAssertEqual(nearby.first?.point.quality, .drinkingWater)
    }

    private func makeMockSession(responseBody: String) -> URLSession {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://overpass-api.de/api/interpreter")
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(responseBody.utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static let liveWaterResponse = """
    {
      "elements": [
        {
          "type": "node",
          "id": 101,
          "lat": -27.4701,
          "lon": 153.0210,
          "tags": {
            "amenity": "drinking_water",
            "name": "Test Drinking Water"
          }
        }
      ]
    }
    """
}

private final class MockURLProtocol: URLProtocol {
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
