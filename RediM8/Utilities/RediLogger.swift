import Foundation
import os

/// Centralized structured logging for RediM8.
/// Uses `os.Logger` for efficient, low-overhead, system-integrated logging.
enum RediLogger {
    static let app = Logger(subsystem: "com.redim8.app", category: "app")
    static let routing = Logger(subsystem: "com.redim8.app", category: "routing")
    static let performance = Logger(subsystem: "com.redim8.app", category: "performance")
    static let basemap = Logger(subsystem: "com.redim8.app", category: "basemap")
    static let spatial = Logger(subsystem: "com.redim8.app", category: "spatial")
    static let safety = Logger(subsystem: "com.redim8.app", category: "safety")
    static let persistence = Logger(subsystem: "com.redim8.app", category: "persistence")
    static let preparedness = Logger(subsystem: "com.redim8.app", category: "preparedness")
    static let alerts = Logger(subsystem: "com.redim8.app", category: "alerts")
    static let hazardFeed = Logger(subsystem: "com.redim8.app", category: "hazardFeed")
    static let mesh = Logger(subsystem: "com.redim8.app", category: "mesh")
    static let commerce = Logger(subsystem: "com.redim8.app", category: "commerce")
    static let vault = Logger(subsystem: "com.redim8.app", category: "vault")
    static let diagnostics = Logger(subsystem: "com.redim8.app", category: "diagnostics")
}

// MARK: - Error Logging Helpers

extension Logger {
    /// Executes a throwing operation and returns nil on failure, logging at `.error` level.
    /// Use instead of bare `try?` so failures are never invisible.
    func tryOrNil<T>(
        _ context: @autoclosure () -> String = "",
        operation: () throws -> T
    ) -> T? {
        do {
            return try operation()
        } catch {
            let message = (error as NSError).localizedDescription
            let ctx = context()
            if ctx.isEmpty {
                self.error("Operation failed: \(message, privacy: .public)")
            } else {
                self.error("\(ctx, privacy: .public): \(message, privacy: .public)")
            }
            return nil
        }
    }

    /// Executes a throwing operation, returning a default value on failure and logging at `.error` level.
    func tryOrDefault<T>(
        _ defaultValue: T,
        _ context: @autoclosure () -> String = "",
        operation: () throws -> T
    ) -> T {
        tryOrNil(context(), operation: operation) ?? defaultValue
    }
}
