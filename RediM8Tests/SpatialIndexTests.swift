import CoreLocation
import XCTest
@testable import RediM8

final class SpatialIndexTests: XCTestCase {

    private struct TestItem {
        let id: String
        let coordinate: CLLocationCoordinate2D
    }

    private func makeItems() -> [TestItem] {
        [
            TestItem(id: "sydney", coordinate: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)),
            TestItem(id: "melbourne", coordinate: CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)),
            TestItem(id: "brisbane", coordinate: CLLocationCoordinate2D(latitude: -27.4705, longitude: 153.0260)),
            TestItem(id: "perth", coordinate: CLLocationCoordinate2D(latitude: -31.9505, longitude: 115.8605)),
            TestItem(id: "adelaide", coordinate: CLLocationCoordinate2D(latitude: -34.9285, longitude: 138.6007)),
            TestItem(id: "canberra", coordinate: CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300)),
            TestItem(id: "hobart", coordinate: CLLocationCoordinate2D(latitude: -42.8821, longitude: 147.3272)),
            TestItem(id: "darwin", coordinate: CLLocationCoordinate2D(latitude: -12.4634, longitude: 130.8456)),
        ]
    }

    private func makeIndex() -> SpatialIndex<TestItem> {
        SpatialIndex(items: makeItems()) { $0.coordinate }
    }

    // MARK: - Construction

    func testEmptyIndexReturnsEmptyResults() {
        let index = SpatialIndex<TestItem>(items: []) { $0.coordinate }

        XCTAssertEqual(index.count, 0)
        XCTAssertTrue(index.nearest(to: CLLocationCoordinate2D(latitude: -33, longitude: 151), limit: 5).isEmpty)
        XCTAssertTrue(index.query(near: CLLocationCoordinate2D(latitude: -33, longitude: 151), radiusMetres: 100_000).isEmpty)
    }

    func testCountMatchesInputSize() {
        let index = makeIndex()
        XCTAssertEqual(index.count, 8)
    }

    // MARK: - Nearest Queries

    func testNearestToSydneyReturnsSydneyFirst() {
        let index = makeIndex()
        let sydneyCoord = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)

        let results = index.nearest(to: sydneyCoord, limit: 1)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].item.id, "sydney")
        XCTAssertEqual(results[0].distanceMetres, 0, accuracy: 1.0)
    }

    func testNearestReturnsSortedByDistance() {
        let index = makeIndex()
        let sydneyCoord = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)

        let results = index.nearest(to: sydneyCoord, limit: 8)

        XCTAssertEqual(results.count, 8)
        for i in 1..<results.count {
            XCTAssertLessThanOrEqual(
                results[i - 1].distanceMetres,
                results[i].distanceMetres,
                "Results should be sorted by distance ascending"
            )
        }
    }

    func testNearestLimitRespectsK() {
        let index = makeIndex()
        let coord = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)

        let three = index.nearest(to: coord, limit: 3)
        XCTAssertEqual(three.count, 3)

        let one = index.nearest(to: coord, limit: 1)
        XCTAssertEqual(one.count, 1)
    }

    func testNearestLimitExceedingCountReturnsAll() {
        let index = makeIndex()
        let coord = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)

        let results = index.nearest(to: coord, limit: 100)
        XCTAssertEqual(results.count, 8)
    }

    func testNearestSingleConvenience() {
        let index = makeIndex()
        let canberraCoord = CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300)

        let result = index.nearest(to: canberraCoord)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.item.id, "canberra")
    }

    // MARK: - Range Queries

    func testQueryWithinBoundingBox() {
        let index = makeIndex()

        // Bounding box covering SE Australia (Sydney, Canberra, Melbourne roughly)
        let bounds = SpatialIndex<TestItem>.BoundingBox(
            minLat: -38, maxLat: -33, minLon: 144, maxLon: 152
        )
        let results = index.query(within: bounds)

        let ids = Set(results.map(\.id))
        XCTAssertTrue(ids.contains("sydney"))
        XCTAssertTrue(ids.contains("melbourne"))
        XCTAssertTrue(ids.contains("canberra"))
        XCTAssertFalse(ids.contains("perth"), "Perth should not be in SE Australia bounding box")
        XCTAssertFalse(ids.contains("darwin"), "Darwin should not be in SE Australia bounding box")
    }

    func testQueryNearRadiusFindsNearbyItems() {
        let index = makeIndex()
        let sydneyCoord = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)

        // Canberra is ~250km from Sydney, so 300km radius should find it
        let results = index.query(near: sydneyCoord, radiusMetres: 300_000)
        let ids = Set(results.map(\.id))

        XCTAssertTrue(ids.contains("sydney"))
        XCTAssertTrue(ids.contains("canberra"), "Canberra (~250km) should be within 300km of Sydney")
        XCTAssertFalse(ids.contains("perth"), "Perth should not be within 300km of Sydney")
    }

    func testQueryNearSmallRadiusFiltersCorrectly() {
        let index = makeIndex()
        let sydneyCoord = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)

        // 10km radius should only find Sydney itself
        let results = index.query(near: sydneyCoord, radiusMetres: 10_000)
        let ids = Set(results.map(\.id))

        XCTAssertEqual(ids.count, 1)
        XCTAssertTrue(ids.contains("sydney"))
    }

    // MARK: - Large Dataset

    func testLargeDatasetPerformance() {
        var items: [TestItem] = []
        for i in 0..<10_000 {
            let lat = -10.0 - Double(i % 100) * 0.3
            let lon = 110.0 + Double(i / 100) * 0.4
            items.append(TestItem(id: "item-\(i)", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
        }
        let index = SpatialIndex(items: items) { $0.coordinate }
        let center = CLLocationCoordinate2D(latitude: -25, longitude: 130)

        measure {
            _ = index.nearest(to: center, limit: 10)
        }
    }

    // MARK: - Bounding Box

    func testBoundingBoxContains() {
        let box = SpatialIndex<TestItem>.BoundingBox(minLat: -40, maxLat: -30, minLon: 140, maxLon: 155)

        XCTAssertTrue(box.contains(CLLocationCoordinate2D(latitude: -35, longitude: 150)))
        XCTAssertFalse(box.contains(CLLocationCoordinate2D(latitude: -25, longitude: 150)))
        XCTAssertFalse(box.contains(CLLocationCoordinate2D(latitude: -35, longitude: 160)))
    }

    func testBoundingBoxIntersects() {
        let box1 = SpatialIndex<TestItem>.BoundingBox(minLat: -40, maxLat: -30, minLon: 140, maxLon: 155)
        let box2 = SpatialIndex<TestItem>.BoundingBox(minLat: -35, maxLat: -25, minLon: 145, maxLon: 160)
        let box3 = SpatialIndex<TestItem>.BoundingBox(minLat: -20, maxLat: -10, minLon: 100, maxLon: 110)

        XCTAssertTrue(box1.intersects(box2), "Overlapping boxes should intersect")
        XCTAssertFalse(box1.intersects(box3), "Non-overlapping boxes should not intersect")
    }

    func testBoundingBoxMinDistanceInsideReturnsZero() {
        let box = SpatialIndex<TestItem>.BoundingBox(minLat: -40, maxLat: -30, minLon: 140, maxLon: 155)
        let inside = CLLocationCoordinate2D(latitude: -35, longitude: 150)

        XCTAssertEqual(box.minDistance(to: inside), 0)
    }

    func testBoundingBoxMinDistanceOutsideReturnsPositive() {
        let box = SpatialIndex<TestItem>.BoundingBox(minLat: -40, maxLat: -30, minLon: 140, maxLon: 155)
        let outside = CLLocationCoordinate2D(latitude: -20, longitude: 130)

        XCTAssertGreaterThan(box.minDistance(to: outside), 0)
    }
}
