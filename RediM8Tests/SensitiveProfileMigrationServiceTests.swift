import XCTest
@testable import RediM8

final class SensitiveProfileMigrationServiceTests: XCTestCase {
    func testRunIfNeededMigratesLegacySensitiveFieldsAndRedactsSQLite() throws {
        let context = try makeContext(testName: #function)
        let legacyProfile = sampleProfile()
        try context.store.save(legacyProfile, for: ProfileStorageKey.profile)

        try context.migrationService.runIfNeeded()

        let storedProfile = try XCTUnwrap(context.store.load(UserProfile.self, for: ProfileStorageKey.profile))
        let storedSensitiveProfile = try context.sensitiveProfileService.loadProfile()
        let migrationCompleted = try context.store.load(Bool.self, for: ProfileStorageKey.sensitiveMigrationCompleted)

        XCTAssertFalse(storedProfile.hasSensitiveProfileData)
        XCTAssertEqual(storedSensitiveProfile, legacyProfile.sensitiveProfile)
        XCTAssertEqual(storedProfile.merged(with: storedSensitiveProfile), legacyProfile)
        XCTAssertEqual(migrationCompleted, true)
    }

    func testRunIfNeededIsIdempotent() throws {
        let context = try makeContext(testName: #function)
        let legacyProfile = sampleProfile()
        try context.store.save(legacyProfile, for: ProfileStorageKey.profile)

        try context.migrationService.runIfNeeded()
        try context.migrationService.runIfNeeded()

        let storedProfile = try XCTUnwrap(context.store.load(UserProfile.self, for: ProfileStorageKey.profile))
        let storedSensitiveProfile = try context.sensitiveProfileService.loadProfile()

        XCTAssertFalse(storedProfile.hasSensitiveProfileData)
        XCTAssertEqual(storedSensitiveProfile, legacyProfile.sensitiveProfile)
    }

    func testRunIfNeededLeavesLegacyProfileUntouchedWhenSecureWriteFails() throws {
        let context = try makeContext(
            testName: #function,
            keyProvider: FailingSecureStoreKeyProvider()
        )
        let legacyProfile = sampleProfile()
        try context.store.save(legacyProfile, for: ProfileStorageKey.profile)

        XCTAssertThrowsError(try context.migrationService.runIfNeeded())

        let storedProfile = try XCTUnwrap(context.store.load(UserProfile.self, for: ProfileStorageKey.profile))
        let migrationCompleted = try context.store.load(Bool.self, for: ProfileStorageKey.sensitiveMigrationCompleted)

        XCTAssertEqual(storedProfile, legacyProfile)
        XCTAssertNil(migrationCompleted)
    }

    private func makeContext(
        testName: String,
        keyProvider: any SecureStoreKeyProviding = FixedSecureStoreKeyProvider(byte: 7)
    ) throws -> MigrationContext {
        let store = try SQLiteStore(filename: "SensitiveProfileMigration-\(UUID().uuidString).sqlite")
        let secureBaseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("SensitiveProfileMigrationServiceTests", isDirectory: true)
            .appendingPathComponent(testName.replacingOccurrences(of: " ", with: "_"), isDirectory: true)
        try? FileManager.default.removeItem(at: secureBaseURL)

        let secureStore = SecureStore(
            namespace: "migration-tests",
            baseURL: secureBaseURL,
            keyProvider: keyProvider,
            fileManager: .default
        )
        let sensitiveProfileService = SensitiveProfileService(secureStore: secureStore)
        let migrationService = SensitiveProfileMigrationService(
            store: store,
            sensitiveProfileService: sensitiveProfileService
        )

        return MigrationContext(
            store: store,
            sensitiveProfileService: sensitiveProfileService,
            migrationService: migrationService
        )
    }

    private func sampleProfile() -> UserProfile {
        var profile = UserProfile.empty
        profile.selectedScenarios = [.bushfires, .remoteTravel]
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 1)
        profile.supplies = Supplies(waterLitres: 20, foodDays: 4, fuelLitres: 12, batteryCapacity: 60)
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
        profile.medicalNotes = "Keep inhaler accessible"
        profile.emergencyMedicalInfo = EmergencyMedicalInfo(
            criticalConditions: [.asthma],
            severeAllergies: "Peanuts",
            otherCriticalCondition: "",
            bloodType: "O+",
            emergencyMedication: "Ventolin"
        )
        profile.meetingPoints = MeetingPoints(primary: "Front gate", secondary: "Oval", fallback: "Town hall")
        profile.evacuationRoutes = ["South via Main Road"]
        profile.accountabilityCircle = AccountabilityCircle(
            members: [
                AccountabilityMember(name: "Taylor", phone: "0400 000 111", source: .selfUser)
            ]
        )
        return profile
    }
}

private struct MigrationContext {
    let store: SQLiteStore
    let sensitiveProfileService: SensitiveProfileService
    let migrationService: SensitiveProfileMigrationService
}

private struct FailingSecureStoreKeyProvider: SecureStoreKeyProviding {
    func fetchOrCreateKey() throws -> Data {
        throw SecureStoreError.keyUnavailable("Key generation failed")
    }
}
