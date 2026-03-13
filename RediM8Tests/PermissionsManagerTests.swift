import CoreLocation
import XCTest
@testable import RediM8

final class PermissionsManagerTests: XCTestCase {
    @MainActor
    func testLocationPermissionStateMapsCoreLocationStatuses() {
        let permissionsManager = PermissionsManager()

        XCTAssertEqual(permissionsManager.locationPermissionState(for: .notDetermined), .notDetermined)
        XCTAssertEqual(permissionsManager.locationPermissionState(for: .restricted), .restricted)
        XCTAssertEqual(permissionsManager.locationPermissionState(for: .denied), .denied)
        XCTAssertEqual(permissionsManager.locationPermissionState(for: .authorizedWhenInUse), .authorized)
        XCTAssertEqual(permissionsManager.locationPermissionState(for: .authorizedAlways), .authorized)
    }

    @MainActor
    func testOnlyUndeterminedLocationPermissionCanBeRequested() {
        let permissionsManager = PermissionsManager()

        XCTAssertTrue(permissionsManager.canRequestLocationPermission(status: .notDetermined))
        XCTAssertFalse(permissionsManager.canRequestLocationPermission(status: .denied))
        XCTAssertFalse(permissionsManager.canRequestLocationPermission(status: .authorizedWhenInUse))
    }
}
