import Combine
import Foundation

@MainActor
final class PowerSystem: ObservableObject, AppSystem {
    @Published private(set) var batteryStatus: BatteryStatus
    @Published private(set) var shouldPromptForSurvivalMode = false
    @Published private(set) var isLowBatterySurvivalModeEnabled = false

    let batteryService: BatteryService

    private let featureFlags: AppFeatureFlags
    private let torchService: TorchService
    private var batterySettings: BatterySettings
    private var deferredSurvivalPromptDismissal = false
    private var cancellables = Set<AnyCancellable>()

    init(
        featureFlags: AppFeatureFlags,
        batteryService: BatteryService,
        torchService: TorchService,
        initialSettings: BatterySettings
    ) {
        self.featureFlags = featureFlags
        self.batteryService = batteryService
        self.torchService = torchService
        batterySettings = initialSettings
        batteryStatus = batteryService.status

        batteryService.$status
            .sink { [weak self] status in
                self?.applyBatteryStatus(status)
            }
            .store(in: &cancellables)

        applyBatteryStatus(batteryStatus)
    }

    func start() {
        applyBatteryStatus(batteryStatus)
    }

    func stop() {}

    func updateSettings(_ settings: BatterySettings) {
        batterySettings = settings
        applyBatteryStatus(batteryStatus)
    }

    func enableLowBatterySurvivalMode() {
        guard featureFlags.enablesLowBatterySurvivalMode else {
            shouldPromptForSurvivalMode = false
            return
        }

        isLowBatterySurvivalModeEnabled = true
        shouldPromptForSurvivalMode = false
        deferredSurvivalPromptDismissal = true
    }

    func disableLowBatterySurvivalMode() {
        isLowBatterySurvivalModeEnabled = false
        torchService.setTorch(on: false)
    }

    func dismissSurvivalModePrompt() {
        shouldPromptForSurvivalMode = false
        deferredSurvivalPromptDismissal = true
    }

    private func applyBatteryStatus(_ status: BatteryStatus) {
        batteryStatus = status

        guard featureFlags.enablesLowBatterySurvivalMode else {
            shouldPromptForSurvivalMode = false
            deferredSurvivalPromptDismissal = false
            return
        }

        guard batterySettings.enablesSurvivalModeAtFifteenPercent else {
            shouldPromptForSurvivalMode = false
            deferredSurvivalPromptDismissal = false
            return
        }

        guard status.isBelowSurvivalThreshold else {
            shouldPromptForSurvivalMode = false
            deferredSurvivalPromptDismissal = false
            return
        }

        guard !isLowBatterySurvivalModeEnabled else {
            shouldPromptForSurvivalMode = false
            return
        }

        if !deferredSurvivalPromptDismissal {
            shouldPromptForSurvivalMode = true
        }
    }
}
