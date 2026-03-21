import CoreLocation
import MapKit

@MainActor
struct MapRenderController {
    private let fallbackRegion: MKCoordinateRegion

    init(mapService: MapService) {
        fallbackRegion = mapService.fallbackRegion()
    }

    func preferredRegion(
        currentLocation: CLLocation?,
        installedPacks: [OfflineMapPack]
    ) -> MKCoordinateRegion {
        if let location = currentLocation {
            return MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            )
        }

        if let firstInstalledPack = installedPacks.first {
            return focusRegion(for: firstInstalledPack)
        }

        return fallbackRegion
    }

    func focusRegion(for pack: OfflineMapPack) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: pack.center.coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: pack.latitudeDelta,
                longitudeDelta: pack.longitudeDelta
            )
        )
    }
}
