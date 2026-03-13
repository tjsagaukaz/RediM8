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

    var summaryLines: [String] {
        var lines = [statusText]

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
