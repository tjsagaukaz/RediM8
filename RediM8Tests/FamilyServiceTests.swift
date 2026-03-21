import XCTest
@testable import RediM8

@MainActor
final class FamilyServiceTests: XCTestCase {
    func testSaveProfilePersistsSensitiveAndStandardDomainsSeparately() throws {
        let context = try makeContext(testName: #function)
        let profile = sampleProfile()

        context.familyService.saveProfile(profile)

        let storedProfile = try XCTUnwrap(context.store.load(UserProfile.self, for: ProfileStorageKey.profile))
        let storedSensitiveProfile = try context.sensitiveProfileService.loadProfile()

        XCTAssertFalse(storedProfile.hasSensitiveProfileData)
        XCTAssertEqual(storedSensitiveProfile, profile.sensitiveProfile)
        XCTAssertEqual(storedProfile.merged(with: storedSensitiveProfile), profile)
    }

    func testLoadProfileMergesRedactedStandardDataWithSecureProfile() throws {
        let context = try makeContext(testName: #function)
        let profile = sampleProfile()

        try context.store.save(profile.redactedForStandardStorage, for: ProfileStorageKey.profile)
        try context.store.save(true, for: ProfileStorageKey.sensitiveMigrationCompleted)
        try context.sensitiveProfileService.saveProfile(profile.sensitiveProfile)

        let loadedProfile = context.familyService.loadProfile()

        XCTAssertEqual(loadedProfile, profile)
    }

    func testLoadProfileFallsBackToStandardDomainWhenSecurePayloadIsCorrupted() throws {
        let context = try makeContext(testName: #function)
        let profile = sampleProfile()

        context.familyService.saveProfile(profile)

        let encryptedFileURL = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(
                at: context.secureBaseURL,
                includingPropertiesForKeys: nil
            ).first
        )
        var data = try Data(contentsOf: encryptedFileURL)
        data[0] ^= 0xFF
        try data.write(to: encryptedFileURL, options: .atomic)

        let freshFamilyService = FamilyService(
            store: context.store,
            sensitiveProfileService: context.sensitiveProfileService,
            migrationService: context.migrationService
        )
        let loadedProfile = freshFamilyService.loadProfile()

        XCTAssertEqual(loadedProfile.selectedScenarios, profile.selectedScenarios)
        XCTAssertEqual(loadedProfile.supplies, profile.supplies)
        XCTAssertTrue(loadedProfile.familyMembers.isEmpty)
        XCTAssertTrue(loadedProfile.emergencyContacts.isEmpty)
        XCTAssertFalse(loadedProfile.emergencyMedicalInfo.hasAnyContent)
    }

    private func makeContext(testName: String) throws -> FamilyServiceContext {
        let store = try SQLiteStore(filename: "FamilyServiceTests-\(UUID().uuidString).sqlite")
        let secureBaseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("FamilyServiceTests", isDirectory: true)
            .appendingPathComponent(testName.replacingOccurrences(of: " ", with: "_"), isDirectory: true)
        try? FileManager.default.removeItem(at: secureBaseURL)

        let secureStore = SecureStore(
            namespace: "family-service-tests",
            baseURL: secureBaseURL,
            keyProvider: FixedSecureStoreKeyProvider(byte: 7),
            fileManager: .default
        )
        let sensitiveProfileService = SensitiveProfileService(secureStore: secureStore)
        let migrationService = SensitiveProfileMigrationService(
            store: store,
            sensitiveProfileService: sensitiveProfileService
        )
        let familyService = FamilyService(
            store: store,
            sensitiveProfileService: sensitiveProfileService,
            migrationService: migrationService
        )

        return FamilyServiceContext(
            store: store,
            secureBaseURL: secureBaseURL,
            sensitiveProfileService: sensitiveProfileService,
            migrationService: migrationService,
            familyService: familyService
        )
    }

    private func sampleProfile() -> UserProfile {
        var profile = UserProfile.empty
        profile.selectedScenarios = [.bushfires]
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 1)
        profile.supplies = Supplies(waterLitres: 18, foodDays: 3, fuelLitres: 8, batteryCapacity: 40)
        profile.familyMembers = [
            FamilyMember(
                name: "Taylor",
                phone: "0400 000 111",
                medicalNotes: "Asthma",
                emergencyRole: "Primary",
                isPrimaryUser: true
            )
        ]
        profile.emergencyContacts = [
            EmergencyContact(name: "Alex", phone: "0400 123 456")
        ]
        profile.medicalNotes = "Inhaler in kitchen pouch"
        profile.emergencyMedicalInfo = EmergencyMedicalInfo(
            criticalConditions: [.asthma],
            severeAllergies: "Peanuts",
            bloodType: "O+"
        )
        profile.meetingPoints = MeetingPoints(primary: "Front gate", secondary: "Oval", fallback: "Town hall")
        profile.evacuationRoutes = ["South via Main Road"]
        profile.accountabilityCircle = AccountabilityCircle(
            members: [AccountabilityMember(name: "Taylor", phone: "0400 000 111", source: .selfUser)]
        )
        return profile
    }
}

private struct FamilyServiceContext {
    let store: SQLiteStore
    let secureBaseURL: URL
    let sensitiveProfileService: SensitiveProfileService
    let migrationService: SensitiveProfileMigrationService
    let familyService: FamilyService
}
