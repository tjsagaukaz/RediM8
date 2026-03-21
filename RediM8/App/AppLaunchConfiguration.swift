import Foundation

@MainActor
struct AppLaunchConfiguration {
    private enum Argument {
        static let uiTesting = "-ui-testing"
        static let disableAutomaticAlertRefresh = "-disable-automatic-alert-refresh"
        static let skipOnboarding = "-ui-testing-skip-onboarding"
        static let startEmergencyMode = "-ui-testing-start-emergency-mode"
    }

    let environment: AppEnvironment
    let usesTestingEnvironment: Bool
    let disablesAutomaticAlertRefresh: Bool
    let skipsOnboarding: Bool
    let startsInEmergencyMode: Bool

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppLaunchConfiguration {
        let arguments = Set(arguments)
        let usesTestingEnvironment = arguments.contains(Argument.uiTesting)
        let disablesAutomaticAlertRefresh =
            usesTestingEnvironment || arguments.contains(Argument.disableAutomaticAlertRefresh)
        let startsInEmergencyMode = arguments.contains(Argument.startEmergencyMode)
        let skipsOnboarding = startsInEmergencyMode || arguments.contains(Argument.skipOnboarding)

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
            startsInEmergencyMode: startsInEmergencyMode
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

        if startsInEmergencyMode {
            router.presentEmergencyMode(appState: appState)
        }
    }
}
