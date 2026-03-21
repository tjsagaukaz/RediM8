import Foundation

enum BeaconStorageKey {
    static let activeBeacon = "community_beacon.active"
    static let nearbyBeacons = "community_beacon.nearby"
    static let localNodeID = "community_beacon.local_node_id"
    static let relayBacklog = "community_beacon.relay_backlog"
    static let secureState = "community_beacon.secure_state.v1"
    static let secureMigrationCompleted = "community_beacon.secure_state.v1.complete"
}

struct SensitiveBeaconState: Codable, Equatable {
    var localNodeID: String
    var activeBeacon: CommunityBeacon?
    var nearbyBeacons: [CommunityBeacon]
    var relayBacklog: [RelayBacklogEntry]

    init(
        localNodeID: String = "",
        activeBeacon: CommunityBeacon? = nil,
        nearbyBeacons: [CommunityBeacon] = [],
        relayBacklog: [RelayBacklogEntry] = []
    ) {
        self.localNodeID = localNodeID
        self.activeBeacon = activeBeacon
        self.nearbyBeacons = nearbyBeacons
        self.relayBacklog = relayBacklog
    }

    static let empty = SensitiveBeaconState()

    var hasAnyContent: Bool {
        localNodeID.nilIfBlank != nil
            || activeBeacon != nil
            || !nearbyBeacons.isEmpty
            || !relayBacklog.isEmpty
    }
}

final class SensitiveBeaconStateService {
    private let secureStore: SecureStore

    init(secureStore: SecureStore) {
        self.secureStore = secureStore
    }

    func loadState() throws -> SensitiveBeaconState {
        try secureStore.load(SensitiveBeaconState.self, for: BeaconStorageKey.secureState) ?? .empty
    }

    func saveState(_ state: SensitiveBeaconState) throws {
        if state.hasAnyContent {
            try secureStore.save(state, for: BeaconStorageKey.secureState)
        } else {
            try secureStore.deleteValue(for: BeaconStorageKey.secureState)
        }
    }

    var hasStoredState: Bool {
        secureStore.containsValue(for: BeaconStorageKey.secureState)
    }
}

final class SensitiveBeaconMigrationService {
    private let store: SQLiteStore
    private let sensitiveBeaconStateService: SensitiveBeaconStateService

    init(store: SQLiteStore, sensitiveBeaconStateService: SensitiveBeaconStateService) {
        self.store = store
        self.sensitiveBeaconStateService = sensitiveBeaconStateService
    }

    func runIfNeeded() throws {
        guard !(try isMigrationCompleted()) else {
            return
        }

        let legacyState = try loadLegacyState()
        if sensitiveBeaconStateService.hasStoredState {
            if legacyState.hasAnyContent {
                try clearLegacyState()
            }
            try markMigrationCompleted()
            return
        }

        guard legacyState.hasAnyContent else {
            try markMigrationCompleted()
            return
        }

        try sensitiveBeaconStateService.saveState(legacyState)
        try clearLegacyState()
        try markMigrationCompleted()
    }

    func markMigrationCompleted() throws {
        try store.save(true, for: BeaconStorageKey.secureMigrationCompleted)
    }

    private func isMigrationCompleted() throws -> Bool {
        try store.load(Bool.self, for: BeaconStorageKey.secureMigrationCompleted) ?? false
    }

    private func loadLegacyState() throws -> SensitiveBeaconState {
        let localNodeID = try store.load(String.self, for: BeaconStorageKey.localNodeID) ?? ""
        let activeBeacon = try store.load(Optional<CommunityBeacon>.self, for: BeaconStorageKey.activeBeacon) ?? nil
        let nearbyBeacons = try store.load([CommunityBeacon].self, for: BeaconStorageKey.nearbyBeacons) ?? []
        let relayBacklog = try store.load([RelayBacklogEntry].self, for: BeaconStorageKey.relayBacklog) ?? []

        return SensitiveBeaconState(
            localNodeID: localNodeID,
            activeBeacon: activeBeacon,
            nearbyBeacons: nearbyBeacons,
            relayBacklog: relayBacklog
        )
    }

    private func clearLegacyState() throws {
        try store.save(Optional<CommunityBeacon>.none, for: BeaconStorageKey.activeBeacon)
        try store.save([CommunityBeacon](), for: BeaconStorageKey.nearbyBeacons)
        try store.save(Optional<String>.none, for: BeaconStorageKey.localNodeID)
        try store.save([RelayBacklogEntry](), for: BeaconStorageKey.relayBacklog)
    }
}
