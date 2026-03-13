import Foundation
import SQLite3

enum SQLiteStoreError: Error {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteStore {
    private let queue = DispatchQueue(label: AppConstants.Storage.sqliteQueueLabel)
    private var database: OpaquePointer?
    private let migrationManager: MigrationManager

    init(
        filename: String = AppConstants.Storage.databaseFilename,
        migrationManager: MigrationManager = .default
    ) throws {
        self.migrationManager = migrationManager
        let url = try Self.databaseURL(filename: filename)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        var db: OpaquePointer?
        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            sqlite3_close(db)
            throw SQLiteStoreError.openFailed(message)
        }

        database = db
        try applyMigrations()
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    func save<T: Encodable>(_ value: T, for key: String) throws {
        let payload = try JSONEncoder.rediM8.encode(value)
        let sql = """
        INSERT INTO \(AppConstants.Storage.appStateTableName) (storage_key, payload, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(storage_key) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at;
        """

        try queue.sync {
            guard let database else {
                throw SQLiteStoreError.openFailed("Database unavailable")
            }

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteStoreError.prepareFailed(String(cString: sqlite3_errmsg(database)))
            }
            defer { sqlite3_finalize(statement) }

            try bind(text: key, at: 1, for: statement, in: database)

            try payload.withUnsafeBytes { bytes in
                guard sqlite3_bind_blob(statement, 2, bytes.baseAddress, Int32(bytes.count), sqliteTransient) == SQLITE_OK else {
                    throw SQLiteStoreError.bindFailed(String(cString: sqlite3_errmsg(database)))
                }
            }

            let updatedAt = ISO8601DateFormatter().string(from: .now)
            try bind(text: updatedAt, at: 3, for: statement, in: database)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SQLiteStoreError.stepFailed(String(cString: sqlite3_errmsg(database)))
            }
        }
    }

    func load<T: Decodable>(_ type: T.Type, for key: String) throws -> T? {
        let sql = "SELECT payload FROM \(AppConstants.Storage.appStateTableName) WHERE storage_key = ? LIMIT 1;"

        return try queue.sync {
            guard let database else {
                throw SQLiteStoreError.openFailed("Database unavailable")
            }

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteStoreError.prepareFailed(String(cString: sqlite3_errmsg(database)))
            }
            defer { sqlite3_finalize(statement) }

            try bind(text: key, at: 1, for: statement, in: database)

            if sqlite3_step(statement) == SQLITE_ROW,
               let blob = sqlite3_column_blob(statement, 0)
            {
                let size = Int(sqlite3_column_bytes(statement, 0))
                let data = Data(bytes: blob, count: size)
                return try JSONDecoder.rediM8.decode(type, from: data)
            }

            return nil
        }
    }

    private func applyMigrations() throws {
        try queue.sync {
            guard let database else {
                throw SQLiteStoreError.openFailed("Database unavailable")
            }
            try migrationManager.applyMigrations(to: database)
        }
    }

    private func bind(text: String, at index: Int32, for statement: OpaquePointer?, in database: OpaquePointer?) throws {
        guard sqlite3_bind_text(statement, index, text, -1, sqliteTransient) == SQLITE_OK else {
            throw SQLiteStoreError.bindFailed(String(cString: sqlite3_errmsg(database)))
        }
    }

    private static func databaseURL(filename: String) throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return baseURL
            .appendingPathComponent(AppConstants.Storage.appSupportDirectoryName, isDirectory: true)
            .appendingPathComponent(filename)
    }
}
