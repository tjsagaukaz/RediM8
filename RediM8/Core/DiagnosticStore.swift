import Foundation
import SQLite3

// MARK: - Diagnostic Event Model

struct DiagnosticEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let type: DiagnosticType
    let systemState: String
    let error: String?
    let context: [String: String]

    var shortLabel: String {
        switch type {
        case .crash: return "CRASH"
        case .error: return "ERROR"
        case .degraded: return "DEGRADED"
        case .recovery: return "RECOVERY"
        }
    }

    var timestampText: String {
        Self.formatter.string(from: timestamp)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}

enum DiagnosticType: String, Codable, CaseIterable {
    case crash
    case error
    case degraded
    case recovery
}

// MARK: - Diagnostics Logger Protocol

protocol DiagnosticsLogging: Sendable {
    func log(
        _ type: DiagnosticType,
        error: AppError?,
        context: [String: String]
    )
}

// MARK: - Diagnostic Store (SQLite-backed, fully offline, thread-safe)

/// Stores diagnostic events locally in SQLite. Never leaves the device.
/// FIFO eviction at 200 events. No location, no PII, no device identifiers.
final class DiagnosticStore: DiagnosticsLogging, @unchecked Sendable {

    static let shared = DiagnosticStore()

    private static let maxEvents = 200
    private static let tableName = "diagnostic_events"
    private static let dbFilename = "redim8_diagnostics.sqlite"

    private let queue = DispatchQueue(label: "com.redim8.diagnostics.store")
    private var database: OpaquePointer?

    // MARK: - Crash Detection

    private static let cleanShutdownKey = "com.redim8.diagnostics.cleanShutdown"

    /// Call on every app launch BEFORE anything else.
    /// If the flag is `false`, the previous session crashed.
    func detectCrashOnLaunch() {
        let wasClean = UserDefaults.standard.bool(forKey: Self.cleanShutdownKey)
        // Mark as unclean immediately — will be set to true on graceful shutdown
        UserDefaults.standard.set(false, forKey: Self.cleanShutdownKey)

        if !wasClean {
            log(.crash, error: nil, context: [
                "service": "app",
                "detail": "Previous session did not shut down cleanly"
            ])
        }
    }

    /// Call when the app is about to enter background or terminate gracefully.
    func markCleanShutdown() {
        UserDefaults.standard.set(true, forKey: Self.cleanShutdownKey)
    }

    // MARK: - Init

    init() {
        queue.sync {
            do {
                try openDatabase()
                try createTableIfNeeded()
            } catch {
                RediLogger.app.error("DiagnosticStore failed to initialize: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    // MARK: - Logging (non-blocking, thread-safe)

    func log(
        _ type: DiagnosticType,
        error: AppError?,
        context: [String: String]
    ) {
        let event = DiagnosticEvent(
            id: UUID(),
            timestamp: .now,
            type: type,
            systemState: context["systemState"] ?? "unknown",
            error: error?.userMessage ?? context["detail"],
            context: sanitize(context)
        )

        queue.async { [weak self] in
            self?.insert(event)
            self?.evictIfNeeded()
        }
    }

    // MARK: - Read (synchronous, for UI)

    func recentEvents(limit: Int = 50) -> [DiagnosticEvent] {
        queue.sync {
            fetchEvents(limit: limit)
        }
    }

    func allEvents() -> [DiagnosticEvent] {
        queue.sync {
            fetchEvents(limit: Self.maxEvents)
        }
    }

    var eventCount: Int {
        queue.sync {
            countEvents()
        }
    }

    // MARK: - Export

    func exportJSON() -> Data? {
        let events = allEvents()
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

        let healthyCount = events.filter { $0.type == .recovery }.count
        let errorCount = events.filter { $0.type == .error || $0.type == .crash }.count
        let summary: String
        if errorCount == 0 {
            summary = "System Healthy — \(events.count) events recorded"
        } else {
            summary = "\(errorCount) errors, \(healthyCount) recoveries — \(events.count) total events"
        }

        let export: [String: Any] = [
            "app_version": "\(shortVersion) (\(buildNumber))",
            "events": events.map { event in
                [
                    "id": event.id.uuidString,
                    "timestamp": ISO8601DateFormatter().string(from: event.timestamp),
                    "type": event.type.rawValue,
                    "systemState": event.systemState,
                    "error": event.error as Any,
                    "context": event.context
                ] as [String: Any]
            },
            "system_summary": summary,
            "generated_at": ISO8601DateFormatter().string(from: .now)
        ]

        return try? JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Privacy Sanitization

    /// Strips any fields that could contain PII, location, vault content, or device identifiers.
    private func sanitize(_ context: [String: String]) -> [String: String] {
        let forbidden: Set<String> = [
            "location", "latitude", "longitude", "lat", "lon", "coordinate",
            "userId", "user_id", "email", "name", "phone",
            "deviceId", "device_id", "identifierForVendor", "udid",
            "vault", "document", "password", "token", "secret", "key"
        ]

        return context.filter { key, _ in
            !forbidden.contains(key) && !forbidden.contains(key.lowercased())
        }
    }

    // MARK: - SQLite Operations

    private func openDatabase() throws {
        let url = try databaseURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown"
            sqlite3_close(db)
            throw SQLiteStoreError.openFailed(message)
        }
        database = db
    }

    private func createTableIfNeeded() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS \(Self.tableName) (
            id TEXT PRIMARY KEY,
            timestamp REAL NOT NULL,
            type TEXT NOT NULL,
            system_state TEXT NOT NULL,
            error TEXT,
            context TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_diagnostic_timestamp ON \(Self.tableName)(timestamp DESC);
        """
        guard let database else { return }
        var errmsg: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errmsg) == SQLITE_OK else {
            let msg = errmsg.flatMap { String(cString: $0) } ?? "Unknown"
            sqlite3_free(errmsg)
            throw SQLiteStoreError.prepareFailed(msg)
        }
    }

    private func insert(_ event: DiagnosticEvent) {
        guard let database else { return }
        let sql = """
        INSERT OR REPLACE INTO \(Self.tableName) (id, timestamp, type, system_state, error, context)
        VALUES (?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        let idStr = event.id.uuidString
        let contextJSON = (try? JSONEncoder().encode(event.context)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        idStr.withCString { sqlite3_bind_text(stmt, 1, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
        sqlite3_bind_double(stmt, 2, event.timestamp.timeIntervalSince1970)
        event.type.rawValue.withCString { sqlite3_bind_text(stmt, 3, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
        event.systemState.withCString { sqlite3_bind_text(stmt, 4, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }

        if let error = event.error {
            error.withCString { sqlite3_bind_text(stmt, 5, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
        } else {
            sqlite3_bind_null(stmt, 5)
        }

        contextJSON.withCString { sqlite3_bind_text(stmt, 6, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }

        sqlite3_step(stmt)
    }

    private func fetchEvents(limit: Int) -> [DiagnosticEvent] {
        guard let database else { return [] }
        let sql = "SELECT id, timestamp, type, system_state, error, context FROM \(Self.tableName) ORDER BY timestamp DESC LIMIT ?;"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(limit))

        var events: [DiagnosticEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idStr = sqlite3_column_text(stmt, 0).flatMap({ String(cString: $0) }),
                  let id = UUID(uuidString: idStr),
                  let typeStr = sqlite3_column_text(stmt, 2).flatMap({ String(cString: $0) }),
                  let type = DiagnosticType(rawValue: typeStr),
                  let stateStr = sqlite3_column_text(stmt, 3).flatMap({ String(cString: $0) }) else { continue }

            let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
            let error = sqlite3_column_text(stmt, 4).flatMap { String(cString: $0) }
            let contextStr = sqlite3_column_text(stmt, 5).flatMap { String(cString: $0) } ?? "{}"
            let context = (try? JSONDecoder().decode([String: String].self, from: Data(contextStr.utf8))) ?? [:]

            events.append(DiagnosticEvent(
                id: id,
                timestamp: timestamp,
                type: type,
                systemState: stateStr,
                error: error,
                context: context
            ))
        }

        return events
    }

    private func countEvents() -> Int {
        guard let database else { return 0 }
        let sql = "SELECT COUNT(*) FROM \(Self.tableName);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
    }

    private func evictIfNeeded() {
        let count = countEvents()
        guard count > Self.maxEvents else { return }
        guard let database else { return }

        let excess = count - Self.maxEvents
        let sql = "DELETE FROM \(Self.tableName) WHERE id IN (SELECT id FROM \(Self.tableName) ORDER BY timestamp ASC LIMIT ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(excess))
        sqlite3_step(stmt)
    }

    private func databaseURL() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("RediM8").appendingPathComponent(Self.dbFilename)
    }
}
