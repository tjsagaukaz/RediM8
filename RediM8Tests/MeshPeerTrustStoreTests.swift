import XCTest
@testable import RediM8

final class MeshPeerTrustStoreTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "MeshPeerTrustStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    // MARK: - TOFU (existing)

    func testFirstSeenPeerFingerprintIsTrustedAndPersisted() {
        let store = MeshPeerTrustStore(defaults: defaults)

        let firstDecision = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        let secondDecision = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")

        XCTAssertEqual(firstDecision, .trustedFirstUse)
        XCTAssertEqual(secondDecision, .trustedKnownPeer)
    }

    func testChangedFingerprintForKnownPeerIsRejected() {
        let store = MeshPeerTrustStore(defaults: defaults)

        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        let decision = store.evaluate(fingerprint: "def456", peerDisplayName: "Camp Alpha")

        XCTAssertEqual(decision, .rejectedChangedIdentity)
    }

    func testMissingFingerprintIsRejected() {
        let store = MeshPeerTrustStore(defaults: defaults)

        let decision = store.evaluate(fingerprint: nil, peerDisplayName: "Camp Alpha")

        XCTAssertEqual(decision, .rejectedMissingCertificate)
    }

    func testPeerIdentityLookupNormalizesDisplayNameFormatting() {
        let store = MeshPeerTrustStore(defaults: defaults)

        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: " Camp Alpha ")
        let decision = store.evaluate(fingerprint: "abc123", peerDisplayName: "camp alpha")

        XCTAssertEqual(decision, .trustedKnownPeer)
    }

    // MARK: - Trust Levels

    func testNewPeerStartsAsUnknownTrustLevel() {
        let store = MeshPeerTrustStore(defaults: defaults)
        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")

        XCTAssertEqual(store.trustLevel(for: "Camp Alpha"), .unknown)
    }

    func testVerifyPeerSetsVerifiedTrustLevel() {
        let store = MeshPeerTrustStore(defaults: defaults)
        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")

        store.verify(peerDisplayName: "Camp Alpha")

        XCTAssertEqual(store.trustLevel(for: "Camp Alpha"), .verified)
    }

    func testVerifiedPeerReturnsVerifiedDecision() {
        let store = MeshPeerTrustStore(defaults: defaults)
        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        store.verify(peerDisplayName: "Camp Alpha")

        let decision = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")

        XCTAssertEqual(decision, .trustedVerifiedPeer)
        XCTAssertTrue(decision.isVerified)
    }

    // MARK: - Blocking

    func testBlockPeerRejectsConnection() {
        let store = MeshPeerTrustStore(defaults: defaults)
        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")

        store.block(peerDisplayName: "Camp Alpha")

        let decision = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        XCTAssertEqual(decision, .rejectedBlocked)
        XCTAssertFalse(decision.allowsConnection)
    }

    func testBlockedPeerStaysBlockedEvenWithCorrectFingerprint() {
        let store = MeshPeerTrustStore(defaults: defaults)
        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        store.verify(peerDisplayName: "Camp Alpha")
        store.block(peerDisplayName: "Camp Alpha")

        let decision = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")

        XCTAssertEqual(decision, .rejectedBlocked)
        XCTAssertEqual(store.trustLevel(for: "Camp Alpha"), .blocked)
    }

    // MARK: - Revoke & Forget

    func testRevokeTrustResetsToUnknown() {
        let store = MeshPeerTrustStore(defaults: defaults)
        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        store.verify(peerDisplayName: "Camp Alpha")

        store.revokeTrust(peerDisplayName: "Camp Alpha")

        XCTAssertEqual(store.trustLevel(for: "Camp Alpha"), .unknown)
        // Should still recognize the fingerprint (not TOFU again)
        let decision = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        XCTAssertEqual(decision, .trustedKnownPeer)
    }

    func testForgetPeerRemovesAllData() {
        let store = MeshPeerTrustStore(defaults: defaults)
        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        store.verify(peerDisplayName: "Camp Alpha")

        store.forget(peerDisplayName: "Camp Alpha")

        XCTAssertEqual(store.trustLevel(for: "Camp Alpha"), .unknown)
        XCTAssertTrue(store.knownPeers().isEmpty)
        // Next connection should be TOFU again
        let decision = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        XCTAssertEqual(decision, .trustedFirstUse)
    }

    func testUnblockViRevokeTrustAllowsReconnection() {
        let store = MeshPeerTrustStore(defaults: defaults)
        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        store.block(peerDisplayName: "Camp Alpha")

        store.revokeTrust(peerDisplayName: "Camp Alpha")

        let decision = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        XCTAssertEqual(decision, .trustedKnownPeer)
        XCTAssertTrue(decision.allowsConnection)
    }

    // MARK: - Known Peers Listing

    func testKnownPeersListsAllPeersWithTrustLevels() {
        let store = MeshPeerTrustStore(defaults: defaults)
        _ = store.evaluate(fingerprint: "aaa", peerDisplayName: "Alpha")
        _ = store.evaluate(fingerprint: "bbb", peerDisplayName: "Bravo")
        _ = store.evaluate(fingerprint: "ccc", peerDisplayName: "Charlie")

        store.verify(peerDisplayName: "Alpha")
        store.block(peerDisplayName: "Charlie")

        let peers = store.knownPeers()
        XCTAssertEqual(peers.count, 3)
        XCTAssertEqual(peers.first(where: { $0.displayName == "Alpha" })?.trustLevel, .verified)
        XCTAssertEqual(peers.first(where: { $0.displayName == "Bravo" })?.trustLevel, .unknown)
        XCTAssertEqual(peers.first(where: { $0.displayName == "Charlie" })?.trustLevel, .blocked)
    }

    func testShortFingerprintReturnsFirst16Characters() {
        let store = MeshPeerTrustStore(defaults: defaults)
        let longFingerprint = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
        _ = store.evaluate(fingerprint: longFingerprint, peerDisplayName: "Alpha")

        XCTAssertEqual(store.shortFingerprint(for: "Alpha"), "abcdef0123456789")
    }

    func testShortFingerprintReturnsNilForUnknownPeer() {
        let store = MeshPeerTrustStore(defaults: defaults)

        XCTAssertNil(store.shortFingerprint(for: "Nobody"))
    }

    // MARK: - Escalation Prevention

    func testBlockedPeerCannotEscalateWithoutExplicitUserAction() {
        let store = MeshPeerTrustStore(defaults: defaults)
        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        store.block(peerDisplayName: "Camp Alpha")

        // Repeated evaluations must NOT change blocked status
        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        _ = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")

        XCTAssertEqual(store.trustLevel(for: "Camp Alpha"), .blocked, "Blocked peer must stay blocked without explicit user action")

        // Even verifying a different name must not affect the blocked peer
        _ = store.evaluate(fingerprint: "zzz999", peerDisplayName: "Camp Bravo")
        store.verify(peerDisplayName: "Camp Bravo")

        XCTAssertEqual(store.trustLevel(for: "Camp Alpha"), .blocked, "Verifying another peer must not affect blocked peer")
    }

    // MARK: - Migration

    func testMigratesFromLegacyFingerprintOnlyStore() {
        // Write legacy format
        defaults.set(
            ["camp alpha": "abc123", "camp bravo": "def456"],
            forKey: "mesh.trusted-peer-fingerprints.v1"
        )

        // Creating a new store should trigger migration
        let store = MeshPeerTrustStore(defaults: defaults)
        let peers = store.knownPeers()

        XCTAssertEqual(peers.count, 2)
        XCTAssertTrue(peers.allSatisfy { $0.trustLevel == .unknown })

        // Should be able to evaluate against migrated fingerprints
        let decision = store.evaluate(fingerprint: "abc123", peerDisplayName: "Camp Alpha")
        XCTAssertEqual(decision, .trustedKnownPeer)
    }
}
