import CoreLocation
import Foundation

enum BeaconTone: String, Codable, Equatable {
    case safe
    case resource
    case help
    case hazard
}

enum BeaconType: String, CaseIterable, Codable, Identifiable {
    case safeLocation = "safe_location"
    case fireSpotted = "fire_spotted"
    case floodedRoad = "flooded_road"
    case roadBlocked = "road_blocked"
    case medicalHelp = "medical_help"
    case waterAvailable = "water_available"
    case fuelAvailable = "fuel_available"
    case shelter
    case needHelp = "need_help"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safeLocation:
            "Safe Location"
        case .fireSpotted:
            "Fire Report"
        case .floodedRoad:
            "Flood Report"
        case .roadBlocked:
            "Road Blocked"
        case .medicalHelp:
            "Medical Emergency"
        case .waterAvailable:
            "Water Available"
        case .fuelAvailable:
            "Fuel Available"
        case .shelter:
            "Safe Shelter"
        case .needHelp:
            "Help Needed"
        }
    }

    var defaultStatusText: String {
        switch self {
        case .safeLocation:
            "Safe"
        case .fireSpotted:
            "Fire reported"
        case .floodedRoad:
            "Flooded road"
        case .roadBlocked:
            "Road blocked"
        case .shelter:
            "Safe shelter"
        case .medicalHelp:
            "Medical emergency"
        case .waterAvailable:
            "Water available"
        case .fuelAvailable:
            "Fuel available"
        case .needHelp:
            "Need assistance"
        }
    }

    var buttonTitle: String {
        switch self {
        case .safeLocation:
            "Safe"
        case .fireSpotted:
            "Fire"
        case .floodedRoad:
            "Flood"
        case .roadBlocked:
            "Blocked road"
        case .medicalHelp:
            "Medical emergency"
        case .waterAvailable:
            "Water available"
        case .fuelAvailable:
            "Fuel available"
        case .shelter:
            "Safe shelter"
        case .needHelp:
            "Need help"
        }
    }

    var symbolName: String {
        switch self {
        case .safeLocation:
            "meeting_point"
        case .fireSpotted:
            "fire_trail"
        case .floodedRoad:
            "flood"
        case .roadBlocked:
            "road_blocked"
        case .medicalHelp:
            "medical"
        case .waterAvailable:
            "water"
        case .fuelAvailable:
            "fuel"
        case .shelter:
            "shelter"
        case .needHelp:
            "alert"
        }
    }

    var tone: BeaconTone {
        switch self {
        case .safeLocation, .shelter:
            .safe
        case .waterAvailable, .fuelAvailable:
            .resource
        case .medicalHelp, .needHelp:
            .help
        case .fireSpotted, .floodedRoad, .roadBlocked:
            .hazard
        }
    }

    var priority: Int {
        switch self {
        case .needHelp:
            0
        case .medicalHelp:
            1
        case .fireSpotted:
            2
        case .roadBlocked:
            3
        case .floodedRoad:
            4
        case .shelter:
            5
        case .safeLocation:
            6
        case .waterAvailable:
            7
        case .fuelAvailable:
            8
        }
    }

    var defaultResources: [BeaconResource] {
        switch self {
        case .medicalHelp:
            [.firstAid]
        case .waterAvailable:
            [.water]
        case .fuelAvailable:
            [.fuel]
        case .shelter:
            [.shelter]
        case .safeLocation, .fireSpotted, .floodedRoad, .roadBlocked, .needHelp:
            []
        }
    }

    var defaultLifetime: TimeInterval {
        switch self {
        case .fireSpotted, .medicalHelp, .needHelp:
            2 * 60 * 60
        case .floodedRoad, .roadBlocked:
            6 * 60 * 60
        case .waterAvailable, .fuelAvailable, .safeLocation:
            24 * 60 * 60
        case .shelter:
            48 * 60 * 60
        }
    }

    var maxRelayDepth: Int {
        AppConstants.Beacon.maxRelayDepth
    }

    var staleAfter: TimeInterval {
        switch self {
        case .fireSpotted, .medicalHelp, .needHelp:
            30 * 60
        case .floodedRoad, .roadBlocked:
            2 * 60 * 60
        case .waterAvailable, .fuelAvailable:
            8 * 60 * 60
        case .safeLocation:
            6 * 60 * 60
        case .shelter:
            12 * 60 * 60
        }
    }

    var expiryBadgeTitle: String {
        switch self {
        case .fireSpotted, .medicalHelp, .needHelp:
            "2h expiry"
        case .floodedRoad, .roadBlocked:
            "6h expiry"
        case .waterAvailable, .fuelAvailable, .safeLocation:
            "24h expiry"
        case .shelter:
            "48h expiry"
        }
    }

    var lifetimeSummary: String {
        switch self {
        case .fireSpotted, .medicalHelp, .needHelp:
            "Expires in about 2 hours unless refreshed."
        case .floodedRoad, .roadBlocked:
            "Expires in about 6 hours unless refreshed."
        case .waterAvailable, .fuelAvailable, .safeLocation:
            "Expires in about 24 hours unless refreshed."
        case .shelter:
            "Expires in about 48 hours unless refreshed."
        }
    }

    var locationPrompt: String {
        switch self {
        case .fireSpotted:
            "Fire location or landmark"
        case .floodedRoad:
            "Flooded road or crossing"
        case .roadBlocked:
            "Blocked road or landmark"
        case .medicalHelp:
            "Medical location or landmark"
        case .waterAvailable:
            "Water source name or landmark"
        case .fuelAvailable:
            "Fuel location or station name"
        case .shelter:
            "Shelter name or landmark"
        case .safeLocation:
            "Safe location label"
        case .needHelp:
            "Help location or landmark"
        }
    }

    var notePrompt: String {
        switch self {
        case .fireSpotted:
            "Optional note, e.g. Fire spreading east"
        case .floodedRoad:
            "Optional note, e.g. Bridge under water"
        case .roadBlocked:
            "Optional note, e.g. Fallen trees blocking both lanes"
        case .medicalHelp:
            "Optional note, e.g. Injury needs first aid"
        case .waterAvailable:
            "Optional note, e.g. Farm tank available"
        case .fuelAvailable:
            "Optional note, e.g. Diesel only"
        case .shelter:
            "Optional note, e.g. Hall open with toilets"
        case .safeLocation:
            "Optional note, e.g. Safe to regroup here"
        case .needHelp:
            "Optional note, e.g. Need pickup"
        }
    }

    var isPriorityReport: Bool {
        switch tone {
        case .help, .hazard:
            true
        case .safe, .resource:
            false
        }
    }

    var isSituationReport: Bool {
        switch self {
        case .fireSpotted, .floodedRoad, .roadBlocked, .medicalHelp, .waterAvailable, .fuelAvailable, .shelter:
            true
        case .safeLocation, .needHelp:
            false
        }
    }

    var supportsEmergencyMedicalDisclosure: Bool {
        switch self {
        case .medicalHelp, .needHelp:
            true
        case .safeLocation, .fireSpotted, .floodedRoad, .roadBlocked, .waterAvailable, .fuelAvailable, .shelter:
            false
        }
    }

    var defaultSeverity: BeaconSeverity {
        switch self {
        case .safeLocation:
            .low
        case .waterAvailable, .fuelAvailable, .shelter:
            .moderate
        case .floodedRoad, .roadBlocked, .needHelp:
            .high
        case .fireSpotted, .medicalHelp:
            .critical
        }
    }

    var defaultConfidence: BeaconConfidence {
        .medium
    }

    var supportsDirectionHint: Bool {
        switch self {
        case .fireSpotted, .floodedRoad:
            true
        case .safeLocation, .roadBlocked, .medicalHelp, .waterAvailable, .fuelAvailable, .shelter, .needHelp:
            false
        }
    }

    var supportsRouteCondition: Bool {
        switch self {
        case .floodedRoad, .roadBlocked:
            true
        case .safeLocation, .fireSpotted, .medicalHelp, .waterAvailable, .fuelAvailable, .shelter, .needHelp:
            false
        }
    }

    var supportsWaterSafety: Bool {
        self == .waterAvailable
    }

    var supportsShelterStatus: Bool {
        self == .shelter
    }

    var supportsShelterCapacityNote: Bool {
        self == .shelter
    }

    var supportsBatteryLevel: Bool {
        switch self {
        case .medicalHelp, .needHelp:
            true
        case .safeLocation, .fireSpotted, .floodedRoad, .roadBlocked, .waterAvailable, .fuelAvailable, .shelter:
            false
        }
    }

    var directionLabel: String {
        switch self {
        case .fireSpotted:
            "Spread"
        case .floodedRoad:
            "Movement"
        case .safeLocation, .roadBlocked, .medicalHelp, .waterAvailable, .fuelAvailable, .shelter, .needHelp:
            "Direction"
        }
    }

    var detailPrompt: String? {
        switch self {
        case .fireSpotted:
            "Spread direction or movement"
        case .floodedRoad:
            "Water movement or crossing direction"
        case .safeLocation, .roadBlocked, .medicalHelp, .waterAvailable, .fuelAvailable, .shelter, .needHelp:
            nil
        }
    }

    var defaultSignalMetadata: BeaconSignalMetadata {
        BeaconSignalMetadata(
            severity: defaultSeverity,
            confidence: defaultConfidence,
            directionHint: nil,
            routeCondition: supportsRouteCondition ? .blocked : nil,
            waterSafety: supportsWaterSafety ? .unknown : nil,
            shelterStatus: supportsShelterStatus ? .unknown : nil,
            capacityNote: nil,
            batteryLevelPercent: nil
        )
    }
}

enum BeaconSeverity: String, Codable, CaseIterable, Identifiable {
    case low
    case moderate
    case high
    case critical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low:
            "Low"
        case .moderate:
            "Moderate"
        case .high:
            "High"
        case .critical:
            "Critical"
        }
    }

    var badgeTitle: String {
        "Severity \(title)"
    }

    var rank: Int {
        switch self {
        case .low:
            0
        case .moderate:
            1
        case .high:
            2
        case .critical:
            3
        }
    }
}

enum BeaconConfidence: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low:
            "Low"
        case .medium:
            "Medium"
        case .high:
            "High"
        }
    }

    var badgeTitle: String {
        "Confidence \(title)"
    }
}

enum BeaconRouteCondition: String, Codable, CaseIterable, Identifiable {
    case blocked
    case limited
    case passable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blocked:
            "Blocked"
        case .limited:
            "Limited"
        case .passable:
            "Passable"
        }
    }
}

enum BeaconWaterSafety: String, Codable, CaseIterable, Identifiable {
    case unknown
    case treatBeforeUse = "treat_before_use"
    case safe
    case unsafe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unknown:
            "Unknown"
        case .treatBeforeUse:
            "Treat Before Use"
        case .safe:
            "Safe"
        case .unsafe:
            "Unsafe"
        }
    }
}

enum BeaconShelterStatus: String, Codable, CaseIterable, Identifiable {
    case unknown
    case open
    case limited
    case full
    case closed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unknown:
            "Unknown"
        case .open:
            "Open"
        case .limited:
            "Limited"
        case .full:
            "Full"
        case .closed:
            "Closed"
        }
    }
}

struct BeaconSignalMetadata: Codable, Equatable, Hashable {
    var severity: BeaconSeverity
    var confidence: BeaconConfidence
    var directionHint: String?
    var routeCondition: BeaconRouteCondition?
    var waterSafety: BeaconWaterSafety?
    var shelterStatus: BeaconShelterStatus?
    var capacityNote: String?
    var batteryLevelPercent: Int?

    init(
        severity: BeaconSeverity,
        confidence: BeaconConfidence,
        directionHint: String? = nil,
        routeCondition: BeaconRouteCondition? = nil,
        waterSafety: BeaconWaterSafety? = nil,
        shelterStatus: BeaconShelterStatus? = nil,
        capacityNote: String? = nil,
        batteryLevelPercent: Int? = nil
    ) {
        self.severity = severity
        self.confidence = confidence
        self.directionHint = directionHint?.nilIfBlank
        self.routeCondition = routeCondition
        self.waterSafety = waterSafety
        self.shelterStatus = shelterStatus
        self.capacityNote = capacityNote?.nilIfBlank
        self.batteryLevelPercent = batteryLevelPercent.map { min(max($0, 0), 100) }
    }

    func highlights(for type: BeaconType) -> [(label: String, value: String)] {
        var items: [(String, String)] = [
            ("Severity", severity.title),
            ("Confidence", confidence.title)
        ]

        if type.supportsDirectionHint, let directionHint = directionHint?.nilIfBlank {
            items.append((type.directionLabel, directionHint))
        }

        if type.supportsRouteCondition, let routeCondition {
            items.append(("Route", routeCondition.title))
        }

        if type.supportsWaterSafety, let waterSafety {
            items.append(("Water", waterSafety.title))
        }

        if type.supportsShelterStatus, let shelterStatus {
            items.append(("Shelter", shelterStatus.title))
        }

        if type.supportsShelterCapacityNote, let capacityNote = capacityNote?.nilIfBlank {
            items.append(("Capacity", capacityNote))
        }

        if type.supportsBatteryLevel, let batteryLevelPercent {
            items.append(("Battery", batteryLevelPercent.percentageText))
        }

        return items
    }
}

enum BeaconResource: String, CaseIterable, Codable, Identifiable, Hashable {
    case water
    case firstAid = "first_aid"
    case fuel
    case power
    case shelter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water:
            "Water"
        case .firstAid:
            "First Aid"
        case .fuel:
            "Fuel"
        case .power:
            "Power"
        case .shelter:
            "Shelter"
        }
    }
}

enum BeaconState: String, Codable, Equatable {
    case active
    case inactive
}

struct CommunityBeacon: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let nodeID: String
    var type: BeaconType
    var state: BeaconState
    var latitude: Double
    var longitude: Double
    var locationName: String
    var statusText: String
    var message: String
    var resources: [BeaconResource]
    var createdAt: Date
    var updatedAt: Date
    var expiresAt: Date
    var relayDepth: Int
    var displayName: String?
    var showsName: Bool
    var emergencyMedicalSummary: String?
    var signalMetadata: BeaconSignalMetadata

    enum CodingKeys: String, CodingKey {
        case id
        case nodeID = "node_id"
        case type
        case state = "status"
        case latitude = "lat"
        case longitude = "lng"
        case locationName = "location_label"
        case statusText = "status_text"
        case message
        case resources
        case createdAt = "created_at"
        case updatedAt = "timestamp"
        case expiresAt = "expires_at"
        case relayDepth = "relay_depth"
        case displayName = "display_name"
        case showsName = "shows_name"
        case emergencyMedicalSummary = "emergency_medical_summary"
        case signalMetadata = "signal_metadata"
    }

    init(
        id: String,
        nodeID: String,
        type: BeaconType,
        state: BeaconState,
        latitude: Double,
        longitude: Double,
        locationName: String,
        statusText: String,
        message: String,
        resources: [BeaconResource],
        createdAt: Date,
        updatedAt: Date,
        expiresAt: Date,
        relayDepth: Int,
        displayName: String?,
        showsName: Bool,
        emergencyMedicalSummary: String?,
        signalMetadata: BeaconSignalMetadata? = nil
    ) {
        self.id = id
        self.nodeID = nodeID
        self.type = type
        self.state = state
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.statusText = statusText
        self.message = message
        self.resources = resources
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
        self.relayDepth = relayDepth
        self.displayName = displayName
        self.showsName = showsName
        self.emergencyMedicalSummary = emergencyMedicalSummary
        self.signalMetadata = signalMetadata ?? type.defaultSignalMetadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(BeaconType.self, forKey: .type)

        self.init(
            id: try container.decode(String.self, forKey: .id),
            nodeID: try container.decode(String.self, forKey: .nodeID),
            type: type,
            state: try container.decode(BeaconState.self, forKey: .state),
            latitude: try container.decode(Double.self, forKey: .latitude),
            longitude: try container.decode(Double.self, forKey: .longitude),
            locationName: try container.decode(String.self, forKey: .locationName),
            statusText: try container.decode(String.self, forKey: .statusText),
            message: try container.decode(String.self, forKey: .message),
            resources: try container.decode([BeaconResource].self, forKey: .resources),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            expiresAt: try container.decode(Date.self, forKey: .expiresAt),
            relayDepth: try container.decode(Int.self, forKey: .relayDepth),
            displayName: try container.decodeIfPresent(String.self, forKey: .displayName),
            showsName: try container.decode(Bool.self, forKey: .showsName),
            emergencyMedicalSummary: try container.decodeIfPresent(String.self, forKey: .emergencyMedicalSummary),
            signalMetadata: try container.decodeIfPresent(BeaconSignalMetadata.self, forKey: .signalMetadata) ?? type.defaultSignalMetadata
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(nodeID, forKey: .nodeID)
        try container.encode(type, forKey: .type)
        try container.encode(state, forKey: .state)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(locationName, forKey: .locationName)
        try container.encode(statusText, forKey: .statusText)
        try container.encode(message, forKey: .message)
        try container.encode(resources, forKey: .resources)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(expiresAt, forKey: .expiresAt)
        try container.encode(relayDepth, forKey: .relayDepth)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(showsName, forKey: .showsName)
        try container.encode(emergencyMedicalSummary, forKey: .emergencyMedicalSummary)
        try container.encode(signalMetadata, forKey: .signalMetadata)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var nodeLabel: String {
        "Node \(nodeID)"
    }

    var displayLabel: String {
        if showsName, let displayName, let visibleName = displayName.nilIfBlank {
            return visibleName
        }
        return nodeLabel
    }

    var isExpired: Bool {
        state == .inactive || expiresAt <= .now
    }

    var isRelayed: Bool {
        relayDepth > 0
    }

    var relayStateKey: String {
        let milliseconds = Int((updatedAt.timeIntervalSince1970 * 1_000).rounded())
        return "\(id)|\(state.rawValue)|\(milliseconds)"
    }

    var relayExpiresAt: Date {
        if state == .inactive {
            return updatedAt.addingTimeInterval(AppConstants.Beacon.inactiveRelayLifetime)
        }

        let staleCutoff = updatedAt.addingTimeInterval(type.staleAfter)
        return min(expiresAt, staleCutoff)
    }

    func canRelayFurther(reference: Date = .now) -> Bool {
        relayDepth < type.maxRelayDepth && relayExpiresAt > reference
    }

    var relayTrustLabel: String {
        switch relayDepth {
        case ...0:
            "Direct nearby"
        case 1:
            "Relayed 1 hop"
        default:
            "Relayed \(relayDepth) hops"
        }
    }

    var relayDelayNotice: String? {
        guard relayDepth > 0 else {
            return nil
        }

        return "Relayed report. This may have moved across nearby RediM8 devices and can be delayed."
    }

    var sharedEmergencyMedicalSummary: String? {
        emergencyMedicalSummary?.nilIfBlank
    }

    var signalHighlights: [(label: String, value: String)] {
        signalMetadata.highlights(for: type)
    }

    var severity: BeaconSeverity {
        signalMetadata.severity
    }

    var confidence: BeaconConfidence {
        signalMetadata.confidence
    }

    var summaryLines: [String] {
        var lines = [statusText]

        lines.append(contentsOf: signalHighlights.map { "\($0.label): \($0.value)" })

        if !resources.isEmpty {
            lines.append(resources.map(\.title).joined(separator: ", "))
        }

        if let message = message.nilIfBlank {
            lines.append(message)
        }

        if let sharedEmergencyMedicalSummary {
            lines.append("Medical note: \(sharedEmergencyMedicalSummary)")
        }

        if let locationName = locationName.nilIfBlank {
            lines.append(locationName)
        }

        return lines
    }
}
