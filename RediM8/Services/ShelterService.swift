import CoreLocation
import Foundation

struct NearbyShelter: Identifiable, Equatable {
    let shelter: ShelterLocation
    let distanceMetres: CLLocationDistance

    var id: String { shelter.id }

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

final class ShelterService {
    private enum NetworkConfig {
        static let endpoint = URL(string: "https://overpass-api.de/api/interpreter")!
        static let refreshMaxAge: TimeInterval = 15 * 60
        static let displayMaxAge: TimeInterval = 6 * 60 * 60
        static let cacheReuseDistanceMetres: CLLocationDistance = 3_000
        static let duplicateDistanceMetres: CLLocationDistance = 250
        static let maxResults = 18
        static let radiusSequence = [6_000, 18_000]
    }

    private let shelterDataset: ShelterDataset
    private let session: URLSession
    private var nearbyNetworkCache: NearbyShelterNetworkCache?

    private(set) var lastNearbyNetworkError: String?

    init(bundle: Bundle = .main, session: URLSession = .shared) {
        shelterDataset = (try? bundle.decode("Shelters.json", as: ShelterDataset.self))
            ?? ShelterDataset(lastUpdated: .distantPast, shelters: [])
        self.session = session
    }

    var lastUpdated: Date {
        max(shelterDataset.lastUpdated, nearbyNetworkCache?.fetchedAt ?? .distantPast)
    }

    var didLoadOfflineData: Bool {
        !shelterDataset.shelters.isEmpty
    }

    var availableTypes: [ShelterType] {
        ShelterType.allCases
    }

    var hasNearbyNetworkData: Bool {
        !(nearbyNetworkCache?.shelters.isEmpty ?? true)
    }

    func shelters(
        for installedPackIDs: Set<String>,
        near coordinate: CLLocationCoordinate2D? = nil,
        types: Set<ShelterType> = []
    ) -> [ShelterLocation] {
        let offlineShelters = shelterDataset.shelters.filter { shelter in
            guard isFeatureAvailable(shelter.packIDs, within: installedPackIDs) else {
                return false
            }
            return types.isEmpty || types.contains(shelter.type)
        }

        guard let coordinate else {
            return offlineShelters
        }

        let networkShelters = (cachedNearbyNetworkShelters(near: coordinate, maxAge: NetworkConfig.displayMaxAge) ?? [])
            .filter { types.isEmpty || types.contains($0.type) }

        return mergeOfflineAndNetworkShelters(
            offlineShelters,
            networkShelters,
            referenceCoordinate: coordinate
        )
    }

    func nearbyShelters(
        near coordinate: CLLocationCoordinate2D,
        installedPackIDs: Set<String>,
        types: Set<ShelterType> = [],
        limit: Int = 3
    ) -> [NearbyShelter] {
        let anchor = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return shelters(for: installedPackIDs, near: coordinate, types: types)
            .map { shelter in
                NearbyShelter(
                    shelter: shelter,
                    distanceMetres: anchor.distance(from: CLLocation(latitude: shelter.latitude, longitude: shelter.longitude))
                )
            }
            .sorted { lhs, rhs in
                if lhs.distanceMetres == rhs.distanceMetres {
                    return lhs.shelter.name < rhs.shelter.name
                }
                return lhs.distanceMetres < rhs.distanceMetres
            }
            .prefix(limit)
            .map { $0 }
    }

    @MainActor
    func refreshNearbyNetworkData(
        near coordinate: CLLocationCoordinate2D,
        force: Bool = false
    ) async -> [ShelterLocation] {
        if !force,
           let cachedShelters = cachedNearbyNetworkShelters(near: coordinate, maxAge: NetworkConfig.refreshMaxAge),
           !cachedShelters.isEmpty
        {
            lastNearbyNetworkError = nil
            return cachedShelters
        }

        do {
            let shelters = try await fetchNearbyNetworkData(near: coordinate)
            nearbyNetworkCache = NearbyShelterNetworkCache(
                anchor: coordinate,
                fetchedAt: .now,
                shelters: shelters
            )
            lastNearbyNetworkError = nil
            return shelters
        } catch {
            lastNearbyNetworkError = "Live nearby shelter search is unavailable right now."
            return cachedNearbyNetworkShelters(near: coordinate, maxAge: NetworkConfig.displayMaxAge) ?? []
        }
    }

    private func cachedNearbyNetworkShelters(
        near coordinate: CLLocationCoordinate2D,
        maxAge: TimeInterval
    ) -> [ShelterLocation]? {
        guard let nearbyNetworkCache,
              nearbyNetworkCache.matches(
                  coordinate: coordinate,
                  maxAge: maxAge,
                  reuseDistanceMetres: NetworkConfig.cacheReuseDistanceMetres
              )
        else {
            return nil
        }

        return nearbyNetworkCache.shelters
    }

    private func mergeOfflineAndNetworkShelters(
        _ offlineShelters: [ShelterLocation],
        _ networkShelters: [ShelterLocation],
        referenceCoordinate: CLLocationCoordinate2D
    ) -> [ShelterLocation] {
        guard !networkShelters.isEmpty else {
            return offlineShelters
        }

        var merged = offlineShelters
        for shelter in networkShelters.sorted(by: { distance(from: referenceCoordinate, to: $0.coordinate) < distance(from: referenceCoordinate, to: $1.coordinate) }) {
            let duplicatesOfflineShelter = merged.contains { existing in
                guard metresBetween(existing.coordinate, shelter.coordinate) <= NetworkConfig.duplicateDistanceMetres else {
                    return false
                }
                if existing.name.normalizedLookupKey == shelter.name.normalizedLookupKey {
                    return true
                }
                return existing.type == shelter.type
            }

            if !duplicatesOfflineShelter {
                merged.append(shelter)
            }
        }

        return merged
    }

    private func fetchNearbyNetworkData(
        near coordinate: CLLocationCoordinate2D
    ) async throws -> [ShelterLocation] {
        var bestCandidates: [RankedShelterCandidate] = []

        for radius in NetworkConfig.radiusSequence {
            let candidates = try await fetchNearbyNetworkData(near: coordinate, radiusMetres: radius)
            if !candidates.isEmpty {
                bestCandidates = candidates
                if candidates.count >= 4 {
                    break
                }
            }
        }

        return deduplicate(candidates: bestCandidates)
            .prefix(NetworkConfig.maxResults)
            .map(\.shelter)
    }

    private func fetchNearbyNetworkData(
        near coordinate: CLLocationCoordinate2D,
        radiusMetres: Int
    ) async throws -> [RankedShelterCandidate] {
        let requestBody = Self.shelterOverpassQuery(
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

        return payload.elements.compactMap { element -> RankedShelterCandidate? in
            let tags = element.tags ?? [:]
            guard let type = Self.shelterType(for: tags) else {
                return nil
            }
            let resolvedCoordinate = element.center?.coordinate
                ?? {
                    guard let lat = element.lat, let lon = element.lon else {
                        return nil
                    }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }()
            guard let resolvedCoordinate else {
                return nil
            }

            let shelter = ShelterLocation(
                id: "osm_shelter_\(element.type)_\(element.id)",
                name: Self.name(for: tags, type: type),
                latitude: resolvedCoordinate.latitude,
                longitude: resolvedCoordinate.longitude,
                type: type,
                capacity: Int(tags["capacity"] ?? ""),
                notes: Self.notes(for: tags, type: type),
                packIDs: [],
                source: "Live nearby baseline facilities (OSM / Overpass)",
                availability: .networkNearby,
                sourceKind: .openMapData,
                lastUpdated: .now
            )

            return RankedShelterCandidate(
                shelter: shelter,
                distanceMetres: anchor.distance(from: CLLocation(latitude: resolvedCoordinate.latitude, longitude: resolvedCoordinate.longitude))
            )
        }
        .sorted {
            if $0.distanceMetres == $1.distanceMetres {
                return $0.shelter.name < $1.shelter.name
            }
            return $0.distanceMetres < $1.distanceMetres
        }
    }

    private func deduplicate(candidates: [RankedShelterCandidate]) -> [RankedShelterCandidate] {
        var kept: [RankedShelterCandidate] = []

        for candidate in candidates {
            let isDuplicate = kept.contains { existing in
                guard metresBetween(existing.shelter.coordinate, candidate.shelter.coordinate) <= NetworkConfig.duplicateDistanceMetres else {
                    return false
                }
                if existing.shelter.name.normalizedLookupKey == candidate.shelter.name.normalizedLookupKey {
                    return true
                }
                return existing.shelter.type == candidate.shelter.type
                    && existing.shelter.name.isGenericNearbyLabel
                    && candidate.shelter.name.isGenericNearbyLabel
            }

            if !isDuplicate {
                kept.append(candidate)
            }
        }

        return kept
    }

    private func isFeatureAvailable(_ featurePackIDs: [String], within installedPackIDs: Set<String>) -> Bool {
        featurePackIDs.isEmpty || !Set(featurePackIDs).isDisjoint(with: installedPackIDs)
    }

    private static func shelterOverpassQuery(
        latitude: Double,
        longitude: Double,
        radiusMetres: Int
    ) -> String {
        let latitudeString = String(format: "%.5f", latitude)
        let longitudeString = String(format: "%.5f", longitude)

        return """
        [out:json][timeout:25];
        (
          node(around:\(radiusMetres),\(latitudeString),\(longitudeString))[emergency=assembly_point];
          node(around:\(radiusMetres),\(latitudeString),\(longitudeString))[social_facility=shelter];
          node(around:\(radiusMetres),\(latitudeString),\(longitudeString))[amenity~"^(community_centre|townhall|school)$"];
          way(around:\(radiusMetres),\(latitudeString),\(longitudeString))[emergency=assembly_point];
          way(around:\(radiusMetres),\(latitudeString),\(longitudeString))[social_facility=shelter];
          way(around:\(radiusMetres),\(latitudeString),\(longitudeString))[amenity~"^(community_centre|townhall|school)$"];
        );
        out body center tags;
        """
    }

    private static func shelterType(for tags: [String: String]) -> ShelterType? {
        if tags["emergency"] == "assembly_point" {
            return .publicAssemblyPoint
        }

        if tags["social_facility"] == "shelter" {
            return .temporaryReliefCentre
        }

        if let amenity = tags["amenity"], ["community_centre", "townhall", "school"].contains(amenity) {
            return .communityShelter
        }

        return nil
    }

    private static func name(for tags: [String: String], type: ShelterType) -> String {
        if let name = tags["name"]?.nilIfBlank {
            return name
        }

        if tags["emergency"] == "assembly_point" {
            return "Nearby Assembly Point"
        }

        if tags["social_facility"] == "shelter" {
            return "Nearby Shelter Facility"
        }

        if let amenity = tags["amenity"] {
            switch amenity {
            case "community_centre":
                return "Nearby Community Centre"
            case "townhall":
                return "Nearby Town Hall"
            case "school":
                return "Nearby School Facility"
            default:
                break
            }
        }

        return type.title
    }

    private static func notes(for tags: [String: String], type: ShelterType) -> String {
        var notes: [String] = []

        if let description = tags["description"]?.nilIfBlank {
            notes.append(description)
        }

        if let access = tags["access"]?.nilIfBlank, access != "yes" {
            notes.append("Access tagged as \(access).")
        }

        if notes.isEmpty {
            switch type {
            case .publicAssemblyPoint:
                notes.append("Nearby assembly point from open map data. Use only if local conditions and official instructions support it.")
            case .temporaryReliefCentre:
                notes.append("Nearby shelter facility from open map data. Confirm official activation before you travel.")
            case .communityShelter, .evacuationCentre, .cycloneShelter:
                notes.append("Nearby baseline facility from open map data. Confirm official activation before relying on it as a shelter.")
            }
        }

        return notes.joined(separator: " ")
    }
}

private struct RankedShelterCandidate {
    let shelter: ShelterLocation
    let distanceMetres: CLLocationDistance
}

private struct NearbyShelterNetworkCache {
    let anchor: CLLocationCoordinate2D
    let fetchedAt: Date
    let shelters: [ShelterLocation]

    func matches(
        coordinate: CLLocationCoordinate2D,
        maxAge: TimeInterval,
        reuseDistanceMetres: CLLocationDistance
    ) -> Bool {
        Date().timeIntervalSince(fetchedAt) <= maxAge
            && metresBetween(anchor, coordinate) <= reuseDistanceMetres
    }
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
