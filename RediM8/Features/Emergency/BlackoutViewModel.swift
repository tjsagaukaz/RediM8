import Combine
import Foundation

@MainActor
final class BlackoutViewModel: ObservableObject {
    @Published private(set) var isTorchOn = false
    @Published private(set) var headingText = "0° N"
    @Published private(set) var orientationSummary = "Stable"
    @Published private(set) var emergencyContacts: [EmergencyContact] = []
    @Published private(set) var quickContacts: [EmergencyQuickContact] = []

    private let torchService: TorchService
    private let locationService: LocationService
    private let motionService: MotionService
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        torchService = appState.torchService
        locationService = appState.locationService
        motionService = appState.motionService
        emergencyContacts = appState.profile.emergencyContacts
        quickContacts = TrustLayer.quickContacts(for: appState.profile)

        appState.$profile
            .sink { [weak self] profile in
                self?.emergencyContacts = profile.emergencyContacts
                self?.quickContacts = TrustLayer.quickContacts(for: profile)
            }
            .store(in: &cancellables)

        torchService.$isTorchOn
            .assign(to: &$isTorchOn)

        locationService.$heading
            .map(Self.headingText(from:))
            .assign(to: &$headingText)

        motionService.$orientationSummary
            .assign(to: &$orientationSummary)
    }

    func onAppear() {
        locationService.start()
        motionService.start()
    }

    func onDisappear() {
        locationService.stop()
        motionService.stop()
        torchService.setTorch(on: false)
    }

    func toggleTorch() {
        torchService.toggleTorch()
    }

    private static func headingText(from value: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]
        let index = Int((value / 45.0).rounded()) % 8
        return "\(Int(value.rounded()))° \(directions[index])"
    }
}
