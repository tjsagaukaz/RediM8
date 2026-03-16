import Foundation
import UIKit

@MainActor
final class SignalSystem: ObservableObject, AppSystem {
    @Published private(set) var isStealthModeEnabled = false
    @Published private(set) var stealthNodeID: String

    let meshService: MeshService
    let beaconService: BeaconService
    let locationService: LocationService
    let torchService: TorchService
    let motionService: MotionService

    private let featureFlags: AppFeatureFlags
    private var currentSettings: AppSettings

    init(
        featureFlags: AppFeatureFlags,
        meshService: MeshService,
        beaconService: BeaconService,
        locationService: LocationService,
        torchService: TorchService,
        motionService: MotionService,
        initialSettings: AppSettings
    ) {
        self.featureFlags = featureFlags
        self.meshService = meshService
        self.beaconService = beaconService
        self.locationService = locationService
        self.torchService = torchService
        self.motionService = motionService
        currentSettings = initialSettings
        stealthNodeID = Self.generateEphemeralNodeID()

        applyRuntimeConfiguration()
    }

    func start() {
        applyRuntimeConfiguration()
    }

    func stop() {}

    func updateSettings(_ settings: AppSettings) {
        currentSettings = settings
        applyRuntimeConfiguration()
    }

    func enableStealthMode() {
        guard featureFlags.enablesStealthMode else { return }
        setStealthMode(true)
    }

    func disableStealthMode() {
        setStealthMode(false)
    }

    func toggleStealthMode() {
        if isStealthModeEnabled {
            disableStealthMode()
        } else {
            enableStealthMode()
        }
    }

    @discardableResult
    func resetLocalNodeID() -> String {
        let nodeID = beaconService.resetLocalNodeID()
        applyRuntimeConfiguration()
        return nodeID
    }

    func clearCachedData() {
        meshService.clearSessionMessages()
        beaconService.clearNearbyBeaconsCache()
    }

    var stealthModeNodeLabel: String {
        "Node \(stealthNodeID)"
    }

    private func applyRuntimeConfiguration() {
        let effectiveRangeMode: SignalRangeMode = isStealthModeEnabled ? .lowPower : currentSettings.signalDiscovery.rangeMode

        meshService.updateConfiguration(
            displayName: resolvedMeshDisplayName(for: currentSettings),
            isBrowsingEnabled: currentSettings.signalDiscovery.discoversNearbyUsers,
            isBroadcastingEnabled: !currentSettings.privacy.isAnonymousModeEnabled && !isStealthModeEnabled,
            autoAcceptInvitations: currentSettings.signalDiscovery.autoAcceptsMessages,
            locationShareMode: currentSettings.privacy.locationShareMode,
            rangeMode: effectiveRangeMode,
            allowsOutgoingInvitations: !isStealthModeEnabled,
            usesLowFrequencyBrowsing: isStealthModeEnabled && currentSettings.signalDiscovery.discoversNearbyUsers
        )

        beaconService.updateSettings(
            BeaconRuntimeSettings(
                isStealthModeEnabled: isStealthModeEnabled,
                isAnonymousModeEnabled: currentSettings.privacy.isAnonymousModeEnabled,
                allowsBeaconBroadcasts: currentSettings.signalDiscovery.allowsBeaconBroadcasts,
                locationShareMode: currentSettings.privacy.locationShareMode,
                showsDeviceName: isStealthModeEnabled ? false : currentSettings.privacy.showsDeviceName,
                rangeMode: effectiveRangeMode
            )
        )

        locationService.updateRuntimeMode(isStealthModeEnabled ? .stealth : .standard)
    }

    private func resolvedMeshDisplayName(for settings: AppSettings) -> String {
        if isStealthModeEnabled {
            return stealthModeNodeLabel
        }
        if settings.privacy.showsDeviceName {
            return String(UIDevice.current.name.prefix(20))
        }
        return beaconService.localNodeLabel
    }

    private func setStealthMode(_ isEnabled: Bool) {
        guard !isEnabled || featureFlags.enablesStealthMode else { return }
        guard isStealthModeEnabled != isEnabled else { return }

        if isEnabled {
            stealthNodeID = Self.generateEphemeralNodeID()
        }

        isStealthModeEnabled = isEnabled
        applyRuntimeConfiguration()
    }

    private static func generateEphemeralNodeID() -> String {
        let value = Int.random(in: 0...0xFFFF)
        return String(format: "%04X", value)
    }
}
