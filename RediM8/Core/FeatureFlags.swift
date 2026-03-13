import Foundation

struct AppFeatureFlags: Equatable {
    var usesPersistentSQLiteStorage: Bool
    var enablesStealthMode: Bool
    var enablesLowBatterySurvivalMode: Bool
    var enablesMotionFeatures: Bool

    static let live = AppFeatureFlags(
        usesPersistentSQLiteStorage: true,
        enablesStealthMode: true,
        enablesLowBatterySurvivalMode: true,
        enablesMotionFeatures: true
    )

    static let testing = AppFeatureFlags(
        usesPersistentSQLiteStorage: false,
        enablesStealthMode: true,
        enablesLowBatterySurvivalMode: true,
        enablesMotionFeatures: false
    )
}
