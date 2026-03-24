import CoreLocation
import Foundation

final class MapDataService {
    private enum StorageKey {
        static let enabledLayers = "map_enabled_layers"
        static let installedPackIDs = "map_installed_pack_ids"
    }

    private let store: SQLiteStore?
    private let trackDataset: TrackDataset
    private let packCatalog: OfflineMapPackCatalog
    private let waterPointService: WaterPointService
    private let fireTrailService: FireTrailService
    private let shelterService: ShelterService
    #if DEBUG
    private var installedPackIDsOverride: Set<String>?
    #endif

    init(
        store: SQLiteStore?,
        bundle: Bundle = .main,
        waterPointService: WaterPointService? = nil,
        fireTrailService: FireTrailService? = nil,
        shelterService: ShelterService? = nil
    ) {
        self.store = store
        self.waterPointService = waterPointService ?? WaterPointService(bundle: bundle)
        self.fireTrailService = fireTrailService ?? FireTrailService(bundle: bundle)
        self.shelterService = shelterService ?? ShelterService(bundle: bundle)
        do {
            trackDataset = try bundle.decode("TrackSegments.json", as: TrackDataset.self)
        } catch {
            RediLogger.basemap.error("Failed to decode TrackSegments.json: \(error.localizedDescription)")
            trackDataset = TrackDataset(lastUpdated: .distantPast, tracks: [])
        }
        do {
            packCatalog = try bundle.decode("MapPacks.json", as: OfflineMapPackCatalog.self)
        } catch {
            RediLogger.basemap.error("Failed to decode MapPacks.json: \(error.localizedDescription)")
            packCatalog = OfflineMapPackCatalog(lastUpdated: .distantPast, packs: [])
        }
    }

    var availableLayers: [MapLayer] {
        MapLayer.allCases
    }

    var availablePacks: [OfflineMapPack] {
        packCatalog.packs.sorted {
            if $0.kind != $1.kind {
                return $0.kind.rawValue < $1.kind.rawValue
            }
            return $0.name < $1.name
        }
    }

    var lastUpdated: Date {
        [trackDataset.lastUpdated, fireTrailService.lastUpdated, waterPointService.lastUpdated, shelterService.lastUpdated, packCatalog.lastUpdated]
            .max() ?? .distantPast
    }

    /// Worst-case freshness across all bundled sub-services.
    var dataFreshness: DataFreshness {
        serviceFreshnessEntries.map(\.freshness).max(by: { $0.severity < $1.severity }) ?? .current
    }

    /// Impact message from the stalest sub-service, explaining *why* the staleness matters.
    var freshnessImpactMessage: String? {
        guard let worst = serviceFreshnessEntries.filter({ $0.freshness.shouldWarn }).max(by: { $0.freshness.severity < $1.freshness.severity }) else {
            return nil
        }
        return worst.impact
    }

    private var serviceFreshnessEntries: [(freshness: DataFreshness, impact: String)] {
        [
            (waterPointService.dataFreshness, waterPointService.freshnessImpactMessage),
            (fireTrailService.dataFreshness, fireTrailService.freshnessImpactMessage),
            (shelterService.dataFreshness, shelterService.freshnessImpactMessage),
            (TrustLayer.dataFreshness(lastUpdated: trackDataset.lastUpdated, sourceKind: .curatedBundle), "Track data may not reflect current conditions"),
            (TrustLayer.dataFreshness(lastUpdated: packCatalog.lastUpdated, sourceKind: .curatedBundle), "Map pack coverage may be incomplete")
        ]
    }

    var didLoadOfflineData: Bool {
        !trackDataset.tracks.isEmpty
            || fireTrailService.didLoadOfflineData
            || waterPointService.didLoadOfflineData
            || shelterService.didLoadOfflineData
            || !packCatalog.packs.isEmpty
    }

    func loadEnabledLayers() -> Set<MapLayer> {
        guard let store else {
            return defaultEnabledLayers
        }

        do {
            if let stored = try store.load(StoredMapLayerSelection.self, for: StorageKey.enabledLayers) {
                return stored.enabledLayers
            }
            return defaultEnabledLayers
        } catch {
            RediLogger.persistence.error("Failed to load enabled map layers: \(error.localizedDescription, privacy: .public)")
            return defaultEnabledLayers
        }
    }

    func saveEnabledLayers(_ enabledLayers: Set<MapLayer>) {
        guard let store else {
            return
        }

        do {
            try store.save(StoredMapLayerSelection(enabledLayers: enabledLayers), for: StorageKey.enabledLayers)
        } catch {
            RediLogger.persistence.error("Failed to save enabled map layers: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadInstalledPackIDs() -> Set<String> {
        #if DEBUG
        if let installedPackIDsOverride {
            return installedPackIDsOverride
        }
        #endif

        guard let store else {
            return defaultInstalledPackIDs
        }

        do {
            guard let stored = try store.load(StoredMapPackSelection.self, for: StorageKey.installedPackIDs) else {
                return defaultInstalledPackIDs
            }
            let installedPackIDs = stored.installedPackIDs
            guard !installedPackIDs.isEmpty else {
                return defaultInstalledPackIDs
            }
            return installedPackIDs
        } catch {
            RediLogger.persistence.error("Failed to load installed map packs: \(error.localizedDescription, privacy: .public)")
            return defaultInstalledPackIDs
        }
    }

    func installPack(_ packID: String, into installedPackIDs: Set<String>) -> Set<String> {
        var updated = installedPackIDs
        updated.insert(packID)
        saveInstalledPackIDs(updated)
        return updated
    }

    func removePack(_ packID: String, from installedPackIDs: Set<String>) -> Set<String> {
        var updated = installedPackIDs
        updated.remove(packID)
        saveInstalledPackIDs(updated.isEmpty ? defaultInstalledPackIDs : updated)
        return updated.isEmpty ? defaultInstalledPackIDs : updated
    }

    func pack(withID packID: String) -> OfflineMapPack? {
        packCatalog.packs.first { $0.id == packID }
    }

    func packs(withIDs packIDs: Set<String>) -> [OfflineMapPack] {
        availablePacks.filter { packIDs.contains($0.id) }
    }

    var allTracks: [TrackSegment] {
        trackDataset.tracks + fireTrailService.allTrails
    }

    func dirtRoads(for installedPackIDs: Set<String>) -> [TrackSegment] {
        trackDataset.tracks.filter { track in
            guard !track.isFireAccessTrail else { return false }
            return isFeatureAvailable(track.packIDs, within: installedPackIDs)
        }
    }

    func fireTrails(for installedPackIDs: Set<String>) -> [TrackSegment] {
        fireTrailService.fireTrails(for: installedPackIDs)
    }

    func waterPoints(
        for installedPackIDs: Set<String>,
        near coordinate: CLLocationCoordinate2D? = nil,
        kinds: Set<WaterPointKind> = []
    ) -> [WaterPoint] {
        waterPointService.waterPoints(for: installedPackIDs, near: coordinate, kinds: kinds)
    }

    func shelters(
        for installedPackIDs: Set<String>,
        near coordinate: CLLocationCoordinate2D? = nil,
        types: Set<ShelterType> = []
    ) -> [ShelterLocation] {
        shelterService.shelters(for: installedPackIDs, near: coordinate, types: types)
    }

    private var defaultEnabledLayers: Set<MapLayer> {
        Set(MapLayer.allCases.filter(\.defaultEnabled))
    }

    private var defaultInstalledPackIDs: Set<String> {
        Set(packCatalog.packs.filter(\.isBundledByDefault).map(\.id))
    }

    private func saveInstalledPackIDs(_ installedPackIDs: Set<String>) {
        #if DEBUG
        if installedPackIDsOverride != nil {
            installedPackIDsOverride = installedPackIDs
        }
        #endif

        guard let store else {
            return
        }

        do {
            try store.save(StoredMapPackSelection(installedPackIDs: installedPackIDs), for: StorageKey.installedPackIDs)
        } catch {
            RediLogger.persistence.error("Failed to save installed map packs: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func isFeatureAvailable(_ featurePackIDs: [String], within installedPackIDs: Set<String>) -> Bool {
        featurePackIDs.isEmpty || !Set(featurePackIDs).isDisjoint(with: installedPackIDs)
    }
}

#if DEBUG
extension MapDataService {
    func seedInstalledPackIDsForTesting(_ installedPackIDs: Set<String>) {
        installedPackIDsOverride = installedPackIDs
    }
}
#endif
