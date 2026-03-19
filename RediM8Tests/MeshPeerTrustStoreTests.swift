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
}
