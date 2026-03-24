import CoreLocation
import Foundation

/// Represents a map feature tapped by the user.
/// Carries display metadata extracted from the MapLibre feature attributes.
struct MapSelectedFeature: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let kind: String?
    let quality: String?
    let layer: FeatureLayer
    let coordinate: CLLocationCoordinate2D?

    enum FeatureLayer: String, Equatable {
        case shelter
        case waterPoint
        case resource
        case officialAlert
        case beacon
        case unknown

        var displayTitle: String {
            switch self {
            case .shelter: "Evacuation Point"
            case .waterPoint: "Water Source"
            case .resource: "Resource"
            case .officialAlert: "Official Alert"
            case .beacon: "Community Report"
            case .unknown: "Map Feature"
            }
        }

        var systemImage: String {
            switch self {
            case .shelter: "building.2"
            case .waterPoint: "drop.fill"
            case .resource: "cross.case.fill"
            case .officialAlert: "exclamationmark.triangle.fill"
            case .beacon: "antenna.radiowaves.left.and.right"
            case .unknown: "mappin"
            }
        }
    }

    static func == (lhs: MapSelectedFeature, rhs: MapSelectedFeature) -> Bool {
        lhs.id == rhs.id && lhs.layer == rhs.layer
    }

    /// Distance text from a reference location.
    func distanceText(from location: CLLocation?) -> String? {
        guard let coordinate, let location else { return nil }
        let distance = location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        guard distance.isFinite else { return nil }
        if distance >= 1000 {
            return String(format: "%.1f km away", distance / 1000)
        }
        return "\(Int(distance.rounded())) m away"
    }
}
