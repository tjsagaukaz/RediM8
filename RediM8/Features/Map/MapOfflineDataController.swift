import CoreLocation
import Foundation

struct MapOfflineDataSnapshot {
    let availablePacks: [OfflineMapPack]
    let dirtRoads: [TrackSegment]
    let fireTrails: [TrackSegment]
    let waterPoints: [WaterPoint]
    let shelters: [ShelterLocation]
    let lastUpdated: Date
    let didLoadOfflineData: Bool
}

final class MapOfflineDataController {
    private let mapDataService: MapDataService
    private let queue = DispatchQueue(
        label: "au.com.redim8.map.offline-data",
        qos: .userInitiated
    )

    init(mapDataService: MapDataService) {
        self.mapDataService = mapDataService
    }

    func makeSnapshot(
        installedPackIDs: Set<String>,
        currentLocation: CLLocationCoordinate2D?
    ) -> MapOfflineDataSnapshot {
        MapOfflineDataSnapshot(
            availablePacks: mapDataService.availablePacks,
            dirtRoads: mapDataService.dirtRoads(for: installedPackIDs),
            fireTrails: mapDataService.fireTrails(for: installedPackIDs),
            waterPoints: mapDataService.waterPoints(for: installedPackIDs, near: currentLocation),
            shelters: mapDataService.shelters(for: installedPackIDs, near: currentLocation),
            lastUpdated: mapDataService.lastUpdated,
            didLoadOfflineData: mapDataService.didLoadOfflineData
        )
    }

    func loadSnapshot(
        installedPackIDs: Set<String>,
        currentLocation: CLLocationCoordinate2D?,
        completion: @escaping (MapOfflineDataSnapshot) -> Void
    ) {
        queue.async { [mapDataService] in
            let snapshot = MapOfflineDataSnapshot(
                availablePacks: mapDataService.availablePacks,
                dirtRoads: mapDataService.dirtRoads(for: installedPackIDs),
                fireTrails: mapDataService.fireTrails(for: installedPackIDs),
                waterPoints: mapDataService.waterPoints(for: installedPackIDs, near: currentLocation),
                shelters: mapDataService.shelters(for: installedPackIDs, near: currentLocation),
                lastUpdated: mapDataService.lastUpdated,
                didLoadOfflineData: mapDataService.didLoadOfflineData
            )

            DispatchQueue.main.async {
                completion(snapshot)
            }
        }
    }
}
