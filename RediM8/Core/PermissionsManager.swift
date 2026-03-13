import CoreLocation
import CoreMotion
import Foundation

enum AppPermissionState: Equatable {
    case unavailable
    case notDetermined
    case denied
    case restricted
    case authorized
}

final class PermissionsManager {
    static let live = PermissionsManager()

    func canRequestLocationPermission(status: CLAuthorizationStatus) -> Bool {
        status == .notDetermined
    }

    func locationPermissionState(for status: CLAuthorizationStatus) -> AppPermissionState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .restricted:
            .restricted
        case .denied:
            .denied
        case .authorizedAlways, .authorizedWhenInUse:
            .authorized
        @unknown default:
            .restricted
        }
    }

    func isMotionAccessAvailable() -> Bool {
        CMMotionManager().isDeviceMotionAvailable
    }

    func motionPermissionState() -> AppPermissionState {
        guard isMotionAccessAvailable() else {
            return .unavailable
        }

        switch CMMotionActivityManager.authorizationStatus() {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .restricted
        }
    }

    func canUseMotionUpdates() -> Bool {
        let permissionState = motionPermissionState()
        return permissionState != .denied && permissionState != .restricted
    }
}
