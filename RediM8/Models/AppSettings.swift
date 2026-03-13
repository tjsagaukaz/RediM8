import CoreLocation
import Foundation

enum LocationShareMode: String, CaseIterable, Codable, Identifiable {
    case off
    case approximate
    case precise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            "Off"
        case .approximate:
            "Approximate"
        case .precise:
            "Precise"
        }
    }

    var subtitle: String {
        switch self {
        case .off:
            "Do not share coordinates in Signal or Community Report modes"
        case .approximate:
            "Share a rounded area instead of an exact point"
        case .precise:
            "Share the current coordinate"
        }
    }

    func sharedCoordinate(from coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        switch self {
        case .off:
            nil
        case .approximate:
            CLLocationCoordinate2D(
                latitude: coordinate.latitude.rounded(toPlaces: 2),
                longitude: coordinate.longitude.rounded(toPlaces: 2)
            )
        case .precise:
            coordinate
        }
    }
}

enum SignalRangeMode: String, CaseIterable, Codable, Identifiable {
    case lowPower = "low_power"
    case balanced
    case maximumRange = "maximum_range"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lowPower:
            "Low Power"
        case .balanced:
            "Balanced"
        case .maximumRange:
            "Maximum Range"
        }
    }

    var subtitle: String {
        switch self {
        case .lowPower:
            "Reduce mesh activity to preserve battery"
        case .balanced:
            "Balanced scanning and battery use"
        case .maximumRange:
            "Scan and refresh more aggressively"
        }
    }

    var beaconBroadcastInterval: TimeInterval {
        switch self {
        case .lowPower:
            30
        case .balanced:
            15
        case .maximumRange:
            8
        }
    }

    var autoInviteCooldown: TimeInterval {
        switch self {
        case .lowPower:
            35
        case .balanced:
            20
        case .maximumRange:
            8
        }
    }

    var invitationTimeout: TimeInterval {
        switch self {
        case .lowPower:
            6
        case .balanced:
            10
        case .maximumRange:
            15
        }
    }
}

struct PrivacySettings: Codable, Equatable {
    var isAnonymousModeEnabled: Bool
    var locationShareMode: LocationShareMode
    var showsDeviceName: Bool

    static let `default` = PrivacySettings(
        isAnonymousModeEnabled: true,
        locationShareMode: .approximate,
        showsDeviceName: false
    )
}

struct SignalDiscoverySettings: Codable, Equatable {
    var discoversNearbyUsers: Bool
    var allowsBeaconBroadcasts: Bool
    var autoAcceptsMessages: Bool
    var rangeMode: SignalRangeMode

    static let `default` = SignalDiscoverySettings(
        discoversNearbyUsers: true,
        allowsBeaconBroadcasts: false,
        autoAcceptsMessages: true,
        rangeMode: .balanced
    )
}

enum MapSurfaceMode: String, CaseIterable, Codable, Identifiable {
    case liveTiles = "live_tiles"
    case hybrid
    case tactical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .liveTiles:
            "Live Tiles"
        case .hybrid:
            "Hybrid Tiles"
        case .tactical:
            "Offline Tactical"
        }
    }

    var shortTitle: String {
        switch self {
        case .liveTiles:
            "Tiles"
        case .hybrid:
            "Hybrid"
        case .tactical:
            "Offline"
        }
    }

    var subtitle: String {
        switch self {
        case .liveTiles:
            "Best all-round road and place context when Apple map data is available."
        case .hybrid:
            "Satellite-backed context for terrain, fire edges, flood spread, and remote landmarks."
        case .tactical:
            "Guaranteed local tactical surface with RediM8 overlays even when live tiles are missing."
        }
    }

    var usesAppleTiles: Bool {
        switch self {
        case .liveTiles, .hybrid:
            true
        case .tactical:
            false
        }
    }
}

struct MapSettings: Codable, Equatable {
    var defaultLayers: Set<MapLayer>
    var showsAirstrips: Bool
    var surfaceMode: MapSurfaceMode

    init(
        defaultLayers: Set<MapLayer>,
        showsAirstrips: Bool,
        surfaceMode: MapSurfaceMode = .liveTiles
    ) {
        self.defaultLayers = defaultLayers
        self.showsAirstrips = showsAirstrips
        self.surfaceMode = surfaceMode
    }

    private enum CodingKeys: String, CodingKey {
        case defaultLayers
        case showsAirstrips
        case surfaceMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultLayers = try container.decodeIfPresent(Set<MapLayer>.self, forKey: .defaultLayers)
            ?? Set(MapLayer.allCases.filter(\.defaultEnabled))
        showsAirstrips = try container.decodeIfPresent(Bool.self, forKey: .showsAirstrips) ?? false
        surfaceMode = try container.decodeIfPresent(MapSurfaceMode.self, forKey: .surfaceMode) ?? .liveTiles
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultLayers, forKey: .defaultLayers)
        try container.encode(showsAirstrips, forKey: .showsAirstrips)
        try container.encode(surfaceMode, forKey: .surfaceMode)
    }

    static let `default` = MapSettings(
        defaultLayers: Set(MapLayer.allCases.filter(\.defaultEnabled)),
        showsAirstrips: false,
        surfaceMode: .liveTiles
    )
}

struct PreparednessSettings: Codable, Equatable {
    var prepScoreNotificationsEnabled: Bool
    var seventyTwoHourPlanAlertsEnabled: Bool
    var goBagRemindersEnabled: Bool

    static let `default` = PreparednessSettings(
        prepScoreNotificationsEnabled: true,
        seventyTwoHourPlanAlertsEnabled: true,
        goBagRemindersEnabled: true
    )
}

struct BatterySettings: Codable, Equatable {
    var enablesSurvivalModeAtFifteenPercent: Bool
    var disablesBackgroundScanning: Bool
    var reducesMapAnimations: Bool

    static let `default` = BatterySettings(
        enablesSurvivalModeAtFifteenPercent: true,
        disablesBackgroundScanning: true,
        reducesMapAnimations: true
    )
}

struct AppSettings: Codable, Equatable {
    var privacy: PrivacySettings
    var signalDiscovery: SignalDiscoverySettings
    var maps: MapSettings
    var preparedness: PreparednessSettings
    var battery: BatterySettings

    static let `default` = AppSettings(
        privacy: .default,
        signalDiscovery: .default,
        maps: .default,
        preparedness: .default,
        battery: .default
    )
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (self * factor).rounded() / factor
    }
}
