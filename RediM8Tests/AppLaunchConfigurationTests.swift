import XCTest
@testable import RediM8

final class AppLaunchConfigurationTests: XCTestCase {
    @MainActor
    func testUITestLaunchUsesTestingEnvironmentAndDisablesAutomaticRefresh() {
        let configuration = AppLaunchConfiguration.current(arguments: ["RediM8", "-ui-testing"])

        XCTAssertTrue(configuration.usesTestingEnvironment)
        XCTAssertTrue(configuration.disablesAutomaticAlertRefresh)
    }

    @MainActor
    func testRefreshCanBeDisabledWithoutSwitchingToTestingEnvironment() {
        let configuration = AppLaunchConfiguration.current(arguments: ["RediM8", "-disable-automatic-alert-refresh"])

        XCTAssertFalse(configuration.usesTestingEnvironment)
        XCTAssertTrue(configuration.disablesAutomaticAlertRefresh)
    }
}
