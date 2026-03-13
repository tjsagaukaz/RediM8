import Foundation
import SQLite3

struct MigrationManager {
    let migrations: [DatabaseMigration]

    static let `default` = MigrationManager(migrations: DatabaseSchema.migrations)

    func applyMigrations(to database: OpaquePointer?) throws {
        guard let database else {
            throw SQLiteStoreError.openFailed("Database unavailable")
        }

        let currentVersion = try schemaVersion(in: database)
        let pendingMigrations = migrations
            .sorted { $0.version < $1.version }
            .filter { $0.version > currentVersion }

        for migration in pendingMigrations {
            for statement in migration.statements {
                guard sqlite3_exec(database, statement, nil, nil, nil) == SQLITE_OK else {
                    throw SQLiteStoreError.stepFailed(String(cString: sqlite3_errmsg(database)))
                }
            }

            guard sqlite3_exec(database, "PRAGMA user_version = \(migration.version);", nil, nil, nil) == SQLITE_OK else {
                throw SQLiteStoreError.stepFailed(String(cString: sqlite3_errmsg(database)))
            }
        }
    }

    private func schemaVersion(in database: OpaquePointer) throws -> Int {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(database, "PRAGMA user_version;", -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepareFailed(String(cString: sqlite3_errmsg(database)))
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteStoreError.stepFailed(String(cString: sqlite3_errmsg(database)))
        }

        return Int(sqlite3_column_int(statement, 0))
    }
}
