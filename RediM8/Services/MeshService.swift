import Combine
import CoreLocation
import Foundation
@preconcurrency import MultipeerConnectivity
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

    /// Convert received hazard reports into HazardZones for the routing engine.
    var hazardZonesFromMesh: [OfflineRoutingService.HazardZone] {
        receivedHazardReports.compactMap { msg -> OfflineRoutingService.HazardZone? in
            guard let report = msg.hazardReport else { return nil }
            let kind: OfflineRoutingService.HazardZone.HazardKind
            switch report.kind {
            case "flood": kind = .flood
            case "fire": kind = .fire
            case "storm_surge": kind = .stormSurge
            case "road_closure": kind = .roadClosure
            default: kind = .roadClosure
            }
            let penalty: Double = switch report.severity {
            case "critical": 10.0
            case "high": 6.0
            case "moderate": 3.0
            default: 2.0
            }
            return OfflineRoutingService.HazardZone(
                center: CLLocationCoordinate2D(latitude: report.latitude, longitude: report.longitude),
                radiusMetres: report.radiusMetres,
                penalty: penalty,
                kind: kind
            )
        }
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

    /// Minimum confidence threshold for mesh hazards to affect routing.
    /// Reports below this threshold are stored but not forwarded to the routing engine.
    static let minRoutingConfidence: HazardIntelligenceService.HazardConfidence = .medium

    func clearSessionMessages() {
        sessionMessages = []
        recentHazardHashes = []
    }

    private func sendMessage(_ message: MeshMessage, to peers: [MeshPeer]) {
        guard !peers.isEmpty else { return }

        var didSend = false
        for (transport, transportPeers) in peersByTransport(from: peers) {
            didSend = transport.sendMessage(message, to: transportPeers) || didSend
        }

        if didSend {
            sessionMessages.insert(message, at: 0)
        }
    }

    private func handle(_ event: MeshTransportEvent) {
        switch event {
        case let .message(message):
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
        nearbyPeers = mergedPeers { $0.nearbyPeers }
        connectedPeers = mergedPeers { $0.connectedPeers }
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
        if let message = try? JSONDecoder.rediM8.decode(MeshMessage.self, from: data) {
            Task { @MainActor in
                self.onEvent?(.message(message))
            }
            return
        }

        if let beacon = try? JSONDecoder.rediM8.decode(CommunityBeacon.self, from: data) {
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
        certificateHandler(true)
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
