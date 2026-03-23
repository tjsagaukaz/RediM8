import Combine
import CoreBluetooth
import CoreLocation
import CoreMotion
import Foundation
import Network
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
            return "No connection"
        case let .nearbyUsers(count):
            let noun = count == 1 ? "user" : "users"
            return "\(count) \(noun) nearby"
        case .networkForming:
            return "Mesh active"
        case .emergencyBroadcast:
            return "Broadcast live"
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
            resetStructuredSignalDraft(for: selectedBeaconType)
        }
    }
    @Published var beaconStatusText = BeaconType.safeLocation.defaultStatusText
    @Published var beaconMessage = ""
    @Published var beaconLocationName = ""
    @Published var selectedResources = Set<BeaconResource>()
    @Published var showsName = false
    @Published var displayName = ""
    @Published var includesEmergencyMedicalInfo = false
    @Published var selectedSeverity = BeaconType.safeLocation.defaultSeverity
    @Published var selectedConfidence = BeaconType.safeLocation.defaultConfidence
    @Published var directionHint = ""
    @Published var selectedRouteCondition = BeaconRouteCondition.blocked
    @Published var selectedWaterSafety = BeaconWaterSafety.unknown
    @Published var selectedShelterStatus = BeaconShelterStatus.unknown
    @Published var shelterCapacityNote = ""
    @Published var batteryLevelText = ""
    @Published var newAccountabilityMemberName = ""
    @Published var isShowingAnalogSignalMode = false
    @Published var beaconNotice: BeaconNotice?
    @Published private(set) var settings: AppSettings
    @Published private(set) var profile: UserProfile
    @Published private(set) var nearbyPeers: [MeshPeer] = []
    @Published private(set) var connectedPeers: [MeshPeer] = []
    @Published private(set) var sessionMessages: [MeshMessage] = []
    @Published private(set) var activeBeacon: CommunityBeacon?
    @Published private(set) var nearbyBeacons: [CommunityBeacon] = []
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var isStealthModeEnabled = false
    @Published private(set) var scannerSnapshot: SituationalScannerSnapshot = .inactive
    @Published private(set) var lastError: AppError?
    @Published private(set) var systemState: SystemState = .healthy

    private let appState: AppState
    private let meshService: MeshService
    private let beaconService: BeaconService
    private let locationService: LocationService
    private let analogSignalService: AnalogSignalService
    private let scannerService: SituationalScannerService
    private var cancellables = Set<AnyCancellable>()
    private var processedAccountabilityMessageIDs = Set<UUID>()

    init(appState: AppState) {
        self.appState = appState
        meshService = appState.meshService
        beaconService = appState.beaconService
        locationService = appState.locationService
        analogSignalService = AnalogSignalService(torchService: appState.torchService)
        scannerService = SituationalScannerService(
            locationService: appState.locationService,
            batteryService: appState.batteryService
        )
        settings = appState.settings
        profile = appState.profile
        isStealthModeEnabled = appState.isStealthModeEnabled
        displayName = appState.isStealthModeEnabled
            ? appState.stealthModeNodeLabel
            : (appState.settings.privacy.showsDeviceName ? String(UIDevice.current.name.prefix(20)) : appState.beaconService.localNodeLabel)
        activeBeacon = appState.beaconService.activeBeacon
        if let activeBeacon {
            syncDraft(from: activeBeacon)
        } else {
            resetStructuredSignalDraft(for: selectedBeaconType)
        }

        meshService.$nearbyPeers
            .assign(to: &$nearbyPeers)

        meshService.$connectedPeers
            .assign(to: &$connectedPeers)

        meshService.$sessionMessages
            .sink { [weak self] messages in
                guard let self else { return }
                self.sessionMessages = messages
                self.ingestAccountabilityMessages(messages)
            }
            .store(in: &cancellables)

        beaconService.$activeBeacon
            .sink { [weak self] beacon in
                self?.activeBeacon = beacon
            }
            .store(in: &cancellables)

        beaconService.$nearbyBeacons
            .assign(to: &$nearbyBeacons)

        locationService.$currentLocation
            .assign(to: &$currentLocation)

        analogSignalService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        scannerService.$snapshot
            .assign(to: &$scannerSnapshot)

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

        seedAccountabilityCircleIfNeeded()

        // Reactively compute system state from mesh + location
        meshService.$connectedPeers
            .combineLatest(locationService.$currentLocation)
            .sink { [weak self] peers, location in
                guard let self else { return }
                self.recalculateSystemState(connectedPeers: peers, location: location)
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

    var isProUser: Bool {
        appState.isProUser
    }

    var requiresProForMeshSend: Bool {
        !ProFeatureGate.allowsMeshSend(isProUser: isProUser)
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

    var analogSignalSummary: String {
        if analogSignalService.isActive {
            return "\(analogSignalService.selectedPattern.title) signal is live with screen beacon and local rescue card."
        }

        return "Flashlight, screen, sound, vibration, and rescue details still work with zero network."
    }

    var scannerSummary: String {
        if let alert = scannerSnapshot.alerts.first {
            return alert.detail
        }

        return scannerSnapshot.summary
    }

    var scannerHeadline: String {
        scannerSnapshot.headline
    }

    var scannerStatusLabel: String {
        scannerSnapshot.statusLabel
    }

    var scannerAlerts: [SituationalScannerAlert] {
        scannerSnapshot.alerts
    }

    var scannerTone: OperationalStatusTone {
        scannerSnapshot.tone
    }

    var accountabilityCircle: AccountabilityCircle {
        Self.synchronizedAccountabilityCircle(
            profile.accountabilityCircle,
            with: profile,
            fallbackLocalName: fallbackAccountabilityLocalName
        )
    }

    var accountabilityMembers: [AccountabilityMember] {
        accountabilityCircle.members.sorted { lhs, rhs in
            if lhs.source == .selfUser, rhs.source != .selfUser {
                return true
            }
            if rhs.source == .selfUser, lhs.source != .selfUser {
                return false
            }
            if lhs.status.sortPriority != rhs.status.sortPriority {
                return lhs.status.sortPriority < rhs.status.sortPriority
            }
            if lhs.updatedAt != rhs.updatedAt {
                return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var accountabilitySelfMember: AccountabilityMember? {
        accountabilityCircle.members.first(where: { $0.source == .selfUser })
    }

    var accountabilitySummary: String {
        if accountabilityMembers.isEmpty {
            return "Build a local roll call even before any mesh links appear."
        }

        let counts = Dictionary(grouping: accountabilityCircle.members, by: \.status).mapValues(\.count)
        let ordered: [AccountabilityStatus] = [.safe, .checkingIn, .needHelp, .injured, .unknown]
        let summary = ordered.compactMap { status -> String? in
            guard let count = counts[status], count > 0 else { return nil }
            return "\(count) \(status.title.lowercased())"
        }

        return summary.joined(separator: " • ")
    }

    var accountabilityHeadline: String {
        accountabilityCircle.title
    }

    var accountabilityCoverageSummary: String {
        let total = accountabilityCircle.members.count
        guard total > 0 else {
            return "No roster yet"
        }
        return "\(accountabilityCircle.checkedInCount)/\(total) checked in"
    }

    var accountabilityStatusButtons: [AccountabilityStatus] {
        [.safe, .checkingIn, .needHelp]
    }

    var canBroadcastAccountabilityStatus: Bool {
        canBroadcastOutboundSignals && !connectedPeers.isEmpty
    }

    var analogSignalButtonTitle: String {
        analogSignalService.isActive ? "Resume Analog Signal" : "Activate Analog Signal"
    }

    var analogSignalButtonDetail: String {
        analogSignalService.isActive
            ? "\(analogSignalService.selectedPattern.title) beacon active"
            : "No internet or nearby users required"
    }

    var analogSignalStatus: String {
        analogSignalService.isActive ? "Live" : "Ready"
    }

    var analogSignalPattern: AnalogSignalPattern {
        analogSignalService.selectedPattern
    }

    var analogSignalPulseInterval: AnalogSignalPulseInterval {
        analogSignalService.pulseInterval
    }

    var isAnalogSignalActive: Bool {
        analogSignalService.isActive
    }

    var isAnalogTorchPatternEnabled: Bool {
        analogSignalService.isTorchPatternEnabled
    }

    var isAnalogAudiblePingEnabled: Bool {
        analogSignalService.isAudiblePingEnabled
    }

    var isAnalogVibrationPingEnabled: Bool {
        analogSignalService.isVibrationPingEnabled
    }

    var isAnalogTorchAvailable: Bool {
        analogSignalService.isTorchAvailable
    }

    var analogSignalLastErrorMessage: String? {
        analogSignalService.lastErrorMessage
    }

    var analogRescueSnapshot: AnalogRescueSnapshot {
        AnalogRescueSnapshot(
            profile: profile,
            fallbackOwnerName: String(UIDevice.current.name.prefix(24)),
            location: currentLocation
        )
    }

    var displayedBeacons: [CommunityBeacon] {
        nearbyBeacons.sorted { lhs, rhs in
            if lhs.type.priority != rhs.type.priority {
                return lhs.type.priority < rhs.type.priority
            }
            if lhs.severity.rank != rhs.severity.rank {
                return lhs.severity.rank > rhs.severity.rank
            }

            return distance(to: lhs) < distance(to: rhs)
        }
    }

    var beaconActionTitle: String {
        activeBeacon == nil ? "Broadcast Alert" : "Update Broadcast"
    }

    var canActivateBeacon: Bool {
        canUseBeaconMode && (currentLocation != nil || activeBeacon != nil)
    }

    var beaconAvailabilityMessage: String? {
        if isStealthModeEnabled {
            return "Stealth Mode is active. RediM8 is receive-only, so community report broadcasting is paused."
        }
        if isAnonymousModeEnabled {
            return "Hidden Mode is active. RediM8 will receive nearby updates but will not broadcast from this device."
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
            return "Hidden Mode is active. Outgoing alerts and name sharing are paused."
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
                label: "Broadcast",
                value: canBroadcastOutboundSignals ? "Ready" : "Receive-only",
                tone: canBroadcastOutboundSignals ? .danger : .caution
            ),
            OperationalStatusItem(
                iconName: "family",
                label: "Nearby Users",
                value: nearbyPeerSummary,
                tone: nearbyPeers.isEmpty ? .neutral : (connectedPeers.isEmpty ? .caution : .info)
            ),
            OperationalStatusItem(
                iconName: "clock",
                label: "Last Activity",
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
            return "No mesh connection"
        case let .nearbyUsers(count):
            let noun = count == 1 ? "user" : "users"
            return "\(count) nearby \(noun) detected"
        case let .networkForming(count):
            if connectedPeers.isEmpty {
                let noun = count == 1 ? "device" : "devices"
                return "Mesh link pending with \(count) nearby \(noun)"
            }

            let noun = connectedPeers.count == 1 ? "link" : "links"
            return "\(connectedPeers.count) mesh \(noun) active"
        case let .emergencyBroadcast(type):
            return "\(type.title) broadcast live"
        }
    }

    var meshStatusDetail: String {
        switch meshStatusState {
        case .noNearbyUsers:
            if beaconService.relayQueueCount > 0 {
                let noun = beaconService.relayQueueCount == 1 ? "report" : "reports"
                return "No nearby devices detected. \(beaconService.relayQueueCount) stored \(noun) will carry forward once another device comes within likely short range."
            }
            return "No nearby devices detected. Move closer to others or use broadcast."
        case .nearbyUsers:
            if beaconService.relayQueueCount > 0 {
                return "Nearby devices are visible, but no link is open yet. Move closer and keep Signal active so stored reports can forward."
            }
            return "Nearby devices are in range, but no link is open yet. Keep Signal visible and transmissions brief."
        case .networkForming:
            if beaconService.relayQueueCount > 0 {
                return "Mesh links are active. Use short transmissions and allow fresh reports to relay while they remain current."
            }

            return "A local mesh link is active. Use short transmissions, keep the app open, and assume delivery can still fail."
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
        if nearbyPeers.isEmpty {
            return "No users nearby"
        }

        let noun = nearbyPeers.count == 1 ? "user" : "users"
        return "\(nearbyPeers.count) \(noun) nearby"
    }

    var connectedPeerSummary: String {
        if connectedPeers.isEmpty {
            return "No links active"
        }

        let noun = connectedPeers.count == 1 ? "link" : "links"
        return "\(connectedPeers.count) \(noun) active"
    }

    var lastSignalLabel: String {
        guard let timestamp = sessionMessages.first?.timestamp else {
            return "No activity"
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

        return "No relay queued"
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
            TrustPillItem(title: selectedSeverity.badgeTitle, tone: tone(for: selectedSeverity)),
            TrustPillItem(title: selectedConfidence.badgeTitle, tone: tone(for: selectedConfidence)),
            TrustPillItem(title: "Can relay while fresh", tone: .info),
            TrustPillItem(title: selectedBeaconType.expiryBadgeTitle, tone: .neutral),
            TrustPillItem(title: "Delivery not guaranteed", tone: .danger)
        ]
        if includesEmergencyMedicalInfo, selectedBeaconType.supportsEmergencyMedicalDisclosure {
            items.insert(TrustPillItem(title: "Medical note shared", tone: .info), at: 3)
        }
        return items
    }

    func activeBeaconTrustItems(for beacon: CommunityBeacon) -> [TrustPillItem] {
        var items = [
            TrustPillItem(title: "This device", tone: .verified),
            TrustPillItem(title: beacon.severity.badgeTitle, tone: tone(for: beacon.severity)),
            TrustPillItem(title: beacon.confidence.badgeTitle, tone: tone(for: beacon.confidence)),
            TrustPillItem(title: "Can relay while fresh", tone: .info),
            TrustPillItem(title: beacon.type.expiryBadgeTitle, tone: .neutral),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: beacon.updatedAt), tone: .neutral)
        ]
        if beacon.sharedEmergencyMedicalSummary != nil {
            items.insert(TrustPillItem(title: "Medical note shared", tone: .info), at: 3)
        }
        return items
    }

    func beaconTrustItems(for beacon: CommunityBeacon) -> [TrustPillItem] {
        var items = [
            TrustPillItem(title: "Community-reported", tone: .caution),
            TrustPillItem(title: beacon.severity.badgeTitle, tone: tone(for: beacon.severity)),
            TrustPillItem(title: beacon.confidence.badgeTitle, tone: tone(for: beacon.confidence)),
            TrustPillItem(title: beacon.relayTrustLabel, tone: beacon.isRelayed ? .caution : .info),
            TrustPillItem(title: "Approximate", tone: .caution),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: beacon.updatedAt), tone: .neutral)
        ]
        if beacon.sharedEmergencyMedicalSummary != nil {
            items.insert(TrustPillItem(title: "Medical note shared", tone: .info), at: 4)
        }
        return items
    }

    var selectedSignalHighlights: [(label: String, value: String)] {
        draftSignalMetadata.highlights(for: selectedBeaconType)
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

    private func recalculateSystemState(connectedPeers: [MeshPeer], location: CLLocation?) {
        var reasons: [String] = []

        if connectedPeers.isEmpty && nearbyPeers.isEmpty {
            reasons.append("No mesh peers detected")
        }
        if location == nil {
            reasons.append("Location unavailable")
        }
        if let errorMessage = analogSignalService.lastErrorMessage {
            reasons.append("Signal: \(errorMessage)")
        }

        if reasons.isEmpty {
            systemState = .healthy
            lastError = nil
        } else if connectedPeers.isEmpty && nearbyPeers.isEmpty && location == nil {
            systemState = .unavailable(reason: reasons.joined(separator: ". "))
            lastError = .serviceUnavailable(service: "Mesh network and location")
        } else {
            let combined = reasons.joined(separator: ". ")
            systemState = .degraded(reason: combined)
            lastError = .serviceUnavailable(service: combined)
        }
    }

    func onAppear() {
        seedAccountabilityCircleIfNeeded()
        beaconService.startMonitoring()
        scannerService.startMonitoring()
    }

    func onDisappear() {
        scannerService.stopMonitoring()
        beaconService.stopMonitoring()
    }

    func connect(to peer: MeshPeer) {
        guard canInitiateConnections else {
            beaconNotice = BeaconNotice(
                title: "Stealth Mode Active",
                message: "Stealth Mode keeps this device receive-only, so new mesh connections cannot be started."
            )
            return
        }
        meshService.invite(peer)
    }

    func sendDirect(to peer: MeshPeer) {
        guard !requiresProForMeshSend else {
            beaconNotice = BeaconNotice(
                title: ProFeatureGate.paywallTitle(for: .meshSend),
                message: ProFeatureGate.paywallSubtitle(for: .meshSend)
            )
            return
        }
        guard canBroadcastOutboundSignals else {
            beaconNotice = BeaconNotice(
                title: isStealthModeEnabled ? "Stealth Mode Active" : "Hidden Mode Active",
                message: isStealthModeEnabled ? "Stealth Mode blocks outgoing messages from this device." : "Hidden Mode blocks outgoing messages from this device."
            )
            return
        }
        let text = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        meshService.sendDirect(text, to: peer)
        draftMessage = ""
    }

    func broadcastAlert() {
        guard !requiresProForMeshSend else {
            beaconNotice = BeaconNotice(
                title: ProFeatureGate.paywallTitle(for: .meshSend),
                message: ProFeatureGate.paywallSubtitle(for: .meshSend)
            )
            return
        }
        guard canBroadcastOutboundSignals else {
            beaconNotice = BeaconNotice(
                title: isStealthModeEnabled ? "Stealth Mode Active" : "Hidden Mode Active",
                message: isStealthModeEnabled ? "Disable Stealth Mode before broadcasting an alert." : "Disable Hidden Mode before broadcasting an alert."
            )
            return
        }
        let text = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        meshService.broadcastAlert(text)
        draftMessage = ""
    }

    func shareLocation() {
        guard !requiresProForMeshSend else {
            beaconNotice = BeaconNotice(
                title: ProFeatureGate.paywallTitle(for: .meshSend),
                message: ProFeatureGate.paywallSubtitle(for: .meshSend)
            )
            return
        }
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

    func applyStructuredQuickSignal(_ template: String) {
        switch template {
        case "Need water":
            selectedBeaconType = .needHelp
            selectedResources = [.water]
            beaconStatusText = BeaconType.needHelp.defaultStatusText
            beaconMessage = "Need water"
            selectedSeverity = .high
            selectedConfidence = .medium
        case "Safe here":
            selectedBeaconType = .safeLocation
            beaconStatusText = BeaconType.safeLocation.defaultStatusText
            beaconMessage = "Safe here"
            selectedSeverity = .low
            selectedConfidence = .high
        case "Fire nearby":
            selectedBeaconType = .fireSpotted
            beaconStatusText = BeaconType.fireSpotted.defaultStatusText
            beaconMessage = "Fire nearby"
            selectedSeverity = .critical
            selectedConfidence = .medium
        case "Need pickup":
            selectedBeaconType = .needHelp
            beaconStatusText = BeaconType.needHelp.defaultStatusText
            beaconMessage = "Need pickup"
            selectedSeverity = .high
            selectedConfidence = .medium
        default:
            break
        }
    }

    func activateBeacon() {
        guard !requiresProForMeshSend else {
            beaconNotice = BeaconNotice(
                title: ProFeatureGate.paywallTitle(for: .meshSend),
                message: ProFeatureGate.paywallSubtitle(for: .meshSend)
            )
            return
        }
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
                emergencyMedicalSummary: emergencyMedicalBroadcastPreview,
                signalMetadata: draftSignalMetadata
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

    func openAnalogSignalMode() {
        analogSignalService.activate()
        isShowingAnalogSignalMode = true
    }

    func closeAnalogSignalMode() {
        analogSignalService.deactivate()
        isShowingAnalogSignalMode = false
    }

    func setAnalogSignalPattern(_ pattern: AnalogSignalPattern) {
        analogSignalService.selectedPattern = pattern
    }

    func setAnalogTorchPatternEnabled(_ isEnabled: Bool) {
        analogSignalService.isTorchPatternEnabled = isEnabled
    }

    func setAnalogAudiblePingEnabled(_ isEnabled: Bool) {
        analogSignalService.isAudiblePingEnabled = isEnabled
    }

    func setAnalogVibrationPingEnabled(_ isEnabled: Bool) {
        analogSignalService.isVibrationPingEnabled = isEnabled
    }

    func setAnalogSignalPulseInterval(_ interval: AnalogSignalPulseInterval) {
        analogSignalService.pulseInterval = interval
    }

    func triggerAnalogManualPing() {
        analogSignalService.triggerManualPing()
    }

    func disableHiddenMode() {
        guard settings.privacy.isAnonymousModeEnabled else { return }

        appState.mutateSettings { settings in
            settings.privacy.isAnonymousModeEnabled = false
        }

        beaconNotice = BeaconNotice(
            title: "Hidden Mode Off",
            message: "Signal can broadcast again on this device."
        )
    }

    func setAccountabilityCircleTitle(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmed.isEmpty ? "Household Status" : trimmed
        appState.mutateProfile { profile in
            var circle = Self.synchronizedAccountabilityCircle(
                profile.accountabilityCircle,
                with: profile,
                fallbackLocalName: fallbackAccountabilityLocalName
            )
            circle.title = resolvedTitle
            profile.accountabilityCircle = circle
        }
    }

    func addAccountabilityMember() {
        let trimmed = newAccountabilityMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appState.mutateProfile { profile in
            var circle = Self.synchronizedAccountabilityCircle(
                profile.accountabilityCircle,
                with: profile,
                fallbackLocalName: fallbackAccountabilityLocalName
            )
            circle.members.append(
                AccountabilityMember(
                    name: trimmed,
                    status: .unknown,
                    source: .custom,
                    lastCheckInMethod: .manual
                )
            )
            profile.accountabilityCircle = circle
        }

        newAccountabilityMemberName = ""
    }

    func removeAccountabilityMember(_ memberID: UUID) {
        appState.mutateProfile { profile in
            var circle = Self.synchronizedAccountabilityCircle(
                profile.accountabilityCircle,
                with: profile,
                fallbackLocalName: fallbackAccountabilityLocalName
            )
            circle.members.removeAll { $0.id == memberID && $0.source != .selfUser }
            profile.accountabilityCircle = circle
        }
    }

    func syncAccountabilityRosterFromProfile() {
        appState.mutateProfile { profile in
            profile.accountabilityCircle = Self.synchronizedAccountabilityCircle(
                profile.accountabilityCircle,
                with: profile,
                fallbackLocalName: fallbackAccountabilityLocalName
            )
        }

        beaconNotice = BeaconNotice(
            title: "Roster Synced",
            message: "Household and emergency contacts have been pulled into Accountability Mode."
        )
    }

    func markSelfAccountabilityStatus(_ status: AccountabilityStatus) {
        guard let memberID = accountabilitySelfMember?.id else { return }
        setAccountabilityStatus(status, for: memberID, note: "", source: .local, broadcast: true)
    }

    func setAccountabilityStatus(
        _ status: AccountabilityStatus,
        for memberID: UUID,
        note: String = "",
        source: AccountabilityCheckInMethod = .manual,
        broadcast: Bool = false
    ) {
        var updatedMember: AccountabilityMember?

        appState.mutateProfile { profile in
            var circle = Self.synchronizedAccountabilityCircle(
                profile.accountabilityCircle,
                with: profile,
                fallbackLocalName: fallbackAccountabilityLocalName
            )

            guard let index = circle.members.firstIndex(where: { $0.id == memberID }) else {
                return
            }

            circle.members[index].status = status
            circle.members[index].note = note
            circle.members[index].updatedAt = .now
            circle.members[index].lastCheckInMethod = source
            updatedMember = circle.members[index]
            profile.accountabilityCircle = circle
        }

        guard let updatedMember else { return }

        if broadcast {
            broadcastAccountabilityStatus(for: updatedMember)
        } else {
            beaconNotice = BeaconNotice(
                title: "Status Saved",
                message: "\(updatedMember.name) marked \(updatedMember.status.title.lowercased())."
            )
        }
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
        selectedSeverity = beacon.signalMetadata.severity
        selectedConfidence = beacon.signalMetadata.confidence
        directionHint = beacon.signalMetadata.directionHint ?? ""
        selectedRouteCondition = beacon.signalMetadata.routeCondition ?? .blocked
        selectedWaterSafety = beacon.signalMetadata.waterSafety ?? .unknown
        selectedShelterStatus = beacon.signalMetadata.shelterStatus ?? .unknown
        shelterCapacityNote = beacon.signalMetadata.capacityNote ?? ""
        batteryLevelText = beacon.signalMetadata.batteryLevelPercent.map(String.init) ?? ""
    }

    private func distance(to beacon: CommunityBeacon) -> CLLocationDistance {
        guard let currentLocation else {
            return .greatestFiniteMagnitude
        }

        let target = CLLocation(latitude: beacon.latitude, longitude: beacon.longitude)
        return currentLocation.distance(from: target)
    }

    private var parsedBatteryLevel: Int? {
        let trimmed = batteryLevelText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let level = Int(trimmed), !trimmed.isEmpty else {
            return nil
        }
        return min(max(level, 0), 100)
    }

    private var draftSignalMetadata: BeaconSignalMetadata {
        BeaconSignalMetadata(
            severity: selectedSeverity,
            confidence: selectedConfidence,
            directionHint: selectedBeaconType.supportsDirectionHint ? directionHint : nil,
            routeCondition: selectedBeaconType.supportsRouteCondition ? selectedRouteCondition : nil,
            waterSafety: selectedBeaconType.supportsWaterSafety ? selectedWaterSafety : nil,
            shelterStatus: selectedBeaconType.supportsShelterStatus ? selectedShelterStatus : nil,
            capacityNote: selectedBeaconType.supportsShelterCapacityNote ? shelterCapacityNote : nil,
            batteryLevelPercent: selectedBeaconType.supportsBatteryLevel ? parsedBatteryLevel : nil
        )
    }

    private func resetStructuredSignalDraft(for type: BeaconType) {
        let defaults = type.defaultSignalMetadata
        selectedSeverity = defaults.severity
        selectedConfidence = defaults.confidence
        directionHint = defaults.directionHint ?? ""
        selectedRouteCondition = defaults.routeCondition ?? .blocked
        selectedWaterSafety = defaults.waterSafety ?? .unknown
        selectedShelterStatus = defaults.shelterStatus ?? .unknown
        shelterCapacityNote = defaults.capacityNote ?? ""
        batteryLevelText = defaults.batteryLevelPercent.map(String.init) ?? ""
    }

    private func tone(for severity: BeaconSeverity) -> TrustPillTone {
        switch severity {
        case .low:
            .neutral
        case .moderate:
            .info
        case .high:
            .caution
        case .critical:
            .danger
        }
    }

    private func tone(for confidence: BeaconConfidence) -> TrustPillTone {
        switch confidence {
        case .low:
            .danger
        case .medium:
            .caution
        case .high:
            .verified
        }
    }

    private var fallbackAccountabilityLocalName: String {
        profile.primaryFamilyMember?.name.nilIfBlank ?? "You"
    }

    private func seedAccountabilityCircleIfNeeded() {
        guard profile.accountabilityCircle.members.isEmpty else {
            return
        }

        let seededCircle = Self.synchronizedAccountabilityCircle(
            profile.accountabilityCircle,
            with: profile,
            fallbackLocalName: fallbackAccountabilityLocalName
        )

        guard !seededCircle.members.isEmpty else {
            return
        }

        appState.mutateProfile { profile in
            guard profile.accountabilityCircle.members.isEmpty else {
                return
            }
            profile.accountabilityCircle = seededCircle
        }
    }

    private func broadcastAccountabilityStatus(for member: AccountabilityMember) {
        guard !requiresProForMeshSend else {
            beaconNotice = BeaconNotice(
                title: "Saved Locally",
                message: "\(member.name) marked \(member.status.title.lowercased()). Outbound mesh requires RediM8 Pro — the update has been saved on this device."
            )
            return
        }
        guard canBroadcastOutboundSignals else {
            beaconNotice = BeaconNotice(
                title: "Saved Locally",
                message: isStealthModeEnabled
                    ? "\(member.name) marked \(member.status.title.lowercased()). Stealth Mode keeps this device receive-only, so the roll call update stayed on your phone."
                    : "\(member.name) marked \(member.status.title.lowercased()). Hidden Mode keeps this device from broadcasting, so the roll call update stayed on your phone."
            )
            return
        }

        if connectedPeers.isEmpty {
            beaconNotice = BeaconNotice(
                title: "Saved Locally",
                message: "\(member.name) marked \(member.status.title.lowercased()). No nearby mesh links are open yet."
            )
            return
        }

        meshService.broadcastAccountabilityStatus(
            circleTitle: accountabilityCircle.title,
            memberName: member.name,
            status: member.status,
            note: member.note
        )

        beaconNotice = BeaconNotice(
            title: "Status Broadcast",
            message: "\(member.name) marked \(member.status.title.lowercased()) and shared with nearby mesh links."
        )
    }

    private func ingestAccountabilityMessages(_ messages: [MeshMessage]) {
        for message in messages.reversed() {
            guard processedAccountabilityMessageIDs.insert(message.id).inserted else {
                continue
            }
            guard let payload = message.accountabilityStatus, message.kind == .accountabilityStatus else {
                continue
            }
            guard payload.memberName.caseInsensitiveCompare(fallbackAccountabilityLocalName) != .orderedSame else {
                continue
            }
            applyIncomingAccountabilityStatus(payload)
        }
    }

    private func applyIncomingAccountabilityStatus(_ payload: AccountabilityMeshStatus) {
        appState.mutateProfile { profile in
            var circle = Self.synchronizedAccountabilityCircle(
                profile.accountabilityCircle,
                with: profile,
                fallbackLocalName: fallbackAccountabilityLocalName
            )
            let key = Self.accountabilityMemberLookupKey(name: payload.memberName, phone: "")

            if let index = circle.members.firstIndex(where: {
                Self.accountabilityMemberLookupKey(name: $0.name, phone: $0.phone) == key
            }) {
                circle.members[index].status = payload.status
                circle.members[index].note = payload.note
                circle.members[index].updatedAt = payload.updatedAt
                circle.members[index].lastCheckInMethod = .mesh
                if circle.members[index].source == .custom {
                    circle.members[index].source = .mesh
                }
            } else {
                circle.members.append(
                    AccountabilityMember(
                        name: payload.memberName,
                        status: payload.status,
                        note: payload.note,
                        updatedAt: payload.updatedAt,
                        source: .mesh,
                        lastCheckInMethod: .mesh
                    )
                )
            }

            if circle.title == "Household Status", let title = payload.circleTitle.nilIfBlank {
                circle.title = title
            }

            profile.accountabilityCircle = circle
        }
    }

    static func synchronizedAccountabilityCircle(
        _ existingCircle: AccountabilityCircle,
        with profile: UserProfile,
        fallbackLocalName: String
    ) -> AccountabilityCircle {
        var circle = existingCircle
        circle.title = circle.title.nilIfBlank ?? "Household Status"

        let seededMembers = seededAccountabilityMembers(from: profile, fallbackLocalName: fallbackLocalName)

        guard !seededMembers.isEmpty else {
            return circle
        }

        if circle.members.isEmpty {
            circle.members = seededMembers
            return circle
        }

        let existingIndex = Dictionary(
            uniqueKeysWithValues: circle.members.enumerated().map {
                (accountabilityMemberLookupKey(name: $0.element.name, phone: $0.element.phone), $0.offset)
            }
        )

        for member in seededMembers {
            let key = accountabilityMemberLookupKey(name: member.name, phone: member.phone)
            if let index = existingIndex[key] {
                circle.members[index].phone = member.phone
                if circle.members[index].role.nilIfBlank == nil {
                    circle.members[index].role = member.role
                }
                if circle.members[index].source != .mesh {
                    circle.members[index].source = member.source
                }
            } else {
                circle.members.append(member)
            }
        }

        return circle
    }

    static func seededAccountabilityMembers(from profile: UserProfile, fallbackLocalName: String) -> [AccountabilityMember] {
        var members = [AccountabilityMember]()
        let localName = profile.primaryFamilyMember?.name.nilIfBlank ?? fallbackLocalName
        members.append(
            AccountabilityMember(
                name: localName,
                phone: profile.primaryFamilyMember?.phone ?? "",
                role: "This device",
                status: .unknown,
                source: .selfUser,
                lastCheckInMethod: .local
            )
        )

        for familyMember in profile.familyMembers where !familyMember.isPrimaryUser {
            guard let name = familyMember.name.nilIfBlank else { continue }
            members.append(
                AccountabilityMember(
                    name: name,
                    phone: familyMember.phone,
                    role: familyMember.emergencyRole.nilIfBlank ?? "Family",
                    status: .unknown,
                    source: .family
                )
            )
        }

        for contact in profile.emergencyContacts {
            guard let name = contact.name.nilIfBlank else { continue }
            members.append(
                AccountabilityMember(
                    name: name,
                    phone: contact.phone,
                    role: "Emergency contact",
                    status: .unknown,
                    source: .emergencyContact
                )
            )
        }

        var seen = Set<String>()
        return members.compactMap { member in
            let key = accountabilityMemberLookupKey(name: member.name, phone: member.phone)
            guard seen.insert(key).inserted else {
                return nil
            }
            return member
        }
    }

    static func accountabilityMemberLookupKey(name: String, phone: String) -> String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPhone = phone.filter(\.isNumber)
        if normalizedPhone.isEmpty {
            return normalizedName
        }
        return "\(normalizedName)|\(normalizedPhone)"
    }
}

enum ScannerGPSState: Equatable {
    case unavailable
    case approximate
    case locked

    var title: String {
        switch self {
        case .unavailable:
            "Waiting"
        case .approximate:
            "Approx"
        case .locked:
            "OK"
        }
    }

    var detail: String {
        switch self {
        case .unavailable:
            "GPS not locked yet"
        case .approximate:
            "Location is coarse"
        case .locked:
            "GPS fix looks usable"
        }
    }

    var tone: OperationalStatusTone {
        switch self {
        case .unavailable:
            .caution
        case .approximate:
            .info
        case .locked:
            .ready
        }
    }
}

enum ScannerNetworkState: Equatable {
    case offline
    case searching
    case weakCellular
    case cellularAvailable
    case wifiOnly
    case localOnly

    var title: String {
        switch self {
        case .offline:
            "Offline"
        case .searching:
            "Searching"
        case .weakCellular:
            "Weak"
        case .cellularAvailable:
            "Cell OK"
        case .wifiOnly:
            "Wi-Fi"
        case .localOnly:
            "Local"
        }
    }

    var detail: String {
        switch self {
        case .offline:
            "No network path detected"
        case .searching:
            "The phone is still trying to form a path"
        case .weakCellular:
            "Cellular is available but constrained"
        case .cellularAvailable:
            "Cellular path is available"
        case .wifiOnly:
            "Wi-Fi path only right now"
        case .localOnly:
            "Local radios only"
        }
    }

    var tone: OperationalStatusTone {
        switch self {
        case .offline:
            .danger
        case .searching, .weakCellular:
            .caution
        case .cellularAvailable, .wifiOnly, .localOnly:
            .info
        }
    }
}

enum ScannerRadioState: Equatable {
    case unavailable
    case bluetoothOff
    case scanning(Int)

    var title: String {
        switch self {
        case .unavailable:
            return "Unavailable"
        case .bluetoothOff:
            return "Bluetooth Off"
        case let .scanning(count):
            return "\(count)"
        }
    }

    var detail: String {
        switch self {
        case .unavailable:
            return "Passive scan unavailable"
        case .bluetoothOff:
            return "Enable Bluetooth to sense nearby radios"
        case let .scanning(count):
            let noun = count == 1 ? "signal" : "signals"
            return "\(count) nearby Bluetooth \(noun)"
        }
    }

    var tone: OperationalStatusTone {
        switch self {
        case .unavailable:
            return .neutral
        case .bluetoothOff:
            return .caution
        case let .scanning(count):
            return count > 0 ? .info : .neutral
        }
    }
}

enum ScannerPressureTrend: Equatable {
    case unavailable
    case steady
    case falling
    case rising

    var title: String {
        switch self {
        case .unavailable:
            "Unavailable"
        case .steady:
            "Steady"
        case .falling:
            "Falling"
        case .rising:
            "Rising"
        }
    }

    var detail: String {
        switch self {
        case .unavailable:
            "No barometric trend yet"
        case .steady:
            "No strong pressure swing detected"
        case .falling:
            "Pressure is trending downward"
        case .rising:
            "Pressure is trending upward"
        }
    }

    var tone: OperationalStatusTone {
        switch self {
        case .unavailable:
            .neutral
        case .steady, .rising:
            .info
        case .falling:
            .caution
        }
    }
}

enum ScannerPowerState: Equatable {
    case charging
    case full
    case onBattery
    case unknown

    var title: String {
        switch self {
        case .charging:
            "Charging"
        case .full:
            "Full"
        case .onBattery:
            "Battery"
        case .unknown:
            "Unknown"
        }
    }

    var detail: String {
        switch self {
        case .charging:
            "External power connected"
        case .full:
            "Battery is full"
        case .onBattery:
            "Running on battery only"
        case .unknown:
            "Power state unavailable"
        }
    }

    var tone: OperationalStatusTone {
        switch self {
        case .charging, .full:
            .ready
        case .onBattery:
            .info
        case .unknown:
            .neutral
        }
    }
}

struct SituationalScannerAlert: Identifiable, Equatable {
    let title: String
    let detail: String
    let iconName: String
    let tone: OperationalStatusTone

    var id: String {
        "\(title)-\(detail)"
    }
}

struct SituationalScannerSnapshot: Equatable {
    var gpsState: ScannerGPSState
    var networkState: ScannerNetworkState
    var radioState: ScannerRadioState
    var pressureTrend: ScannerPressureTrend
    var powerState: ScannerPowerState
    var batteryStatus: BatteryStatus
    var lastNetworkDropAt: Date?
    var updatedAt: Date

    static let inactive = SituationalScannerSnapshot(
        gpsState: .unavailable,
        networkState: .searching,
        radioState: .unavailable,
        pressureTrend: .unavailable,
        powerState: .unknown,
        batteryStatus: BatteryStatus(level: nil, state: .unknown),
        lastNetworkDropAt: nil,
        updatedAt: .now
    )

    var nearbySignalCount: Int {
        if case let .scanning(count) = radioState {
            return count
        }
        return 0
    }

    var batteryPercentageText: String {
        batteryStatus.percentageText
    }

    var headline: String {
        alerts.first?.title ?? "Local scanner active"
    }

    var summary: String {
        let radioSummary: String
        switch radioState {
        case .unavailable:
            radioSummary = "radio scan unavailable"
        case .bluetoothOff:
            radioSummary = "Bluetooth off"
        case let .scanning(count):
            let noun = count == 1 ? "signal" : "signals"
            radioSummary = "\(count) nearby \(noun)"
        }

        return "GPS \(gpsState.title), network \(networkState.title.lowercased()), \(radioSummary)."
    }

    var statusLabel: String {
        switch tone {
        case .danger:
            "Watch"
        case .caution:
            "Monitor"
        case .info, .ready:
            "Active"
        case .neutral:
            "Idle"
        }
    }

    var tone: OperationalStatusTone {
        if networkState == .offline {
            return .danger
        }
        if batteryStatus.isBelowSurvivalThreshold || pressureTrend == .falling || gpsState == .unavailable {
            return .caution
        }
        if radioState == .bluetoothOff {
            return .caution
        }
        if nearbySignalCount > 0 || networkState == .cellularAvailable {
            return .info
        }
        return .neutral
    }

    var alerts: [SituationalScannerAlert] {
        var items: [SituationalScannerAlert] = []

        if networkState == .offline {
            items.append(
                SituationalScannerAlert(
                    title: lastNetworkDropAt == nil ? "No network path detected" : "Network drop detected",
                    detail: "Operate as if the area may be offline. Keep comms brief and lean on local tools.",
                    iconName: "antenna.radiowaves.left.and.right.slash",
                    tone: .danger
                )
            )
        } else if networkState == .weakCellular {
            items.append(
                SituationalScannerAlert(
                    title: "Cell network looks weak",
                    detail: "Messages may be delayed or fail. Prepare to stay local-first.",
                    iconName: "wifi.exclamationmark",
                    tone: .caution
                )
            )
        }

        if pressureTrend == .falling {
            items.append(
                SituationalScannerAlert(
                    title: "Pressure trend is falling",
                    detail: "Weather conditions may be deteriorating. Treat this as a local cue, not a forecast.",
                    iconName: "barometer",
                    tone: .caution
                )
            )
        }

        if batteryStatus.isBelowSurvivalThreshold && powerState == .onBattery {
            items.append(
                SituationalScannerAlert(
                    title: "Battery reserve is low",
                    detail: "Shorten check-ins and reduce screen time so Signal and maps stay available longer.",
                    iconName: "battery.25",
                    tone: .danger
                )
            )
        }

        if radioState == .bluetoothOff {
            items.append(
                SituationalScannerAlert(
                    title: "Bluetooth scanning is off",
                    detail: "Nearby radio density cannot be sensed until Bluetooth is enabled.",
                    iconName: "bolt.horizontal.circle",
                    tone: .caution
                )
            )
        } else if nearbySignalCount >= 12 {
            items.append(
                SituationalScannerAlert(
                    title: "Nearby radio activity is high",
                    detail: "A dense pocket of nearby devices may mean congestion, sheltering, or movement close by.",
                    iconName: "dot.radiowaves.left.and.right",
                    tone: .info
                )
            )
        }

        if gpsState == .unavailable {
            items.append(
                SituationalScannerAlert(
                    title: "GPS is still acquiring",
                    detail: "Distance labels and location-based guidance will improve once a fix is available.",
                    iconName: "location.slash",
                    tone: .caution
                )
            )
        }

        return Array(items.prefix(3))
    }
}

@MainActor
final class SituationalScannerService: NSObject, ObservableObject {
    @Published private(set) var snapshot: SituationalScannerSnapshot = .inactive

    private struct PressureSample {
        let timestamp: Date
        let kilopascals: Double
    }

    private let locationService: LocationService
    private let batteryService: BatteryService
    private let altimeter = CMAltimeter()
    private let pathMonitorQueue = DispatchQueue(label: "au.com.redim8.signal.scanner.path")

    private var pathMonitor: NWPathMonitor?
    private var bluetoothManager: CBCentralManager?
    private var pruneTicker: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    private var monitorCount = 0
    private var networkState: ScannerNetworkState = .searching
    private var bluetoothState: CBManagerState = .unknown
    private var lastNetworkDropAt: Date?
    private var discoveredPeripheralTimestamps: [UUID: Date] = [:]
    private var pressureSamples: [PressureSample] = []

    init(locationService: LocationService, batteryService: BatteryService) {
        self.locationService = locationService
        self.batteryService = batteryService
        super.init()

        batteryService.$status
            .sink { [weak self] _ in
                self?.refreshSnapshot()
            }
            .store(in: &cancellables)

        locationService.$currentLocation
            .sink { [weak self] _ in
                self?.refreshSnapshot()
            }
            .store(in: &cancellables)

        locationService.$authorizationStatus
            .sink { [weak self] _ in
                self?.refreshSnapshot()
            }
            .store(in: &cancellables)

        refreshSnapshot()
    }

    func startMonitoring() {
        monitorCount += 1
        guard monitorCount == 1 else { return }

        startPathMonitor()
        startBluetoothMonitoring()
        startPressureMonitoring()
        startPruneLoop()
        refreshSnapshot()
    }

    func stopMonitoring() {
        guard monitorCount > 0 else { return }
        monitorCount -= 1
        guard monitorCount == 0 else { return }

        pathMonitor?.cancel()
        pathMonitor = nil

        bluetoothManager?.stopScan()
        discoveredPeripheralTimestamps.removeAll()

        altimeter.stopRelativeAltitudeUpdates()
        pressureSamples.removeAll()

        pruneTicker?.cancel()
        pruneTicker = nil

        refreshSnapshot()
    }

    private func startPathMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.apply(path: path)
            }
        }
        monitor.start(queue: pathMonitorQueue)
        pathMonitor = monitor
    }

    private func apply(path: NWPath) {
        let previousState = networkState
        networkState = Self.networkState(for: path)

        if previousState != .offline, networkState == .offline {
            lastNetworkDropAt = .now
        }

        refreshSnapshot()
    }

    private func startBluetoothMonitoring() {
        if bluetoothManager == nil {
            bluetoothManager = CBCentralManager(
                delegate: self,
                queue: nil,
                options: [CBCentralManagerOptionShowPowerAlertKey: false]
            )
        } else {
            syncBluetoothScanState()
        }
    }

    private func syncBluetoothScanState() {
        guard let bluetoothManager else { return }

        if bluetoothManager.state == .poweredOn {
            if !bluetoothManager.isScanning {
                bluetoothManager.scanForPeripherals(
                    withServices: nil,
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
                )
            }
        } else {
            bluetoothManager.stopScan()
            discoveredPeripheralTimestamps.removeAll()
        }

        refreshSnapshot()
    }

    private func startPressureMonitoring() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            pressureSamples.removeAll()
            refreshSnapshot()
            return
        }

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let self, let pressure = data?.pressure.doubleValue else { return }
            self.recordPressure(pressure)
        }
    }

    private func recordPressure(_ kilopascals: Double) {
        pressureSamples.append(PressureSample(timestamp: .now, kilopascals: kilopascals))
        pressureSamples = pressureSamples
            .filter { Date().timeIntervalSince($0.timestamp) <= 20 * 60 }
            .suffix(12)
        refreshSnapshot()
    }

    private func startPruneLoop() {
        pruneTicker = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.pruneNearbySignals(now: now)
            }
    }

    private func pruneNearbySignals(now: Date) {
        discoveredPeripheralTimestamps = discoveredPeripheralTimestamps.filter { now.timeIntervalSince($0.value) <= 25 }
        refreshSnapshot()
    }

    private func refreshSnapshot() {
        snapshot = SituationalScannerSnapshot(
            gpsState: Self.gpsState(
                location: locationService.currentLocation,
                authorizationStatus: locationService.authorizationStatus
            ),
            networkState: networkState,
            radioState: Self.radioState(
                bluetoothState: bluetoothState,
                nearbySignalCount: discoveredPeripheralTimestamps.count
            ),
            pressureTrend: Self.pressureTrend(from: pressureSamples),
            powerState: Self.powerState(from: batteryService.status),
            batteryStatus: batteryService.status,
            lastNetworkDropAt: lastNetworkDropAt,
            updatedAt: .now
        )
    }

    private static func gpsState(
        location: CLLocation?,
        authorizationStatus: CLAuthorizationStatus
    ) -> ScannerGPSState {
        guard authorizationStatus != .denied, authorizationStatus != .restricted else {
            return .unavailable
        }
        guard let location else {
            return .unavailable
        }
        let accuracy = max(location.horizontalAccuracy, 0)
        if accuracy <= 120 {
            return .locked
        }
        return .approximate
    }

    private static func networkState(for path: NWPath) -> ScannerNetworkState {
        switch path.status {
        case .unsatisfied:
            return .offline
        case .requiresConnection:
            return .searching
        case .satisfied:
            if path.usesInterfaceType(.cellular) {
                return (path.isConstrained || path.isExpensive) ? .weakCellular : .cellularAvailable
            }
            if path.usesInterfaceType(.wifi) {
                return .wifiOnly
            }
            return .localOnly
        @unknown default:
            return .searching
        }
    }

    private static func radioState(
        bluetoothState: CBManagerState,
        nearbySignalCount: Int
    ) -> ScannerRadioState {
        switch bluetoothState {
        case .poweredOn:
            return .scanning(nearbySignalCount)
        case .poweredOff, .resetting:
            return .bluetoothOff
        case .unauthorized, .unsupported, .unknown:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    private static func pressureTrend(from samples: [PressureSample]) -> ScannerPressureTrend {
        guard let oldest = samples.first, let newest = samples.last, samples.count >= 3 else {
            return .unavailable
        }

        let delta = newest.kilopascals - oldest.kilopascals
        if delta <= -0.2 {
            return .falling
        }
        if delta >= 0.2 {
            return .rising
        }
        return .steady
    }

    private static func powerState(from batteryStatus: BatteryStatus) -> ScannerPowerState {
        switch batteryStatus.state {
        case .charging:
            return .charging
        case .full:
            return .full
        case .unplugged:
            return .onBattery
        case .unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}

extension SituationalScannerService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.bluetoothState = central.state
            self.syncBluetoothScanState()
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            self.discoveredPeripheralTimestamps[peripheral.identifier] = .now
            self.pruneNearbySignals(now: .now)
        }
    }
}
