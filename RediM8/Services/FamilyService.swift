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
        return (try? store.load(UserProfile.self, for: StorageKey.profile)) ?? .empty
    }

    func saveProfile(_ profile: UserProfile) {
        try? store?.save(profile, for: StorageKey.profile)
    }
}
