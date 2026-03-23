import CoreLocation
import Foundation

struct NearbyWaterPoint: Identifiable, Equatable {
    let point: WaterPoint
    let distanceMetres: CLLocationDistance

    var id: String { point.id }

    var distanceText: String {
        guard distanceMetres.isFinite else {
            return "Offline reference"
        }
        if distanceMetres >= 1000 {
            return String(format: "%.1f km", distanceMetres / 1000)
        }
        return "\(Int(distanceMetres.rounded())) m"
    }
}

struct WaterPointGuide: Equatable {
    let nearbySources: [NearbyWaterPoint]
    let context: String
}

final class WaterPointService {
    private enum Config {
        static let duplicateDistanceMetres: CLLocationDistance = 180
    }

    private let waterPointDataset: WaterPointDataset
    private let spatialIndex: SpatialIndex<WaterPoint>

    private(set) var lastNearbyNetworkError: String?

    init(bundle: Bundle = .main) {
        let dataset: WaterPointDataset
        do {
            dataset = try bundle.decode("WaterPoints.json", as: WaterPointDataset.self)
        } catch {
            RediLogger.spatial.error("Failed to decode WaterPoints.json: \(error.localizedDescription)")
            dataset = WaterPointDataset(lastUpdated: .distantPast, waterPoints: [])
        }
        self.waterPointDataset = dataset
        self.spatialIndex = SpatialIndex(items: dataset.waterPoints) { $0.coordinate.coordinate }
    }

    var lastUpdated: Date {
        waterPointDataset.lastUpdated
    }

    var didLoadOfflineData: Bool {
        !waterPointDataset.waterPoints.isEmpty
    }

    var availableKinds: [WaterPointKind] {
        WaterPointKind.allCases
    }

    var hasNearbyNetworkData: Bool {
        false
    }

    func waterPoints(
        for installedPackIDs: Set<String>,
        near coordinate: CLLocationCoordinate2D? = nil,
        kinds: Set<WaterPointKind> = []
    ) -> [WaterPoint] {
        offlineWaterPoints(for: installedPackIDs, kinds: kinds)
    }

    func nearbyWaterPoints(
        near coordinate: CLLocationCoordinate2D,
        installedPackIDs: Set<String>,
        kinds: Set<WaterPointKind> = [],
        limit: Int = 3
    ) -> [NearbyWaterPoint] {
        // Use R-tree for fast nearest-neighbor query on offline data
        Array(spatialIndex.nearest(to: coordinate, limit: limit * 4)
            .filter { entry in
                let point = entry.item
                guard isFeatureAvailable(point.packIDs, within: installedPackIDs) else { return false }
                return kinds.isEmpty || kinds.contains(point.kind)
            }
            .sorted { $0.distanceMetres < $1.distanceMetres }
            .prefix(limit)
            .map { NearbyWaterPoint(point: $0.item, distanceMetres: $0.distanceMetres) })
    }

    func guide(
        installedPacks: [OfflineMapPack],
        installedPackIDs: Set<String>,
        currentLocation: CLLocation?,
        kinds: Set<WaterPointKind> = [],
        limit: Int = 3
    ) -> WaterPointGuide? {
        guard let anchor = anchorContext(installedPacks: installedPacks, currentLocation: currentLocation) else {
            return nil
        }

        let nearbySources = nearbyWaterPoints(
            near: anchor.coordinate,
            installedPackIDs: installedPackIDs,
            kinds: kinds,
            limit: limit
        )

        guard !nearbySources.isEmpty else {
            return nil
        }

        let includesNetworkNearby = nearbySources.contains { $0.point.availability == .networkNearby }
        let context = anchor.context

        return WaterPointGuide(nearbySources: nearbySources, context: context)
    }

    /// Offline-only: no network refresh. Returns empty — all data is from bundled datasets.
    @MainActor
    func refreshNearbyNetworkData(
        near coordinate: CLLocationCoordinate2D,
        force: Bool = false
    ) async -> [WaterPoint] {
        []
    }

    private func offlineWaterPoints(
        for installedPackIDs: Set<String>,
        kinds: Set<WaterPointKind>
    ) -> [WaterPoint] {
        waterPointDataset.waterPoints.filter { point in
            guard isFeatureAvailable(point.packIDs, within: installedPackIDs) else {
                return false
            }
            return kinds.isEmpty || kinds.contains(point.kind)
        }
    }

    // Network methods removed — offline architecture uses bundled data only

    private func anchorContext(
        installedPacks: [OfflineMapPack],
        currentLocation: CLLocation?
    ) -> (coordinate: CLLocationCoordinate2D, context: String)? {
        if let currentLocation {
            return (
                currentLocation.coordinate,
                "Sorted from your current location using installed offline packs."
            )
        }

        guard let firstPack = installedPacks.sorted(by: { $0.name < $1.name }).first else {
            return nil
        }

        return (
            firstPack.center.coordinate,
            "Sorted from the \(firstPack.name) pack area until live location is available."
        )
    }

    private func isFeatureAvailable(_ featurePackIDs: [String], within installedPackIDs: Set<String>) -> Bool {
        featurePackIDs.isEmpty || !Set(featurePackIDs).isDisjoint(with: installedPackIDs)
    }

    // All Overpass query, classification, name, and notes methods removed
    // — offline architecture uses pre-curated bundled data only
}

struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

struct OverpassElement: Decodable {
    let type: String
    let id: Int64
    let lat: Double?
    let lon: Double?
    let center: OverpassCoordinate?
    let geometry: [OverpassCoordinate]?
    let tags: [String: String]?
}

struct OverpassCoordinate: Decodable {
    let lat: Double
    let lon: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

func metresBetween(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D) -> CLLocationDistance {
    CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
        .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
}

func distance(from reference: CLLocationCoordinate2D, to target: CLLocationCoordinate2D) -> CLLocationDistance {
    metresBetween(reference, target)
}

func nearestCoordinate(
    in geometry: [OverpassCoordinate],
    to anchor: CLLocationCoordinate2D,
    closesGeometry: Bool
) -> CLLocationCoordinate2D? {
    guard !geometry.isEmpty else {
        return nil
    }

    if geometry.count == 1 {
        return geometry[0].coordinate
    }

    let originLatitudeRadians = anchor.latitude.degreesToRadians
    let earthRadius = 6_371_000.0

    func project(_ coordinate: CLLocationCoordinate2D) -> ProjectedCoordinate {
        let latitudeRadians = coordinate.latitude.degreesToRadians
        let longitudeRadians = coordinate.longitude.degreesToRadians
        let anchorLongitudeRadians = anchor.longitude.degreesToRadians
        let anchorLatitudeRadians = anchor.latitude.degreesToRadians

        return ProjectedCoordinate(
            x: (longitudeRadians - anchorLongitudeRadians) * cos(originLatitudeRadians) * earthRadius,
            y: (latitudeRadians - anchorLatitudeRadians) * earthRadius
        )
    }

    func unproject(_ coordinate: ProjectedCoordinate) -> CLLocationCoordinate2D {
        let latitude = anchor.latitude + (coordinate.y / earthRadius).radiansToDegrees
        let longitude = anchor.longitude + (coordinate.x / (earthRadius * cos(originLatitudeRadians))).radiansToDegrees
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var bestProjectedCoordinate: ProjectedCoordinate?
    var bestDistance = Double.infinity

    for index in 0 ..< geometry.count - 1 {
        let start = project(geometry[index].coordinate)
        let end = project(geometry[index + 1].coordinate)
        let candidate = nearestPointOnSegment(from: start, to: end)
        let distance = hypot(candidate.x, candidate.y)
        if distance < bestDistance {
            bestDistance = distance
            bestProjectedCoordinate = candidate
        }
    }

    if closesGeometry, let first = geometry.first, let last = geometry.last {
        let start = project(last.coordinate)
        let end = project(first.coordinate)
        let candidate = nearestPointOnSegment(from: start, to: end)
        let distance = hypot(candidate.x, candidate.y)
        if distance < bestDistance {
            bestDistance = distance
            bestProjectedCoordinate = candidate
        }
    }

    return bestProjectedCoordinate.map(unproject)
}

private func nearestPointOnSegment(
    from start: ProjectedCoordinate,
    to end: ProjectedCoordinate
) -> ProjectedCoordinate {
    let segmentX = end.x - start.x
    let segmentY = end.y - start.y
    let segmentLengthSquared = segmentX * segmentX + segmentY * segmentY

    guard segmentLengthSquared > 0 else {
        return start
    }

    let projection = max(
        0,
        min(
            1,
            ((-start.x) * segmentX + (-start.y) * segmentY) / segmentLengthSquared
        )
    )

    return ProjectedCoordinate(
        x: start.x + projection * segmentX,
        y: start.y + projection * segmentY
    )
}

private struct ProjectedCoordinate {
    let x: Double
    let y: Double
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}

private extension String {
    var percentEncodedForFormBody: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))) ?? self
    }

    var normalizedLookupKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    var isGenericNearbyLabel: Bool {
        hasPrefix("Nearby ")
    }
}
