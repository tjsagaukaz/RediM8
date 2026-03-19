@preconcurrency import CoreLocation
import Foundation
import MapKit

enum LocationRuntimeMode: Equatable {
    case standard
    case stealth
}

final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var heading: CLLocationDirection = 0

    private let manager: CLLocationManager
    private let permissionsManager: PermissionsManager
    private var activeClients = 0
    private var runtimeMode: LocationRuntimeMode = .standard

    var activeClientCount: Int {
        activeClients
    }

    init(permissionsManager: PermissionsManager = .live) {
        let manager = CLLocationManager()
        self.manager = manager
        self.permissionsManager = permissionsManager
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        applyRuntimeMode()
    }

    @MainActor
    func requestAccess() {
        if permissionsManager.canRequestLocationPermission(status: authorizationStatus) {
            manager.requestWhenInUseAuthorization()
        }
    }

    @MainActor
    func start(requestAccess shouldRequestAccess: Bool = true) {
        activeClients += 1
        if shouldRequestAccess {
            requestAccess()
        }
        syncLocationUpdates()
    }

    @MainActor
    func stop() {
        guard activeClients > 0 else { return }
        activeClients -= 1
        syncLocationUpdates()
    }

    @MainActor
    func updateRuntimeMode(_ mode: LocationRuntimeMode) {
        guard runtimeMode != mode else { return }
        runtimeMode = mode
        applyRuntimeMode()
    }

    @MainActor
    func region(fallback: MKCoordinateRegion) -> MKCoordinateRegion {
        guard let coordinate = currentLocation?.coordinate else {
            return fallback
        }
        return MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
        )
    }

    #if DEBUG
    @MainActor
    func simulate(location: CLLocation) {
        currentLocation = location
    }
    #endif

    private func applyRuntimeMode() {
        switch runtimeMode {
        case .standard:
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.distanceFilter = 50
            manager.headingFilter = 5
            manager.pausesLocationUpdatesAutomatically = false
        case .stealth:
            manager.desiredAccuracy = kCLLocationAccuracyKilometer
            manager.distanceFilter = 250
            manager.headingFilter = 20
            manager.pausesLocationUpdatesAutomatically = true
        }
    }

    @MainActor
    private func syncLocationUpdates() {
        guard activeClients > 0, permissionsManager.canUseLocationUpdates(status: authorizationStatus) else {
            manager.stopUpdatingLocation()
            manager.stopUpdatingHeading()
            return
        }

        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            self.syncLocationUpdates()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            self.currentLocation = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            self.heading = heading
        }
    }
}
