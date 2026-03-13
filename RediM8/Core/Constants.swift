import Foundation

enum AppConstants {
    enum AppInfo {
        static let name = "RediM8"
        static let shortVersionKey = "CFBundleShortVersionString"
        static let buildNumberKey = "CFBundleVersion"
    }

    enum Storage {
        static let sqliteQueueLabel = "au.com.redim8.sqlite"
        static let appSupportDirectoryName = AppInfo.name
        static let databaseFilename = "RediM8.sqlite"
        static let appStateTableName = "app_state"
    }

    enum Mesh {
        static let serviceType = "redim8mesh"
        static let fallbackDisplayName = "RediM8 Node"
        static let stealthPulseInterval: TimeInterval = 24
        static let stealthPulseDuration: TimeInterval = 6
    }

    enum Beacon {
        static let lifetime: TimeInterval = 2 * 60 * 60
        static let maxRelayDepth = 2
        static let inactiveRelayLifetime: TimeInterval = 15 * 60
        static let maxRelayBacklogSize = 200
    }
}
