import CoreMotion
import Foundation

@MainActor
final class MotionService: ObservableObject {
    @Published private(set) var orientationSummary = "Stable"

    private let manager = CMMotionManager()
    private let permissionsManager: PermissionsManager
    private let isEnabled: Bool

    init(permissionsManager: PermissionsManager = .live, isEnabled: Bool = true) {
        self.permissionsManager = permissionsManager
        self.isEnabled = isEnabled
    }

    func start() {
        guard isEnabled else { return }
        guard permissionsManager.isMotionAccessAvailable() else { return }
        guard permissionsManager.canUseMotionUpdates() else { return }
        manager.deviceMotionUpdateInterval = 0.5
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let pitch = abs(motion.attitude.pitch)
            let roll = abs(motion.attitude.roll)
            if pitch < 0.3 && roll < 0.3 {
                self?.orientationSummary = "Flat"
            } else if pitch > 1.0 {
                self?.orientationSummary = "Upright"
            } else {
                self?.orientationSummary = "Tilted"
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
