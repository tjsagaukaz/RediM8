import Foundation

final class SensitiveProfileMigrationService {
    private let store: SQLiteStore
    private let sensitiveProfileService: SensitiveProfileService

    init(store: SQLiteStore, sensitiveProfileService: SensitiveProfileService) {
        self.store = store
        self.sensitiveProfileService = sensitiveProfileService
    }

    func runIfNeeded() throws {
        guard !(try isMigrationCompleted()) else {
            return
        }

        guard let storedProfile = try store.load(UserProfile.self, for: ProfileStorageKey.profile) else {
            try markMigrationCompleted()
            return
        }

        if storedProfile.hasSensitiveProfileData {
            try sensitiveProfileService.saveProfile(storedProfile.sensitiveProfile)
            try store.save(storedProfile.redactedForStandardStorage, for: ProfileStorageKey.profile)
        } else if !sensitiveProfileService.hasStoredProfile {
            try markMigrationCompleted()
            return
        }

        try markMigrationCompleted()
    }

    func markMigrationCompleted() throws {
        try store.save(true, for: ProfileStorageKey.sensitiveMigrationCompleted)
    }

    private func isMigrationCompleted() throws -> Bool {
        try store.load(Bool.self, for: ProfileStorageKey.sensitiveMigrationCompleted) ?? false
    }
}
