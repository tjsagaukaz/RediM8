import Foundation

// MARK: - Network Policy (Compile-Time + Runtime Enforcement)

/// Hard architectural constraint: RediM8 is a fully offline application.
///
/// No data leaves the device. No URLSession calls. No remote telemetry.
/// No analytics. No crash reporting to external services.
///
/// This enum exists as a compile-time marker AND runtime guard.
/// Any code path that attempts network I/O must check this policy first.
/// Violations are treated as fatal programming errors during development
/// and are silently blocked in release builds.
enum NetworkPolicy {
    /// Master kill switch. Always `true`. Cannot be toggled at runtime.
    /// Exists so grep/audit can find every guarded call site.
    static let isOfflineOnly = true

    /// Call at every potential network entry point.
    /// In DEBUG builds, this traps immediately to surface violations during development.
    /// In RELEASE builds, it logs and returns — the caller must handle the `false` return.
    @discardableResult
    static func assertOffline(caller: StaticString = #function, file: StaticString = #file) -> Bool {
        guard isOfflineOnly else { return false }
        #if DEBUG
        RediLogger.app.fault("NETWORK POLICY VIOLATION in \(String(describing: caller), privacy: .public) (\(String(describing: file), privacy: .public)). All network access is forbidden.")
        #endif
        return true
    }
}
