import Combine
import CoreLocation
import XCTest
@testable import RediM8

final class LocationServiceTests: XCTestCase {
    @MainActor
    func testPermissionRecoveryStartsLocationUpdatesWithoutRestartingClients() {
        let service = LocationService(permissionsManager: PermissionsManager())
        service.simulateAuthorizationStatus(.notDetermined)

        service.start(requestAccess: false)

        XCTAssertEqual(service.activeClientCount, 1)
        XCTAssertFalse(service.isUpdatingLocation)

        service.simulateAuthorizationStatus(.authorizedWhenInUse)

        XCTAssertEqual(service.activeClientCount, 1)
        XCTAssertTrue(service.isUpdatingLocation)
    }

    @MainActor
    func testPermissionLossStopsLocationUpdatesButKeepsRecoveryPathAlive() {
        let service = LocationService(permissionsManager: PermissionsManager())
        service.simulateAuthorizationStatus(.authorizedWhenInUse)
        service.start(requestAccess: false)

        XCTAssertTrue(service.isUpdatingLocation)

        service.simulateAuthorizationStatus(.denied)

        XCTAssertEqual(service.activeClientCount, 1)
        XCTAssertFalse(service.isUpdatingLocation)
    }

    @MainActor
    func testSituationalScannerRecoversGpsStateAfterPermissionAndFixReturn() {
        let locationService = LocationService(permissionsManager: PermissionsManager())
        let batteryService = BatteryService(notificationCenter: NotificationCenter())
        let scanner = SituationalScannerService(locationService: locationService, batteryService: batteryService)
        var cancellables = Set<AnyCancellable>()

        locationService.simulateAuthorizationStatus(.denied)
        XCTAssertEqual(scanner.snapshot.gpsState, .unavailable)

        let recovered = expectation(description: "scanner recovers GPS state")
        scanner.$snapshot
            .dropFirst()
            .sink { snapshot in
                if snapshot.gpsState == .locked {
                    recovered.fulfill()
                }
            }
            .store(in: &cancellables)

        locationService.simulateAuthorizationStatus(.authorizedWhenInUse)
        locationService.simulate(location: CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -27.4705, longitude: 153.0260),
            altitude: 0,
            horizontalAccuracy: 35,
            verticalAccuracy: 10,
            course: 0,
            speed: 0,
            timestamp: .now
        ))

        wait(for: [recovered], timeout: 1)
        XCTAssertEqual(scanner.snapshot.gpsState, .locked)
    }
}
