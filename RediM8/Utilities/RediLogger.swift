import os

/// Centralized structured logging for RediM8.
/// Uses `os.Logger` for efficient, low-overhead, system-integrated logging.
enum RediLogger {
    static let app = Logger(subsystem: "com.redim8.app", category: "app")
    static let routing = Logger(subsystem: "com.redim8.app", category: "routing")
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
}
