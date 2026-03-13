import CoreLocation
import Foundation

enum AustralianJurisdiction: String, CaseIterable, Codable, Hashable, Identifiable {
    case act
    case nsw
    case nt
    case qld
    case sa
    case tas
    case vic
    case wa

    var id: String { rawValue }

    var title: String {
        switch self {
        case .act:
            "Australian Capital Territory"
        case .nsw:
            "New South Wales"
        case .nt:
            "Northern Territory"
        case .qld:
            "Queensland"
        case .sa:
            "South Australia"
        case .tas:
            "Tasmania"
        case .vic:
            "Victoria"
        case .wa:
            "Western Australia"
        }
    }

    var shortTitle: String {
        switch self {
        case .act:
            "ACT"
        case .nsw:
            "NSW"
        case .nt:
            "NT"
        case .qld:
            "QLD"
        case .sa:
            "SA"
        case .tas:
            "TAS"
        case .vic:
            "VIC"
        case .wa:
            "WA"
        }
    }

    static func containing(_ coordinate: CLLocationCoordinate2D) -> AustralianJurisdiction? {
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude

        if (-43.9 ... -39.0).contains(latitude), (143.0 ... 149.0).contains(longitude) {
            return .tas
        }

        if (-35.95 ... -35.08).contains(latitude), (148.75 ... 149.45).contains(longitude) {
            return .act
        }

        if longitude < 129.05, (-35.5 ... -13.0).contains(latitude) {
            return .wa
        }

        if (129.0 ... 138.1).contains(longitude), (-26.2 ... -10.8).contains(latitude) {
            return .nt
        }

        if (138.0 ... 154.5).contains(longitude), (-29.3 ... -9.0).contains(latitude) {
            return .qld
        }

        if (140.9 ... 150.2).contains(longitude), (-39.3 ... -33.8).contains(latitude) {
            return .vic
        }

        if (141.0 ... 153.9).contains(longitude), (-37.6 ... -28.0).contains(latitude) {
            return .nsw
        }

        if (129.0 ... 141.2).contains(longitude), (-38.2 ... -25.8).contains(latitude) {
            return .sa
        }

        return nil
    }
}

enum OfficialAlertKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case bushfire
    case flood
    case cyclone
    case severeStorm
    case heatwave
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bushfire:
            "Bushfire"
        case .flood:
            "Flood"
        case .cyclone:
            "Cyclone"
        case .severeStorm:
            "Severe Storm"
        case .heatwave:
            "Heatwave"
        case .other:
            "Official Warning"
        }
    }

    var mapMarkerAssetName: String {
        switch self {
        case .bushfire:
            "fire_trail_marker"
        case .flood:
            "flood_marker"
        case .cyclone, .severeStorm, .heatwave, .other:
            "warning_marker"
        }
    }

    var systemImage: String {
        switch self {
        case .bushfire:
            "fire_trail"
        case .flood:
            "flood"
        case .cyclone, .severeStorm:
            "warning"
        case .heatwave:
            "warning"
        case .other:
            "alert"
        }
    }
}

enum OfficialAlertSeverity: String, CaseIterable, Codable, Hashable, Identifiable {
    case advice
    case watchAndAct
    case emergencyWarning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .advice:
            "Advice"
        case .watchAndAct:
            "Watch and Act"
        case .emergencyWarning:
            "Emergency Warning"
        }
    }

    var rank: Int {
        switch self {
        case .emergencyWarning:
            0
        case .watchAndAct:
            1
        case .advice:
            2
        }
    }

    var triggersSafeMode: Bool {
        switch self {
        case .watchAndAct, .emergencyWarning:
            true
        case .advice:
            false
        }
    }
}

struct OfficialAlertArea: Codable, Equatable, Hashable {
    let description: String
    let center: GeoPoint
    let radiusKilometres: Double

    var radiusMetres: CLLocationDistance {
        max(radiusKilometres, 1) * 1_000
    }
}

struct OfficialAlertSource: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let jurisdiction: AustralianJurisdiction
    let urlString: String
}

struct OfficialAlert: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let message: String
    let instruction: String?
    let issuer: String
    let sourceName: String
    let sourceURLString: String?
    let jurisdiction: AustralianJurisdiction
    let kind: OfficialAlertKind
    let severity: OfficialAlertSeverity
    let regionScope: String
    let area: OfficialAlertArea?
    let issuedAt: Date
    let lastUpdated: Date
    let expiresAt: Date?

    var coordinate: CLLocationCoordinate2D? {
        area?.center.coordinate
    }

    var sourceURL: URL? {
        guard let sourceURLString else {
            return nil
        }
        return URL(string: sourceURLString)
    }

    var isAreaScoped: Bool {
        area != nil
    }

    var scopeTrustLabel: String {
        isAreaScoped ? "Area-scoped" : "Statewide feed"
    }

    var jurisdictionTrustLabel: String {
        jurisdiction.shortTitle
    }

    var isActive: Bool {
        isActive(reference: .now)
    }

    func isActive(reference: Date) -> Bool {
        guard let expiresAt else {
            return true
        }
        return expiresAt >= reference
    }

    func distance(from location: CLLocation) -> CLLocationDistance {
        guard let coordinate else {
            return .infinity
        }
        return location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    func isRelevant(to location: CLLocation, paddingKilometres: Double = 10) -> Bool {
        guard let area else {
            return false
        }
        return distance(from: location) <= area.radiusMetres + (paddingKilometres * 1_000)
    }
}

struct OfficialAlertLibrary: Codable, Equatable {
    let lastUpdated: Date
    let sources: [OfficialAlertSource]
    let alerts: [OfficialAlert]

    static let empty = OfficialAlertLibrary(
        lastUpdated: .distantPast,
        sources: [],
        alerts: []
    )
}
