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
            L10n.tr("settings.privacy.location_mode.off", "Off")
        case .approximate:
            L10n.tr("settings.privacy.location_mode.approximate", "Approximate")
        case .precise:
            L10n.tr("settings.privacy.location_mode.precise", "Precise")
        }
    }

    var subtitle: String {
        switch self {
        case .off:
            L10n.tr(
                "settings.privacy.location_mode.off_subtitle",
                "Do not share coordinates in Signal or Community Report modes"
            )
        case .approximate:
            L10n.tr(
                "settings.privacy.location_mode.approximate_subtitle",
                "Share a rounded area instead of an exact point"
            )
        case .precise:
            L10n.tr(
                "settings.privacy.location_mode.precise_subtitle",
                "Share the current coordinate"
            )
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
            L10n.tr("settings.signal.range.low_power", "Low Power")
        case .balanced:
            L10n.tr("settings.signal.range.balanced", "Balanced")
        case .maximumRange:
            L10n.tr("settings.signal.range.maximum_range", "Maximum Range")
        }
    }

    var subtitle: String {
        switch self {
        case .lowPower:
            L10n.tr(
                "settings.signal.range.low_power_subtitle",
                "Reduced connectivity. Preserve battery by lowering mesh activity."
            )
        case .balanced:
            L10n.tr(
                "settings.signal.range.balanced_subtitle",
                "Recommended. Balanced scanning and battery use."
            )
        case .maximumRange:
            L10n.tr(
                "settings.signal.range.maximum_range_subtitle",
                "Higher battery use. Scan and refresh more aggressively."
            )
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
            L10n.tr("settings.maps.surface.live_tiles", "Live Tiles")
        case .hybrid:
            L10n.tr("settings.maps.surface.hybrid", "Hybrid Tiles")
        case .tactical:
            L10n.tr("settings.maps.surface.tactical", "Offline Tactical")
        }
    }

    var shortTitle: String {
        switch self {
        case .liveTiles:
            L10n.tr("settings.maps.surface.live_tiles_short", "Tiles")
        case .hybrid:
            L10n.tr("settings.maps.surface.hybrid_short", "Hybrid")
        case .tactical:
            L10n.tr("settings.maps.surface.tactical_short", "Offline")
        }
    }

    var subtitle: String {
        switch self {
        case .liveTiles:
            L10n.tr(
                "settings.maps.surface.live_tiles_subtitle",
                "Best all-round road and place context when Apple map data is available."
            )
        case .hybrid:
            L10n.tr(
                "settings.maps.surface.hybrid_subtitle",
                "Satellite-backed context for terrain, fire edges, flood spread, and remote landmarks."
            )
        case .tactical:
            L10n.tr(
                "settings.maps.surface.tactical_subtitle",
                "Guaranteed local tactical surface with RediM8 overlays even when live tiles are missing."
            )
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
    var showsDistanceRings: Bool

    init(
        defaultLayers: Set<MapLayer>,
        showsAirstrips: Bool,
        surfaceMode: MapSurfaceMode = .liveTiles,
        showsDistanceRings: Bool = true
    ) {
        self.defaultLayers = defaultLayers
        self.showsAirstrips = showsAirstrips
        self.surfaceMode = surfaceMode
        self.showsDistanceRings = showsDistanceRings
    }

    private enum CodingKeys: String, CodingKey {
        case defaultLayers
        case showsAirstrips
        case surfaceMode
        case showsDistanceRings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultLayers = try container.decodeIfPresent(Set<MapLayer>.self, forKey: .defaultLayers)
            ?? Set(MapLayer.allCases.filter(\.defaultEnabled))
        showsAirstrips = try container.decodeIfPresent(Bool.self, forKey: .showsAirstrips) ?? false
        surfaceMode = try container.decodeIfPresent(MapSurfaceMode.self, forKey: .surfaceMode) ?? .liveTiles
        showsDistanceRings = try container.decodeIfPresent(Bool.self, forKey: .showsDistanceRings) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultLayers, forKey: .defaultLayers)
        try container.encode(showsAirstrips, forKey: .showsAirstrips)
        try container.encode(surfaceMode, forKey: .surfaceMode)
        try container.encode(showsDistanceRings, forKey: .showsDistanceRings)
    }

    static let `default` = MapSettings(
        defaultLayers: Set(MapLayer.allCases.filter(\.defaultEnabled)),
        showsAirstrips: false,
        surfaceMode: .liveTiles,
        showsDistanceRings: true
    )
}

struct PreparednessSettings: Codable, Equatable {
    var prepScoreNotificationsEnabled: Bool
    var seventyTwoHourPlanAlertsEnabled: Bool
    var goBagRemindersEnabled: Bool
    var officialAlertNotificationsEnabled: Bool
    var officialAlertNotificationScope: OfficialAlertNotificationScope
    var officialAlertNotificationJurisdiction: AustralianJurisdiction?

    private enum CodingKeys: String, CodingKey {
        case prepScoreNotificationsEnabled
        case seventyTwoHourPlanAlertsEnabled
        case goBagRemindersEnabled
        case officialAlertNotificationsEnabled
        case officialAlertNotificationScope
        case officialAlertNotificationJurisdiction
    }

    init(
        prepScoreNotificationsEnabled: Bool,
        seventyTwoHourPlanAlertsEnabled: Bool,
        goBagRemindersEnabled: Bool,
        officialAlertNotificationsEnabled: Bool,
        officialAlertNotificationScope: OfficialAlertNotificationScope,
        officialAlertNotificationJurisdiction: AustralianJurisdiction?
    ) {
        self.prepScoreNotificationsEnabled = prepScoreNotificationsEnabled
        self.seventyTwoHourPlanAlertsEnabled = seventyTwoHourPlanAlertsEnabled
        self.goBagRemindersEnabled = goBagRemindersEnabled
        self.officialAlertNotificationsEnabled = officialAlertNotificationsEnabled
        self.officialAlertNotificationScope = officialAlertNotificationScope
        self.officialAlertNotificationJurisdiction = officialAlertNotificationJurisdiction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prepScoreNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .prepScoreNotificationsEnabled) ?? true
        seventyTwoHourPlanAlertsEnabled = try container.decodeIfPresent(Bool.self, forKey: .seventyTwoHourPlanAlertsEnabled) ?? true
        goBagRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .goBagRemindersEnabled) ?? true
        officialAlertNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .officialAlertNotificationsEnabled) ?? false
        officialAlertNotificationScope = try container.decodeIfPresent(OfficialAlertNotificationScope.self, forKey: .officialAlertNotificationScope) ?? .local
        officialAlertNotificationJurisdiction = try container.decodeIfPresent(AustralianJurisdiction.self, forKey: .officialAlertNotificationJurisdiction)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prepScoreNotificationsEnabled, forKey: .prepScoreNotificationsEnabled)
        try container.encode(seventyTwoHourPlanAlertsEnabled, forKey: .seventyTwoHourPlanAlertsEnabled)
        try container.encode(goBagRemindersEnabled, forKey: .goBagRemindersEnabled)
        try container.encode(officialAlertNotificationsEnabled, forKey: .officialAlertNotificationsEnabled)
        try container.encode(officialAlertNotificationScope, forKey: .officialAlertNotificationScope)
        try container.encodeIfPresent(officialAlertNotificationJurisdiction, forKey: .officialAlertNotificationJurisdiction)
    }

    static let `default` = PreparednessSettings(
        prepScoreNotificationsEnabled: true,
        seventyTwoHourPlanAlertsEnabled: true,
        goBagRemindersEnabled: true,
        officialAlertNotificationsEnabled: false,
        officialAlertNotificationScope: .local,
        officialAlertNotificationJurisdiction: nil
    )
}

enum OfficialAlertNotificationScope: String, CaseIterable, Codable, Identifiable {
    case local
    case state
    case australia

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local:
            L10n.tr("settings.preparedness.official_alert_notifications.scope.local", "Local")
        case .state:
            L10n.tr("settings.preparedness.official_alert_notifications.scope.state", "State")
        case .australia:
            L10n.tr("settings.preparedness.official_alert_notifications.scope.australia", "Australia")
        }
    }

    var subtitle: String {
        switch self {
        case .local:
            L10n.tr(
                "settings.preparedness.official_alert_notifications.scope.local_subtitle",
                "Alerts matched to your area and installed coverage"
            )
        case .state:
            L10n.tr(
                "settings.preparedness.official_alert_notifications.scope.state_subtitle",
                "One state or territory feed for family or travel context"
            )
        case .australia:
            L10n.tr(
                "settings.preparedness.official_alert_notifications.scope.australia_subtitle",
                "All cached official feeds across Australia"
            )
        }
    }
}

struct AssistantSettings: Codable, Equatable {
    var offlineAISummariesEnabled: Bool

    static let `default` = AssistantSettings(
        offlineAISummariesEnabled: true
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
    var assistant: AssistantSettings
    var battery: BatterySettings

    init(
        privacy: PrivacySettings,
        signalDiscovery: SignalDiscoverySettings,
        maps: MapSettings,
        preparedness: PreparednessSettings,
        assistant: AssistantSettings,
        battery: BatterySettings
    ) {
        self.privacy = privacy
        self.signalDiscovery = signalDiscovery
        self.maps = maps
        self.preparedness = preparedness
        self.assistant = assistant
        self.battery = battery
    }

    private enum CodingKeys: String, CodingKey {
        case privacy
        case signalDiscovery
        case maps
        case preparedness
        case assistant
        case battery
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        privacy = try container.decodeIfPresent(PrivacySettings.self, forKey: .privacy) ?? .default
        signalDiscovery = try container.decodeIfPresent(SignalDiscoverySettings.self, forKey: .signalDiscovery) ?? .default
        maps = try container.decodeIfPresent(MapSettings.self, forKey: .maps) ?? .default
        preparedness = try container.decodeIfPresent(PreparednessSettings.self, forKey: .preparedness) ?? .default
        assistant = try container.decodeIfPresent(AssistantSettings.self, forKey: .assistant) ?? .default
        battery = try container.decodeIfPresent(BatterySettings.self, forKey: .battery) ?? .default
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(privacy, forKey: .privacy)
        try container.encode(signalDiscovery, forKey: .signalDiscovery)
        try container.encode(maps, forKey: .maps)
        try container.encode(preparedness, forKey: .preparedness)
        try container.encode(assistant, forKey: .assistant)
        try container.encode(battery, forKey: .battery)
    }

    static let `default` = AppSettings(
        privacy: .default,
        signalDiscovery: .default,
        maps: .default,
        preparedness: .default,
        assistant: .default,
        battery: .default
    )

    static let emergencySafe = AppSettings(
        privacy: PrivacySettings(
            isAnonymousModeEnabled: false,
            locationShareMode: .approximate,
            showsDeviceName: false
        ),
        signalDiscovery: SignalDiscoverySettings(
            discoversNearbyUsers: true,
            allowsBeaconBroadcasts: false,
            autoAcceptsMessages: true,
            rangeMode: .balanced
        ),
        maps: MapSettings(
            defaultLayers: [.waterPoints, .evacuationPoints, .officialAlerts],
            showsAirstrips: false,
            surfaceMode: .liveTiles,
            showsDistanceRings: true
        ),
        preparedness: .default,
        assistant: .default,
        battery: .default
    )
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (self * factor).rounded() / factor
    }
}
