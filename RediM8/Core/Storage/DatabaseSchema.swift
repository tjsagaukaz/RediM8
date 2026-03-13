import Foundation

struct DatabaseMigration: Equatable {
    let version: Int
    let statements: [String]
}

enum DatabaseSchema {
    static let currentVersion = 1

    static let migrations: [DatabaseMigration] = [
        DatabaseMigration(
            version: 1,
            statements: [
                """
                CREATE TABLE IF NOT EXISTS \(AppConstants.Storage.appStateTableName) (
                    storage_key TEXT PRIMARY KEY,
                    payload BLOB NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """
            ]
        )
    ]
}
