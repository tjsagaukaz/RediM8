import Foundation

@MainActor
final class FamilyService {
    private let store: SQLiteStore?
    private let sensitiveProfileService: SensitiveProfileService?
    private let migrationService: SensitiveProfileMigrationService?
    private var hasEnsuredSensitiveMigration = false

    init(
        store: SQLiteStore?,
        sensitiveProfileService: SensitiveProfileService? = nil,
        migrationService: SensitiveProfileMigrationService? = nil
    ) {
        self.store = store
        let resolvedSensitiveProfileService = sensitiveProfileService ?? store.map {
            SensitiveProfileService(
                secureStore: SecureStore(namespace: "profile-\($0.storageNamespace)")
            )
        }
        self.sensitiveProfileService = resolvedSensitiveProfileService
        self.migrationService = migrationService ?? {
            guard let store, let resolvedSensitiveProfileService else {
                return nil
            }
            return SensitiveProfileMigrationService(
                store: store,
                sensitiveProfileService: resolvedSensitiveProfileService
            )
        }()
    }

    func loadProfile() -> UserProfile {
        guard let store else {
            return .empty
        }

        ensureSensitiveMigrationIfNeeded()

        do {
            let standardProfile = try store.load(UserProfile.self, for: ProfileStorageKey.profile) ?? .empty
            return standardProfile.merged(with: loadSensitiveProfile())
        } catch {
            RediLogger.persistence.error("Failed to load user profile: \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }

    func saveProfile(_ profile: UserProfile) {
        guard let store else {
            return
        }

        let normalizedProfile = profile.withNormalizedChecklistItems()

        do {
            try sensitiveProfileService?.saveProfile(normalizedProfile.sensitiveProfile)
            try store.save(normalizedProfile.redactedForStandardStorage, for: ProfileStorageKey.profile)
            try migrationService?.markMigrationCompleted()
        } catch {
            RediLogger.persistence.error("Failed to save user profile: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func ensureSensitiveMigrationIfNeeded() {
        guard !hasEnsuredSensitiveMigration else {
            return
        }

        do {
            try migrationService?.runIfNeeded()
            hasEnsuredSensitiveMigration = true
        } catch {
            RediLogger.persistence.error("Failed to migrate sensitive profile data: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadSensitiveProfile() -> SensitiveProfile {
        do {
            return try sensitiveProfileService?.loadProfile() ?? .empty
        } catch {
            RediLogger.persistence.error("Failed to load secure profile data: \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }
}
