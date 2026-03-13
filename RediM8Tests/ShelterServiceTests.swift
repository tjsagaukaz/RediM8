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

    @MainActor
    func testNearbySheltersCanUseLiveNearbyDataWithoutInstalledPacks() async {
        let session = makeMockSession(responseBody: Self.liveShelterResponse)
        let service = ShelterService(bundle: .main, session: session)
        let coordinate = CLLocationCoordinate2D(latitude: -27.4701, longitude: 153.0210)

        let refreshed = await service.refreshNearbyNetworkData(near: coordinate)
        let nearby = service.nearbyShelters(
            near: coordinate,
            installedPackIDs: [],
            limit: 1
        )

        XCTAssertEqual(refreshed.count, 1)
        XCTAssertEqual(nearby.first?.shelter.name, "Test Community Centre")
        XCTAssertEqual(nearby.first?.shelter.availability, .networkNearby)
        XCTAssertEqual(nearby.first?.shelter.sourceKind, .openMapData)
        XCTAssertEqual(nearby.first?.shelter.type, .communityShelter)
    }

    private func makeMockSession(responseBody: String) -> URLSession {
        ShelterMockURLProtocol.requestHandler = { request in
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
        configuration.protocolClasses = [ShelterMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static let liveShelterResponse = """
    {
      "elements": [
        {
          "type": "node",
          "id": 202,
          "lat": -27.4701,
          "lon": 153.0210,
          "tags": {
            "amenity": "community_centre",
            "name": "Test Community Centre"
          }
        }
      ]
    }
    """
}

private final class ShelterMockURLProtocol: URLProtocol {
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
