import Foundation

enum MapStorageKey {
    static let userMarkers = "user_markers"
    static let secureUserMarkers = "user_markers.secure.v1"
    static let secureMigrationCompleted = "user_markers.secure.migration.v1.complete"
}

final class SensitiveMapMarkerService {
    private let secureStore: SecureStore

    init(secureStore: SecureStore) {
        self.secureStore = secureStore
    }

    func loadMarkers() throws -> [ResourceMarker] {
        try secureStore.load([ResourceMarker].self, for: MapStorageKey.secureUserMarkers) ?? []
    }

    func saveMarkers(_ markers: [ResourceMarker]) throws {
        if markers.isEmpty {
            try secureStore.deleteValue(for: MapStorageKey.secureUserMarkers)
        } else {
            try secureStore.save(markers, for: MapStorageKey.secureUserMarkers)
        }
    }

    var hasStoredMarkers: Bool {
        secureStore.containsValue(for: MapStorageKey.secureUserMarkers)
    }
}

final class SensitiveMapMarkerMigrationService {
    private let store: SQLiteStore
    private let sensitiveMapMarkerService: SensitiveMapMarkerService

    init(store: SQLiteStore, sensitiveMapMarkerService: SensitiveMapMarkerService) {
        self.store = store
        self.sensitiveMapMarkerService = sensitiveMapMarkerService
    }

    func runIfNeeded() throws {
        guard try !migrationCompleted() else {
            return
        }

        if sensitiveMapMarkerService.hasStoredMarkers {
            try clearLegacyMarkers()
            try markMigrationCompleted()
            return
        }

        let legacyMarkers = try store.load([ResourceMarker].self, for: MapStorageKey.userMarkers) ?? []
        if !legacyMarkers.isEmpty {
            try sensitiveMapMarkerService.saveMarkers(legacyMarkers)
        }

        try clearLegacyMarkers()
        try markMigrationCompleted()
    }

    func markMigrationCompleted() throws {
        try store.save(true, for: MapStorageKey.secureMigrationCompleted)
    }

    private func migrationCompleted() throws -> Bool {
        try store.load(Bool.self, for: MapStorageKey.secureMigrationCompleted) ?? false
    }

    private func clearLegacyMarkers() throws {
        try store.save([ResourceMarker](), for: MapStorageKey.userMarkers)
    }
}
