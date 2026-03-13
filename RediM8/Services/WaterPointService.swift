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
    private enum NetworkConfig {
        static let endpoint = URL(string: "https://overpass-api.de/api/interpreter")!
        static let refreshMaxAge: TimeInterval = 15 * 60
        static let displayMaxAge: TimeInterval = 6 * 60 * 60
        static let cacheReuseDistanceMetres: CLLocationDistance = 2_500
        static let maxResults = 24
        static let duplicateDistanceMetres: CLLocationDistance = 180
        static let radiusSequence = [4_000, 12_000]
    }

    private let waterPointDataset: WaterPointDataset
    private let session: URLSession
    private var nearbyNetworkCache: NearbyWaterNetworkCache?

    private(set) var lastNearbyNetworkError: String?

    init(bundle: Bundle = .main, session: URLSession = .shared) {
        waterPointDataset = (try? bundle.decode("WaterPoints.json", as: WaterPointDataset.self))
            ?? WaterPointDataset(lastUpdated: .distantPast, waterPoints: [])
        self.session = session
    }

    var lastUpdated: Date {
        max(waterPointDataset.lastUpdated, nearbyNetworkCache?.fetchedAt ?? .distantPast)
    }

    var didLoadOfflineData: Bool {
        !waterPointDataset.waterPoints.isEmpty
    }

    var availableKinds: [WaterPointKind] {
        WaterPointKind.allCases
    }

    var hasNearbyNetworkData: Bool {
        !(nearbyNetworkCache?.points.isEmpty ?? true)
    }

    func waterPoints(
        for installedPackIDs: Set<String>,
        near coordinate: CLLocationCoordinate2D? = nil,
        kinds: Set<WaterPointKind> = []
    ) -> [WaterPoint] {
        let offlinePoints = offlineWaterPoints(for: installedPackIDs, kinds: kinds)

        guard let coordinate else {
            return offlinePoints
        }

        let networkPoints = (cachedNearbyNetworkPoints(near: coordinate, maxAge: NetworkConfig.displayMaxAge) ?? [])
            .filter { kinds.isEmpty || kinds.contains($0.kind) }

        return mergeOfflineAndNetworkPoints(
            offlinePoints,
            networkPoints,
            referenceCoordinate: coordinate
        )
    }

    func nearbyWaterPoints(
        near coordinate: CLLocationCoordinate2D,
        installedPackIDs: Set<String>,
        kinds: Set<WaterPointKind> = [],
        limit: Int = 3
    ) -> [NearbyWaterPoint] {
        let anchor = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return waterPoints(for: installedPackIDs, near: coordinate, kinds: kinds)
            .map { point in
                NearbyWaterPoint(
                    point: point,
                    distanceMetres: anchor.distance(from: CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude))
                )
            }
            .sorted { lhs, rhs in
                if lhs.distanceMetres == rhs.distanceMetres {
                    return lhs.point.name < rhs.point.name
                }
                return lhs.distanceMetres < rhs.distanceMetres
            }
            .prefix(limit)
            .map { $0 }
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
        let context: String
        if currentLocation != nil, includesNetworkNearby, !installedPackIDs.isEmpty {
            context = "Sorted from your current location using live nearby map data, with offline packs as fallback."
        } else if currentLocation != nil, includesNetworkNearby {
            context = "Sorted from your current location using live nearby map data."
        } else {
            context = anchor.context
        }

        return WaterPointGuide(nearbySources: nearbySources, context: context)
    }

    @MainActor
    func refreshNearbyNetworkData(
        near coordinate: CLLocationCoordinate2D,
        force: Bool = false
    ) async -> [WaterPoint] {
        if !force,
           let cachedPoints = cachedNearbyNetworkPoints(near: coordinate, maxAge: NetworkConfig.refreshMaxAge),
           !cachedPoints.isEmpty
        {
            lastNearbyNetworkError = nil
            return cachedPoints
        }

        do {
            let points = try await fetchNearbyNetworkData(near: coordinate)
            nearbyNetworkCache = NearbyWaterNetworkCache(
                anchor: coordinate,
                fetchedAt: .now,
                points: points
            )
            lastNearbyNetworkError = nil
            return points
        } catch {
            lastNearbyNetworkError = "Live nearby water search is unavailable right now."
            return cachedNearbyNetworkPoints(near: coordinate, maxAge: NetworkConfig.displayMaxAge) ?? []
        }
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

    private func cachedNearbyNetworkPoints(
        near coordinate: CLLocationCoordinate2D,
        maxAge: TimeInterval
    ) -> [WaterPoint]? {
        guard let nearbyNetworkCache,
              nearbyNetworkCache.matches(
                  coordinate: coordinate,
                  maxAge: maxAge,
                  reuseDistanceMetres: NetworkConfig.cacheReuseDistanceMetres
              )
        else {
            return nil
        }

        return nearbyNetworkCache.points
    }

    private func mergeOfflineAndNetworkPoints(
        _ offlinePoints: [WaterPoint],
        _ networkPoints: [WaterPoint],
        referenceCoordinate: CLLocationCoordinate2D
    ) -> [WaterPoint] {
        guard !networkPoints.isEmpty else {
            return offlinePoints
        }

        var merged = offlinePoints
        for point in networkPoints.sorted(by: { distance(from: referenceCoordinate, to: $0.location) < distance(from: referenceCoordinate, to: $1.location) }) {
            let duplicatesOfflinePoint = merged.contains { existing in
                guard metresBetween(existing.location, point.location) <= NetworkConfig.duplicateDistanceMetres else {
                    return false
                }
                if existing.kind == point.kind {
                    return true
                }
                return existing.name.normalizedLookupKey == point.name.normalizedLookupKey
            }
            if !duplicatesOfflinePoint {
                merged.append(point)
            }
        }
        return merged
    }

    private func fetchNearbyNetworkData(
        near coordinate: CLLocationCoordinate2D
    ) async throws -> [WaterPoint] {
        var bestCandidates: [RankedWaterCandidate] = []

        for radius in NetworkConfig.radiusSequence {
            let candidates = try await fetchNearbyNetworkData(near: coordinate, radiusMetres: radius)
            if !candidates.isEmpty {
                bestCandidates = candidates
                if candidates.count >= 6 {
                    break
                }
            }
        }

        return deduplicate(candidates: bestCandidates)
            .prefix(NetworkConfig.maxResults)
            .map(\.point)
    }

    private func fetchNearbyNetworkData(
        near coordinate: CLLocationCoordinate2D,
        radiusMetres: Int
    ) async throws -> [RankedWaterCandidate] {
        let requestBody = Self.waterOverpassQuery(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMetres: radiusMetres
        )

        var request = URLRequest(url: NetworkConfig.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("RediM8/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = "data=\(requestBody.percentEncodedForFormBody)".data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200 ..< 300).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        let payload = try JSONDecoder().decode(OverpassResponse.self, from: data)
        let anchor = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return payload.elements.compactMap { element in
            let classification = Self.classifyWaterElement(element)
            guard let classification else {
                return nil
            }

            let resolvedCoordinate = Self.coordinate(for: element, relativeTo: coordinate, closesGeometry: classification.closesGeometry)
            guard let resolvedCoordinate else {
                return nil
            }

            let point = WaterPoint(
                id: "osm_water_\(element.type)_\(element.id)",
                name: Self.name(for: element.tags ?? [:], kind: classification.kind),
                kind: classification.kind,
                coordinate: GeoPoint(latitude: resolvedCoordinate.latitude, longitude: resolvedCoordinate.longitude),
                packIDs: [],
                quality: classification.quality,
                notes: Self.notes(for: element.tags ?? [:], kind: classification.kind, quality: classification.quality),
                source: "Live nearby open map data (OSM / Overpass)",
                availability: .networkNearby,
                sourceKind: .openMapData,
                lastUpdated: .now
            )

            return RankedWaterCandidate(
                point: point,
                distanceMetres: anchor.distance(from: CLLocation(latitude: resolvedCoordinate.latitude, longitude: resolvedCoordinate.longitude))
            )
        }
        .sorted {
            if $0.distanceMetres == $1.distanceMetres {
                return $0.point.name < $1.point.name
            }
            return $0.distanceMetres < $1.distanceMetres
        }
    }

    private func deduplicate(candidates: [RankedWaterCandidate]) -> [RankedWaterCandidate] {
        var kept: [RankedWaterCandidate] = []

        for candidate in candidates {
            let isDuplicate = kept.contains { existing in
                guard metresBetween(existing.point.location, candidate.point.location) <= NetworkConfig.duplicateDistanceMetres else {
                    return false
                }

                if existing.point.name.normalizedLookupKey == candidate.point.name.normalizedLookupKey {
                    return true
                }

                return existing.point.kind == candidate.point.kind
                    && existing.point.name.isGenericNearbyLabel
                    && candidate.point.name.isGenericNearbyLabel
            }

            if !isDuplicate {
                kept.append(candidate)
            }
        }

        return kept
    }

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

    private static func waterOverpassQuery(
        latitude: Double,
        longitude: Double,
        radiusMetres: Int
    ) -> String {
        let latitudeString = String(format: "%.5f", latitude)
        let longitudeString = String(format: "%.5f", longitude)

        return """
        [out:json][timeout:25];
        (
          node(around:\(radiusMetres),\(latitudeString),\(longitudeString))[amenity=drinking_water];
          node(around:\(radiusMetres),\(latitudeString),\(longitudeString))[man_made~"^(water_tap|water_well|water_tank)$"];
          node(around:\(radiusMetres),\(latitudeString),\(longitudeString))[natural=spring];
          way(around:\(radiusMetres),\(latitudeString),\(longitudeString))[waterway~"^(river|stream|canal|drain)$"];
          way(around:\(radiusMetres),\(latitudeString),\(longitudeString))[natural=water];
          way(around:\(radiusMetres),\(latitudeString),\(longitudeString))[water~"^(lake|pond|reservoir)$"];
        );
        out body geom tags;
        """
    }

    private static func classifyWaterElement(_ element: OverpassElement) -> WaterElementClassification? {
        let tags = element.tags ?? [:]

        if tags["amenity"] == "drinking_water" || tags["man_made"] == "water_tap" {
            return WaterElementClassification(kind: .communityTap, quality: .drinkingWater, closesGeometry: false)
        }

        if tags["man_made"] == "water_well" {
            return WaterElementClassification(kind: .boreWater, quality: .unknownQuality, closesGeometry: false)
        }

        if tags["man_made"] == "water_tank" {
            return WaterElementClassification(kind: .waterTank, quality: .unknownQuality, closesGeometry: false)
        }

        if tags["natural"] == "spring" {
            return WaterElementClassification(kind: .riverCreek, quality: .seasonal, closesGeometry: false)
        }

        if let waterway = tags["waterway"], ["river", "stream", "canal", "drain"].contains(waterway) {
            return WaterElementClassification(kind: .riverCreek, quality: tags["intermittent"] == "yes" ? .seasonal : .unknownQuality, closesGeometry: false)
        }

        if tags["natural"] == "water" || tags["water"] != nil {
            return WaterElementClassification(kind: .riverCreek, quality: .unknownQuality, closesGeometry: true)
        }

        return nil
    }

    private static func coordinate(
        for element: OverpassElement,
        relativeTo anchor: CLLocationCoordinate2D,
        closesGeometry: Bool
    ) -> CLLocationCoordinate2D? {
        if let lat = element.lat, let lon = element.lon {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        if let geometry = element.geometry, !geometry.isEmpty {
            return nearestCoordinate(in: geometry, to: anchor, closesGeometry: closesGeometry)
        }

        if let center = element.center {
            return center.coordinate
        }

        return nil
    }

    private static func name(for tags: [String: String], kind: WaterPointKind) -> String {
        if let name = tags["name"]?.nilIfBlank {
            return name
        }

        if tags["amenity"] == "drinking_water" || tags["man_made"] == "water_tap" {
            return "Nearby Drinking Water"
        }

        if tags["man_made"] == "water_well" {
            return "Nearby Water Well"
        }

        if tags["man_made"] == "water_tank" {
            return "Nearby Water Tank"
        }

        if tags["natural"] == "spring" {
            return "Nearby Spring"
        }

        if let waterway = tags["waterway"] {
            switch waterway {
            case "river":
                return "Nearby River Access"
            case "stream":
                return "Nearby Stream Access"
            case "canal":
                return "Nearby Canal Access"
            default:
                return "Nearby Waterway Access"
            }
        }

        if let water = tags["water"] {
            switch water {
            case "reservoir":
                return "Nearby Reservoir Edge"
            case "pond":
                return "Nearby Pond Edge"
            default:
                return "Nearby Waterbody Edge"
            }
        }

        if tags["natural"] == "water" {
            return "Nearby Waterbody Edge"
        }

        return kind.title
    }

    private static func notes(
        for tags: [String: String],
        kind: WaterPointKind,
        quality: WaterQualityLabel
    ) -> String {
        var notes: [String] = []

        if let description = tags["description"]?.nilIfBlank {
            notes.append(description)
        }

        if let access = tags["access"]?.nilIfBlank, access != "yes" {
            notes.append("Access tagged as \(access).")
        }

        if tags["intermittent"] == "yes" || quality == .seasonal {
            notes.append("Flow or availability may be seasonal.")
        }

        if notes.isEmpty {
            switch kind {
            case .communityTap, .campgroundWater, .townWaterPoint:
                notes.append("Nearby tap or potable water point from open map data. Confirm access and drinkability on site.")
            case .boreWater, .waterTank, .rainwaterTank, .stockTrough:
                notes.append("Nearby stored or extracted water source from open map data. Treat before drinking unless locally confirmed.")
            case .riverCreek:
                notes.append("Nearby natural surface water from open map data. Treat before drinking and confirm safe access on site.")
            }
        }

        return notes.joined(separator: " ")
    }
}

private struct RankedWaterCandidate {
    let point: WaterPoint
    let distanceMetres: CLLocationDistance
}

private struct NearbyWaterNetworkCache {
    let anchor: CLLocationCoordinate2D
    let fetchedAt: Date
    let points: [WaterPoint]

    func matches(
        coordinate: CLLocationCoordinate2D,
        maxAge: TimeInterval,
        reuseDistanceMetres: CLLocationDistance
    ) -> Bool {
        Date().timeIntervalSince(fetchedAt) <= maxAge
            && metresBetween(anchor, coordinate) <= reuseDistanceMetres
    }
}

private struct WaterElementClassification {
    let kind: WaterPointKind
    let quality: WaterQualityLabel
    let closesGeometry: Bool
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
