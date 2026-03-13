import SwiftUI

struct MapAssetIcon: View {
    let assetName: String?
    let fallbackSystemName: String?
    let size: CGFloat

    init(assetName: String?, fallbackSystemName: String? = nil, size: CGFloat) {
        self.assetName = assetName
        self.fallbackSystemName = fallbackSystemName
        self.size = size
    }

    @ViewBuilder
    var body: some View {
        if let assetName, let symbolName = RediIcon.mappedSystemName(for: assetName) {
            Image(systemName: symbolName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if let assetName {
            Image(assetName)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if let fallbackSystemName {
            RediIcon(fallbackSystemName)
                .frame(width: size, height: size)
        }
    }
}

struct MapLayerIcon: View {
    let layer: MapLayer
    let size: CGFloat

    init(_ layer: MapLayer, size: CGFloat) {
        self.layer = layer
        self.size = size
    }

    var body: some View {
        MapAssetIcon(assetName: layer.mapLayerAssetName, fallbackSystemName: layer.systemImage, size: size)
    }
}

extension MapLayer {
    var mapLayerAssetName: String? {
        switch self {
        case .resources:
            nil
        case .waterPoints:
            "layer_water"
        case .dirtRoads:
            "layer_roads"
        case .fireTrails:
            "layer_fire_trails"
        case .evacuationPoints:
            "layer_shelters"
        case .officialAlerts:
            nil
        case .communityBeacons:
            "layer_beacons"
        }
    }
}

extension MarkerKind {
    var mapMarkerAssetName: String {
        switch self {
        case .hospital:
            "hospital_marker"
        case .fuelStation, .fuelAvailable:
            "fuel_marker"
        case .pharmacy:
            "pharmacy_marker"
        case .supermarket:
            "food_marker"
        case .hardwareStore:
            "hardware_store_marker"
        case .policeStation:
            "police_marker"
        case .waterSource, .waterAvailable:
            "water_marker"
        case .shelter:
            "shelter_marker"
        case .danger:
            "warning_marker"
        case .roadBlocked:
            "checkpoint_marker"
        }
    }
}

extension WaterPointKind {
    var mapMarkerAssetName: String {
        switch self {
        case .communityTap, .campgroundWater, .townWaterPoint:
            "water_marker"
        case .boreWater, .riverCreek, .rainwaterTank, .stockTrough, .waterTank:
            "remote_water_marker"
        }
    }
}

extension ShelterType {
    var mapMarkerAssetName: String {
        "shelter_marker"
    }
}

extension BeaconType {
    var mapMarkerAssetName: String {
        switch self {
        case .safeLocation:
            "community_beacon_marker"
        case .fireSpotted:
            "fire_trail_marker"
        case .floodedRoad:
            "flood_marker"
        case .roadBlocked:
            "road_blocked_marker"
        case .medicalHelp:
            "medical_marker"
        case .waterAvailable:
            "water_marker"
        case .fuelAvailable:
            "fuel_marker"
        case .shelter:
            "shelter_marker"
        case .needHelp:
            "warning_marker"
        }
    }
}

extension TrackKind {
    var mapMarkerAssetName: String {
        switch self {
        case .unsealedRoad, .stationTrack:
            "dirt_road_marker"
        case .fourWheelDriveTrack:
            "fourwd_track_marker"
        case .fireTrail:
            "fire_trail_marker"
        }
    }
}
