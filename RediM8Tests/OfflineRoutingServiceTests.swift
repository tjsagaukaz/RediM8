import CoreLocation
import XCTest
@testable import RediM8

@MainActor
final class OfflineRoutingServiceTests: XCTestCase {
    func testLoadGraphAndRouteRoundTripProducesExpectedPath() throws {
        let service = OfflineRoutingService()
        let url = try writeGraph(makeLinearGraph(), with: service)
        defer { try? FileManager.default.removeItem(at: url) }

        try service.loadGraph(from: url)

        XCTAssertTrue(service.isGraphLoaded)
        XCTAssertEqual(service.loadedGraphRegion, "linear-test")
        XCTAssertEqual(service.loadedGraphVersion, "1.0.0")

        let route = try service.route(
            from: coordinate(latitude: -27.0000, longitude: 153.0000),
            to: coordinate(latitude: -27.0000, longitude: 153.0200)
        )

        XCTAssertEqual(route.profile, .vehicle)
        XCTAssertEqual(route.coordinates.count, 3)
        XCTAssertEqual(route.steps.map(\.maneuver), [.depart, .arrive])
        XCTAssertGreaterThan(route.distanceMetres, 1_900)
        XCTAssertLessThan(route.distanceMetres, 2_300)
        XCTAssertEqual(route.steps.first?.instruction, "Head east")
    }

    func testHazardZonesCanRerouteAwayFromPenalizedNode() throws {
        let service = OfflineRoutingService()
        let url = try writeGraph(makeAlternativeGraph(), with: service)
        defer { try? FileManager.default.removeItem(at: url) }

        try service.loadGraph(from: url)

        let origin = coordinate(latitude: -27.0000, longitude: 153.0000)
        let destination = coordinate(latitude: -26.9900, longitude: 153.0100)

        let baselineRoute = try service.route(from: origin, to: destination)
        XCTAssertTrue(route(baselineRoute, containsCoordinateNear: coordinate(latitude: -27.0000, longitude: 153.0100)))

        service.setHazardZones([
            OfflineRoutingService.HazardZone(
                center: coordinate(latitude: -27.0000, longitude: 153.0100),
                radiusMetres: 500,
                penalty: 10,
                kind: .fire
            ),
        ])

        let hazardAwareRoute = try service.route(from: origin, to: destination)

        XCTAssertFalse(route(hazardAwareRoute, containsCoordinateNear: coordinate(latitude: -27.0000, longitude: 153.0100)))
        XCTAssertTrue(route(hazardAwareRoute, containsCoordinateNear: coordinate(latitude: -26.9900, longitude: 153.0000)))
        XCTAssertNotEqual(routeSignature(baselineRoute), routeSignature(hazardAwareRoute))
    }

    func testRouteRejectsDestinationOutsideLoadedBounds() throws {
        let service = OfflineRoutingService()
        let url = try writeGraph(makeLinearGraph(), with: service)
        defer { try? FileManager.default.removeItem(at: url) }

        try service.loadGraph(from: url)

        XCTAssertThrowsError(
            try service.route(
                from: CLLocationCoordinate2D(latitude: -27.0000, longitude: 153.0000),
                to: CLLocationCoordinate2D(latitude: -26.8000, longitude: 153.4000)
            )
        ) { error in
            XCTAssertEqual(error as? OfflineRoutingService.RoutingError, .destinationOutsideBounds)
        }
    }

    func testLoadGraphRejectsTamperedChecksum() throws {
        let service = OfflineRoutingService()
        let graph = makeLinearGraph()
        var data = service.serializeGraph(graph)
        data[data.count - 1].toggleBit(0)

        let url = tempGraphURL()
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try service.loadGraph(from: url)) { error in
            XCTAssertEqual(error as? OfflineRoutingService.RoutingError, .graphChecksumMismatch)
        }
    }

    private func makeLinearGraph() -> OfflineRoutingService.RoutingGraph {
        let nodes = [
            makeNode(id: 0, latitude: -27.0000, longitude: 153.0000),
            makeNode(id: 1, latitude: -27.0000, longitude: 153.0100),
            makeNode(id: 2, latitude: -27.0000, longitude: 153.0200),
        ]
        let edges = [
            OfflineRoutingService.GraphEdge(from: 0, to: 1, weightMetres: 1_100, shortcutMidNode: 0),
            OfflineRoutingService.GraphEdge(from: 1, to: 2, weightMetres: 1_100, shortcutMidNode: 0),
        ]

        return makeGraph(region: "linear-test", version: "1.0.0", nodes: nodes, edges: edges)
    }

    private func makeAlternativeGraph() -> OfflineRoutingService.RoutingGraph {
        let nodes = [
            makeNode(id: 0, latitude: -27.0000, longitude: 153.0000),
            makeNode(id: 1, latitude: -27.0000, longitude: 153.0100),
            makeNode(id: 2, latitude: -26.9900, longitude: 153.0000),
            makeNode(id: 3, latitude: -26.9900, longitude: 153.0100),
        ]
        let edges = [
            OfflineRoutingService.GraphEdge(from: 0, to: 1, weightMetres: 1_000, shortcutMidNode: 0),
            OfflineRoutingService.GraphEdge(from: 1, to: 3, weightMetres: 1_000, shortcutMidNode: 0),
            OfflineRoutingService.GraphEdge(from: 0, to: 2, weightMetres: 1_200, shortcutMidNode: 0),
            OfflineRoutingService.GraphEdge(from: 2, to: 3, weightMetres: 1_200, shortcutMidNode: 0),
        ]

        return makeGraph(region: "hazard-test", version: "1.0.0", nodes: nodes, edges: edges)
    }

    private func makeGraph(
        region: String,
        version: String,
        nodes: [OfflineRoutingService.GraphNode],
        edges: [OfflineRoutingService.GraphEdge]
    ) -> OfflineRoutingService.RoutingGraph {
        let latitudes = nodes.map { Double($0.latitude) }
        let longitudes = nodes.map { Double($0.longitude) }
        let header = OfflineRoutingService.OSRGHeader(
            formatVersion: 2,
            flags: 0,
            nodeCount: UInt32(nodes.count),
            edgeCount: UInt32(edges.count),
            bboxMinLat: OfflineRoutingService.degreesToMicrodegrees(latitudes.min() ?? 0),
            bboxMinLon: OfflineRoutingService.degreesToMicrodegrees(longitudes.min() ?? 0),
            bboxMaxLat: OfflineRoutingService.degreesToMicrodegrees(latitudes.max() ?? 0),
            bboxMaxLon: OfflineRoutingService.degreesToMicrodegrees(longitudes.max() ?? 0),
            regionNameLength: UInt16(region.utf8.count),
            versionStringLength: UInt16(version.utf8.count)
        )

        return OfflineRoutingService.RoutingGraph(
            region: region,
            version: version,
            header: header,
            nodes: nodes,
            edges: edges
        )
    }

    private func makeNode(
        id: UInt32,
        latitude: Double,
        longitude: Double
    ) -> OfflineRoutingService.GraphNode {
        OfflineRoutingService.GraphNode(
            id: id,
            latitude: Float(latitude),
            longitude: Float(longitude),
            level: 1
        )
    }

    private func writeGraph(
        _ graph: OfflineRoutingService.RoutingGraph,
        with service: OfflineRoutingService
    ) throws -> URL {
        let url = tempGraphURL()
        let data = service.serializeGraph(graph)
        try data.write(to: url)
        return url
    }

    private func tempGraphURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("osrg")
    }

    private func route(
        _ route: OfflineRoutingService.Route,
        containsCoordinateNear target: CLLocationCoordinate2D,
        accuracy: CLLocationDegrees = 0.0001
    ) -> Bool {
        route.coordinates.contains { coordinate in
            abs(coordinate.latitude - target.latitude) <= accuracy
                && abs(coordinate.longitude - target.longitude) <= accuracy
        }
    }

    private func routeSignature(_ route: OfflineRoutingService.Route) -> [String] {
        route.coordinates.map { coordinate in
            String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
        }
    }

    private func coordinate(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: Double(Float(latitude)),
            longitude: Double(Float(longitude))
        )
    }
}

private extension UInt8 {
    mutating func toggleBit(_ bit: UInt8) {
        self ^= 1 << bit
    }
}
