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

    enum UITestMapScenario: Equatable {
        case noInstalledPack
        case basemapUnavailable

        fileprivate init?(arguments: Set<String>) {
            if arguments.contains(Argument.mapNoInstalledPack) {
                self = .noInstalledPack
            } else if arguments.contains(Argument.mapBasemapUnavailable) {
                self = .basemapUnavailable
            } else {
                return nil
            }
        }

        @MainActor
        func apply(to appState: AppState) {
            #if DEBUG
            appState.mutateSettings { settings in
                settings.maps.surfaceMode = .tactical
            }

            switch self {
            case .noInstalledPack:
                appState.mapDataService.seedInstalledPackIDsForTesting([])
                let currentStyleURL = appState.offlineBasemapService.configuration.styleURL
                appState.offlineBasemapService.seedForTesting(
                    configuration: OfflineBasemapService.Configuration(
                        styleURL: currentStyleURL,
                        mode: .fallback(reason: "No verified local tile package is available.")
                    )
                )
            case .basemapUnavailable:
                let currentStyleURL = appState.offlineBasemapService.configuration.styleURL
                appState.offlineBasemapService.seedForTesting(
                    configuration: OfflineBasemapService.Configuration(
                        styleURL: currentStyleURL,
                        mode: .fallback(reason: "Installed basemap package is incomplete or invalid.")
                    )
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
        static let startMap = "-ui-testing-start-map"
        static let officialAlertsUnavailable = "-ui-testing-official-alerts-unavailable"
        static let officialAlertsRecovered = "-ui-testing-official-alerts-recovered"
        static let mapNoInstalledPack = "-ui-testing-map-no-installed-pack"
        static let mapBasemapUnavailable = "-ui-testing-map-basemap-unavailable"
    }

    let environment: AppEnvironment
    let usesTestingEnvironment: Bool
    let disablesAutomaticAlertRefresh: Bool
    let disablesAutomaticMapActivity: Bool
    let skipsOnboarding: Bool
    let startsOnMap: Bool
    let startsInEmergencyMode: Bool
    let officialAlertScenario: UITestOfficialAlertScenario?
    let mapScenario: UITestMapScenario?

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppLaunchConfiguration {
        let arguments = Set(arguments)
        let usesTestingEnvironment = arguments.contains(Argument.uiTesting)
        let mapScenario = UITestMapScenario(arguments: arguments)
        let disablesAutomaticAlertRefresh =
            usesTestingEnvironment || arguments.contains(Argument.disableAutomaticAlertRefresh)
        let disablesAutomaticMapActivity = mapScenario != nil
        let startsInEmergencyMode = arguments.contains(Argument.startEmergencyMode)
        let startsOnMap = arguments.contains(Argument.startMap) || mapScenario != nil
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
            disablesAutomaticMapActivity: disablesAutomaticMapActivity,
            skipsOnboarding: skipsOnboarding,
            startsOnMap: startsOnMap,
            startsInEmergencyMode: startsInEmergencyMode,
            officialAlertScenario: officialAlertScenario,
            mapScenario: mapScenario
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
        mapScenario?.apply(to: appState)

        if startsOnMap {
            router.selectedTab = .map
        }

        if startsInEmergencyMode {
            router.presentEmergencyMode(appState: appState)
        }
    }
}
