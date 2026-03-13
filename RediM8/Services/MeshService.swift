import Combine
import CoreLocation
import Foundation
@preconcurrency import MultipeerConnectivity
import UIKit

struct ReceivedCommunityBeacon: Equatable {
    let beacon: CommunityBeacon
    let sourcePeerDisplayName: String
}

final class MeshService: NSObject, ObservableObject {
    @Published private(set) var nearbyPeers: [MCPeerID] = []
    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var sessionMessages: [MeshMessage] = []

    private(set) var localPeer: MCPeerID
    let receivedBeacons = PassthroughSubject<ReceivedCommunityBeacon, Never>()

    private let serviceType = AppConstants.Mesh.serviceType
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    private var isRunning = false
    private var isBrowsingEnabled = true
    private var isBroadcastingEnabled = true
    private var automaticallyAcceptsInvitations = true
    private var allowsOutgoingInvitations = true
    private var usesLowFrequencyBrowsing = false
    private var locationShareMode: LocationShareMode = .approximate
    private var invitationTimeout: TimeInterval = SignalRangeMode.balanced.invitationTimeout
    private var preferredDisplayName: String
    private var browsePulseTicker: AnyCancellable?
    private var browsePulseStopWorkItem: DispatchWorkItem?

    override init() {
        let displayName = Self.defaultDisplayName()
        preferredDisplayName = displayName
        let peer = MCPeerID(displayName: displayName)
        localPeer = peer
        session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: AppConstants.Mesh.serviceType)
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: AppConstants.Mesh.serviceType)
        super.init()
        bindDelegates()
    }

    @MainActor
    func start() {
        isRunning = true
        applyTransportState()
        refreshConnectedPeers()
    }

    @MainActor
    func stop() {
        isRunning = false
        stopTransports()
        refreshConnectedPeers()
    }

    @MainActor
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
        let trimmedDisplayName = Self.sanitizedDisplayName(displayName)
        let needsPeerRebuild = trimmedDisplayName != preferredDisplayName

        preferredDisplayName = trimmedDisplayName
        self.isBrowsingEnabled = isBrowsingEnabled
        self.isBroadcastingEnabled = isBroadcastingEnabled
        automaticallyAcceptsInvitations = autoAcceptInvitations
        self.allowsOutgoingInvitations = allowsOutgoingInvitations
        self.usesLowFrequencyBrowsing = usesLowFrequencyBrowsing
        self.locationShareMode = locationShareMode
        invitationTimeout = rangeMode.invitationTimeout

        if needsPeerRebuild {
            rebuildPeer(displayName: trimmedDisplayName)
        }

        applyTransportState()
    }

    @MainActor
    func invite(_ peer: MCPeerID) {
        guard allowsOutgoingInvitations else { return }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: invitationTimeout)
    }

    @MainActor
    func sendDirect(_ text: String, to peer: MCPeerID) {
        let message = MeshMessage(sender: localPeer.displayName, recipient: peer.displayName, body: text, kind: .direct)
        send(message, to: [peer])
    }

    @MainActor
    func broadcastAlert(_ text: String) {
        let message = MeshMessage(sender: localPeer.displayName, body: text, kind: .broadcastAlert)
        send(message, to: session.connectedPeers)
    }

    @MainActor
    func shareLocation(_ coordinate: CLLocationCoordinate2D, label: String) {
        guard let sharedCoordinate = locationShareMode.sharedCoordinate(from: coordinate) else {
            return
        }

        let location = SharedLocation(latitude: sharedCoordinate.latitude, longitude: sharedCoordinate.longitude, label: label)
        let message = MeshMessage(sender: localPeer.displayName, body: label, kind: .locationShare, location: location)
        send(message, to: session.connectedPeers)
    }

    @MainActor
    func sendBeacon(_ beacon: CommunityBeacon) {
        sendData(beacon, to: session.connectedPeers, mode: .unreliable)
    }

    @MainActor
    func sendBeacon(_ beacon: CommunityBeacon, excludingDisplayName excludedDisplayName: String?) {
        let peers = session.connectedPeers.filter { $0.displayName != excludedDisplayName }
        sendData(beacon, to: peers, mode: .unreliable)
    }

    @MainActor
    func sendBeacon(_ beacon: CommunityBeacon, to peers: [MCPeerID]) {
        sendData(beacon, to: peers, mode: .unreliable)
    }

    @MainActor
    func clearSessionMessages() {
        sessionMessages = []
    }

    @MainActor
    private func send(_ message: MeshMessage, to peers: [MCPeerID]) {
        sendData(message, to: peers, mode: .reliable)
    }

    @MainActor
    private func sendData<T: Encodable>(_ payload: T, to peers: [MCPeerID], mode: MCSessionSendDataMode) {
        guard !peers.isEmpty else { return }

        do {
            let data = try JSONEncoder.rediM8.encode(payload)
            try session.send(data, toPeers: peers, with: mode)
            if let message = payload as? MeshMessage {
                sessionMessages.insert(message, at: 0)
            }
            refreshConnectedPeers()
        } catch {
            sessionMessages.insert(
                MeshMessage(sender: "System", body: "Unable to send message. Keep peers nearby and retry.", kind: .broadcastAlert),
                at: 0
            )
        }
    }

    @MainActor
    private func rebuildPeer(displayName: String) {
        let wasRunning = isRunning

        stopTransports()
        session.disconnect()

        let peer = MCPeerID(displayName: displayName)
        localPeer = peer
        session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: serviceType)
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: serviceType)
        bindDelegates()

        if wasRunning {
            applyTransportState()
        }
        refreshConnectedPeers()
    }

    @MainActor
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

    @MainActor
    private func stopTransports() {
        advertiser.stopAdvertisingPeer()
        stopLowFrequencyBrowsing(clearPeers: true)
    }

    @MainActor
    private func startLowFrequencyBrowsing() {
        browsePulseTicker?.cancel()
        browsePulseTicker = nil
        beginBrowsingPulse()
        browsePulseTicker = Timer.publish(every: AppConstants.Mesh.stealthPulseInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.beginBrowsingPulse()
            }
    }

    @MainActor
    private func beginBrowsingPulse() {
        browser.startBrowsingForPeers()

        browsePulseStopWorkItem?.cancel()
        let stopWorkItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.browser.stopBrowsingForPeers()
            }
        }
        browsePulseStopWorkItem = stopWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Mesh.stealthPulseDuration, execute: stopWorkItem)
    }

    @MainActor
    private func stopLowFrequencyBrowsing(clearPeers: Bool) {
        browsePulseTicker?.cancel()
        browsePulseTicker = nil
        browsePulseStopWorkItem?.cancel()
        browsePulseStopWorkItem = nil
        browser.stopBrowsingForPeers()
        if clearPeers {
            nearbyPeers = []
        }
    }

    private func bindDelegates() {
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    @MainActor
    private func refreshConnectedPeers() {
        connectedPeers = session.connectedPeers.sorted { $0.displayName < $1.displayName }
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

extension MeshService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(automaticallyAcceptsInvitations, automaticallyAcceptsInvitations ? session : nil)
    }
}

extension MeshService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard peerID != localPeer else { return }
        Task { @MainActor in
            guard !self.nearbyPeers.contains(peerID) else { return }
            self.nearbyPeers.append(peerID)
            self.nearbyPeers.sort { $0.displayName < $1.displayName }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.nearbyPeers.removeAll { $0 == peerID }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.sessionMessages.insert(MeshMessage(sender: "System", body: "Peer discovery unavailable right now.", kind: .broadcastAlert), at: 0)
        }
    }
}

extension MeshService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.refreshConnectedPeers()
            if state == .connected {
                self.sessionMessages.insert(
                    MeshMessage(sender: "System", body: "\(peerID.displayName) connected.", kind: .broadcastAlert),
                    at: 0
                )
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = try? JSONDecoder.rediM8.decode(MeshMessage.self, from: data) {
            Task { @MainActor in
                self.sessionMessages.insert(message, at: 0)
            }
            return
        }

        if let beacon = try? JSONDecoder.rediM8.decode(CommunityBeacon.self, from: data) {
            Task { @MainActor in
                self.receivedBeacons.send(
                    ReceivedCommunityBeacon(
                        beacon: beacon,
                        sourcePeerDisplayName: peerID.displayName
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
