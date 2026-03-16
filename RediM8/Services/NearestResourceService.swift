import CoreLocation
import Foundation

/// Unified KNN query engine across all survival resource types.
/// Uses R-tree spatial indexes where available, falls back to linear scan.
@MainActor
final class NearestResourceService {
    enum ResourceCategory: String, CaseIterable, Identifiable {
        case water
        case shelter
        case road
        case town

        var id: String { rawValue }

        var title: String {
            switch self {
            case .water: "WATER"
            case .shelter: "SHELTER"
            case .road: "ROAD"
            case .town: "TOWN"
            }
        }

        var icon: String {
            switch self {
            case .water: "drop"
            case .shelter: "house"
            case .road: "road.lanes"
            case .town: "building.2"
            }
        }
    }

    struct NearestResult: Identifiable {
        let id: String
        let name: String
        let subtitle: String
        let category: ResourceCategory
        let coordinate: CLLocationCoordinate2D
        let distanceMetres: CLLocationDistance

        var distanceText: String {
            if distanceMetres >= 1000 {
                return String(format: "%.1f km", distanceMetres / 1000)
            }
            return "\(Int(distanceMetres.rounded())) m"
        }

        var bearingText: String? { nil }
    }

    private let waterPointService: WaterPointService
    private let shelterService: ShelterService
    private let mapService: MapService
    private let mapDataService: MapDataService

    private let resourceIndex: SpatialIndex<ResourceMarker>
    private let trackIndex: SpatialIndex<TrackSegment>

    init(
        waterPointService: WaterPointService,
        shelterService: ShelterService,
        mapService: MapService,
        mapDataService: MapDataService
    ) {
        self.waterPointService = waterPointService
        self.shelterService = shelterService
        self.mapService = mapService
        self.mapDataService = mapDataService

        // Build spatial indexes for resources and tracks
        self.resourceIndex = SpatialIndex(items: mapService.bundledResources) {
            $0.coordinate
        }
        self.trackIndex = SpatialIndex(items: mapDataService.allTracks) {
            $0.midpoint
        }
    }

    /// Find the K nearest resources of a given category.
    func nearest(
        _ category: ResourceCategory,
        to coordinate: CLLocationCoordinate2D,
        installedPackIDs: Set<String>,
        limit: Int = 5
    ) -> [NearestResult] {
        switch category {
        case .water:
            return nearestWater(to: coordinate, installedPackIDs: installedPackIDs, limit: limit)
        case .shelter:
            return nearestShelters(to: coordinate, installedPackIDs: installedPackIDs, limit: limit)
        case .road:
            return nearestRoads(to: coordinate, installedPackIDs: installedPackIDs, limit: limit)
        case .town:
            return nearestTowns(to: coordinate, limit: limit)
        }
    }

    /// Find nearest resources across all categories.
    func nearestAll(
        to coordinate: CLLocationCoordinate2D,
        installedPackIDs: Set<String>,
        limitPerCategory: Int = 3
    ) -> [NearestResult] {
        ResourceCategory.allCases.flatMap { category in
            nearest(category, to: coordinate, installedPackIDs: installedPackIDs, limit: limitPerCategory)
        }
        .sorted { $0.distanceMetres < $1.distanceMetres }
    }

    // MARK: - Category Queries

    private func nearestWater(
        to coordinate: CLLocationCoordinate2D,
        installedPackIDs: Set<String>,
        limit: Int
    ) -> [NearestResult] {
        waterPointService.nearbyWaterPoints(
            near: coordinate,
            installedPackIDs: installedPackIDs,
            limit: limit
        ).map { nearby in
            NearestResult(
                id: "water-\(nearby.point.id)",
                name: nearby.point.name,
                subtitle: nearby.point.kind.title,
                category: .water,
                coordinate: nearby.point.coordinate.coordinate,
                distanceMetres: nearby.distanceMetres
            )
        }
    }

    private func nearestShelters(
        to coordinate: CLLocationCoordinate2D,
        installedPackIDs: Set<String>,
        limit: Int
    ) -> [NearestResult] {
        shelterService.nearbyShelters(
            near: coordinate,
            installedPackIDs: installedPackIDs,
            limit: limit
        ).map { nearby in
            NearestResult(
                id: "shelter-\(nearby.shelter.id)",
                name: nearby.shelter.name,
                subtitle: nearby.shelter.type.title,
                category: .shelter,
                coordinate: CLLocationCoordinate2D(
                    latitude: nearby.shelter.latitude,
                    longitude: nearby.shelter.longitude
                ),
                distanceMetres: nearby.distanceMetres
            )
        }
    }

    private func nearestRoads(
        to coordinate: CLLocationCoordinate2D,
        installedPackIDs: Set<String>,
        limit: Int
    ) -> [NearestResult] {
        trackIndex.nearest(to: coordinate, limit: limit * 3)
            .filter { entry in
                let track = entry.item
                return track.packIDs.isEmpty || !Set(track.packIDs).isDisjoint(with: installedPackIDs)
            }
            .prefix(limit)
            .map { entry in
                let track = entry.item
                return NearestResult(
                    id: "road-\(track.id)",
                    name: track.name,
                    subtitle: trackSubtitle(for: track),
                    category: .road,
                    coordinate: track.midpoint,
                    distanceMetres: entry.distanceMetres
                )
            }
    }

    private func nearestTowns(
        to coordinate: CLLocationCoordinate2D,
        limit: Int
    ) -> [NearestResult] {
        let townKinds: Set<MarkerKind> = [.hospital, .fuelStation, .policeStation, .supermarket, .pharmacy]
        return resourceIndex.nearest(to: coordinate, limit: limit * 3)
            .filter { townKinds.contains($0.item.kind) }
            .prefix(limit)
            .map { entry in
                NearestResult(
                    id: "town-\(entry.item.id.uuidString)",
                    name: entry.item.title,
                    subtitle: entry.item.kind.title,
                    category: .town,
                    coordinate: entry.item.coordinate,
                    distanceMetres: entry.distanceMetres
                )
            }
    }

    private func trackSubtitle(for track: TrackSegment) -> String {
        var parts: [String] = []
        parts.append(track.kind.title)
        if let advice = track.vehicleAdvice {
            parts.append(advice.title)
        }
        return parts.joined(separator: " · ")
    }
}
