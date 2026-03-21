import XCTest
@testable import RediM8

final class SecureStoreTests: XCTestCase {
    func testSaveAndLoadRoundTrip() throws {
        let baseURL = makeBaseURL(testName: #function)
        let store = makeStore(baseURL: baseURL, keyByte: 7)
        let payload = sampleSensitiveProfile()

        try store.save(payload, for: "profile")

        let loaded = try store.load(SensitiveProfile.self, for: "profile")

        XCTAssertEqual(loaded, payload)
    }

    func testLoadingWithDifferentKeyFails() throws {
        let baseURL = makeBaseURL(testName: #function)
        let writer = makeStore(baseURL: baseURL, keyByte: 7)
        let reader = makeStore(baseURL: baseURL, keyByte: 9)

        try writer.save(sampleSensitiveProfile(), for: "profile")

        XCTAssertThrowsError(try reader.load(SensitiveProfile.self, for: "profile"))
    }

    func testTamperedCiphertextFails() throws {
        let baseURL = makeBaseURL(testName: #function)
        let store = makeStore(baseURL: baseURL, keyByte: 7)

        try store.save(sampleSensitiveProfile(), for: "profile")

        let encryptedFileURL = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: nil
            ).first
        )
        var data = try Data(contentsOf: encryptedFileURL)
        data[0] ^= 0xFF
        try data.write(to: encryptedFileURL, options: .atomic)

        XCTAssertThrowsError(try store.load(SensitiveProfile.self, for: "profile"))
    }

    private func makeBaseURL(testName: String) -> URL {
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("SecureStoreTests", isDirectory: true)
            .appendingPathComponent(testName.replacingOccurrences(of: " ", with: "_"), isDirectory: true)
        try? FileManager.default.removeItem(at: baseURL)
        return baseURL
    }

    private func makeStore(baseURL: URL, keyByte: UInt8) -> SecureStore {
        SecureStore(
            namespace: "secure-store-tests",
            baseURL: baseURL,
            keyProvider: FixedSecureStoreKeyProvider(byte: keyByte),
            fileManager: .default
        )
    }

    private func sampleSensitiveProfile() -> SensitiveProfile {
        SensitiveProfile(
            familyMembers: [
                FamilyMember(
                    name: "Taylor",
                    phone: "0400 000 111",
                    medicalNotes: "Asthma",
                    emergencyRole: "Primary",
                    isPrimaryUser: true
                )
            ],
            emergencyContacts: [
                EmergencyContact(name: "Alex", phone: "0400 123 456")
            ],
            medicalNotes: "Keep inhaler accessible",
            emergencyMedicalInfo: EmergencyMedicalInfo(
                criticalConditions: [.asthma],
                severeAllergies: "Peanuts",
                otherCriticalCondition: "",
                bloodType: "O+",
                emergencyMedication: "Ventolin"
            ),
            meetingPoints: MeetingPoints(primary: "Front gate", secondary: "Oval", fallback: "Town hall"),
            evacuationRoutes: ["South via Main Road"],
            accountabilityCircle: AccountabilityCircle(
                members: [AccountabilityMember(name: "Taylor", phone: "0400 000 111", source: .selfUser)]
            )
        )
    }
}

struct FixedSecureStoreKeyProvider: SecureStoreKeyProviding {
    let byte: UInt8

    func fetchOrCreateKey() throws -> Data {
        Data(repeating: byte, count: 32)
    }
}
