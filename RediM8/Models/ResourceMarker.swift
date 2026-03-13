import Foundation
import MapKit
import SwiftUI

enum MarkerKind: String, CaseIterable, Codable, Identifiable {
    case hospital
    case fuelStation
    case pharmacy
    case supermarket
    case hardwareStore
    case policeStation
    case waterSource
    case fuelAvailable
    case waterAvailable
    case shelter
    case danger
    case roadBlocked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hospital:
            "Hospital"
        case .fuelStation:
            "Fuel"
        case .pharmacy:
            "Pharmacy"
        case .supermarket:
            "Supermarket"
        case .hardwareStore:
            "Hardware"
        case .policeStation:
            "Police"
        case .waterSource:
            "Water"
        case .fuelAvailable:
            "Fuel available"
        case .waterAvailable:
            "Water available"
        case .shelter:
            "Shelter"
        case .danger:
            "Danger"
        case .roadBlocked:
            "Road blocked"
        }
    }

    var defaultSymbolName: String {
        switch self {
        case .hospital:
            "medical"
        case .fuelStation, .fuelAvailable:
            "fuel"
        case .pharmacy:
            "pharmacy"
        case .supermarket:
            "food"
        case .hardwareStore:
            "hammer.fill"
        case .policeStation:
            "shield.fill"
        case .waterSource, .waterAvailable:
            "water"
        case .shelter:
            "shelter"
        case .danger:
            "warning"
        case .roadBlocked:
            "alert"
        }
    }

    var resourceCategoryID: String? {
        switch self {
        case .hospital:
            "hospital"
        case .fuelStation:
            "fuel"
        case .pharmacy:
            "pharmacy"
        case .supermarket:
            "supermarket"
        case .hardwareStore:
            "hardware_store"
        case .policeStation:
            "police_station"
        case .waterSource:
            "water_source"
        case .shelter:
            "shelter"
        case .fuelAvailable, .waterAvailable, .danger, .roadBlocked:
            nil
        }
    }

    var tint: Color {
        switch self {
        case .hospital, .pharmacy:
            ColorTheme.danger
        case .waterSource, .waterAvailable:
            ColorTheme.water
        case .fuelStation, .hardwareStore, .supermarket, .fuelAvailable:
            ColorTheme.warning
        case .policeStation:
            ColorTheme.info
        case .shelter:
            ColorTheme.ready
        case .danger, .roadBlocked:
            ColorTheme.danger
        }
    }
}

struct ResourceMarker: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var subtitle: String
    var kind: MarkerKind
    var latitude: Double
    var longitude: Double
    var detail: String
    var source: String
    var isUserGenerated: Bool

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        kind: MarkerKind,
        latitude: Double,
        longitude: Double,
        detail: String,
        source: String,
        isUserGenerated: Bool
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.latitude = latitude
        self.longitude = longitude
        self.detail = detail
        self.source = source
        self.isUserGenerated = isUserGenerated
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct ResourceDataset: Codable, Equatable {
    let lastUpdated: Date
    let resources: [ResourceMarker]
}
