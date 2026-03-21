import Combine
import CoreLocation
import Foundation

enum BeaconServiceError: LocalizedError {
    case locationUnavailable
    case locationSharingDisabled
    case broadcastingDisabled

    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            "Current location is unavailable. Move outdoors or allow location access before broadcasting a report."
        case .locationSharingDisabled:
            "Location sharing is off. Enable approximate or precise sharing before using Community Reports."
        case .broadcastingDisabled:
            "Community report broadcasting is disabled. Check Stealth Mode, Anonymous Mode, and Community Report settings."
        }
    }
}

struct BeaconRuntimeSettings: Equatable {
    var isStealthModeEnabled: Bool
    var isAnonymousModeEnabled: Bool
    var allowsBeaconBroadcasts: Bool
    var locationShareMode: LocationShareMode
    var showsDeviceName: Bool
    var rangeMode: SignalRangeMode

    var canRelayReports: Bool {
        !isStealthModeEnabled && !isAnonymousModeEnabled && allowsBeaconBroadcasts
    }

    var canBroadcastBeacon: Bool {
        canRelayReports && locationShareMode != .off
    }

    static let `default` = BeaconRuntimeSettings(
        isStealthModeEnabled: false,
        isAnonymousModeEnabled: true,
        allowsBeaconBroadcasts: false,
        locationShareMode: .approximate,
        showsDeviceName: false,
        rangeMode: .balanced
    )
}

struct RelayBacklogEntry: Codable, Equatable, Identifiable {
    let id: String
    var beacon: CommunityBeacon
    var sourcePeerDisplayName: String?
    var forwardedPeerDisplayNames: Set<String>
    var receivedAt: Date
    var lastForwardedAt: Date?

    init(
        beacon: CommunityBeacon,
        sourcePeerDisplayName: String?,
        forwardedPeerDisplayNames: Set<String> = [],
        receivedAt: Date = .now,
        lastForwardedAt: Date? = nil
    ) {
        id = beacon.relayStateKey
        self.beacon = beacon
        self.sourcePeerDisplayName = sourcePeerDisplayName
        self.forwardedPeerDisplayNames = forwardedPeerDisplayNames
        self.receivedAt = receivedAt
        self.lastForwardedAt = lastForwardedAt
    }

    func canRelay(at reference: Date) -> Bool {
        beacon.canRelayFurther(reference: reference)
    }
}

@MainActor
final class BeaconService: ObservableObject {
    @Published private(set) var activeBeacon: CommunityBeacon?
    @Published private(set) var nearbyBeacons: [CommunityBeacon]
    @Published private(set) var localNodeID: String

    private let meshService: MeshService
    private let locationService: LocationService
    private let store: SQLiteStore?
    private let sensitiveBeaconStateService: SensitiveBeaconStateService?
    private let sensitiveBeaconMigrationService: SensitiveBeaconMigrationService?
    private var runtimeSettings: BeaconRuntimeSettings = .default
    private var cancellables = Set<AnyCancellable>()
    private var maintenanceTicker: AnyCancellable?
    private var monitorCount = 0
    private var inviteTimestamps: [String: Date] = [:]
    private var relayBacklog: [RelayBacklogEntry]
    private var activeBroadcastInterval: TimeInterval?
    private var isMeshServiceActive = false
    private var isLocationServiceActive = false

    init(
        meshService: MeshService,
        locationService: LocationService,
        store: SQLiteStore?,
        sensitiveBeaconStateService: SensitiveBeaconStateService? = nil,
        sensitiveBeaconMigrationService: SensitiveBeaconMigrationService? = nil
    ) {
        self.meshService = meshService
        self.locationService = locationService
        self.store = store
        let resolvedSensitiveBeaconStateService = sensitiveBeaconStateService ?? store.map {
            SensitiveBeaconStateService(
                secureStore: SecureStore(namespace: "beacon-\($0.storageNamespace)")
            )
        }
        self.sensitiveBeaconStateService = resolvedSensitiveBeaconStateService
        self.sensitiveBeaconMigrationService = sensitiveBeaconMigrationService ?? {
            guard let store, let resolvedSensitiveBeaconStateService else {
                return nil
            }
            return SensitiveBeaconMigrationService(
                store: store,
                sensitiveBeaconStateService: resolvedSensitiveBeaconStateService
            )
        }()
        activeBeacon = nil
        nearbyBeacons = []
        localNodeID = ""
        relayBacklog = []

        let persistedState = loadPersistedState()
        let nodeID = persistedState.localNodeID.nilIfBlank ?? Self.generateNodeID()
        localNodeID = nodeID

        let now = Date()
        nearbyBeacons = Self.sorted(Self.pruned(persistedState.nearbyBeacons, now: now, excludingNodeID: nodeID))

        let shouldClearStoredActive: Bool
        if let storedActive = persistedState.activeBeacon, !storedActive.isExpired {
            activeBeacon = storedActive
            shouldClearStoredActive = false
        } else {
            activeBeacon = nil
            shouldClearStoredActive = true
        }

        relayBacklog = Self.pruned(persistedState.relayBacklog, now: now, excludingNodeID: nodeID)

        if shouldClearStoredActive {
            activeBeacon = nil
        }
        persistState()

        meshService.receivedBeacons
            .sink { [weak self] received in
                self?.recordReceivedBeacon(
                    received.beacon,
                    sourcePeerDisplayName: received.sourcePeerDisplayName,
                    receivedFromMesh: true
                )
            }
            .store(in: &cancellables)

        meshService.$nearbyPeers
            .combineLatest(meshService.$connectedPeers)
            .sink { [weak self] nearby, connected in
                self?.autoConnect(nearby: nearby, connected: connected)
            }
            .store(in: &cancellables)

        meshService.$connectedPeers
            .sink { [weak self] _ in
                self?.flushRelayBacklog(now: .now)
            }
            .store(in: &cancellables)
    }

    var localNodeLabel: String {
        "Node \(localNodeID)"
    }

    var defaultDisplayName: String {
        meshService.localPeer.displayName
    }

    var relayQueueCount: Int {
        relayBacklog.filter { $0.beacon.state == .active && $0.beacon.relayExpiresAt > .now }.count
    }

    var relayedBeaconCount: Int {
        nearbyBeacons.filter(\.isRelayed).count
    }

    func updateSettings(_ settings: BeaconRuntimeSettings) {
        let previous = runtimeSettings
        runtimeSettings = settings

        if previous.rangeMode != settings.rangeMode {
            restartMaintenanceLoopIfNeeded()
        }

        if !settings.canRelayReports {
            clearRelayBacklog()
        }

        guard var activeBeacon else {
            syncOperatingServices()
            flushRelayBacklog(now: .now)
            return
        }

        guard settings.canBroadcastBeacon else {
            if settings.isStealthModeEnabled {
                silentlyDeactivateActiveBeacon()
            } else {
                deactivateActiveBeacon(enqueueForRelay: settings.canRelayReports)
            }
            if !settings.canRelayReports {
                clearRelayBacklog()
            }
            syncOperatingServices()
            flushRelayBacklog(now: .now)
            return
        }

        if !settings.showsDeviceName {
            activeBeacon.showsName = false
            activeBeacon.displayName = nil
        }

        let refreshed = refreshedActiveBeacon(from: activeBeacon)
        self.activeBeacon = refreshed
        persistActiveBeacon()
        syncOperatingServices()
        if shouldRunMeshService {
            meshService.sendBeacon(refreshed)
        }
        flushRelayBacklog(now: .now)
    }

    func startMonitoring() {
        monitorCount += 1
        syncOperatingServices()
        if let activeBeacon, runtimeSettings.canBroadcastBeacon {
            let refreshed = refreshedActiveBeacon(from: activeBeacon)
            self.activeBeacon = refreshed
            persistActiveBeacon()
            meshService.sendBeacon(refreshed)
        }
        flushRelayBacklog(now: .now)
    }

    func stopMonitoring() {
        guard monitorCount > 0 else { return }
        monitorCount -= 1
        syncOperatingServices()
    }

    func activateBeacon(
        type: BeaconType,
        statusText: String,
        message: String,
        locationName: String,
        resources: Set<BeaconResource>,
        showsName: Bool,
        displayName: String?,
        emergencyMedicalSummary: String?,
        signalMetadata: BeaconSignalMetadata
    ) throws -> CommunityBeacon {
        guard runtimeSettings.locationShareMode != .off else {
            throw BeaconServiceError.locationSharingDisabled
        }
        guard runtimeSettings.canBroadcastBeacon else {
            throw BeaconServiceError.broadcastingDisabled
        }

        let now = Date()
        let coordinate = currentCoordinate(fallback: activeBeacon?.coordinate)
        guard let coordinate else {
            throw BeaconServiceError.locationUnavailable
        }

        let beacon = CommunityBeacon(
            id: "beacon_\(localNodeID.lowercased())",
            nodeID: localNodeID,
            type: type,
            state: .active,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            locationName: locationName.nilIfBlank ?? "Current location",
            statusText: statusText.nilIfBlank ?? type.defaultStatusText,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            resources: resources.sorted { $0.title < $1.title },
            createdAt: activeBeacon?.createdAt ?? now,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(type.defaultLifetime),
            relayDepth: 0,
            displayName: runtimeSettings.showsDeviceName && showsName ? displayName?.nilIfBlank : nil,
            showsName: runtimeSettings.showsDeviceName && showsName,
            emergencyMedicalSummary: emergencyMedicalSummary?.nilIfBlank,
            signalMetadata: signalMetadata
        )

        activeBeacon = beacon
        persistActiveBeacon()
        syncOperatingServices()
        meshService.sendBeacon(beacon)
        return beacon
    }

    func refreshActiveBeacon() {
        guard let activeBeacon, runtimeSettings.canBroadcastBeacon else { return }
        let refreshed = refreshedActiveBeacon(from: activeBeacon)
        self.activeBeacon = refreshed
        persistActiveBeacon()
        syncOperatingServices()
        meshService.sendBeacon(refreshed)
    }

    func deactivateActiveBeacon() {
        deactivateActiveBeacon(enqueueForRelay: runtimeSettings.canRelayReports)
    }

    func resetLocalNodeID() -> String {
        if activeBeacon != nil {
            deactivateActiveBeacon(enqueueForRelay: false)
        }

        let nodeID = Self.generateNodeID()
        localNodeID = nodeID
        inviteTimestamps = [:]
        clearRelayBacklog()
        nearbyBeacons = Self.sorted(Self.pruned(nearbyBeacons, now: .now, excludingNodeID: nodeID))
        persistState()
        syncOperatingServices()
        return nodeID
    }

    func clearNearbyBeaconsCache() {
        nearbyBeacons = []
        persistNearbyBeacons()
        clearRelayBacklog()
        syncOperatingServices()
    }

    func distanceText(for beacon: CommunityBeacon) -> String {
        guard let currentLocation = locationService.currentLocation else {
            return "Range unknown"
        }

        let target = CLLocation(latitude: beacon.latitude, longitude: beacon.longitude)
        let distance = currentLocation.distance(from: target)

        if distance < 1_000 {
            return "\(Int(distance.rounded()))m"
        }

        return "\(String(format: "%.1f", distance / 1_000))km"
    }

    func recordReceivedBeacon(
        _ beacon: CommunityBeacon,
        sourcePeerDisplayName: String? = nil,
        receivedFromMesh: Bool = false
    ) {
        let now = Date()
        pruneExpiredBeacons(now: now)

        guard beacon.nodeID != localNodeID else { return }

        if beacon.state == .inactive || beacon.isExpired {
            nearbyBeacons.removeAll { $0.id == beacon.id }
            persistNearbyBeacons()

            if receivedFromMesh, beacon.state == .inactive {
                enqueueRelay(beacon, sourcePeerDisplayName: sourcePeerDisplayName, receivedAt: now)
                flushRelayBacklog(now: now)
            }

            syncOperatingServices()
            return
        }

        if let existingIndex = nearbyBeacons.firstIndex(where: { $0.id == beacon.id }) {
            let existing = nearbyBeacons[existingIndex]
            if Self.shouldKeep(existing, over: beacon) {
                return
            }
            nearbyBeacons.remove(at: existingIndex)
        }

        nearbyBeacons.append(beacon)
        nearbyBeacons = Self.sorted(nearbyBeacons)
        persistNearbyBeacons()

        if receivedFromMesh {
            enqueueRelay(beacon, sourcePeerDisplayName: sourcePeerDisplayName, receivedAt: now)
            flushRelayBacklog(now: now)
        }

        syncOperatingServices()
    }

    func pruneExpiredBeacons(now: Date = .now) {
        let prunedNearby = Self.pruned(nearbyBeacons, now: now, excludingNodeID: localNodeID)
        if prunedNearby != nearbyBeacons {
            nearbyBeacons = Self.sorted(prunedNearby)
            persistNearbyBeacons()
        }

        pruneRelayBacklog(now: now)

        if let activeBeacon, activeBeacon.isExpired {
            self.activeBeacon = nil
            clearActiveBeaconFromStore()
        }

        syncOperatingServices()
    }

    private var hasRelayBacklog: Bool {
        !relayBacklog.isEmpty
    }

    private var shouldRunMeshService: Bool {
        monitorCount > 0 || activeBeacon != nil || (runtimeSettings.canRelayReports && hasRelayBacklog)
    }

    private var shouldRunLocationService: Bool {
        monitorCount > 0 || activeBeacon != nil
    }

    private var shouldRunMaintenanceLoop: Bool {
        activeBeacon != nil || (runtimeSettings.canRelayReports && hasRelayBacklog)
    }

    private func startMaintenanceLoopIfNeeded() {
        let interval = runtimeSettings.rangeMode.beaconBroadcastInterval
        guard maintenanceTicker == nil, shouldRunMaintenanceLoop else {
            return
        }

        activeBroadcastInterval = interval
        maintenanceTicker = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performMaintenance()
            }
    }

    private func restartMaintenanceLoopIfNeeded() {
        stopMaintenanceLoop()
        if shouldRunMaintenanceLoop {
            startMaintenanceLoopIfNeeded()
        }
    }

    private func stopMaintenanceLoop() {
        maintenanceTicker?.cancel()
        maintenanceTicker = nil
        activeBroadcastInterval = nil
    }

    private func performMaintenance() {
        let now = Date()
        pruneExpiredBeacons(now: now)

        if let activeBeacon, runtimeSettings.canBroadcastBeacon {
            let refreshed = refreshedActiveBeacon(from: activeBeacon)
            self.activeBeacon = refreshed
            persistActiveBeacon()
            meshService.sendBeacon(refreshed)
        }

        flushRelayBacklog(now: now)
        syncOperatingServices()
    }

    private func autoConnect(nearby: [MeshPeer], connected: [MeshPeer]) {
        guard shouldRunMeshService, !runtimeSettings.isStealthModeEnabled else { return }

        let connectedNames = Set(connected.map(\.displayName))
        let now = Date()

        for peer in nearby where !connectedNames.contains(peer.displayName) {
            let lastInvite = inviteTimestamps[peer.displayName] ?? .distantPast
            guard now.timeIntervalSince(lastInvite) >= runtimeSettings.rangeMode.autoInviteCooldown else { continue }
            inviteTimestamps[peer.displayName] = now
            meshService.invite(peer)
        }
    }

    private func enqueueRelay(
        _ beacon: CommunityBeacon,
        sourcePeerDisplayName: String?,
        receivedAt: Date
    ) {
        guard runtimeSettings.canRelayReports else { return }
        guard beacon.nodeID != localNodeID else { return }
        guard beacon.canRelayFurther(reference: receivedAt) else { return }

        relayBacklog.removeAll { entry in
            entry.beacon.id == beacon.id && entry.beacon.updatedAt <= beacon.updatedAt && entry.id != beacon.relayStateKey
        }

        if let index = relayBacklog.firstIndex(where: { $0.id == beacon.relayStateKey }) {
            let existing = relayBacklog[index]
            relayBacklog[index].beacon = Self.shouldKeep(existing.beacon, over: beacon) ? existing.beacon : beacon
            relayBacklog[index].sourcePeerDisplayName = sourcePeerDisplayName ?? existing.sourcePeerDisplayName
            relayBacklog[index].receivedAt = max(existing.receivedAt, receivedAt)
        } else {
            relayBacklog.append(
                RelayBacklogEntry(
                    beacon: beacon,
                    sourcePeerDisplayName: sourcePeerDisplayName,
                    receivedAt: receivedAt
                )
            )
        }

        relayBacklog = Self.sorted(relayBacklog)

        if relayBacklog.count > AppConstants.Beacon.maxRelayBacklogSize {
            relayBacklog.removeLast(relayBacklog.count - AppConstants.Beacon.maxRelayBacklogSize)
        }

        persistRelayBacklog()
    }

    private func flushRelayBacklog(now: Date) {
        pruneRelayBacklog(now: now)

        guard runtimeSettings.canRelayReports else { return }

        let connectedPeers = meshService.connectedPeers
        guard !connectedPeers.isEmpty else { return }

        var didForward = false

        for index in relayBacklog.indices {
            guard relayBacklog[index].canRelay(at: now) else { continue }

            let eligiblePeers = connectedPeers.filter { peer in
                !relayBacklog[index].forwardedPeerDisplayNames.contains(peer.displayName)
                    && peer.displayName != relayBacklog[index].sourcePeerDisplayName
            }

            guard !eligiblePeers.isEmpty else { continue }

            var relayedBeacon = relayBacklog[index].beacon
            relayedBeacon.relayDepth = min(relayedBeacon.relayDepth + 1, relayedBeacon.type.maxRelayDepth)
            meshService.sendBeacon(relayedBeacon, to: eligiblePeers)

            relayBacklog[index].forwardedPeerDisplayNames.formUnion(eligiblePeers.map(\.displayName))
            relayBacklog[index].lastForwardedAt = now
            didForward = true
        }

        if didForward {
            persistRelayBacklog()
        }
    }

    private func pruneRelayBacklog(now: Date) {
        let pruned = Self.pruned(relayBacklog, now: now, excludingNodeID: localNodeID)
        if pruned != relayBacklog {
            relayBacklog = pruned
            persistRelayBacklog()
        }
    }

    private func syncOperatingServices() {
        if shouldRunMeshService {
            if !isMeshServiceActive {
                meshService.start()
                isMeshServiceActive = true
            }
        } else if isMeshServiceActive {
            meshService.stop()
            isMeshServiceActive = false
        }

        if shouldRunLocationService {
            if !isLocationServiceActive {
                locationService.start()
                isLocationServiceActive = true
            }
        } else if isLocationServiceActive {
            locationService.stop()
            isLocationServiceActive = false
        }

        if shouldRunMaintenanceLoop {
            startMaintenanceLoopIfNeeded()
        } else {
            stopMaintenanceLoop()
        }
    }

    private func refreshedActiveBeacon(from beacon: CommunityBeacon) -> CommunityBeacon {
        var refreshed = beacon
        if let coordinate = currentCoordinate(fallback: beacon.coordinate) {
            refreshed.latitude = coordinate.latitude
            refreshed.longitude = coordinate.longitude
        }
        refreshed.state = .active
        refreshed.updatedAt = .now
        refreshed.expiresAt = .now.addingTimeInterval(refreshed.type.defaultLifetime)
        refreshed.relayDepth = 0
        refreshed.displayName = runtimeSettings.showsDeviceName && refreshed.showsName ? refreshed.displayName : nil
        refreshed.showsName = runtimeSettings.showsDeviceName && refreshed.showsName
        return refreshed
    }

    private func currentCoordinate(fallback: CLLocationCoordinate2D? = nil) -> CLLocationCoordinate2D? {
        guard runtimeSettings.locationShareMode != .off else {
            return nil
        }
        let coordinate = locationService.currentLocation?.coordinate ?? fallback
        guard let coordinate else {
            return nil
        }
        return runtimeSettings.locationShareMode.sharedCoordinate(from: coordinate)
    }

    private func deactivateActiveBeacon(enqueueForRelay: Bool) {
        guard let activeBeacon else { return }

        var inactiveBeacon = activeBeacon
        inactiveBeacon.state = .inactive
        inactiveBeacon.updatedAt = .now
        inactiveBeacon.expiresAt = .now
        inactiveBeacon.relayDepth = 0
        meshService.sendBeacon(inactiveBeacon)

        if enqueueForRelay {
            enqueueRelay(inactiveBeacon, sourcePeerDisplayName: nil, receivedAt: inactiveBeacon.updatedAt)
            flushRelayBacklog(now: inactiveBeacon.updatedAt)
        }

        self.activeBeacon = nil
        clearActiveBeaconFromStore()
        syncOperatingServices()
    }

    private func silentlyDeactivateActiveBeacon() {
        activeBeacon = nil
        clearActiveBeaconFromStore()
        syncOperatingServices()
    }

    private func clearRelayBacklog() {
        relayBacklog = []
        persistRelayBacklog()
    }

    private func persistActiveBeacon() {
        persistState()
    }

    private func clearActiveBeaconFromStore() {
        persistState()
    }

    private func persistNearbyBeacons() {
        persistState()
    }

    private func persistRelayBacklog() {
        persistState()
    }

    private func persistState() {
        let state = SensitiveBeaconState(
            localNodeID: localNodeID,
            activeBeacon: activeBeacon,
            nearbyBeacons: nearbyBeacons,
            relayBacklog: relayBacklog
        )

        do {
            if let sensitiveBeaconStateService {
                try sensitiveBeaconStateService.saveState(state)
                try sensitiveBeaconMigrationService?.markMigrationCompleted()
            } else {
                try store?.save(localNodeID, for: BeaconStorageKey.localNodeID)
                try store?.save(activeBeacon, for: BeaconStorageKey.activeBeacon)
                try store?.save(nearbyBeacons, for: BeaconStorageKey.nearbyBeacons)
                try store?.save(relayBacklog, for: BeaconStorageKey.relayBacklog)
            }
        } catch {
            RediLogger.persistence.error("Failed to persist secure beacon state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadPersistedState() -> SensitiveBeaconState {
        do {
            try sensitiveBeaconMigrationService?.runIfNeeded()
        } catch {
            RediLogger.persistence.error("Failed to migrate secure beacon state: \(error.localizedDescription, privacy: .public)")
        }

        do {
            if let sensitiveBeaconStateService {
                return try sensitiveBeaconStateService.loadState()
            }
        } catch {
            RediLogger.persistence.error("Failed to load secure beacon state: \(error.localizedDescription, privacy: .public)")
        }

        return loadLegacyPersistedState()
    }

    private func loadLegacyPersistedState() -> SensitiveBeaconState {
        guard let store else {
            return .empty
        }

        let localNodeID = (try? store.load(String.self, for: BeaconStorageKey.localNodeID)) ?? ""
        let activeBeacon = (try? store.load(Optional<CommunityBeacon>.self, for: BeaconStorageKey.activeBeacon)) ?? nil
        let nearbyBeacons = (try? store.load([CommunityBeacon].self, for: BeaconStorageKey.nearbyBeacons)) ?? []
        let relayBacklog = (try? store.load([RelayBacklogEntry].self, for: BeaconStorageKey.relayBacklog)) ?? []

        return SensitiveBeaconState(
            localNodeID: localNodeID,
            activeBeacon: activeBeacon,
            nearbyBeacons: nearbyBeacons,
            relayBacklog: relayBacklog
        )
    }

    private static func pruned(_ beacons: [CommunityBeacon], now: Date, excludingNodeID nodeID: String) -> [CommunityBeacon] {
        beacons.filter { beacon in
            beacon.nodeID != nodeID && beacon.state == .active && beacon.expiresAt > now
        }
    }

    private static func pruned(_ entries: [RelayBacklogEntry], now: Date, excludingNodeID nodeID: String) -> [RelayBacklogEntry] {
        entries.filter { entry in
            entry.beacon.nodeID != nodeID && entry.beacon.relayExpiresAt > now
        }
    }

    private static func sorted(_ beacons: [CommunityBeacon]) -> [CommunityBeacon] {
        beacons.sorted { lhs, rhs in
            if lhs.type.priority != rhs.type.priority {
                return lhs.type.priority < rhs.type.priority
            }
            if lhs.severity.rank != rhs.severity.rank {
                return lhs.severity.rank > rhs.severity.rank
            }
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.relayDepth < rhs.relayDepth
        }
    }

    private static func sorted(_ entries: [RelayBacklogEntry]) -> [RelayBacklogEntry] {
        entries.sorted { lhs, rhs in
            if lhs.beacon.type.priority != rhs.beacon.type.priority {
                return lhs.beacon.type.priority < rhs.beacon.type.priority
            }
            if lhs.beacon.severity.rank != rhs.beacon.severity.rank {
                return lhs.beacon.severity.rank > rhs.beacon.severity.rank
            }
            if lhs.beacon.updatedAt != rhs.beacon.updatedAt {
                return lhs.beacon.updatedAt > rhs.beacon.updatedAt
            }
            return lhs.beacon.relayDepth < rhs.beacon.relayDepth
        }
    }

    private static func shouldKeep(_ existing: CommunityBeacon, over incoming: CommunityBeacon) -> Bool {
        if existing.updatedAt != incoming.updatedAt {
            return existing.updatedAt > incoming.updatedAt
        }

        if existing.state != incoming.state {
            return incoming.state != .inactive
        }

        return existing.relayDepth <= incoming.relayDepth
    }

    private static func generateNodeID() -> String {
        let value = Int.random(in: 0...0xFFFF)
        return String(format: "%04X", value)
    }
}
