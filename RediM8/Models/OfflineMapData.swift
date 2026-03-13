import CoreLocation
import Foundation

enum MapLayer: String, CaseIterable, Codable, Hashable, Identifiable {
    case resources
    case waterPoints
    case dirtRoads
    case fireTrails
    case evacuationPoints
    case officialAlerts
    case communityBeacons

    var id: String { rawValue }

    var title: String {
        switch self {
        case .resources:
            "Resources"
        case .waterPoints:
            "Water Points"
        case .dirtRoads:
            "Dirt Roads"
        case .fireTrails:
            "Fire Trails"
        case .evacuationPoints:
            "Evacuation Points"
        case .officialAlerts:
            "Official Alerts"
        case .communityBeacons:
            "Community Reports"
        }
    }

    var subtitle: String {
        switch self {
        case .resources:
            "Hospitals, fuel, pharmacies and other critical places"
        case .waterPoints:
            "Known taps, tanks, bores and creek access"
        case .dirtRoads:
            "Unsealed roads, 4WD tracks and station access"
        case .fireTrails:
            "Forestry roads, firebreak paths and emergency access routes"
        case .evacuationPoints:
            "Baseline evacuation centres, shelters and assembly points"
        case .officialAlerts:
            "Mirrored public warnings cached for offline viewing"
        case .communityBeacons:
            "Nearby mesh reports shared by the community"
        }
    }

    var systemImage: String {
        switch self {
        case .resources:
            "medical"
        case .waterPoints:
            "water"
        case .dirtRoads:
            "dirt_road"
        case .fireTrails:
            "fire_trail"
        case .evacuationPoints:
            "shelter"
        case .officialAlerts:
            "warning"
        case .communityBeacons:
            "beacon"
        }
    }

    var defaultEnabled: Bool {
        switch self {
        case .waterPoints, .evacuationPoints, .officialAlerts:
            true
        case .resources, .dirtRoads, .fireTrails, .communityBeacons:
            false
        }
    }
}

struct GeoPoint: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum MapPackKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case state
    case regional

    var id: String { rawValue }

    var title: String {
        switch self {
        case .state:
            "State Pack"
        case .regional:
            "Regional Pack"
        }
    }
}

struct OfflineMapPack: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let kind: MapPackKind
    let sizeMB: Int
    let center: GeoPoint
    let latitudeDelta: Double
    let longitudeDelta: Double
    let coverageSummary: String
    let supportedLayers: [MapLayer]
    let isBundledByDefault: Bool
    let lastUpdated: Date

    var supportedLayerSummary: String {
        supportedLayers.map(\.title).joined(separator: ", ")
    }
}

enum TrackKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case unsealedRoad
    case fourWheelDriveTrack
    case fireTrail
    case stationTrack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unsealedRoad:
            "Unsealed Road"
        case .fourWheelDriveTrack:
            "4WD Track"
        case .fireTrail:
            "Fire Access Trail"
        case .stationTrack:
            "Station Track"
        }
    }
}

enum TrackSurface: String, CaseIterable, Codable, Hashable, Identifiable {
    case dirt
    case gravel
    case mixed
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dirt:
            "Dirt"
        case .gravel:
            "Gravel"
        case .mixed:
            "Mixed Surface"
        case .unknown:
            "Unknown"
        }
    }
}

enum VehicleAccessAdvice: String, CaseIterable, Codable, Hashable, Identifiable {
    case twoWheelDrivePossible
    case fourWheelDriveRecommended
    case fourWheelDriveOnly
    case emergencyVehiclesOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twoWheelDrivePossible:
            "2WD Possible"
        case .fourWheelDriveRecommended:
            "4WD Recommended"
        case .fourWheelDriveOnly:
            "4WD Only"
        case .emergencyVehiclesOnly:
            "Emergency Vehicles Only"
        }
    }
}

enum TrackPurpose: String, CaseIterable, Codable, Hashable, Identifiable {
    case emergencyAccess
    case forestryAccess
    case firebreakAccess
    case utilityAccess
    case stationAccess
    case remoteConnector

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emergencyAccess:
            "Emergency Access"
        case .forestryAccess:
            "Forestry Access"
        case .firebreakAccess:
            "Firebreak Access"
        case .utilityAccess:
            "Utility Service Access"
        case .stationAccess:
            "Station Access"
        case .remoteConnector:
            "Remote Connector"
        }
    }
}

enum TrackSafetyLabel: String, CaseIterable, Codable, Hashable, Identifiable {
    case emergencyVehicleRoute
    case fourWheelDriveOnly
    case seasonalAccess
    case unmaintainedTrack
    case confirmLocalAccess

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emergencyVehicleRoute:
            "Emergency Vehicle Route"
        case .fourWheelDriveOnly:
            "4WD Only"
        case .seasonalAccess:
            "Seasonal Access"
        case .unmaintainedTrack:
            "Unmaintained Track"
        case .confirmLocalAccess:
            "Confirm Local Access"
        }
    }
}

struct TrackSegment: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let kind: TrackKind
    let surface: TrackSurface
    let vehicleAdvice: VehicleAccessAdvice?
    let purpose: TrackPurpose?
    let points: [GeoPoint]
    let packIDs: [String]
    let safetyLabels: [TrackSafetyLabel]
    let notes: String
    let source: String

    var isFireAccessTrail: Bool {
        kind == .fireTrail
    }

    var midpoint: CLLocationCoordinate2D {
        guard !points.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }

        let latitude = points.map(\.latitude).reduce(0, +) / Double(points.count)
        let longitude = points.map(\.longitude).reduce(0, +) / Double(points.count)
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct TrackDataset: Codable, Equatable {
    let lastUpdated: Date
    let tracks: [TrackSegment]
}

enum MapFeatureAvailability: String, CaseIterable, Codable, Hashable, Identifiable {
    case offlinePack
    case networkNearby

    var id: String { rawValue }

    var title: String {
        switch self {
        case .offlinePack:
            "Offline Pack"
        case .networkNearby:
            "Network Nearby"
        }
    }
}

enum MapFeatureSourceKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case curatedBundle
    case baselineFacility
    case openMapData
    case official

    var id: String { rawValue }

    var title: String {
        switch self {
        case .curatedBundle:
            "Curated Bundle"
        case .baselineFacility:
            "Baseline Facility"
        case .openMapData:
            "Open Map Data"
        case .official:
            "Official"
        }
    }
}

enum WaterPointKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case boreWater
    case communityTap
    case campgroundWater
    case riverCreek
    case rainwaterTank
    case townWaterPoint
    case stockTrough
    case waterTank

    var id: String { rawValue }

    var title: String {
        switch self {
        case .boreWater:
            "Bore Water"
        case .communityTap:
            "Community Tap"
        case .campgroundWater:
            "Campground Water"
        case .riverCreek:
            "River / Creek"
        case .rainwaterTank:
            "Rainwater Tank"
        case .townWaterPoint:
            "Town Water Point"
        case .stockTrough:
            "Stock Trough"
        case .waterTank:
            "Water Tank"
        }
    }
}

enum WaterQualityLabel: String, CaseIterable, Codable, Hashable, Identifiable {
    case drinkingWater
    case nonPotable
    case seasonal
    case unknownQuality

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drinkingWater:
            "Drinking Water"
        case .nonPotable:
            "Non-potable"
        case .seasonal:
            "Seasonal"
        case .unknownQuality:
            "Unknown Quality"
        }
    }
}

struct WaterPoint: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let kind: WaterPointKind
    let coordinate: GeoPoint
    let packIDs: [String]
    let quality: WaterQualityLabel
    let notes: String
    let source: String
    let availability: MapFeatureAvailability
    let sourceKind: MapFeatureSourceKind
    let lastUpdated: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case coordinate
        case packIDs
        case quality
        case notes
        case source
        case availability
        case sourceKind
        case lastUpdated
    }

    init(
        id: String,
        name: String,
        kind: WaterPointKind,
        coordinate: GeoPoint,
        packIDs: [String],
        quality: WaterQualityLabel,
        notes: String,
        source: String,
        availability: MapFeatureAvailability = .offlinePack,
        sourceKind: MapFeatureSourceKind = .curatedBundle,
        lastUpdated: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.coordinate = coordinate
        self.packIDs = packIDs
        self.quality = quality
        self.notes = notes
        self.source = source
        self.availability = availability
        self.sourceKind = sourceKind
        self.lastUpdated = lastUpdated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(WaterPointKind.self, forKey: .kind)
        coordinate = try container.decode(GeoPoint.self, forKey: .coordinate)
        packIDs = try container.decode([String].self, forKey: .packIDs)
        quality = try container.decode(WaterQualityLabel.self, forKey: .quality)
        notes = try container.decode(String.self, forKey: .notes)
        source = try container.decode(String.self, forKey: .source)
        availability = try container.decodeIfPresent(MapFeatureAvailability.self, forKey: .availability) ?? .offlinePack
        sourceKind = try container.decodeIfPresent(MapFeatureSourceKind.self, forKey: .sourceKind) ?? .curatedBundle
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated)
    }

    var location: CLLocationCoordinate2D {
        coordinate.coordinate
    }

    var isNetworkNearby: Bool {
        availability == .networkNearby
    }
}

struct WaterPointDataset: Codable, Equatable {
    let lastUpdated: Date
    let waterPoints: [WaterPoint]
}

enum ShelterType: String, CaseIterable, Codable, Hashable, Identifiable {
    case evacuationCentre = "evacuation_centre"
    case communityShelter = "community_shelter"
    case cycloneShelter = "cyclone_shelter"
    case temporaryReliefCentre = "temporary_relief_centre"
    case publicAssemblyPoint = "public_assembly_point"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .evacuationCentre:
            "Emergency Evacuation Centre"
        case .communityShelter:
            "Community Shelter"
        case .cycloneShelter:
            "Cyclone Shelter"
        case .temporaryReliefCentre:
            "Temporary Relief Centre"
        case .publicAssemblyPoint:
            "Public Assembly Point"
        }
    }
}

struct ShelterLocation: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let type: ShelterType
    let capacity: Int?
    let notes: String
    let packIDs: [String]
    let source: String
    let availability: MapFeatureAvailability
    let sourceKind: MapFeatureSourceKind
    let lastUpdated: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case latitude
        case longitude
        case type
        case capacity
        case notes
        case packIDs
        case source
        case availability
        case sourceKind
        case lastUpdated
    }

    init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        type: ShelterType,
        capacity: Int?,
        notes: String,
        packIDs: [String],
        source: String,
        availability: MapFeatureAvailability = .offlinePack,
        sourceKind: MapFeatureSourceKind = .baselineFacility,
        lastUpdated: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.type = type
        self.capacity = capacity
        self.notes = notes
        self.packIDs = packIDs
        self.source = source
        self.availability = availability
        self.sourceKind = sourceKind
        self.lastUpdated = lastUpdated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        type = try container.decode(ShelterType.self, forKey: .type)
        capacity = try container.decodeIfPresent(Int.self, forKey: .capacity)
        notes = try container.decode(String.self, forKey: .notes)
        packIDs = try container.decode([String].self, forKey: .packIDs)
        source = try container.decode(String.self, forKey: .source)
        availability = try container.decodeIfPresent(MapFeatureAvailability.self, forKey: .availability) ?? .offlinePack
        sourceKind = try container.decodeIfPresent(MapFeatureSourceKind.self, forKey: .sourceKind) ?? .baselineFacility
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var capacityText: String {
        guard let capacity else {
            return "Unknown"
        }
        return capacity.formatted()
    }

    var isNetworkNearby: Bool {
        availability == .networkNearby
    }
}

struct ShelterDataset: Codable, Equatable {
    let lastUpdated: Date
    let shelters: [ShelterLocation]
}

struct OfflineMapPackCatalog: Codable, Equatable {
    let lastUpdated: Date
    let packs: [OfflineMapPack]
}

struct StoredMapLayerSelection: Codable, Equatable {
    let enabledLayers: Set<MapLayer>
}

struct StoredMapPackSelection: Codable, Equatable {
    let installedPackIDs: Set<String>
}
