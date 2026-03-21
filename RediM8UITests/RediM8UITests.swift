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

    func testHomeShowsUnavailableOfficialAlertsStateWhenNoCacheExists() {
        let app = makeHomeReadyApp(officialAlertScenario: .unavailable)

        app.launch()

        XCTAssertTrue(app.scrollViews["home.root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["home.todayLocalStatus.card"].exists)
        XCTAssertEqual(app.staticTexts["home.todayLocalStatus.title"].label, "Official alerts unavailable")
        let detail = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Connect once")
        ).firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 2))
    }

    func testHomeShowsRecoveredCachedAlertState() {
        let app = makeHomeReadyApp(officialAlertScenario: .cachedNearbyWarning)

        app.launch()

        XCTAssertTrue(app.scrollViews["home.root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["home.todayLocalStatus.card"].exists)
        XCTAssertEqual(
            app.staticTexts["home.todayLocalStatus.title"].label,
            "Monitoring official feeds and local conditions"
        )
        let detail = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Queensland Fire and Emergency Services")
        ).firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 2))
    }

    func testEmergencyModeEntryFromHomeIsFastAndFocused() {
        let app = makeHomeReadyApp()

        app.launch()
        app.buttons["home.commandTools.toggle"].tap()

        let trigger = app.buttons["home.emergencyModeTrigger"]
        XCTAssertTrue(trigger.waitForExistence(timeout: 5))

        let startedAt = Date()
        trigger.tap()

        let closeButton = app.buttons["emergency.mode.close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2))
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 1.75)
        XCTAssertFalse(trigger.isHittable)
    }

    func testEmergencyModeDefaultStateStaysMinimal() {
        let app = makeEmergencyModeApp()

        app.launch()

        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["emergency.mode.close"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["emergency.mode.instructions"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["emergency.mode.primaryLane"].exists)
        XCTAssertFalse(app.buttons["emergency.mode.support.blackout"].exists)
        XCTAssertFalse(app.buttons["emergency.mode.support.firstAid"].exists)
    }

    func testEmergencyModeSuppressesProAndGearUpsell() {
        let app = makeEmergencyModeApp()

        app.launch()

        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Open Pro Tools"].exists)
        XCTAssertFalse(app.buttons["See Pro Plans"].exists)
        XCTAssertFalse(app.buttons["View options"].exists)
    }

    func testEmergencyModeExitRestoresHomeState() {
        let app = makeHomeReadyApp()

        app.launch()
        app.buttons["home.commandTools.toggle"].tap()
        app.buttons["home.emergencyModeTrigger"].tap()

        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))

        app.buttons["emergency.mode.close"].tap()

        XCTAssertTrue(app.scrollViews["home.root"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["home.emergencyModeTrigger"].waitForExistence(timeout: 2))
    }

    func testEmergencyModeCanBeReenteredAfterQuickExit() {
        let app = makeHomeReadyApp()

        app.launch()
        app.buttons["home.commandTools.toggle"].tap()

        let trigger = app.buttons["home.emergencyModeTrigger"]
        trigger.tap()
        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))

        app.buttons["emergency.mode.close"].tap()
        XCTAssertTrue(trigger.waitForExistence(timeout: 2))

        trigger.tap()
        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))
    }

    func testEmergencyModeSurvivesBackgroundAndForeground() {
        let app = makeEmergencyModeApp()

        app.launch()
        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["emergency.mode.close"].isHittable)
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-disable-automatic-alert-refresh"
        ]
        return app
    }

    private func makeHomeReadyApp() -> XCUIApplication {
        let app = makeApp()
        app.launchArguments += [
            "-ui-testing-skip-onboarding"
        ]
        return app
    }

    private func makeHomeReadyApp(officialAlertScenario: OfficialAlertScenario) -> XCUIApplication {
        let app = makeHomeReadyApp()
        app.launchArguments += [officialAlertScenario.launchArgument]
        return app
    }

    private func makeEmergencyModeApp() -> XCUIApplication {
        let app = makeHomeReadyApp()
        app.launchArguments += [
            "-ui-testing-start-emergency-mode"
        ]
        return app
    }
}

private enum OfficialAlertScenario {
    case unavailable
    case cachedNearbyWarning

    var launchArgument: String {
        switch self {
        case .unavailable:
            "-ui-testing-official-alerts-unavailable"
        case .cachedNearbyWarning:
            "-ui-testing-official-alerts-recovered"
        }
    }
}
