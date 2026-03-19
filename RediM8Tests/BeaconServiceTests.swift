import XCTest
@testable import RediM8

final class BeaconServiceTests: XCTestCase {
    func testSituationReportMetadataUsesExpectedExpiryWindowsAndTags() {
        XCTAssertTrue(BeaconType.fireSpotted.isSituationReport)
        XCTAssertTrue(BeaconType.floodedRoad.isSituationReport)
        XCTAssertTrue(BeaconType.roadBlocked.isSituationReport)
        XCTAssertFalse(BeaconType.needHelp.isSituationReport)

        XCTAssertEqual(BeaconType.fireSpotted.defaultLifetime, 2 * 60 * 60)
        XCTAssertEqual(BeaconType.floodedRoad.defaultLifetime, 6 * 60 * 60)
        XCTAssertEqual(BeaconType.waterAvailable.defaultLifetime, 24 * 60 * 60)
        XCTAssertEqual(BeaconType.shelter.defaultLifetime, 48 * 60 * 60)

        XCTAssertEqual(BeaconType.medicalHelp.defaultResources, [.firstAid])
        XCTAssertEqual(BeaconType.waterAvailable.defaultResources, [.water])
        XCTAssertEqual(BeaconType.fuelAvailable.defaultResources, [.fuel])
        XCTAssertEqual(BeaconType.shelter.defaultResources, [.shelter])

        XCTAssertTrue(BeaconType.medicalHelp.supportsEmergencyMedicalDisclosure)
        XCTAssertTrue(BeaconType.needHelp.supportsEmergencyMedicalDisclosure)
        XCTAssertFalse(BeaconType.fireSpotted.supportsEmergencyMedicalDisclosure)

        XCTAssertTrue(BeaconType.fireSpotted.isPriorityReport)
        XCTAssertTrue(BeaconType.medicalHelp.isPriorityReport)
        XCTAssertFalse(BeaconType.waterAvailable.isPriorityReport)
        XCTAssertEqual(BeaconType.fireSpotted.defaultSeverity, .critical)
        XCTAssertEqual(BeaconType.safeLocation.defaultSeverity, .low)
    }

    @MainActor
    func testReceivedBeaconsPreferNewestAndIgnoreInactive() {
        let service = BeaconService(meshService: MeshService(), locationService: LocationService(), store: nil)

        let initial = makeBeacon(
            id: "beacon_alpha",
            nodeID: "A1B2",
            type: .waterAvailable,
            state: .active,
            updatedAt: .now,
            expiresAt: .now.addingTimeInterval(300),
            message: "Water on hand"
        )

        service.recordReceivedBeacon(initial)
        XCTAssertEqual(service.nearbyBeacons.count, 1)
        XCTAssertEqual(service.nearbyBeacons.first?.message, "Water on hand")

        let newer = makeBeacon(
            id: "beacon_alpha",
            nodeID: "A1B2",
            type: .waterAvailable,
            state: .active,
            updatedAt: .now.addingTimeInterval(10),
            expiresAt: .now.addingTimeInterval(600),
            message: "Water and first aid"
        )

        service.recordReceivedBeacon(newer)
        XCTAssertEqual(service.nearbyBeacons.count, 1)
        XCTAssertEqual(service.nearbyBeacons.first?.message, "Water and first aid")

        let inactive = makeBeacon(
            id: "beacon_alpha",
            nodeID: "A1B2",
            type: .waterAvailable,
            state: .inactive,
            updatedAt: .now.addingTimeInterval(20),
            expiresAt: .now.addingTimeInterval(-1),
            message: "Offline"
        )

        service.recordReceivedBeacon(inactive)
        XCTAssertTrue(service.nearbyBeacons.isEmpty)
    }

    @MainActor
    func testReceivedMeshReportQueuesForRelayWhenForwardingEnabled() {
        let service = makeRelayEnabledService()
        let report = makeBeacon(
            id: "beacon_fire",
            nodeID: "B1C2",
            type: .fireSpotted,
            state: .active,
            updatedAt: .now,
            expiresAt: .now.addingTimeInterval(2 * 60 * 60),
            message: "Flames near the ridge"
        )

        service.recordReceivedBeacon(
            report,
            sourcePeerDisplayName: "Scout A",
            receivedFromMesh: true
        )

        XCTAssertEqual(service.nearbyBeacons.count, 1)
        XCTAssertEqual(service.relayQueueCount, 1)
    }

    @MainActor
    func testSameTimestampPrefersLowerRelayDepth() {
        let service = BeaconService(meshService: MeshService(), locationService: LocationService(), store: nil)
        let timestamp = Date()

        service.recordReceivedBeacon(
            makeBeacon(
                id: "beacon_route",
                nodeID: "D4E5",
                type: .roadBlocked,
                state: .active,
                updatedAt: timestamp,
                expiresAt: timestamp.addingTimeInterval(6 * 60 * 60),
                message: "Fallen trees",
                relayDepth: 1
            )
        )

        service.recordReceivedBeacon(
            makeBeacon(
                id: "beacon_route",
                nodeID: "D4E5",
                type: .roadBlocked,
                state: .active,
                updatedAt: timestamp,
                expiresAt: timestamp.addingTimeInterval(6 * 60 * 60),
                message: "Fallen trees",
                relayDepth: 0
            )
        )

        XCTAssertEqual(service.nearbyBeacons.first?.relayDepth, 0)
        XCTAssertEqual(service.nearbyBeacons.count, 1)
    }

    @MainActor
    func testPruneExpiredBeaconsRemovesExpiredEntries() {
        let service = BeaconService(meshService: MeshService(), locationService: LocationService(), store: nil)

        service.recordReceivedBeacon(
            makeBeacon(
                id: "beacon_need_help",
                nodeID: "C3D4",
                type: .needHelp,
                state: .active,
                updatedAt: .now,
                expiresAt: .now.addingTimeInterval(30),
                message: "Need evacuation"
            )
        )

        service.recordReceivedBeacon(
            makeBeacon(
                id: "beacon_shelter",
                nodeID: "E5F6",
                type: .shelter,
                state: .active,
                updatedAt: .now,
                expiresAt: .now.addingTimeInterval(600),
                message: "Covered shelter"
            )
        )

        service.pruneExpiredBeacons(now: .now.addingTimeInterval(45))

        XCTAssertEqual(service.nearbyBeacons.count, 1)
        XCTAssertEqual(service.nearbyBeacons.first?.type, .shelter)
    }

    @MainActor
    func testPruneExpiredBeaconsRemovesStaleRelayBacklogEntries() {
        let service = makeRelayEnabledService()
        let timestamp = Date()

        service.recordReceivedBeacon(
            makeBeacon(
                id: "beacon_help",
                nodeID: "F7A8",
                type: .medicalHelp,
                state: .active,
                updatedAt: timestamp,
                expiresAt: timestamp.addingTimeInterval(2 * 60 * 60),
                message: "First aid needed"
            ),
            sourcePeerDisplayName: "Medic 1",
            receivedFromMesh: true
        )

        XCTAssertEqual(service.relayQueueCount, 1)

        service.pruneExpiredBeacons(now: timestamp.addingTimeInterval(31 * 60))

        XCTAssertEqual(service.relayQueueCount, 0)
    }

    func testCommunityBeaconCanCarrySharedEmergencyMedicalSummary() {
        let beacon = makeBeacon(
            id: "beacon_medical",
            nodeID: "Z9Y8",
            type: .medicalHelp,
            state: .active,
            updatedAt: .now,
            expiresAt: .now.addingTimeInterval(2 * 60 * 60),
            message: "Need first aid",
            emergencyMedicalSummary: "Asthma • Medication: Inhaler in top pocket"
        )

        XCTAssertEqual(beacon.sharedEmergencyMedicalSummary, "Asthma • Medication: Inhaler in top pocket")
        XCTAssertTrue(beacon.summaryLines.contains("Medical note: Asthma • Medication: Inhaler in top pocket"))
    }

    func testCommunityBeaconCanCarryStructuredSignalMetadata() {
        let beacon = makeBeacon(
            id: "beacon_fire",
            nodeID: "F1R3",
            type: .fireSpotted,
            state: .active,
            updatedAt: .now,
            expiresAt: .now.addingTimeInterval(2 * 60 * 60),
            message: "Fire moving uphill",
            signalMetadata: BeaconSignalMetadata(
                severity: .critical,
                confidence: .high,
                directionHint: "Moving east",
                routeCondition: nil,
                waterSafety: nil,
                shelterStatus: nil,
                capacityNote: nil,
                batteryLevelPercent: nil
            )
        )

        XCTAssertEqual(beacon.severity, .critical)
        XCTAssertEqual(beacon.confidence, .high)
        XCTAssertTrue(beacon.signalHighlights.contains { $0.label == "Spread" && $0.value == "Moving east" })
    }

    func testLegacyCommunityBeaconDefaultsStructuredSignalMetadataWhenMissing() throws {
        let legacyJSON = """
        {
          "created_at": "2026-03-15T06:00:00Z",
          "display_name": null,
          "emergency_medical_summary": null,
          "expires_at": "2026-03-15T08:00:00Z",
          "id": "beacon_legacy",
          "lat": -27.468,
          "lng": 153.028,
          "location_label": "Pine Street",
          "message": "Road blocked by debris",
          "node_id": "L0G1",
          "relay_depth": 0,
          "resources": ["water"],
          "shows_name": false,
          "status": "active",
          "status_text": "Road blocked",
          "timestamp": "2026-03-15T06:05:00Z",
          "type": "road_blocked"
        }
        """

        let beacon = try JSONDecoder.rediM8.decode(
            CommunityBeacon.self,
            from: XCTUnwrap(legacyJSON.data(using: .utf8))
        )

        XCTAssertEqual(beacon.severity, .high)
        XCTAssertEqual(beacon.confidence, .medium)
        XCTAssertEqual(beacon.signalMetadata.routeCondition, .blocked)
    }

    @MainActor
    private func makeRelayEnabledService() -> BeaconService {
        let service = BeaconService(meshService: MeshService(), locationService: LocationService(), store: nil)
        service.updateSettings(
            BeaconRuntimeSettings(
                isStealthModeEnabled: false,
                isAnonymousModeEnabled: false,
                allowsBeaconBroadcasts: true,
                locationShareMode: .off,
                showsDeviceName: false,
                rangeMode: .balanced
            )
        )
        return service
    }

    @MainActor
    func testRelayBacklogDoesNotExceedMaximumSize() {
        let service = makeRelayEnabledService()
        let timestamp = Date()
        let cap = AppConstants.Beacon.maxRelayBacklogSize

        for index in 0 ..< cap + 50 {
            service.recordReceivedBeacon(
                makeBeacon(
                    id: "beacon_\(index)",
                    nodeID: "NODE_\(index)",
                    type: .waterAvailable,
                    state: .active,
                    updatedAt: timestamp,
                    expiresAt: timestamp.addingTimeInterval(2 * 60 * 60),
                    message: "Water available"
                ),
                sourcePeerDisplayName: "Peer \(index)",
                receivedFromMesh: true
            )
        }

        XCTAssertLessThanOrEqual(service.relayQueueCount, cap)
    }

    @MainActor
    func testMonitoringSyncDoesNotLeakLocationClients() {
        let locationService = LocationService()
        let service = BeaconService(meshService: MeshService(), locationService: locationService, store: nil)

        service.startMonitoring()
        XCTAssertEqual(locationService.activeClientCount, 1)

        service.updateSettings(
            BeaconRuntimeSettings(
                isStealthModeEnabled: false,
                isAnonymousModeEnabled: true,
                allowsBeaconBroadcasts: false,
                locationShareMode: .off,
                showsDeviceName: false,
                rangeMode: .balanced
            )
        )
        service.pruneExpiredBeacons()
        XCTAssertEqual(locationService.activeClientCount, 1)

        service.stopMonitoring()
        XCTAssertEqual(locationService.activeClientCount, 0)
    }

    private func makeBeacon(
        id: String,
        nodeID: String,
        type: BeaconType,
        state: BeaconState,
        updatedAt: Date,
        expiresAt: Date,
        message: String,
        relayDepth: Int = 0,
        emergencyMedicalSummary: String? = nil,
        signalMetadata: BeaconSignalMetadata? = nil
    ) -> CommunityBeacon {
        CommunityBeacon(
            id: id,
            nodeID: nodeID,
            type: type,
            state: state,
            latitude: -27.468,
            longitude: 153.028,
            locationName: "Pine Street",
            statusText: type.defaultStatusText,
            message: message,
            resources: [.water],
            createdAt: updatedAt,
            updatedAt: updatedAt,
            expiresAt: expiresAt,
            relayDepth: relayDepth,
            displayName: nil,
            showsName: false,
            emergencyMedicalSummary: emergencyMedicalSummary,
            signalMetadata: signalMetadata
        )
    }
}

@MainActor
final class MeshServiceRoutingSafetyTests: XCTestCase {
    func testMeshHazardReportsRemainInformationalUntilTrustExists() {
        let transport = TestMeshTransport()
        let service = MeshService(transports: [transport])
        let report = SharedHazardReport(
            kind: "flood",
            latitude: -27.468,
            longitude: 153.028,
            radiusMetres: 250,
            severity: "high",
            description: "Flooded causeway reported by nearby peer.",
            reportedAt: .now
        )

        transport.emit(
            .message(
                MeshMessage(
                    sender: "Scout A",
                    body: "Flooded causeway ahead",
                    kind: .hazardReport,
                    hazardReport: report
                )
            )
        )

        XCTAssertEqual(service.receivedHazardReports.count, 1)
        XCTAssertTrue(service.hazardZonesFromMesh.isEmpty)
    }
}

@MainActor
private final class TestMeshTransport: MeshTransport {
    let id = "test"
    private(set) var isActive = false
    private(set) var localPeer = MeshPeer(id: "test:local", transportID: "test", displayName: "Local")
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

    func sendMessage(_ message: MeshMessage, to peers: [MeshPeer]) -> Bool {
        false
    }

    func sendBeacon(_ beacon: CommunityBeacon, to peers: [MeshPeer]) -> Bool {
        false
    }

    func emit(_ event: MeshTransportEvent) {
        onEvent?(event)
    }
}
