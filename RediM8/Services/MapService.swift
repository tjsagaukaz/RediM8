import Foundation
import MapKit

@MainActor
final class MapService {
    private let store: SQLiteStore?
    private let preparednessDataService: PreparednessDataService
    private let sensitiveMapMarkerService: SensitiveMapMarkerService?
    private let sensitiveMapMarkerMigrationService: SensitiveMapMarkerMigrationService?
    private let dataset: ResourceDataset
    private let didLoadBundledDataset: Bool
    private var hasEnsuredSensitiveMarkerMigration = false

    init(
        store: SQLiteStore?,
        preparednessDataService: PreparednessDataService,
        bundle: Bundle = .main,
        sensitiveMapMarkerService: SensitiveMapMarkerService? = nil,
        sensitiveMapMarkerMigrationService: SensitiveMapMarkerMigrationService? = nil
    ) {
        self.store = store
        self.preparednessDataService = preparednessDataService
        let resolvedSensitiveMapMarkerService = sensitiveMapMarkerService ?? store.map {
            SensitiveMapMarkerService(
                secureStore: SecureStore(namespace: "map-\($0.storageNamespace)")
            )
        }
        self.sensitiveMapMarkerService = resolvedSensitiveMapMarkerService
        self.sensitiveMapMarkerMigrationService = sensitiveMapMarkerMigrationService ?? {
            guard let store, let resolvedSensitiveMapMarkerService else {
                return nil
            }
            return SensitiveMapMarkerMigrationService(
                store: store,
                sensitiveMapMarkerService: resolvedSensitiveMapMarkerService
            )
        }()
        do {
            let decoded = try bundle.decode("ResourceLocations.json", as: ResourceDataset.self)
            self.dataset = decoded
            didLoadBundledDataset = true
        } catch {
            RediLogger.spatial.error("Failed to decode ResourceLocations.json: \(error.localizedDescription)")
            self.dataset = ResourceDataset(lastUpdated: .distantPast, resources: [])
            didLoadBundledDataset = false
        }
    }

    var bundledResources: [ResourceMarker] {
        dataset.resources
    }

    var resourceCategories: [ResourceCategoryDefinition] {
        preparednessDataService.resourceCategories()
    }

    var lastUpdated: Date {
        dataset.lastUpdated
    }

    var didLoadBundledResources: Bool {
        didLoadBundledDataset
    }

    func loadUserMarkers() -> [ResourceMarker] {
        ensureSensitiveMarkerMigrationIfNeeded()

        do {
            if let sensitiveMapMarkerService {
                return try sensitiveMapMarkerService.loadMarkers()
            }
        } catch {
            RediLogger.persistence.error("Failed to load secure user markers: \(error.localizedDescription, privacy: .public)")
        }

        guard let store else {
            return []
        }
        return (try? store.load([ResourceMarker].self, for: MapStorageKey.userMarkers)) ?? []
    }

    func saveUserMarkers(_ markers: [ResourceMarker]) {
        do {
            if let sensitiveMapMarkerService {
                try sensitiveMapMarkerService.saveMarkers(markers)
                try sensitiveMapMarkerMigrationService?.markMigrationCompleted()
            } else {
                try store?.save(markers, for: MapStorageKey.userMarkers)
            }
        } catch {
            RediLogger.persistence.error("Failed to save user markers: \(error.localizedDescription, privacy: .public)")
        }
    }

    func fallbackRegion() -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -25.2744, longitude: 133.7751),
            span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 35)
        )
    }

    private func ensureSensitiveMarkerMigrationIfNeeded() {
        guard !hasEnsuredSensitiveMarkerMigration else {
            return
        }

        do {
            try sensitiveMapMarkerMigrationService?.runIfNeeded()
            hasEnsuredSensitiveMarkerMigration = true
        } catch {
            RediLogger.persistence.error("Failed to migrate secure user markers: \(error.localizedDescription, privacy: .public)")
        }
    }
}
