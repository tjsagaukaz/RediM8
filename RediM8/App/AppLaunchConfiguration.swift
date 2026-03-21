import CoreLocation
import Foundation

@MainActor
struct AppLaunchConfiguration {
    enum UITestOfficialAlertScenario: Equatable {
        case unavailable
        case cachedNearbyWarning

        fileprivate init?(arguments: Set<String>) {
            if arguments.contains(Argument.officialAlertsUnavailable) {
                self = .unavailable
            } else if arguments.contains(Argument.officialAlertsRecovered) {
                self = .cachedNearbyWarning
            } else {
                return nil
            }
        }

        @MainActor
        func apply(to appState: AppState) {
            #if DEBUG
            switch self {
            case .unavailable:
                appState.officialAlertService.seedForTesting(
                    library: .empty,
                    lastRefreshError: OfficialAlertService.noCachedAlertsMessage
                )
            case .cachedNearbyWarning:
                let source = OfficialAlertSource(
                    id: "ui_test_qld_alerts",
                    name: "Queensland Official Warnings",
                    jurisdiction: .qld,
                    urlString: "https://example.com/qld-test-alerts"
                )
                let alert = OfficialAlert(
                    id: "ui_test_qld_warning",
                    title: "Flood warning for Brisbane Hinterland",
                    message: "Creeks are rising and roads may become cut.",
                    instruction: "Move to higher ground if needed.",
                    issuer: "Queensland Fire and Emergency Services",
                    sourceName: source.name,
                    sourceURLString: source.urlString,
                    jurisdiction: source.jurisdiction,
                    kind: .flood,
                    severity: .advice,
                    regionScope: "Brisbane Hinterland",
                    area: OfficialAlertArea(
                        description: "Brisbane Hinterland",
                        center: GeoPoint(latitude: -27.4, longitude: 152.9),
                        radiusKilometres: 18
                    ),
                    issuedAt: .now.addingTimeInterval(-900),
                    lastUpdated: .now.addingTimeInterval(-300),
                    expiresAt: .now.addingTimeInterval(10_800)
                )
                appState.locationService.simulateAuthorizationStatus(.authorizedWhenInUse)
                appState.locationService.simulate(
                    location: CLLocation(latitude: -27.47, longitude: 153.02)
                )
                appState.officialAlertService.seedForTesting(
                    library: OfficialAlertLibrary(
                        lastUpdated: .now.addingTimeInterval(-120),
                        sources: [source],
                        alerts: [alert]
                    ),
                    lastRefreshError: nil
                )
            }
            #else
            _ = appState
            #endif
        }
    }

    private enum Argument {
        static let uiTesting = "-ui-testing"
        static let disableAutomaticAlertRefresh = "-disable-automatic-alert-refresh"
        static let skipOnboarding = "-ui-testing-skip-onboarding"
        static let startEmergencyMode = "-ui-testing-start-emergency-mode"
        static let officialAlertsUnavailable = "-ui-testing-official-alerts-unavailable"
        static let officialAlertsRecovered = "-ui-testing-official-alerts-recovered"
    }

    let environment: AppEnvironment
    let usesTestingEnvironment: Bool
    let disablesAutomaticAlertRefresh: Bool
    let skipsOnboarding: Bool
    let startsInEmergencyMode: Bool
    let officialAlertScenario: UITestOfficialAlertScenario?

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppLaunchConfiguration {
        let arguments = Set(arguments)
        let usesTestingEnvironment = arguments.contains(Argument.uiTesting)
        let disablesAutomaticAlertRefresh =
            usesTestingEnvironment || arguments.contains(Argument.disableAutomaticAlertRefresh)
        let startsInEmergencyMode = arguments.contains(Argument.startEmergencyMode)
        let skipsOnboarding = startsInEmergencyMode || arguments.contains(Argument.skipOnboarding)
        let officialAlertScenario = UITestOfficialAlertScenario(arguments: arguments)

        let environment: AppEnvironment
        if usesTestingEnvironment {
            environment = .testing(store: nil)
        } else {
            environment = .live()
        }

        return AppLaunchConfiguration(
            environment: environment,
            usesTestingEnvironment: usesTestingEnvironment,
            disablesAutomaticAlertRefresh: disablesAutomaticAlertRefresh,
            skipsOnboarding: skipsOnboarding,
            startsInEmergencyMode: startsInEmergencyMode,
            officialAlertScenario: officialAlertScenario
        )
    }

    func apply(to appState: AppState, router: NavigationRouter) {
        if skipsOnboarding {
            var profile = appState.profile
            if profile.selectedScenarios.isEmpty {
                profile.selectedScenarios = [.generalEmergencies]
            }
            appState.completeOnboarding(with: profile)
        }

        officialAlertScenario?.apply(to: appState)

        if startsInEmergencyMode {
            router.presentEmergencyMode(appState: appState)
        }
    }
}
