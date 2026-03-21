import XCTest
@testable import RediM8

final class MapServiceTests: XCTestCase {
    @MainActor
    func testUserMarkersPersistInSecureStoreInsteadOfSQLite() throws {
        let context = try makePersistenceContext(testName: #function)
        let service = makeService(context: context)
        let marker = makeMarker(title: "Rally point", kind: .shelter)

        service.saveUserMarkers([marker])

        XCTAssertEqual(try context.sensitiveMapMarkerService.loadMarkers(), [marker])
        let legacyMarkers = try context.store.load([ResourceMarker].self, for: MapStorageKey.userMarkers) ?? []
        XCTAssertTrue(legacyMarkers.isEmpty)
    }

    @MainActor
    func testLegacyUserMarkersMigrateIntoSecureStore() throws {
        let context = try makePersistenceContext(testName: #function)
        let legacyMarker = makeMarker(title: "Fuel cache", kind: .fuelAvailable)
        try context.store.save([legacyMarker], for: MapStorageKey.userMarkers)

        let service = makeService(context: context)
        let loadedMarkers = service.loadUserMarkers()

        XCTAssertEqual(loadedMarkers, [legacyMarker])
        XCTAssertEqual(try context.sensitiveMapMarkerService.loadMarkers(), [legacyMarker])
        let legacyMarkers = try context.store.load([ResourceMarker].self, for: MapStorageKey.userMarkers) ?? []
        XCTAssertTrue(legacyMarkers.isEmpty)
        XCTAssertTrue(try context.store.load(Bool.self, for: MapStorageKey.secureMigrationCompleted) ?? false)
    }

    @MainActor
    private func makeService(context: MapPersistenceContext) -> MapService {
        MapService(
            store: context.store,
            preparednessDataService: PreparednessDataService(store: nil),
            sensitiveMapMarkerService: context.sensitiveMapMarkerService,
            sensitiveMapMarkerMigrationService: context.sensitiveMapMarkerMigrationService
        )
    }

    private func makeMarker(title: String, kind: MarkerKind) -> ResourceMarker {
        ResourceMarker(
            title: title,
            subtitle: "Saved on device",
            kind: kind,
            latitude: -27.468,
            longitude: 153.028,
            detail: "User-created marker for offline reference.",
            source: "Personal marker",
            isUserGenerated: true
        )
    }

    private func makePersistenceContext(testName: String) throws -> MapPersistenceContext {
        let store = try SQLiteStore(filename: "MapServiceTests-\(UUID().uuidString).sqlite")
        let secureBaseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("MapServiceTests", isDirectory: true)
            .appendingPathComponent(testName.replacingOccurrences(of: " ", with: "_"), isDirectory: true)
        try? FileManager.default.removeItem(at: secureBaseURL)

        let secureStore = SecureStore(
            namespace: "map-service-tests",
            baseURL: secureBaseURL,
            keyProvider: FixedSecureStoreKeyProvider(byte: 7),
            fileManager: .default
        )
        let sensitiveMapMarkerService = SensitiveMapMarkerService(secureStore: secureStore)
        let sensitiveMapMarkerMigrationService = SensitiveMapMarkerMigrationService(
            store: store,
            sensitiveMapMarkerService: sensitiveMapMarkerService
        )

        return MapPersistenceContext(
            store: store,
            sensitiveMapMarkerService: sensitiveMapMarkerService,
            sensitiveMapMarkerMigrationService: sensitiveMapMarkerMigrationService
        )
    }
}

private struct MapPersistenceContext {
    let store: SQLiteStore
    let sensitiveMapMarkerService: SensitiveMapMarkerService
    let sensitiveMapMarkerMigrationService: SensitiveMapMarkerMigrationService
}
