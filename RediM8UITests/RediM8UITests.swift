import XCTest

final class RediM8UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFirstRunOnboardingCompletesAndShowsHome() {
        let app = makeApp()

        app.launch()

        let primaryAction = app.buttons["onboarding.primaryAction"]
        XCTAssertTrue(app.staticTexts["onboarding.stepTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["onboarding.stepTitle"].label, "System Setup")

        primaryAction.tap()
        XCTAssertEqual(app.staticTexts["onboarding.stepTitle"].label, "Authority")

        primaryAction.tap()
        XCTAssertEqual(app.staticTexts["onboarding.stepTitle"].label, "Operational Context")

        app.buttons["onboarding.scenario.bushfires"].tap()
        primaryAction.tap()
        XCTAssertEqual(app.staticTexts["onboarding.stepTitle"].label, "Activation")

        primaryAction.tap()

        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 5))
    }

    func testScenarioSelectionPersistsWhenMovingBackFromActivation() {
        let app = makeApp()

        app.launch()

        let primaryAction = app.buttons["onboarding.primaryAction"]
        primaryAction.tap()
        primaryAction.tap()

        let bushfireScenario = app.buttons["onboarding.scenario.bushfires"]
        XCTAssertTrue(bushfireScenario.waitForExistence(timeout: 5))
        bushfireScenario.tap()
        XCTAssertEqual(bushfireScenario.value as? String, "Selected")

        primaryAction.tap()
        XCTAssertEqual(app.staticTexts["onboarding.stepTitle"].label, "Activation")

        app.buttons["onboarding.backAction"].tap()

        XCTAssertEqual(app.staticTexts["onboarding.stepTitle"].label, "Operational Context")
        XCTAssertEqual(bushfireScenario.value as? String, "Selected")
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-disable-automatic-alert-refresh"
        ]
        return app
    }
}
