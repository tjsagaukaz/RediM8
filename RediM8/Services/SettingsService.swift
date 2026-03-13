import Foundation

@MainActor
final class SettingsService {
    private enum StorageKey {
        static let appSettings = "app_settings"
    }

    private let store: SQLiteStore?

    init(store: SQLiteStore?) {
        self.store = store
    }

    func loadStoredSettings() -> AppSettings? {
        guard let store else {
            return nil
        }
        return try? store.load(AppSettings.self, for: StorageKey.appSettings)
    }

    func saveSettings(_ settings: AppSettings) {
        try? store?.save(settings, for: StorageKey.appSettings)
    }
}
