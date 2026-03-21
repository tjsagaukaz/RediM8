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

    func testMapShowsFallbackStateWhenNoOfflinePackIsInstalled() {
        let app = makeMapReadyApp(mapScenario: .noInstalledPack)

        app.launch()

        XCTAssertTrue(app.scrollViews["map.root"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["map.statusHeadline"].label, "Offline fallback active")
        XCTAssertEqual(app.staticTexts["map.statusDetail"].label, "Using pack overlays and saved references only")
    }

    func testMapPackPanelShowsFallbackCoverageContext() {
        let app = makeMapReadyApp(mapScenario: .noInstalledPack)

        app.launch()

        XCTAssertTrue(app.scrollViews["map.root"].waitForExistence(timeout: 5))
        let packsToggle = app.buttons["map.packs.toggle"]
        scrollToElement(packsToggle, in: app.scrollViews["map.root"])
        packsToggle.tap()

        let coverageSummary = app.staticTexts["map.packs.coverageSummary"]
        XCTAssertTrue(coverageSummary.waitForExistence(timeout: 2))
        XCTAssertTrue(coverageSummary.label.contains("No regional pack is installed"))
    }

    func testMapShowsGracefulFallbackWhenLocalBasemapIsUnavailable() {
        let app = makeMapReadyApp(mapScenario: .basemapUnavailable)

        app.launch()

        XCTAssertTrue(app.scrollViews["map.root"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["map.statusHeadline"].label, "Offline fallback active")
        XCTAssertTrue(app.staticTexts["map.statusDetail"].label.contains("saved references only"))
    }

    func testPlanSupplyWorkspaceShowsFirstAidGapRecommendation() {
        let app = makePlanSuppliesReadyApp()

        app.launch()

        let planRoot = app.scrollViews["plan.root"]
        XCTAssertTrue(planRoot.waitForExistence(timeout: 5))

        let recommendationsCard = app.staticTexts["Missing Critical Items"]
        scrollToElement(recommendationsCard, in: planRoot)
        XCTAssertTrue(recommendationsCard.waitForExistence(timeout: 2))

        let recommendationTitle = app.staticTexts["First aid kit"]
        scrollToElement(recommendationTitle, in: planRoot)
        XCTAssertTrue(recommendationTitle.waitForExistence(timeout: 2))
    }

    func testPlanChecklistStateSurvivesHomeRoundTrip() {
        let app = makePlanReadyApp()

        app.launch()

        let planRoot = app.scrollViews["plan.root"]
        XCTAssertTrue(planRoot.waitForExistence(timeout: 5))

        let toggle = app.switches["plan.checklist.firstAidKit"]
        scrollToElement(toggle, in: planRoot)
        XCTAssertTrue(toggle.waitForExistence(timeout: 2))
        toggle.tap()
        XCTAssertTrue(waitUntil(timeout: 2) {
            switchValueIsOn(app.switches["plan.checklist.firstAidKit"])
        })

        app.buttons["Home"].tap()
        XCTAssertTrue(app.scrollViews["home.root"].waitForExistence(timeout: 2))

        app.buttons["More"].tap()
        XCTAssertTrue(planRoot.waitForExistence(timeout: 2))

        let reloadedToggle = app.switches["plan.checklist.firstAidKit"]
        scrollToElement(reloadedToggle, in: planRoot)
        XCTAssertTrue(reloadedToggle.waitForExistence(timeout: 2))
        XCTAssertTrue(waitUntil(timeout: 2) {
            switchValueIsOn(app.switches["plan.checklist.firstAidKit"])
        })
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

    private func makeMapReadyApp(mapScenario: MapScenario) -> XCUIApplication {
        let app = makeHomeReadyApp()
        app.launchArguments += [
            "-ui-testing-start-map",
            mapScenario.launchArgument
        ]
        return app
    }

    private func makePlanReadyApp() -> XCUIApplication {
        let app = makeHomeReadyApp()
        app.launchArguments += [
            "-ui-testing-start-plan"
        ]
        return app
    }

    private func makePlanSuppliesReadyApp() -> XCUIApplication {
        let app = makeHomeReadyApp()
        app.launchArguments += [
            "-ui-testing-start-plan-supplies"
        ]
        return app
    }

    private func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement, maxSwipes: Int = 6) {
        var attempts = 0
        while !element.isHittable && attempts < maxSwipes {
            scrollView.swipeUp()
            attempts += 1
        }
    }

    private func waitForNonExistence(of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return !element.exists
    }

    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    private func switchValueIsOn(_ element: XCUIElement) -> Bool {
        guard let value = element.value as? String else {
            return false
        }

        return value == "1" || value.caseInsensitiveCompare("on") == .orderedSame
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

private enum MapScenario {
    case noInstalledPack
    case basemapUnavailable

    var launchArgument: String {
        switch self {
        case .noInstalledPack:
            "-ui-testing-map-no-installed-pack"
        case .basemapUnavailable:
            "-ui-testing-map-basemap-unavailable"
        }
    }
}
