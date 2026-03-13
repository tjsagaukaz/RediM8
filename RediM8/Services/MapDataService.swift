import CoreLocation
import Foundation

@MainActor
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
        trackDataset = (try? bundle.decode("TrackSegments.json", as: TrackDataset.self)) ?? TrackDataset(lastUpdated: .distantPast, tracks: [])
        packCatalog = (try? bundle.decode("MapPacks.json", as: OfflineMapPackCatalog.self)) ?? OfflineMapPackCatalog(lastUpdated: .distantPast, packs: [])
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

    var didLoadOfflineData: Bool {
        !trackDataset.tracks.isEmpty
            || fireTrailService.didLoadOfflineData
            || waterPointService.didLoadOfflineData
            || shelterService.didLoadOfflineData
            || !packCatalog.packs.isEmpty
    }

    func loadEnabledLayers() -> Set<MapLayer> {
        if let stored = try? store?.load(StoredMapLayerSelection.self, for: StorageKey.enabledLayers) {
            return stored.enabledLayers
        }
        return defaultEnabledLayers
    }

    func saveEnabledLayers(_ enabledLayers: Set<MapLayer>) {
        try? store?.save(StoredMapLayerSelection(enabledLayers: enabledLayers), for: StorageKey.enabledLayers)
    }

    func loadInstalledPackIDs() -> Set<String> {
        if let stored = try? store?.load(StoredMapPackSelection.self, for: StorageKey.installedPackIDs) {
            let installedPackIDs = stored.installedPackIDs
            guard !installedPackIDs.isEmpty else {
                return defaultInstalledPackIDs
            }
            return installedPackIDs
        }
        return defaultInstalledPackIDs
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
        try? store?.save(StoredMapPackSelection(installedPackIDs: installedPackIDs), for: StorageKey.installedPackIDs)
    }

    private func isFeatureAvailable(_ featurePackIDs: [String], within installedPackIDs: Set<String>) -> Bool {
        featurePackIDs.isEmpty || !Set(featurePackIDs).isDisjoint(with: installedPackIDs)
    }
}
