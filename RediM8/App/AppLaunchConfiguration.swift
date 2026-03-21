import Foundation

@MainActor
struct AppLaunchConfiguration {
    private enum Argument {
        static let uiTesting = "-ui-testing"
        static let disableAutomaticAlertRefresh = "-disable-automatic-alert-refresh"
    }

    let environment: AppEnvironment
    let usesTestingEnvironment: Bool
    let disablesAutomaticAlertRefresh: Bool

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppLaunchConfiguration {
        let arguments = Set(arguments)
        let usesTestingEnvironment = arguments.contains(Argument.uiTesting)
        let disablesAutomaticAlertRefresh =
            usesTestingEnvironment || arguments.contains(Argument.disableAutomaticAlertRefresh)

        let environment: AppEnvironment
        if usesTestingEnvironment {
            environment = .testing(store: nil)
        } else {
            environment = .live()
        }

        return AppLaunchConfiguration(
            environment: environment,
            usesTestingEnvironment: usesTestingEnvironment,
            disablesAutomaticAlertRefresh: disablesAutomaticAlertRefresh
        )
    }
}
