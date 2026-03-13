import Combine
import CoreLocation
import Foundation
import MultipeerConnectivity
import UIKit

struct BeaconNotice: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

private enum MeshStatusState: Equatable {
    case noNearbyUsers
    case nearbyUsers(count: Int)
    case networkForming(count: Int)
    case emergencyBroadcast(type: BeaconType)

    var label: String {
        switch self {
        case .noNearbyUsers:
            "No nearby users"
        case .nearbyUsers:
            "1-3 users nearby"
        case .networkForming:
            "Network forming"
        case .emergencyBroadcast:
            "Emergency broadcast"
        }
    }

    var tone: OperationalStatusTone {
        switch self {
        case .noNearbyUsers:
            .neutral
        case .nearbyUsers:
            .caution
        case .networkForming:
            .info
        case .emergencyBroadcast:
            .danger
        }
    }
}

@MainActor
final class SignalViewModel: ObservableObject {
    @Published var draftMessage = ""
    @Published var selectedBeaconType: BeaconType = .safeLocation {
        didSet {
            let oldDefaults = Set(oldValue.defaultResources)
            if beaconStatusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || beaconStatusText == oldValue.defaultStatusText {
                beaconStatusText = selectedBeaconType.defaultStatusText
            }
            if selectedResources.isEmpty || selectedResources == oldDefaults {
                selectedResources = Set(selectedBeaconType.defaultResources)
            }
            if !selectedBeaconType.supportsEmergencyMedicalDisclosure {
                includesEmergencyMedicalInfo = false
            }
        }
    }
    @Published var beaconStatusText = BeaconType.safeLocation.defaultStatusText
    @Published var beaconMessage = ""
    @Published var beaconLocationName = ""
    @Published var selectedResources = Set<BeaconResource>()
    @Published var showsName = false
    @Published var displayName = ""
    @Published var includesEmergencyMedicalInfo = false
    @Published var beaconNotice: BeaconNotice?
    @Published private(set) var settings: AppSettings
    @Published private(set) var profile: UserProfile
    @Published private(set) var nearbyPeers: [MCPeerID] = []
    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var sessionMessages: [MeshMessage] = []
    @Published private(set) var activeBeacon: CommunityBeacon?
    @Published private(set) var nearbyBeacons: [CommunityBeacon] = []
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var isStealthModeEnabled = false

    private let appState: AppState
    private let meshService: MeshService
    private let beaconService: BeaconService
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        meshService = appState.meshService
        beaconService = appState.beaconService
        locationService = appState.locationService
        settings = appState.settings
        profile = appState.profile
        isStealthModeEnabled = appState.isStealthModeEnabled
        displayName = appState.isStealthModeEnabled
            ? appState.stealthModeNodeLabel
            : (appState.settings.privacy.showsDeviceName ? String(UIDevice.current.name.prefix(20)) : appState.beaconService.localNodeLabel)
        activeBeacon = appState.beaconService.activeBeacon
        if let activeBeacon {
            syncDraft(from: activeBeacon)
        }

        meshService.$nearbyPeers
            .assign(to: &$nearbyPeers)

        meshService.$connectedPeers
            .assign(to: &$connectedPeers)

        meshService.$sessionMessages
            .assign(to: &$sessionMessages)

        beaconService.$activeBeacon
            .sink { [weak self] beacon in
                self?.activeBeacon = beacon
            }
            .store(in: &cancellables)

        beaconService.$nearbyBeacons
            .assign(to: &$nearbyBeacons)

        locationService.$currentLocation
            .assign(to: &$currentLocation)

        appState.$settings
            .sink { [weak self] settings in
                guard let self else { return }
                self.settings = settings
                if self.isStealthModeEnabled || !settings.privacy.showsDeviceName {
                    self.showsName = false
                    self.displayName = self.isStealthModeEnabled ? self.appState.stealthModeNodeLabel : self.beaconService.localNodeLabel
                } else if self.displayName == self.beaconService.localNodeLabel || self.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.displayName = String(UIDevice.current.name.prefix(20))
                }
            }
            .store(in: &cancellables)

        appState.$profile
            .sink { [weak self] profile in
                self?.profile = profile
                if profile.emergencyMedicalInfo.hasAnyContent == false {
                    self?.includesEmergencyMedicalInfo = false
                }
            }
            .store(in: &cancellables)

        appState.$isStealthModeEnabled
            .sink { [weak self] isEnabled in
                guard let self else { return }
                self.isStealthModeEnabled = isEnabled
                if isEnabled {
                    self.showsName = false
                    self.displayName = self.appState.stealthModeNodeLabel
                } else if !self.settings.privacy.showsDeviceName {
                    self.displayName = self.beaconService.localNodeLabel
                } else if self.displayName == self.appState.stealthModeNodeLabel || self.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.displayName = String(UIDevice.current.name.prefix(20))
                }
            }
            .store(in: &cancellables)
    }

    var deviceName: String {
        meshService.localPeer.displayName
    }

    var localNodeLabel: String {
        isStealthModeEnabled ? appState.stealthModeNodeLabel : beaconService.localNodeLabel
    }

    var beaconResources: [BeaconResource] {
        BeaconResource.allCases
    }

    var isAnonymousModeEnabled: Bool {
        settings.privacy.isAnonymousModeEnabled
    }

    var isDisplayNameControlEnabled: Bool {
        settings.privacy.showsDeviceName && !isStealthModeEnabled
    }

    var canBroadcastOutboundSignals: Bool {
        !isStealthModeEnabled && !settings.privacy.isAnonymousModeEnabled
    }

    var canInitiateConnections: Bool {
        !isStealthModeEnabled
    }

    var canShareLocation: Bool {
        canBroadcastOutboundSignals && settings.privacy.locationShareMode != .off
    }

    var canUseBeaconMode: Bool {
        canBroadcastOutboundSignals
            && settings.signalDiscovery.allowsBeaconBroadcasts
            && settings.privacy.locationShareMode != .off
    }

    var emergencyMedicalInfo: EmergencyMedicalInfo {
        profile.emergencyMedicalInfo
    }

    var hasEmergencyMedicalInfo: Bool {
        emergencyMedicalInfo.hasAnyContent
    }

    var canAttachEmergencyMedicalInfo: Bool {
        selectedBeaconType.supportsEmergencyMedicalDisclosure && hasEmergencyMedicalInfo
    }

    var emergencyMedicalInfoStatusMessage: String? {
        guard selectedBeaconType.supportsEmergencyMedicalDisclosure else {
            return nil
        }

        if hasEmergencyMedicalInfo {
            return TrustLayer.emergencyMedicalInfoPrivacyNotice
        }

        return "No emergency medical info is saved yet. Add it in Settings > Emergency Profile before attaching it to a help report."
    }

    var emergencyMedicalBroadcastPreview: String? {
        guard includesEmergencyMedicalInfo else {
            return nil
        }

        return emergencyMedicalInfo.broadcastSummary
    }

    var displayedBeacons: [CommunityBeacon] {
        nearbyBeacons.sorted { lhs, rhs in
            if lhs.type.priority != rhs.type.priority {
                return lhs.type.priority < rhs.type.priority
            }

            return distance(to: lhs) < distance(to: rhs)
        }
    }

    var beaconActionTitle: String {
        activeBeacon == nil ? "Broadcast Report" : "Update Active Report"
    }

    var canActivateBeacon: Bool {
        canUseBeaconMode && (currentLocation != nil || activeBeacon != nil)
    }

    var beaconAvailabilityMessage: String? {
        if isStealthModeEnabled {
            return "Stealth Mode is active. RediM8 is receive-only, so community report broadcasting is paused."
        }
        if isAnonymousModeEnabled {
            return "Anonymous Mode is active. RediM8 will receive nearby updates but will not broadcast from this device."
        }
        if !settings.signalDiscovery.allowsBeaconBroadcasts {
            return "Enable Community Reports in Settings before broadcasting a report."
        }
        if settings.privacy.locationShareMode == .off {
            return "Enable approximate or precise location sharing before broadcasting a report."
        }
        if currentLocation == nil && activeBeacon == nil {
            return "Location is required before this device can start a report."
        }
        return nil
    }

    var composeAvailabilityMessage: String? {
        if isStealthModeEnabled {
            return "Stealth Mode is active. Outgoing messages, invites, and location sharing are paused while scanning drops to low frequency."
        }
        if isAnonymousModeEnabled {
            return "Anonymous Mode is active. Outgoing alerts and name sharing are paused."
        }
        if settings.privacy.locationShareMode == .off {
            return "Location sharing is off. Broadcast alerts still work, but location sharing is disabled."
        }
        return nil
    }

    var signalTrustItems: [TrustPillItem] {
        [
            TrustPillItem(title: "Assistive only", tone: .caution),
            TrustPillItem(title: likelyRangeLabel, tone: .info),
            TrustPillItem(title: "Reports relay while fresh", tone: .info),
            TrustPillItem(title: "Delivery not guaranteed", tone: .danger),
            TrustPillItem(title: "Bluetooth + Wi-Fi", tone: .neutral)
        ]
    }

    var statusItems: [OperationalStatusItem] {
        [
            OperationalStatusItem(
                iconName: "signal",
                label: "Mesh",
                value: meshStatusLabel,
                tone: meshStatusTone
            ),
            OperationalStatusItem(
                iconName: "signal",
                label: "Broadcasts",
                value: canBroadcastOutboundSignals ? "Available" : "Receive-only",
                tone: canBroadcastOutboundSignals ? meshStatusTone : .caution
            ),
            OperationalStatusItem(
                iconName: "family",
                label: "Nearby",
                value: nearbyPeerSummary,
                tone: nearbyPeers.isEmpty ? .neutral : (connectedPeers.isEmpty ? .caution : .info)
            ),
            OperationalStatusItem(
                iconName: "clock",
                label: "Last Signal",
                value: lastSignalLabel,
                tone: sessionMessages.isEmpty ? .neutral : meshStatusTone
            ),
            OperationalStatusItem(
                iconName: "map_marker",
                label: "Location",
                value: locationPrecisionLabel,
                tone: settings.privacy.locationShareMode == .off ? .caution : .info
            ),
            OperationalStatusItem(
                iconName: "compass",
                label: "Range",
                value: likelyRangeLabel,
                tone: .info
            ),
            OperationalStatusItem(
                iconName: "arrow.triangle.branch",
                label: "Relay",
                value: relayStatusSummary,
                tone: beaconService.relayQueueCount > 0 ? .info : .neutral
            )
        ]
    }

    private var meshStatusState: MeshStatusState {
        if let activeBeacon, (activeBeacon.type.tone == .help || activeBeacon.type.tone == .hazard) {
            return .emergencyBroadcast(type: activeBeacon.type)
        }

        if !connectedPeers.isEmpty || beaconService.relayQueueCount > 0 || nearbyPeers.count > 3 {
            return .networkForming(count: max(connectedPeers.count, nearbyPeers.count))
        }

        if !nearbyPeers.isEmpty {
            return .nearbyUsers(count: nearbyPeers.count)
        }

        return .noNearbyUsers
    }

    var meshStatusLabel: String {
        meshStatusState.label
    }

    var meshStatusHeadline: String {
        switch meshStatusState {
        case .noNearbyUsers:
            return "No nearby RediM8 users"
        case let .nearbyUsers(count):
            let noun = count == 1 ? "user" : "users"
            return "\(count) nearby \(noun) detected"
        case let .networkForming(count):
            if connectedPeers.isEmpty {
                let noun = count == 1 ? "user" : "users"
                return "Network forming around \(count) nearby \(noun)"
            }

            let noun = connectedPeers.count == 1 ? "link" : "links"
            return "\(connectedPeers.count) mesh \(noun) active"
        case let .emergencyBroadcast(type):
            return "\(type.title) report is broadcasting"
        }
    }

    var meshStatusDetail: String {
        switch meshStatusState {
        case .noNearbyUsers:
            if beaconService.relayQueueCount > 0 {
                let noun = beaconService.relayQueueCount == 1 ? "report" : "reports"
                return "\(beaconService.relayQueueCount) stored \(noun) will carry forward when another user comes within likely short range."
            }
            return "Move within likely short range of another user and keep Bluetooth + Wi-Fi on."
        case .nearbyUsers:
            if beaconService.relayQueueCount > 0 {
                return "Move closer and keep the app open. Stored reports will forward when a connection opens."
            }
            return "Nearby users are in range, but a link has not opened yet. Keep Signal visible and messages brief."
        case .networkForming:
            if beaconService.relayQueueCount > 0 {
                return "Short messages are available now. Stored reports can keep moving while they stay fresh."
            }

            return "The mesh is beginning to hold. Use short updates, keep the app open, and assume delivery can still fail."
        case let .emergencyBroadcast(type):
            return "\(type.title) is live on this device. Nearby users should treat it as urgent and relay it while it stays fresh."
        }
    }

    var meshStatusTone: OperationalStatusTone {
        meshStatusState.tone
    }

    var workingBroadcastSummary: String {
        if isStealthModeEnabled {
            return "Receive-only"
        }

        if isAnonymousModeEnabled {
            return "Receive-only"
        }

        return "Alerts + direct messages available"
    }

    var nearbyPeerSummary: String {
        nearbyPeers.isEmpty ? "None detected" : "\(nearbyPeers.count) nearby"
    }

    var connectedPeerSummary: String {
        connectedPeers.isEmpty ? "None connected" : "\(connectedPeers.count) connected"
    }

    var lastSignalLabel: String {
        guard let timestamp = sessionMessages.first?.timestamp else {
            return "No signal yet"
        }

        let now = Date()
        if abs(timestamp.timeIntervalSince(now)) < 90 {
            return "Just now"
        }

        return RelativeDateTimeFormatter.rediM8Short.localizedString(for: timestamp, relativeTo: now)
    }

    var lastSignalSummary: String {
        guard let timestamp = sessionMessages.first?.timestamp else {
            return "No local alerts, direct messages, or mesh status events have been seen in this session yet."
        }

        return "Last signal seen \(RelativeDateTimeFormatter.rediM8Short.localizedString(for: timestamp, relativeTo: .now))."
    }

    var workingLocationSummary: String {
        switch settings.privacy.locationShareMode {
        case .off:
            "Off"
        case .approximate:
            "Approximate sharing"
        case .precise:
            "Precise sharing"
        }
    }

    var likelyRangeLabel: String {
        switch settings.signalDiscovery.rangeMode {
        case .lowPower:
            "Near only"
        case .balanced:
            "100-200 m typical"
        case .maximumRange:
            "Best-case short range"
        }
    }

    var workingRangeSummary: String {
        switch settings.signalDiscovery.rangeMode {
        case .lowPower:
            "Very close range"
        case .balanced:
            "100-200 m typical"
        case .maximumRange:
            "Best-case short range"
        }
    }

    var workingConstraintSummary: String {
        "Needs nearby RediM8 users, Bluetooth, Wi-Fi, and battery."
    }

    var rangeLevelTitle: String {
        switch settings.signalDiscovery.rangeMode {
        case .lowPower:
            "Near"
        case .balanced:
            "Medium"
        case .maximumRange:
            "Far"
        }
    }

    var rangeMeterFillCount: Int {
        switch settings.signalDiscovery.rangeMode {
        case .lowPower:
            2
        case .balanced:
            3
        case .maximumRange:
            5
        }
    }

    var rangeMeterSegmentCount: Int {
        5
    }

    var userFacingDeviceID: String {
        localNodeLabel.replacingOccurrences(of: "Node ", with: "")
    }

    var visibleDeviceName: String? {
        let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != localNodeLabel else {
            return nil
        }
        return trimmed
    }

    var messageAvailabilitySummary: String {
        connectedPeers.isEmpty ? "Not available" : "Available"
    }

    var relayStatusSummary: String {
        let relayCount = beaconService.relayQueueCount
        let relayedCount = beaconService.relayedBeaconCount

        if relayCount > 0 {
            let noun = relayCount == 1 ? "report" : "reports"
            return "\(relayCount) queued \(noun)"
        }

        if relayedCount > 0 {
            let noun = relayedCount == 1 ? "report" : "reports"
            return "Receiving \(relayedCount) relayed \(noun)"
        }

        return "No relay queue"
    }

    var sharingModeSummary: String {
        if isStealthModeEnabled {
            return "Hidden / receive-only"
        }
        if isAnonymousModeEnabled {
            return "Anonymous / receive-only"
        }
        return "Standard sharing"
    }

    var beaconRefreshSummary: String {
        "Active reports refresh about every \(Int(settings.signalDiscovery.rangeMode.beaconBroadcastInterval)) seconds while this device can still transmit."
    }

    var situationReportTypes: [BeaconType] {
        BeaconType.allCases.filter(\.isSituationReport)
    }

    var secondaryBeaconTypes: [BeaconType] {
        BeaconType.allCases.filter { !$0.isSituationReport }
    }

    var selectedReportLifetimeSummary: String {
        selectedBeaconType.lifetimeSummary
    }

    var selectedReportLocationPrompt: String {
        selectedBeaconType.locationPrompt
    }

    var selectedReportMessagePrompt: String {
        selectedBeaconType.notePrompt
    }

    var draftBeaconTrustItems: [TrustPillItem] {
        var items = [
            TrustPillItem(title: locationPrecisionLabel, tone: settings.privacy.locationShareMode == .precise ? .info : .caution),
            TrustPillItem(title: "Community report", tone: .caution),
            TrustPillItem(title: "Can relay while fresh", tone: .info),
            TrustPillItem(title: selectedBeaconType.expiryBadgeTitle, tone: .neutral),
            TrustPillItem(title: "Delivery not guaranteed", tone: .danger)
        ]
        if includesEmergencyMedicalInfo, selectedBeaconType.supportsEmergencyMedicalDisclosure {
            items.insert(TrustPillItem(title: "Medical note shared", tone: .info), at: 2)
        }
        return items
    }

    func activeBeaconTrustItems(for beacon: CommunityBeacon) -> [TrustPillItem] {
        var items = [
            TrustPillItem(title: "This device", tone: .verified),
            TrustPillItem(title: locationPrecisionLabel, tone: settings.privacy.locationShareMode == .precise ? .info : .caution),
            TrustPillItem(title: "Can relay while fresh", tone: .info),
            TrustPillItem(title: beacon.type.expiryBadgeTitle, tone: .neutral),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: beacon.updatedAt), tone: .neutral)
        ]
        if beacon.sharedEmergencyMedicalSummary != nil {
            items.insert(TrustPillItem(title: "Medical note shared", tone: .info), at: 2)
        }
        return items
    }

    func beaconTrustItems(for beacon: CommunityBeacon) -> [TrustPillItem] {
        var items = [
            TrustPillItem(title: "Community-reported", tone: .caution),
            TrustPillItem(title: "Not verified", tone: .danger),
            TrustPillItem(title: beacon.relayTrustLabel, tone: beacon.isRelayed ? .caution : .info),
            TrustPillItem(title: "Approximate", tone: .caution),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: beacon.updatedAt), tone: .neutral)
        ]
        if beacon.sharedEmergencyMedicalSummary != nil {
            items.insert(TrustPillItem(title: "Medical note shared", tone: .info), at: 3)
        }
        return items
    }

    func beaconStaleWarning(for beacon: CommunityBeacon) -> String? {
        guard Date().timeIntervalSince(beacon.updatedAt) >= beacon.type.staleAfter else {
            return nil
        }

        return "Stale report. Treat this as last known information until you confirm it."
    }

    private var locationPrecisionLabel: String {
        switch settings.privacy.locationShareMode {
        case .off:
            "Location off"
        case .approximate:
            "Approximate location"
        case .precise:
            "Precise location"
        }
    }

    func onAppear() {
        beaconService.startMonitoring()
    }

    func onDisappear() {
        beaconService.stopMonitoring()
    }

    func connect(to peer: MCPeerID) {
        guard canInitiateConnections else {
            beaconNotice = BeaconNotice(
                title: "Stealth Mode Active",
                message: "Stealth Mode keeps this device receive-only, so new mesh connections cannot be started."
            )
            return
        }
        meshService.invite(peer)
    }

    func sendDirect(to peer: MCPeerID) {
        guard canBroadcastOutboundSignals else {
            beaconNotice = BeaconNotice(
                title: isStealthModeEnabled ? "Stealth Mode Active" : "Hidden Mode Active",
                message: isStealthModeEnabled ? "Stealth Mode blocks outgoing messages from this device." : "Anonymous Mode blocks outgoing messages from this device."
            )
            return
        }
        let text = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        meshService.sendDirect(text, to: peer)
        draftMessage = ""
    }

    func broadcastAlert() {
        guard canBroadcastOutboundSignals else {
            beaconNotice = BeaconNotice(
                title: isStealthModeEnabled ? "Stealth Mode Active" : "Hidden Mode Active",
                message: isStealthModeEnabled ? "Disable Stealth Mode before broadcasting an alert." : "Disable Anonymous Mode before broadcasting an alert."
            )
            return
        }
        let text = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        meshService.broadcastAlert(text)
        draftMessage = ""
    }

    func shareLocation() {
        guard canShareLocation else {
            beaconNotice = BeaconNotice(
                title: "Location Sharing Disabled",
                message: "Enable approximate or precise location sharing in Settings before sending your position."
            )
            return
        }
        guard let coordinate = locationService.currentLocation?.coordinate else { return }
        meshService.shareLocation(coordinate, label: "Shared location")
    }

    func toggleResource(_ resource: BeaconResource) {
        if selectedResources.contains(resource) {
            selectedResources.remove(resource)
        } else {
            selectedResources.insert(resource)
        }
    }

    func selectSituationReport(_ type: BeaconType) {
        selectedBeaconType = type
        selectedResources = Set(type.defaultResources)
        if beaconStatusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || beaconStatusText == type.defaultStatusText {
            beaconStatusText = type.defaultStatusText
        }
    }

    func activateBeacon() {
        guard canUseBeaconMode else {
            beaconNotice = BeaconNotice(
                title: "Report Unavailable",
                message: beaconAvailabilityMessage ?? "Community reports are unavailable with the current privacy settings."
            )
            return
        }
        do {
            let beacon = try beaconService.activateBeacon(
                type: selectedBeaconType,
                statusText: beaconStatusText,
                message: beaconMessage,
                locationName: beaconLocationName,
                resources: selectedResources,
                showsName: showsName,
                displayName: displayName,
                emergencyMedicalSummary: emergencyMedicalBroadcastPreview
            )
            syncDraft(from: beacon)
            beaconNotice = BeaconNotice(
                title: "Report Active",
                message: beacon.sharedEmergencyMedicalSummary == nil
                    ? "\(beacon.type.title) is now being shared from \(beacon.displayLabel)."
                    : "\(beacon.type.title) is now being shared from \(beacon.displayLabel) with the emergency medical note you chose to include."
            )
        } catch {
            beaconNotice = BeaconNotice(
                title: "Report Unavailable",
                message: error.localizedDescription
            )
        }
    }

    func refreshBeacon() {
        guard canUseBeaconMode else {
            beaconNotice = BeaconNotice(
                title: "Report Unavailable",
                message: beaconAvailabilityMessage ?? "Community reports are unavailable with the current privacy settings."
            )
            return
        }
        beaconService.refreshActiveBeacon()
        if let activeBeacon {
            beaconNotice = BeaconNotice(
                title: "Report Refreshed",
                message: "\(activeBeacon.type.title) refreshed. \(activeBeacon.type.lifetimeSummary)"
            )
        }
    }

    func deactivateBeacon() {
        beaconService.deactivateActiveBeacon()
        beaconNotice = BeaconNotice(
            title: "Report Disabled",
            message: "This device has stopped sharing its community situation report."
        )
    }

    func beaconDistanceText(for beacon: CommunityBeacon) -> String {
        beaconService.distanceText(for: beacon)
    }

    func clearSession() {
        meshService.clearSessionMessages()
    }

    private func syncDraft(from beacon: CommunityBeacon) {
        selectedBeaconType = beacon.type
        beaconStatusText = beacon.statusText
        beaconMessage = beacon.message
        beaconLocationName = beacon.locationName
        selectedResources = Set(beacon.resources)
        showsName = settings.privacy.showsDeviceName && !isStealthModeEnabled && beacon.showsName
        displayName = beacon.displayName ?? (isStealthModeEnabled ? appState.stealthModeNodeLabel : (settings.privacy.showsDeviceName ? String(UIDevice.current.name.prefix(20)) : beaconService.localNodeLabel))
        includesEmergencyMedicalInfo = beacon.sharedEmergencyMedicalSummary != nil
    }

    private func distance(to beacon: CommunityBeacon) -> CLLocationDistance {
        guard let currentLocation else {
            return .greatestFiniteMagnitude
        }

        let target = CLLocation(latitude: beacon.latitude, longitude: beacon.longitude)
        return currentLocation.distance(from: target)
    }
}
