import Foundation

enum ProfileStorageKey {
    static let profile = "user_profile"
    static let sensitiveProfile = "user_profile.sensitive.v1"
    static let sensitiveMigrationCompleted = "user_profile.sensitive.migration.v1.complete"
}

final class SensitiveProfileService {
    private let secureStore: SecureStore

    init(secureStore: SecureStore) {
        self.secureStore = secureStore
    }

    func loadProfile() throws -> SensitiveProfile {
        try secureStore.load(SensitiveProfile.self, for: ProfileStorageKey.sensitiveProfile) ?? .empty
    }

    func saveProfile(_ profile: SensitiveProfile) throws {
        if profile.hasAnyContent {
            try secureStore.save(profile, for: ProfileStorageKey.sensitiveProfile)
        } else {
            try secureStore.deleteValue(for: ProfileStorageKey.sensitiveProfile)
        }
    }

    var hasStoredProfile: Bool {
        secureStore.containsValue(for: ProfileStorageKey.sensitiveProfile)
    }
}
