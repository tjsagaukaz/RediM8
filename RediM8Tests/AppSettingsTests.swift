import CoreLocation
import XCTest
@testable import RediM8

final class AppSettingsTests: XCTestCase {
    func testDefaultSettingsFavorPrivacyAndBalancedMeshBehavior() {
        let settings = AppSettings.default

        XCTAssertTrue(settings.privacy.isAnonymousModeEnabled)
        XCTAssertEqual(settings.privacy.locationShareMode, .approximate)
        XCTAssertFalse(settings.privacy.showsDeviceName)
        XCTAssertTrue(settings.signalDiscovery.discoversNearbyUsers)
        XCTAssertFalse(settings.signalDiscovery.allowsBeaconBroadcasts)
        XCTAssertTrue(settings.signalDiscovery.autoAcceptsMessages)
        XCTAssertEqual(settings.signalDiscovery.rangeMode, .balanced)
        XCTAssertTrue(settings.battery.enablesSurvivalModeAtFifteenPercent)
    }

    func testApproximateLocationRoundsSharedCoordinates() {
        let coordinate = CLLocationCoordinate2D(latitude: -27.467891, longitude: 153.025932)

        let rounded = LocationShareMode.approximate.sharedCoordinate(from: coordinate)

        XCTAssertNotNil(rounded)
        XCTAssertEqual(rounded?.latitude ?? 0, -27.47, accuracy: 0.0001)
        XCTAssertEqual(rounded?.longitude ?? 0, 153.03, accuracy: 0.0001)
    }

    func testUserProfileDecodesMissingBushfirePayloadWithDefaults() throws {
        var profile = UserProfile.empty
        profile.selectedScenarios = [.bushfires]
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 1)
        profile.evacuationRoutes = ["South via Main Road"]

        let encoded = try JSONEncoder.rediM8.encode(profile)
        var jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        jsonObject.removeValue(forKey: "bushfireReadiness")
        let legacyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys])

        let decoded = try JSONDecoder.rediM8.decode(UserProfile.self, from: legacyData)

        XCTAssertEqual(decoded.selectedScenarios, [.bushfires])
        XCTAssertEqual(decoded.bushfireReadiness.checklist.count, BushfireChecklistItemKind.allCases.count)
        XCTAssertEqual(decoded.bushfireReadiness.propertyItems.count, BushfirePropertyItemKind.allCases.count)
        XCTAssertEqual(decoded.bushfireReadiness.petEvacuationPlan, "")
    }

    func testUserProfileDecodesMissingEmergencyMedicalInfoWithDefaults() throws {
        var profile = UserProfile.empty
        profile.medicalNotes = "Planning note only"

        let encoded = try JSONEncoder.rediM8.encode(profile)
        var jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        jsonObject.removeValue(forKey: "emergencyMedicalInfo")
        let legacyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys])

        let decoded = try JSONDecoder.rediM8.decode(UserProfile.self, from: legacyData)

        XCTAssertFalse(decoded.emergencyMedicalInfo.hasAnyContent)
        XCTAssertEqual(decoded.medicalNotes, "Planning note only")
    }

    func testEmergencyMedicalInfoBroadcastSummaryKeepsOnlyCriticalFields() {
        let info = EmergencyMedicalInfo(
            criticalConditions: [.asthma, .diabetes],
            severeAllergies: "Peanuts",
            otherCriticalCondition: "Uses hearing aid",
            bloodType: "O+",
            emergencyMedication: "Inhaler in top pocket"
        )

        let summary = info.broadcastSummary

        XCTAssertEqual(
            summary,
            "Diabetes, Asthma • Allergies: Peanuts • Medication: Inhaler in top pocket • Blood type: O+ • Uses hearing aid"
        )
    }
}
