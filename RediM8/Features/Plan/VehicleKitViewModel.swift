import Combine
import Foundation

@MainActor
final class VehicleKitViewModel: ObservableObject {
    @Published private(set) var plan: VehicleReadinessPlan

    private let appState: AppState
    private let vehicleReadinessService: VehicleReadinessService
    private var profile: UserProfile
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        vehicleReadinessService = appState.vehicleReadinessService
        profile = appState.profile
        plan = vehicleReadinessService.plan(for: appState.profile)

        appState.$profile
            .sink { [weak self] profile in
                guard let self else { return }
                self.profile = profile
                self.refresh()
            }
            .store(in: &cancellables)

        vehicleReadinessService.$completedItemIDs
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    func isItemComplete(_ itemID: String) -> Bool {
        vehicleReadinessService.isItemComplete(itemID)
    }

    func setItemComplete(_ itemID: String, isComplete: Bool) {
        vehicleReadinessService.setItem(itemID, isComplete: isComplete)
    }

    private func refresh() {
        plan = vehicleReadinessService.plan(for: profile)
    }
}
