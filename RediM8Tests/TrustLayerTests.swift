import XCTest
@testable import RediM8

final class TrustLayerTests: XCTestCase {
    func testQuickContactsIncludeOfficialAndSavedNumbers() {
        var profile = UserProfile.empty
        profile.emergencyContacts = [
            EmergencyContact(name: "SES Brisbane", phone: "07 1111 2222")
        ]
        profile.familyMembers = [
            FamilyMember(name: "Alex", phone: "0400 123 456", medicalNotes: "", emergencyRole: "Pickup")
        ]

        let contacts = TrustLayer.quickContacts(for: profile)

        XCTAssertEqual(contacts.map(\.id), ["emergency_services", "ses", "local_contact", "family_contact"])
        XCTAssertEqual(contacts[0].displayNumber, "000")
        XCTAssertEqual(contacts[1].displayNumber, "132 500")
        XCTAssertEqual(contacts[2].subtitle, "SES Brisbane")
        XCTAssertEqual(contacts[3].subtitle, "Alex")
        XCTAssertEqual(contacts[3].dialURL?.absoluteString, "tel://0400123456")
    }

    func testGuideTrustProfileUsesFirstAidCopyForMedicalGuides() {
        let guide = Guide(
            id: "first_aid",
            title: "First Aid",
            category: .firstAid,
            summary: "Help under stress.",
            steps: ["Step 1"],
            notes: "Notes"
        )

        XCTAssertEqual(guide.confidenceTitle, "Preparedness Guide")
        XCTAssertEqual(guide.confidenceSummary, "General first aid guidance")
    }

    func testGuideTrustProfileUsesGeneralSafetyCopyForPreparednessGuides() {
        let guide = Guide(
            id: "storm",
            title: "Storm Safety",
            category: .stormSafety,
            summary: "Storm prep.",
            steps: ["Step 1"],
            notes: ""
        )

        XCTAssertEqual(guide.confidenceSummary, "General safety guidance")
    }

    func testFreshnessLabelUsesUpdatedPrefixForPastDates() {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let pastDate = referenceDate.addingTimeInterval(-3_600)

        let label = TrustLayer.freshnessLabel(for: pastDate, reference: referenceDate)

        XCTAssertTrue(label.hasPrefix("Updated "))
    }

    func testFreshnessLabelUsesDatedPrefixForFutureDates() {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let futureDate = referenceDate.addingTimeInterval(86_400)

        let label = TrustLayer.freshnessLabel(for: futureDate, reference: referenceDate)

        XCTAssertTrue(label.hasPrefix("Dated "))
    }
}
