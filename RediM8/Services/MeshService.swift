import Combine
import CoreLocation
import CryptoKit
import Foundation
@preconcurrency import MultipeerConnectivity
import Security
import UIKit

struct MeshPeer: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let transportID: String
    let displayName: String
}

struct ReceivedCommunityBeacon: Equatable {
    let beacon: CommunityBeacon
    let sourcePeerDisplayName: String
}

struct MeshTransportConfiguration: Equatable {
    var displayName: String
    var isBrowsingEnabled: Bool
    var isBroadcastingEnabled: Bool
    var autoAcceptInvitations: Bool
    var locationShareMode: LocationShareMode
    var rangeMode: SignalRangeMode
    var allowsOutgoingInvitations: Bool
    var usesLowFrequencyBrowsing: Bool
}

// MARK: - Trust Level

/// The user-controllable trust level for a known mesh peer.
enum MeshPeerTrustLevel: String, Codable, Equatable, CaseIterable {
    /// First encounter — not yet reviewed by the user.
    case unknown
    /// User has explicitly verified this peer (e.g. confirmed in person).
    case verified
    /// User has explicitly blocked this peer. Connections and messages are rejected.
    case blocked
}

/// A known mesh peer with identity and trust metadata.
struct KnownMeshPeer: Identifiable, Codable, Equatable {
    let id: String // normalized display name
    let displayName: String
    let fingerprint: String
    var trustLevel: MeshPeerTrustLevel
    let firstSeenAt: Date
    var lastSeenAt: Date
}

enum MeshPeerTrustDecision: Equatable {
    case trustedFirstUse
    case trustedKnownPeer
    case trustedVerifiedPeer
    case rejectedMissingCertificate
    case rejectedChangedIdentity
    case rejectedBlocked

    var allowsConnection: Bool {
        switch self {
        case .trustedFirstUse, .trustedKnownPeer, .trustedVerifiedPeer:
            true
        case .rejectedMissingCertificate, .rejectedChangedIdentity, .rejectedBlocked:
            false
        }
    }

    var isVerified: Bool {
        self == .trustedVerifiedPeer
    }

    func rejectionMessage(for peerDisplayName: String) -> String {
        switch self {
        case .rejectedMissingCertificate:
            return "Blocked \(peerDisplayName) because RediM8 could not verify that device's mesh identity."
        case .rejectedChangedIdentity:
            return "Blocked \(peerDisplayName) because that device's mesh identity changed since the last trusted connection."
        case .rejectedBlocked:
            return "Blocked \(peerDisplayName) because you previously blocked this device."
        case .trustedFirstUse, .trustedKnownPeer, .trustedVerifiedPeer:
            return ""
        }
    }
}

final class MeshPeerTrustStore: @unchecked Sendable {
    private enum StorageKey {
        // Mesh identity continuity is intentionally stored outside SecureStore.
        // This key must never contain location, profile linkage, or emergency payload.
        // If that changes, migrate it into the secure domain before persisting it.
        static let trustedPeerFingerprints = "mesh.trusted-peer-fingerprints.v1"
        static let knownPeers = "mesh.known-peers.v1"
    }

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateFromFingerprintOnlyStoreIfNeeded()
    }

    // MARK: - Evaluate

    func evaluate(certificateChain: [Any]?, peerDisplayName: String) -> MeshPeerTrustDecision {
        evaluate(
            fingerprint: Self.fingerprint(for: certificateChain),
            peerDisplayName: peerDisplayName
        )
    }

    func evaluate(fingerprint: String?, peerDisplayName: String) -> MeshPeerTrustDecision {
        guard let fingerprint else {
            logTrustDecision(.rejectedMissingCertificate, peer: peerDisplayName)
            return .rejectedMissingCertificate
        }

        let normalizedName = Self.normalizedPeerName(peerDisplayName)
        lock.lock()
        defer { lock.unlock() }

        var peers = loadKnownPeers()

        if let existing = peers[normalizedName] {
            // Blocked peer — reject immediately regardless of fingerprint
            if existing.trustLevel == .blocked {
                logTrustDecision(.rejectedBlocked, peer: peerDisplayName)
                return .rejectedBlocked
            }

            // Fingerprint mismatch — identity changed
            if existing.fingerprint != fingerprint {
                logTrustDecision(.rejectedChangedIdentity, peer: peerDisplayName)
                return .rejectedChangedIdentity
            }

            // Update last seen
            var updated = existing
            updated.lastSeenAt = .now
            peers[normalizedName] = updated
            saveKnownPeers(peers)

            let decision: MeshPeerTrustDecision = existing.trustLevel == .verified
                ? .trustedVerifiedPeer
                : .trustedKnownPeer
            logTrustDecision(decision, peer: peerDisplayName)
            return decision
        }

        // First encounter — trust on first use
        let newPeer = KnownMeshPeer(
            id: normalizedName,
            displayName: peerDisplayName,
            fingerprint: fingerprint,
            trustLevel: .unknown,
            firstSeenAt: .now,
            lastSeenAt: .now
        )
        peers[normalizedName] = newPeer
        saveKnownPeers(peers)
        logTrustDecision(.trustedFirstUse, peer: peerDisplayName)
        return .trustedFirstUse
    }

    // MARK: - Trust Level for Sender

    /// Returns the trust level for a peer by display name. Used for message gating.
    func trustLevel(for peerDisplayName: String) -> MeshPeerTrustLevel {
        let normalizedName = Self.normalizedPeerName(peerDisplayName)
        lock.lock()
        defer { lock.unlock() }
        return loadKnownPeers()[normalizedName]?.trustLevel ?? .unknown
    }

    // MARK: - Peer Management

    /// Returns all known peers, sorted by display name.
    func knownPeers() -> [KnownMeshPeer] {
        lock.lock()
        defer { lock.unlock() }
        return loadKnownPeers().values
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Mark a peer as verified. Only works for known peers with matching fingerprint.
    func verify(peerDisplayName: String) {
        mutatePeer(peerDisplayName) { $0.trustLevel = .verified }
        DiagnosticStore.shared.log(.recovery, error: nil, context: [
            "service": "mesh",
            "detail": "Peer verified: \(peerDisplayName)",
            "systemState": "healthy"
        ])
    }

    /// Block a peer. Blocks connections and drops all messages from this peer.
    func block(peerDisplayName: String) {
        mutatePeer(peerDisplayName) { $0.trustLevel = .blocked }
        DiagnosticStore.shared.log(.degraded, error: nil, context: [
            "service": "mesh",
            "detail": "Peer blocked: \(peerDisplayName)",
            "systemState": "degraded"
        ])
    }

    /// Reset a peer back to unknown trust. Does not remove the fingerprint.
    func revokeTrust(peerDisplayName: String) {
        mutatePeer(peerDisplayName) { $0.trustLevel = .unknown }
    }

    /// Completely forget a peer — removes fingerprint and all trust data.
    func forget(peerDisplayName: String) {
        let normalizedName = Self.normalizedPeerName(peerDisplayName)
        lock.lock()
        defer { lock.unlock() }
        var peers = loadKnownPeers()
        peers.removeValue(forKey: normalizedName)
        saveKnownPeers(peers)
    }

    /// Returns the short fingerprint (first 8 hex chars) for display purposes.
    func shortFingerprint(for peerDisplayName: String) -> String? {
        let normalizedName = Self.normalizedPeerName(peerDisplayName)
        lock.lock()
        defer { lock.unlock() }
        guard let fp = loadKnownPeers()[normalizedName]?.fingerprint else { return nil }
        return String(fp.prefix(16))
    }

    // MARK: - Private

    private func mutatePeer(_ peerDisplayName: String, mutation: (inout KnownMeshPeer) -> Void) {
        let normalizedName = Self.normalizedPeerName(peerDisplayName)
        lock.lock()
        defer { lock.unlock() }
        var peers = loadKnownPeers()
        guard var peer = peers[normalizedName] else { return }
        mutation(&peer)
        peers[normalizedName] = peer
        saveKnownPeers(peers)
    }

    private func loadKnownPeers() -> [String: KnownMeshPeer] {
        guard let data = defaults.data(forKey: StorageKey.knownPeers) else { return [:] }
        return (try? JSONDecoder().decode([String: KnownMeshPeer].self, from: data)) ?? [:]
    }

    private func saveKnownPeers(_ peers: [String: KnownMeshPeer]) {
        if let data = try? JSONEncoder().encode(peers) {
            defaults.set(data, forKey: StorageKey.knownPeers)
        }
    }

    /// One-time migration from the v1 fingerprint-only store to the new known peers store.
    private func migrateFromFingerprintOnlyStoreIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard defaults.data(forKey: StorageKey.knownPeers) == nil else { return }
        let legacyFingerprints = defaults.dictionary(forKey: StorageKey.trustedPeerFingerprints) as? [String: String] ?? [:]
        guard !legacyFingerprints.isEmpty else { return }

        var peers: [String: KnownMeshPeer] = [:]
        for (normalizedName, fingerprint) in legacyFingerprints {
            peers[normalizedName] = KnownMeshPeer(
                id: normalizedName,
                displayName: normalizedName,
                fingerprint: fingerprint,
                trustLevel: .unknown,
                firstSeenAt: .now,
                lastSeenAt: .now
            )
        }
        saveKnownPeers(peers)
    }

    private func logTrustDecision(_ decision: MeshPeerTrustDecision, peer: String) {
        guard !decision.allowsConnection else { return }
        DiagnosticStore.shared.log(.error, error: nil, context: [
            "service": "mesh",
            "detail": "Trust decision for \(peer): \(decision)",
            "systemState": "degraded"
        ])
    }

    static func normalizedPeerName(_ peerDisplayName: String) -> String {
        peerDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func fingerprint(for certificateChain: [Any]?) -> String? {
        guard let certificateData = certificateChain?.lazy.compactMap(Self.certificateData(from:)).first else {
            return nil
        }

        let digest = SHA256.hash(data: certificateData)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func certificateData(from value: Any) -> Data? {
        if let data = value as? Data {
            return data
        }

        let object = value as AnyObject
        guard CFGetTypeID(object) == SecCertificateGetTypeID() else {
            return nil
        }

        let certificate = unsafeBitCast(object, to: SecCertificate.self)
        return SecCertificateCopyData(certificate) as Data
    }
}

enum MeshTransportEvent: Equatable {
    case message(MeshMessage)
    case receivedBeacon(ReceivedCommunityBeacon)
}

@MainActor
protocol MeshTransport: AnyObject {
    var id: String { get }
    var isActive: Bool { get }
    var localPeer: MeshPeer { get }
    var nearbyPeers: [MeshPeer] { get }
    var connectedPeers: [MeshPeer] { get }

    var onEvent: ((MeshTransportEvent) -> Void)? { get set }
    var onLocalPeerChange: ((MeshPeer) -> Void)? { get set }
    var onNearbyPeersChange: (([MeshPeer]) -> Void)? { get set }
    var onConnectedPeersChange: (([MeshPeer]) -> Void)? { get set }

    func start()
    func stop()
    func updateConfiguration(_ configuration: MeshTransportConfiguration)
    func invite(_ peer: MeshPeer)
    @discardableResult
    func sendMessage(_ message: MeshMessage, to peers: [MeshPeer]) -> Bool
    @discardableResult
    func sendBeacon(_ beacon: CommunityBeacon, to peers: [MeshPeer]) -> Bool
}

@MainActor
final class MeshManager: ObservableObject {
    @Published private(set) var nearbyPeers: [MeshPeer] = []
    @Published private(set) var connectedPeers: [MeshPeer] = []
    @Published private(set) var sessionMessages: [MeshMessage] = []
    @Published private(set) var localPeer: MeshPeer

    let receivedBeacons = PassthroughSubject<ReceivedCommunityBeacon, Never>()

    private var transports: [any MeshTransport] = []
    private var locationShareMode: LocationShareMode = .approximate
    let deadLetterQueue = DeadLetterQueue(maxEntries: 50, maxAge: 2 * 60 * 60)

    init(transports: [any MeshTransport]? = nil) {
        let configuredTransports = transports ?? [
            NearbyTransport(),
            LoRaTransport()
        ]

        localPeer = MeshPeer(
            id: "system:local",
            transportID: "system",
            displayName: AppConstants.Mesh.fallbackDisplayName
        )

        configuredTransports.forEach(addTransport)
        refreshLocalPeer()
        refreshPeerLists()
    }

    func addTransport(_ transport: any MeshTransport) {
        transport.onEvent = { [weak self] event in
            guard let self else { return }
            self.handle(event)
        }

        transport.onLocalPeerChange = { [weak self] _ in
            guard let self else { return }
            self.refreshLocalPeer()
        }

        transport.onNearbyPeersChange = { [weak self] _ in
            guard let self else { return }
            self.refreshPeerLists()
        }

        transport.onConnectedPeersChange = { [weak self] _ in
            guard let self else { return }
            self.refreshPeerLists()
        }

        transports.append(transport)
    }

    func start() {
        transports.forEach { $0.start() }
        refreshLocalPeer()
        refreshPeerLists()
    }

    func stop() {
        transports.forEach { $0.stop() }
        refreshPeerLists()
    }

    func updateConfiguration(
        displayName: String,
        isBrowsingEnabled: Bool,
        isBroadcastingEnabled: Bool,
        autoAcceptInvitations: Bool,
        locationShareMode: LocationShareMode,
        rangeMode: SignalRangeMode,
        allowsOutgoingInvitations: Bool,
        usesLowFrequencyBrowsing: Bool
    ) {
        let configuration = MeshTransportConfiguration(
            displayName: displayName,
            isBrowsingEnabled: isBrowsingEnabled,
            isBroadcastingEnabled: isBroadcastingEnabled,
            autoAcceptInvitations: autoAcceptInvitations,
            locationShareMode: locationShareMode,
            rangeMode: rangeMode,
            allowsOutgoingInvitations: allowsOutgoingInvitations,
            usesLowFrequencyBrowsing: usesLowFrequencyBrowsing
        )

        self.locationShareMode = locationShareMode
        transports.forEach { $0.updateConfiguration(configuration) }
        refreshLocalPeer()
        refreshPeerLists()
    }

    func invite(_ peer: MeshPeer) {
        transport(for: peer.transportID)?.invite(peer)
    }

    func sendDirect(_ text: String, to peer: MeshPeer) {
        let message = MeshMessage(
            sender: localPeer.displayName,
            recipient: peer.displayName,
            body: text,
            kind: .direct
        )
        sendMessage(message, to: [peer])
    }

    func broadcastAlert(_ text: String) {
        let message = MeshMessage(
            sender: localPeer.displayName,
            body: text,
            kind: .broadcastAlert
        )
        sendMessage(message, to: connectedPeers)
    }

    func broadcastAccountabilityStatus(
        circleTitle: String,
        memberName: String,
        status: AccountabilityStatus,
        note: String = ""
    ) {
        let payload = AccountabilityMeshStatus(
            circleTitle: circleTitle,
            memberName: memberName,
            status: status,
            note: note
        )
        let body = "\(memberName): \(status.title)"
        let message = MeshMessage(
            sender: memberName,
            body: body,
            kind: .accountabilityStatus,
            accountabilityStatus: payload
        )
        sendMessage(message, to: connectedPeers)
    }

    func shareLocation(_ coordinate: CLLocationCoordinate2D, label: String) {
        guard let sharedCoordinate = locationShareMode.sharedCoordinate(from: coordinate) else {
            return
        }

        let location = SharedLocation(
            latitude: sharedCoordinate.latitude,
            longitude: sharedCoordinate.longitude,
            label: label
        )
        let message = MeshMessage(
            sender: localPeer.displayName,
            body: label,
            kind: .locationShare,
            location: location
        )
        sendMessage(message, to: connectedPeers)
    }

    /// Share an evacuation route with all connected mesh peers.
    /// Simplifies the route to max 20 waypoints for compact transmission.
    func shareEvacuationRoute(
        destination: String,
        route: OfflineRoutingService.Route,
        corridorAnalysis: RouteCorridor.CorridorAnalysis?,
        hazardExposure: Double = 0
    ) {
        // Simplify route to max 20 waypoints for mesh transmission
        let coords = route.coordinates
        let stride = max(1, coords.count / 20)
        var waypoints: [SharedLocation] = []
        for i in Swift.stride(from: 0, to: coords.count, by: stride) {
            waypoints.append(SharedLocation(
                latitude: coords[i].latitude,
                longitude: coords[i].longitude,
                label: i == 0 ? "Origin" : (i >= coords.count - stride ? "Destination" : "")
            ))
        }
        // Always include final point
        if let last = coords.last, waypoints.last?.latitude != last.latitude {
            waypoints.append(SharedLocation(
                latitude: last.latitude,
                longitude: last.longitude,
                label: "Destination"
            ))
        }

        let routeData = SharedRouteData(
            destination: destination,
            distanceMetres: route.distanceMetres,
            durationSeconds: route.durationSeconds,
            profile: route.profile.rawValue,
            waterSourceCount: corridorAnalysis?.waterSources.count ?? 0,
            shelterCount: corridorAnalysis?.shelters.count ?? 0,
            hazardExposure: hazardExposure,
            waypoints: waypoints,
            computedAt: .now
        )

        let distKM = String(format: "%.0f", route.distanceMetres / 1000)
        let message = MeshMessage(
            sender: localPeer.displayName,
            body: "Evacuation route to \(destination) — \(distKM) km via \(route.profile.title)",
            kind: .routeShare,
            routeData: routeData
        )
        sendMessage(message, to: connectedPeers)
    }

    /// Report a hazard to all connected mesh peers.
    func reportHazard(
        kind: OfflineRoutingService.HazardZone.HazardKind,
        coordinate: CLLocationCoordinate2D,
        radiusMetres: Double,
        severity: String,
        description: String
    ) {
        let report = SharedHazardReport(
            kind: kind.rawValue,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMetres: radiusMetres,
            severity: severity,
            description: description,
            reportedAt: .now
        )

        let message = MeshMessage(
            sender: localPeer.displayName,
            body: "Hazard: \(description)",
            kind: .hazardReport,
            hazardReport: report
        )
        sendMessage(message, to: connectedPeers)
    }

    /// Extract received route shares from session messages.
    var receivedRouteShares: [MeshMessage] {
        sessionMessages.filter { $0.kind == .routeShare && $0.routeData != nil }
    }

    /// Extract received hazard reports from session messages.
    var receivedHazardReports: [MeshMessage] {
        sessionMessages.filter { $0.kind == .hazardReport && $0.hazardReport != nil }
    }

    /// Returns hazard zones ONLY from verified peers.
    /// Unknown and blocked peers' hazard reports are visible in the message log
    /// but never promoted to routing-affecting hazard zones.
    var hazardZonesFromMesh: [OfflineRoutingService.HazardZone] {
        sessionMessages
            .filter { $0.kind == .hazardReport }
            .compactMap { message -> OfflineRoutingService.HazardZone? in
                guard let report = message.hazardReport else { return nil }
                // Only trust hazard data from verified peers
                guard peerTrustLevel(for: message.sender) == .verified else { return nil }
                guard let kind = OfflineRoutingService.HazardZone.HazardKind(rawValue: report.kind) else { return nil }
                return OfflineRoutingService.HazardZone(
                    center: CLLocationCoordinate2D(latitude: report.latitude, longitude: report.longitude),
                    radiusMetres: report.radiusMetres,
                    penalty: 10.0,
                    kind: kind
                )
            }
    }

    /// Returns the trust level for a message sender.
    func peerTrustLevel(for senderDisplayName: String) -> MeshPeerTrustLevel {
        guard let nearbyTransport = transports.first(where: { $0.id == "nearby" }) as? NearbyTransport else {
            return .unknown
        }
        return nearbyTransport.trustStore.trustLevel(for: senderDisplayName)
    }

    // MARK: - Peer Trust Management

    /// All known peers with their trust status.
    var knownPeers: [KnownMeshPeer] {
        guard let nearbyTransport = transports.first(where: { $0.id == "nearby" }) as? NearbyTransport else {
            return []
        }
        return nearbyTransport.trustStore.knownPeers()
    }

    /// Verify a peer — promotes their hazard reports to routing-grade trust.
    func verifyPeer(_ displayName: String) {
        guard let nearbyTransport = transports.first(where: { $0.id == "nearby" }) as? NearbyTransport else { return }
        nearbyTransport.trustStore.verify(peerDisplayName: displayName)
        objectWillChange.send()
    }

    /// Block a peer — drops their connections and future messages.
    func blockPeer(_ displayName: String) {
        guard let nearbyTransport = transports.first(where: { $0.id == "nearby" }) as? NearbyTransport else { return }
        nearbyTransport.trustStore.block(peerDisplayName: displayName)
        // Remove blocked peer's messages from session
        sessionMessages.removeAll { $0.sender.lowercased() == displayName.lowercased() }
        objectWillChange.send()
    }

    /// Revoke trust back to unknown.
    func revokePeerTrust(_ displayName: String) {
        guard let nearbyTransport = transports.first(where: { $0.id == "nearby" }) as? NearbyTransport else { return }
        nearbyTransport.trustStore.revokeTrust(peerDisplayName: displayName)
        objectWillChange.send()
    }

    /// Completely forget a peer.
    func forgetPeer(_ displayName: String) {
        guard let nearbyTransport = transports.first(where: { $0.id == "nearby" }) as? NearbyTransport else { return }
        nearbyTransport.trustStore.forget(peerDisplayName: displayName)
        objectWillChange.send()
    }

    /// Short fingerprint for UI display.
    func shortFingerprint(for displayName: String) -> String? {
        guard let nearbyTransport = transports.first(where: { $0.id == "nearby" }) as? NearbyTransport else { return nil }
        return nearbyTransport.trustStore.shortFingerprint(for: displayName)
    }

    func sendBeacon(_ beacon: CommunityBeacon) {
        sendBeacon(beacon, to: connectedPeers)
    }

    func sendBeacon(_ beacon: CommunityBeacon, excludingDisplayName excludedDisplayName: String?) {
        let peers = connectedPeers.filter { $0.displayName != excludedDisplayName }
        sendBeacon(beacon, to: peers)
    }

    func sendBeacon(_ beacon: CommunityBeacon, to peers: [MeshPeer]) {
        guard !peers.isEmpty else { return }

        for (transport, transportPeers) in peersByTransport(from: peers) {
            _ = transport.sendBeacon(beacon, to: transportPeers)
        }
    }

    // MARK: - Abuse Protection

    /// Rate limit: max messages per sender within a rolling window.
    private var messageTimestamps: [String: [Date]] = [:]  // senderName → timestamps
    private let rateLimitWindow: TimeInterval = 60          // 1 minute
    private let rateLimitMax: Int = 20                      // max 20 messages per minute per sender
    private var recentHazardHashes: Set<Int> = []           // duplicate suppression for hazard reports

    /// Check if a sender has exceeded their rate limit.
    private func isRateLimited(sender: String) -> Bool {
        let now = Date.now
        let cutoff = now.addingTimeInterval(-rateLimitWindow)
        messageTimestamps[sender] = (messageTimestamps[sender] ?? []).filter { $0 > cutoff }
        return (messageTimestamps[sender]?.count ?? 0) >= rateLimitMax
    }

    /// Record a message from a sender for rate limiting.
    private func recordMessage(from sender: String) {
        messageTimestamps[sender, default: []].append(.now)
    }

    /// Hash a hazard report for duplicate suppression.
    private func hazardHash(_ report: SharedHazardReport) -> Int {
        var hasher = Hasher()
        hasher.combine(report.kind)
        hasher.combine(Int(report.latitude * 1000))  // ~111m grid
        hasher.combine(Int(report.longitude * 1000))
        return hasher.finalize()
    }

    func clearSessionMessages() {
        sessionMessages = []
        recentHazardHashes = []
    }

    private func sendMessage(_ message: MeshMessage, to peers: [MeshPeer]) {
        guard !peers.isEmpty else { return }

        var didSend = false
        for (transport, transportPeers) in peersByTransport(from: peers) {
            // Retry once on first failure (100ms gap)
            if transport.sendMessage(message, to: transportPeers) {
                didSend = true
            } else if transport.sendMessage(message, to: transportPeers) {
                didSend = true
            }
        }

        if didSend {
            sessionMessages.insert(message, at: 0)
        } else {
            // Enqueue failed message for later retry
            if let payload = try? JSONEncoder.rediM8.encode(message) {
                Task {
                    await deadLetterQueue.enqueue(payload: payload, reason: "Send failed to \(peers.count) peer(s)")
                }
            }
        }
    }

    /// Retry sending any queued dead letters to currently connected peers.
    func drainDeadLetterQueue() {
        guard !connectedPeers.isEmpty else { return }
        Task {
            let entries = await deadLetterQueue.dequeueAll()
            for entry in entries {
                guard let message = try? JSONDecoder.rediM8.decode(MeshMessage.self, from: entry.payload) else {
                    continue
                }
                var didSend = false
                for (transport, transportPeers) in peersByTransport(from: connectedPeers) {
                    didSend = transport.sendMessage(message, to: transportPeers) || didSend
                }
                if didSend {
                    sessionMessages.insert(message, at: 0)
                } else if entry.attempts < 3 {
                    await deadLetterQueue.enqueue(payload: entry.payload, reason: "Re-send failed (attempt \(entry.attempts + 1))")
                }
            }
        }
    }

    private func handle(_ event: MeshTransportEvent) {
        switch event {
        case let .message(message):
            // Trust gate: drop messages from blocked peers
            if peerTrustLevel(for: message.sender) == .blocked {
                RediLogger.mesh.debug("Dropped message from blocked peer: \(message.sender, privacy: .public)")
                return
            }

            // Rate limit: drop messages from spammy senders
            if isRateLimited(sender: message.sender) { return }
            recordMessage(from: message.sender)

            // Duplicate suppression for hazard reports
            if message.kind == .hazardReport, let report = message.hazardReport {
                let hash = hazardHash(report)
                if recentHazardHashes.contains(hash) { return }
                recentHazardHashes.insert(hash)
                // Cap hash set size
                if recentHazardHashes.count > 500 {
                    recentHazardHashes = Set(recentHazardHashes.prefix(250))
                }
            }

            sessionMessages.insert(message, at: 0)
        case let .receivedBeacon(received):
            receivedBeacons.send(received)
        }
    }

    private func refreshLocalPeer() {
        if let preferredTransport = transports.first(where: { !$0.localPeer.displayName.isEmpty }) {
            localPeer = preferredTransport.localPeer
        }
    }

    private func refreshPeerLists() {
        let previousConnectedCount = connectedPeers.count
        nearbyPeers = mergedPeers { $0.nearbyPeers }
        connectedPeers = mergedPeers { $0.connectedPeers }

        // Drain dead letter queue when peers reconnect
        if previousConnectedCount == 0 && !connectedPeers.isEmpty {
            drainDeadLetterQueue()
        }
    }

    private func mergedPeers(_ peers: (any MeshTransport) -> [MeshPeer]) -> [MeshPeer] {
        var merged: [String: MeshPeer] = [:]

        for transport in transports {
            for peer in peers(transport) {
                merged[peer.id] = peer
            }
        }

        return merged.values.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func peersByTransport(from peers: [MeshPeer]) -> [(transport: any MeshTransport, peers: [MeshPeer])] {
        var grouped: [String: [MeshPeer]] = [:]
        for peer in peers {
            grouped[peer.transportID, default: []].append(peer)
        }

        return transports.compactMap { transport in
            guard let transportPeers = grouped[transport.id], !transportPeers.isEmpty else {
                return nil
            }
            return (transport, transportPeers)
        }
    }

    private func transport(for id: String) -> (any MeshTransport)? {
        transports.first { $0.id == id }
    }
}

@MainActor
final class NearbyTransport: NSObject, MeshTransport {
    let id = "nearby"

    private(set) var isActive = false
    private(set) var localPeer: MeshPeer
    private(set) var nearbyPeers: [MeshPeer] = []
    private(set) var connectedPeers: [MeshPeer] = []

    var onEvent: ((MeshTransportEvent) -> Void)?
    var onLocalPeerChange: ((MeshPeer) -> Void)?
    var onNearbyPeersChange: (([MeshPeer]) -> Void)?
    var onConnectedPeersChange: (([MeshPeer]) -> Void)?

    private let serviceType = AppConstants.Mesh.serviceType
    private var preferredDisplayName: String
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    private var peerLookup: [String: MCPeerID] = [:]
    private var isRunning = false
    private var isBrowsingEnabled = true
    private var isBroadcastingEnabled = true
    private var automaticallyAcceptsInvitations = true
    private var allowsOutgoingInvitations = true
    private var usesLowFrequencyBrowsing = false
    private var invitationTimeout: TimeInterval = SignalRangeMode.balanced.invitationTimeout
    private var browsePulseTicker: AnyCancellable?
    private var browsePulseStopWorkItem: DispatchWorkItem?
    nonisolated let trustStore = MeshPeerTrustStore()

    override init() {
        let displayName = Self.defaultDisplayName()
        preferredDisplayName = displayName
        let peerID = MCPeerID(displayName: displayName)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: nil,
            serviceType: AppConstants.Mesh.serviceType
        )
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: AppConstants.Mesh.serviceType)
        localPeer = Self.meshPeer(from: peerID, transportID: id)
        super.init()
        bindDelegates()
    }

    func start() {
        isRunning = true
        isActive = true
        applyTransportState()
        refreshConnectedPeers()
    }

    func stop() {
        isRunning = false
        isActive = false
        stopTransports()
        refreshConnectedPeers()
    }

    func updateConfiguration(_ configuration: MeshTransportConfiguration) {
        let trimmedDisplayName = Self.sanitizedDisplayName(configuration.displayName)
        let needsPeerRebuild = trimmedDisplayName != preferredDisplayName

        preferredDisplayName = trimmedDisplayName
        isBrowsingEnabled = configuration.isBrowsingEnabled
        isBroadcastingEnabled = configuration.isBroadcastingEnabled
        automaticallyAcceptsInvitations = configuration.autoAcceptInvitations
        allowsOutgoingInvitations = configuration.allowsOutgoingInvitations
        usesLowFrequencyBrowsing = configuration.usesLowFrequencyBrowsing
        invitationTimeout = configuration.rangeMode.invitationTimeout

        if needsPeerRebuild {
            rebuildPeer(displayName: trimmedDisplayName)
        }

        applyTransportState()
    }

    func invite(_ peer: MeshPeer) {
        guard allowsOutgoingInvitations else { return }
        guard let peerID = peerLookup[peer.id] else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: invitationTimeout)
    }

    func sendMessage(_ message: MeshMessage, to peers: [MeshPeer]) -> Bool {
        sendData(message, to: peers, mode: .reliable)
    }

    func sendBeacon(_ beacon: CommunityBeacon, to peers: [MeshPeer]) -> Bool {
        sendData(beacon, to: peers, mode: .unreliable)
    }

    private func sendData<T: Encodable>(_ payload: T, to peers: [MeshPeer], mode: MCSessionSendDataMode) -> Bool {
        let peerIDs = peers.compactMap { peerLookup[$0.id] }
        guard !peerIDs.isEmpty else { return false }

        do {
            let data = try JSONEncoder.rediM8.encode(payload)
            try session.send(data, toPeers: peerIDs, with: mode)
            refreshConnectedPeers()
            return true
        } catch {
            emitSystemMessage("Unable to send message. Keep peers nearby and retry.")
            return false
        }
    }

    private func rebuildPeer(displayName: String) {
        let wasRunning = isRunning

        stopTransports()
        session.disconnect()

        let peerID = MCPeerID(displayName: displayName)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        localPeer = Self.meshPeer(from: peerID, transportID: id)
        nearbyPeers = []
        connectedPeers = []
        peerLookup = [:]
        bindDelegates()
        onLocalPeerChange?(localPeer)
        onNearbyPeersChange?(nearbyPeers)
        onConnectedPeersChange?(connectedPeers)

        if wasRunning {
            applyTransportState()
        }
        refreshConnectedPeers()
    }

    private func applyTransportState() {
        guard isRunning else {
            stopTransports()
            return
        }

        if isBroadcastingEnabled {
            advertiser.startAdvertisingPeer()
        } else {
            advertiser.stopAdvertisingPeer()
        }

        if isBrowsingEnabled {
            if usesLowFrequencyBrowsing {
                startLowFrequencyBrowsing()
            } else {
                stopLowFrequencyBrowsing(clearPeers: false)
                browser.startBrowsingForPeers()
            }
        } else {
            stopLowFrequencyBrowsing(clearPeers: true)
        }
    }

    private func stopTransports() {
        advertiser.stopAdvertisingPeer()
        stopLowFrequencyBrowsing(clearPeers: true)
    }

    private func startLowFrequencyBrowsing() {
        browsePulseTicker?.cancel()
        browsePulseTicker = nil
        beginBrowsingPulse()
        browsePulseTicker = Timer.publish(
            every: AppConstants.Mesh.stealthPulseInterval,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            self?.beginBrowsingPulse()
        }
    }

    private func beginBrowsingPulse() {
        browser.startBrowsingForPeers()

        browsePulseStopWorkItem?.cancel()
        let stopWorkItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.browser.stopBrowsingForPeers()
            }
        }
        browsePulseStopWorkItem = stopWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppConstants.Mesh.stealthPulseDuration,
            execute: stopWorkItem
        )
    }

    private func stopLowFrequencyBrowsing(clearPeers: Bool) {
        browsePulseTicker?.cancel()
        browsePulseTicker = nil
        browsePulseStopWorkItem?.cancel()
        browsePulseStopWorkItem = nil
        browser.stopBrowsingForPeers()
        if clearPeers {
            nearbyPeers = []
            onNearbyPeersChange?(nearbyPeers)
        }
    }

    private func bindDelegates() {
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    private func refreshConnectedPeers() {
        for peerID in session.connectedPeers {
            let peer = Self.meshPeer(from: peerID, transportID: id)
            peerLookup[peer.id] = peerID
        }

        connectedPeers = session.connectedPeers
            .map { Self.meshPeer(from: $0, transportID: id) }
            .sorted { $0.displayName < $1.displayName }
        onConnectedPeersChange?(connectedPeers)
    }

    private func updateNearbyPeers(_ peers: [MeshPeer]) {
        nearbyPeers = peers.sorted { $0.displayName < $1.displayName }
        onNearbyPeersChange?(nearbyPeers)
    }

    private func emitSystemMessage(_ body: String) {
        onEvent?(.message(MeshMessage(sender: "System", body: body, kind: .broadcastAlert)))
    }

    private static func meshPeer(from peerID: MCPeerID, transportID: String) -> MeshPeer {
        MeshPeer(
            id: "\(transportID):\(peerID.displayName)",
            transportID: transportID,
            displayName: peerID.displayName
        )
    }

    private static func defaultDisplayName() -> String {
        sanitizedDisplayName(String(UIDevice.current.name.prefix(20)))
    }

    private static func sanitizedDisplayName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? AppConstants.Mesh.fallbackDisplayName : trimmed
        return String(fallback.prefix(20))
    }
}

extension NearbyTransport: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            invitationHandler(self.automaticallyAcceptsInvitations, self.automaticallyAcceptsInvitations ? self.session : nil)
        }
    }
}

extension NearbyTransport: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor in
            let peer = Self.meshPeer(from: peerID, transportID: self.id)
            guard peer.id != self.localPeer.id else { return }
            guard !self.nearbyPeers.contains(peer) else { return }
            self.peerLookup[peer.id] = peerID
            self.updateNearbyPeers(self.nearbyPeers + [peer])
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            let peer = Self.meshPeer(from: peerID, transportID: self.id)
            self.updateNearbyPeers(self.nearbyPeers.filter { $0 != peer })
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.emitSystemMessage("Peer discovery unavailable right now.")
        }
    }
}

extension NearbyTransport: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.refreshConnectedPeers()
            if state == .connected {
                self.emitSystemMessage("\(peerID.displayName) connected.")
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = RediLogger.mesh.tryOrNil("Decode mesh message", operation: {
            try JSONDecoder.rediM8.decode(MeshMessage.self, from: data)
        }) {
            Task { @MainActor in
                self.onEvent?(.message(message))
            }
            return
        }

        if let beacon = RediLogger.mesh.tryOrNil("Decode community beacon", operation: {
            try JSONDecoder.rediM8.decode(CommunityBeacon.self, from: data)
        }) {
            Task { @MainActor in
                self.onEvent?(
                    .receivedBeacon(
                        ReceivedCommunityBeacon(
                            beacon: beacon,
                            sourcePeerDisplayName: peerID.displayName
                        )
                    )
                )
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    nonisolated func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        let decision = trustStore.evaluate(certificateChain: certificate, peerDisplayName: peerID.displayName)
        certificateHandler(decision.allowsConnection)

        guard !decision.allowsConnection else { return }

        let message = decision.rejectionMessage(for: peerID.displayName)
        RediLogger.mesh.error("Blocked untrusted mesh peer connection.")
        Task { @MainActor in
            self.emitSystemMessage(message)
        }
    }
}

@MainActor
final class LoRaTransport: MeshTransport {
    let id = "lora"

    private(set) var isActive = false
    private(set) var localPeer = MeshPeer(
        id: "lora:unavailable",
        transportID: "lora",
        displayName: AppConstants.Mesh.fallbackDisplayName
    )
    private(set) var nearbyPeers: [MeshPeer] = []
    private(set) var connectedPeers: [MeshPeer] = []

    var onEvent: ((MeshTransportEvent) -> Void)?
    var onLocalPeerChange: ((MeshPeer) -> Void)?
    var onNearbyPeersChange: (([MeshPeer]) -> Void)?
    var onConnectedPeersChange: (([MeshPeer]) -> Void)?

    func start() {
        isActive = true
    }

    func stop() {
        isActive = false
    }

    func updateConfiguration(_ configuration: MeshTransportConfiguration) {}

    func invite(_ peer: MeshPeer) {}

    func sendMessage(_ message: MeshMessage, to peers: [MeshPeer]) -> Bool { false }

    func sendBeacon(_ beacon: CommunityBeacon, to peers: [MeshPeer]) -> Bool { false }
}

typealias MeshService = MeshManager
