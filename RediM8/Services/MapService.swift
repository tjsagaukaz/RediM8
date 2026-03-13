import Foundation
import MapKit

@MainActor
final class MapService {
    private enum StorageKey {
        static let userMarkers = "user_markers"
    }

    private let store: SQLiteStore?
    private let preparednessDataService: PreparednessDataService
    private let dataset: ResourceDataset
    private let didLoadBundledDataset: Bool

    init(store: SQLiteStore?, preparednessDataService: PreparednessDataService, bundle: Bundle = .main) {
        self.store = store
        self.preparednessDataService = preparednessDataService
        if let dataset = try? bundle.decode("ResourceLocations.json", as: ResourceDataset.self) {
            self.dataset = dataset
            didLoadBundledDataset = true
        } else {
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
        guard let store else {
            return []
        }
        return (try? store.load([ResourceMarker].self, for: StorageKey.userMarkers)) ?? []
    }

    func saveUserMarkers(_ markers: [ResourceMarker]) {
        try? store?.save(markers, for: StorageKey.userMarkers)
    }

    func fallbackRegion() -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -25.2744, longitude: 133.7751),
            span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 35)
        )
    }
}
