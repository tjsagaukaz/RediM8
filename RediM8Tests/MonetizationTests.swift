import XCTest
@testable import RediM8

final class MonetizationTests: XCTestCase {
    private let sampleAlert = OfficialAlert(
        id: "qld-bushfire-test",
        title: "Bushfire Warning",
        message: "Leave now if the threat increases.",
        instruction: "Monitor local conditions.",
        issuer: "Queensland Fire Department",
        sourceName: "Queensland Warnings",
        sourceURLString: "https://example.com/alert",
        jurisdiction: .qld,
        kind: .bushfire,
        severity: .watchAndAct,
        regionScope: "Brisbane Region",
        area: OfficialAlertArea(
            description: "Brisbane hinterland",
            center: GeoPoint(latitude: -27.3811, longitude: 152.8667),
            radiusKilometres: 25
        ),
        issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
        lastUpdated: Date(timeIntervalSince1970: 1_700_000_600),
        expiresAt: Date(timeIntervalSince1970: 1_700_007_200)
    )

    func testAnnualOfferIsRecommendedLaunchDefault() {
        let catalog = RediM8MonetizationCatalog.launch

        XCTAssertEqual(catalog.recommendedOffer.interval, .annual)
        XCTAssertEqual(catalog.recommendedOffer.badge, "Best Value")
        XCTAssertEqual(catalog.recommendedOffer.priceText, "AUD $39.99")
    }

    func testLifetimeOfferIsMarkedAsFoundingPrice() {
        let catalog = RediM8MonetizationCatalog.launch

        XCTAssertEqual(catalog.lifetimeOffer.interval, .lifetime)
        XCTAssertEqual(catalog.lifetimeOffer.badge, "Founding Price")
        XCTAssertTrue(catalog.lifetimeOffer.isFoundingOffer)
    }

    func testCoreSafetyRowsRemainFree() {
        let catalog = RediM8MonetizationCatalog.launch
        let emergencyRows = catalog.alwaysFreeRows.map(\.id)

        XCTAssertTrue(emergencyRows.contains("emergency_mode"))
        XCTAssertTrue(emergencyRows.contains("official_alerts"))
        XCTAssertTrue(emergencyRows.contains("offline_map"))
        XCTAssertTrue(emergencyRows.contains("guide_library"))
        XCTAssertTrue(emergencyRows.contains("community_reports"))

        XCTAssertEqual(
            catalog.featureMatrix.first(where: { $0.id == "emergency_mode" })?.freeValue,
            "Included"
        )
        XCTAssertEqual(
            catalog.featureMatrix.first(where: { $0.id == "official_alerts" })?.freeValue,
            "Included"
        )
    }

    func testOfflineAssistantIsPositionedAsProUpgrade() throws {
        let catalog = RediM8MonetizationCatalog.launch
        let assistantRow = try XCTUnwrap(catalog.featureMatrix.first(where: { $0.id == "assistant" }))

        XCTAssertEqual(assistantRow.freeValue, "Guide retrieval")
        XCTAssertEqual(assistantRow.proValue, "Safe summaries")
    }

    func testEmergencyUnlockUsesAllUpgradeableProRows() {
        let catalog = RediM8MonetizationCatalog.launch

        XCTAssertEqual(catalog.emergencyUnlockRows, catalog.proUpgradeRows)
        XCTAssertEqual(catalog.emergencyUnlockFeatureIDs, catalog.proUpgradeRows.map(\.id))
        XCTAssertFalse(catalog.emergencyUnlockPromise.isEmpty)
    }

    func testEmergencyUnlockActiveStateUsesNearbyOfficialTriggerMessaging() {
        let state = EmergencyUnlockState.active(
            alert: sampleAlert,
            activatedAt: sampleAlert.issuedAt,
            accessEndsAt: sampleAlert.expiresAt,
            unlockedFeatureIDs: RediM8MonetizationCatalog.launch.emergencyUnlockFeatureIDs
        )

        XCTAssertTrue(state.isActive)
        XCTAssertTrue(state.isVisible)
        XCTAssertEqual(state.calloutTitle, "Emergency Unlock Active")
        XCTAssertTrue(state.calloutDetail.contains("temporarily unlocked"))
        XCTAssertEqual(state.featureCount, RediM8MonetizationCatalog.launch.emergencyUnlockFeatureIDs.count)
    }

    func testEmergencyUnlockRecentlyEndedStateInvitesUpgradeAfterIncident() {
        let endedAt = Date(timeIntervalSince1970: 1_700_010_000)
        let state = EmergencyUnlockState.recentlyEnded(
            triggerAlert: sampleAlert,
            activatedAt: sampleAlert.issuedAt,
            endedAt: endedAt,
            unlockedFeatureIDs: RediM8MonetizationCatalog.launch.emergencyUnlockFeatureIDs
        )

        XCTAssertTrue(state.isRecentlyEnded)
        XCTAssertTrue(state.isVisible)
        XCTAssertEqual(state.endedAt, endedAt)
        XCTAssertEqual(state.calloutTitle, "Emergency Access Ended")
        XCTAssertTrue(state.calloutDetail.contains("Upgrade"))
    }
}
