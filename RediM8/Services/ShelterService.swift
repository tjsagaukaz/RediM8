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

/// Offline-only shelter service. All data comes from bundled Shelters.json dataset.
/// No network calls. No Overpass API. No URLSession.
final class ShelterService {
    private let shelterDataset: ShelterDataset
    private let spatialIndex: SpatialIndex<ShelterLocation>

    private(set) var lastNearbyNetworkError: String?

    init(bundle: Bundle = .main) {
        let dataset: ShelterDataset
        do {
            dataset = try bundle.decode("Shelters.json", as: ShelterDataset.self)
        } catch {
            RediLogger.spatial.error("Failed to decode Shelters.json: \(error.localizedDescription)")
            dataset = ShelterDataset(lastUpdated: .distantPast, shelters: [])
        }
        self.shelterDataset = dataset
        self.spatialIndex = SpatialIndex(items: dataset.shelters) {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    var lastUpdated: Date {
        shelterDataset.lastUpdated
    }

    var didLoadOfflineData: Bool {
        !shelterDataset.shelters.isEmpty
    }

    var availableTypes: [ShelterType] {
        ShelterType.allCases
    }

    var hasNearbyNetworkData: Bool {
        false
    }

    func shelters(
        for installedPackIDs: Set<String>,
        near coordinate: CLLocationCoordinate2D? = nil,
        types: Set<ShelterType> = []
    ) -> [ShelterLocation] {
        shelterDataset.shelters.filter { shelter in
            guard isFeatureAvailable(shelter.packIDs, within: installedPackIDs) else {
                return false
            }
            return types.isEmpty || types.contains(shelter.type)
        }
    }

    func nearbyShelters(
        near coordinate: CLLocationCoordinate2D,
        installedPackIDs: Set<String>,
        types: Set<ShelterType> = [],
        limit: Int = 3
    ) -> [NearbyShelter] {
        Array(spatialIndex.nearest(to: coordinate, limit: limit * 4)
            .filter { entry in
                let shelter = entry.item
                guard isFeatureAvailable(shelter.packIDs, within: installedPackIDs) else { return false }
                return types.isEmpty || types.contains(shelter.type)
            }
            .sorted { $0.distanceMetres < $1.distanceMetres }
            .prefix(limit)
            .map { NearbyShelter(shelter: $0.item, distanceMetres: $0.distanceMetres) })
    }

    /// Offline-only: no network refresh. Returns empty.
    @MainActor
    func refreshNearbyNetworkData(
        near coordinate: CLLocationCoordinate2D,
        force: Bool = false
    ) async -> [ShelterLocation] {
        []
    }

    private func isFeatureAvailable(_ featurePackIDs: [String], within installedPackIDs: Set<String>) -> Bool {
        featurePackIDs.isEmpty || !Set(featurePackIDs).isDisjoint(with: installedPackIDs)
    }
}

private extension String {
    var normalizedLookupKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    var isGenericNearbyLabel: Bool {
        hasPrefix("Nearby ")
    }
}
