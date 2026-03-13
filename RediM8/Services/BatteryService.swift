import Combine
import Foundation
import UIKit

struct BatteryStatus: Equatable {
    static let survivalThreshold = 0.15

    let level: Double?
    let state: UIDevice.BatteryState

    var isBelowSurvivalThreshold: Bool {
        guard let level else {
            return false
        }
        return level <= Self.survivalThreshold
    }

    var percentageText: String {
        guard let level else {
            return "Unavailable"
        }
        return "\(Int((level * 100).rounded()))%"
    }
}

@MainActor
final class BatteryService: ObservableObject {
    @Published private(set) var status: BatteryStatus

    private var cancellables = Set<AnyCancellable>()

    init(notificationCenter: NotificationCenter = .default) {
        UIDevice.current.isBatteryMonitoringEnabled = true
        status = Self.currentStatus()

        Publishers.Merge(
            notificationCenter.publisher(for: UIDevice.batteryLevelDidChangeNotification),
            notificationCenter.publisher(for: UIDevice.batteryStateDidChangeNotification)
        )
        .sink { [weak self] _ in
            self?.status = Self.currentStatus()
        }
        .store(in: &cancellables)
    }

    init(initialStatus: BatteryStatus) {
        status = initialStatus
    }

    func simulate(status: BatteryStatus) {
        self.status = status
    }

    private static func currentStatus() -> BatteryStatus {
        let level = UIDevice.current.batteryLevel
        return BatteryStatus(
            level: level >= 0 ? Double(level) : nil,
            state: UIDevice.current.batteryState
        )
    }
}
