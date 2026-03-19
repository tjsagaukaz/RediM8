import Foundation

@MainActor
final class FamilyService {
    private enum StorageKey {
        static let profile = "user_profile"
    }

    private let store: SQLiteStore?

    init(store: SQLiteStore?) {
        self.store = store
    }

    func loadProfile() -> UserProfile {
        guard let store else {
            return .empty
        }

        do {
            return try store.load(UserProfile.self, for: StorageKey.profile) ?? .empty
        } catch {
            RediLogger.persistence.error("Failed to load user profile: \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }

    func saveProfile(_ profile: UserProfile) {
        guard let store else {
            return
        }

        do {
            try store.save(profile, for: StorageKey.profile)
        } catch {
            RediLogger.persistence.error("Failed to save user profile: \(error.localizedDescription, privacy: .public)")
        }
    }
}
