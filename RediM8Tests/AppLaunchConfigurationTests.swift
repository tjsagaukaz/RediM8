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
        XCTAssertFalse(configuration.skipsOnboarding)
        XCTAssertFalse(configuration.startsInEmergencyMode)
    }

    @MainActor
    func testEmergencyLaunchPresetAlsoSkipsOnboarding() {
        let configuration = AppLaunchConfiguration.current(arguments: [
            "RediM8",
            "-ui-testing",
            "-ui-testing-start-emergency-mode"
        ])

        XCTAssertTrue(configuration.usesTestingEnvironment)
        XCTAssertTrue(configuration.skipsOnboarding)
        XCTAssertTrue(configuration.startsInEmergencyMode)
    }

    @MainActor
    func testUnavailableOfficialAlertPresetIsParsed() {
        let configuration = AppLaunchConfiguration.current(arguments: [
            "RediM8",
            "-ui-testing",
            "-ui-testing-skip-onboarding",
            "-ui-testing-official-alerts-unavailable"
        ])

        XCTAssertEqual(configuration.officialAlertScenario, .unavailable)
    }

    @MainActor
    func testRecoveredOfficialAlertPresetIsParsed() {
        let configuration = AppLaunchConfiguration.current(arguments: [
            "RediM8",
            "-ui-testing",
            "-ui-testing-skip-onboarding",
            "-ui-testing-official-alerts-recovered"
        ])

        XCTAssertEqual(configuration.officialAlertScenario, .cachedNearbyWarning)
    }
}
