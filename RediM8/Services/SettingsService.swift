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

        do {
            return try store.load(AppSettings.self, for: StorageKey.appSettings)
        } catch {
            RediLogger.persistence.error("Failed to load app settings: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func saveSettings(_ settings: AppSettings) {
        guard let store else {
            return
        }

        do {
            try store.save(settings, for: StorageKey.appSettings)
        } catch {
            RediLogger.persistence.error("Failed to save app settings: \(error.localizedDescription, privacy: .public)")
        }
    }
}
