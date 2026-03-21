import XCTest

final class RediM8UITests: XCTestCase {
    private static let appBundleIdentifier = "au.com.redim8.app"
    private static let launchSettleDelay: TimeInterval = 1.0

    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateRunningAppIfNeeded()
    }

    override func tearDownWithError() throws {
        terminateRunningAppIfNeeded()
        try super.tearDownWithError()
    }

    func testFirstRunOnboardingCompletesAndShowsHome() {
        let app = makeApp()

        launchApp(app)

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

        launchApp(app)

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

        launchApp(app)

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

        launchApp(app)

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

        launchApp(app)
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

        launchApp(app)

        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["emergency.mode.close"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["emergency.mode.instructions"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["emergency.mode.primaryLane"].exists)
        XCTAssertFalse(app.buttons["emergency.mode.support.blackout"].exists)
        XCTAssertFalse(app.buttons["emergency.mode.support.firstAid"].exists)
    }

    func testEmergencyModeSuppressesProAndGearUpsell() {
        let app = makeEmergencyModeApp()

        launchApp(app)

        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Open Pro Tools"].exists)
        XCTAssertFalse(app.buttons["See Pro Plans"].exists)
        XCTAssertFalse(app.buttons["View options"].exists)
    }

    func testEmergencyModeExitRestoresHomeState() {
        let app = makeHomeReadyApp()

        launchApp(app)
        app.buttons["home.commandTools.toggle"].tap()
        app.buttons["home.emergencyModeTrigger"].tap()

        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))

        app.buttons["emergency.mode.close"].tap()

        XCTAssertTrue(app.scrollViews["home.root"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["home.emergencyModeTrigger"].waitForExistence(timeout: 2))
    }

    func testEmergencyModeCanBeReenteredAfterQuickExit() {
        let app = makeHomeReadyApp()

        launchApp(app)
        app.buttons["home.commandTools.toggle"].tap()

        let trigger = app.buttons["home.emergencyModeTrigger"]
        XCTAssertTrue(trigger.waitForExistence(timeout: 5))
        trigger.tap()
        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))

        app.buttons["emergency.mode.close"].tap()
        XCTAssertTrue(app.scrollViews["home.root"].waitForExistence(timeout: 2))
        XCTAssertTrue(trigger.waitForExistence(timeout: 2))

        trigger.tap()
        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))
    }

    func testEmergencyModeSurvivesBackgroundAndForeground() {
        let app = makeEmergencyModeApp()

        launchApp(app)
        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(app.scrollViews["emergency.mode.root"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["emergency.mode.close"].isHittable)
    }

    func testMapShowsFallbackStateWhenNoOfflinePackIsInstalled() {
        let app = makeMapReadyApp(mapScenario: .noInstalledPack)

        launchApp(app)

        XCTAssertTrue(app.scrollViews["map.root"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["map.statusHeadline"].label, "Offline fallback active")
        XCTAssertEqual(app.staticTexts["map.statusDetail"].label, "Using pack overlays and saved references only")
    }

    func testMapPackPanelShowsFallbackCoverageContext() {
        let app = makeMapReadyApp(mapScenario: .noInstalledPack)

        launchApp(app)

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

        launchApp(app)

        XCTAssertTrue(app.scrollViews["map.root"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["map.statusHeadline"].label, "Offline fallback active")
        XCTAssertTrue(app.staticTexts["map.statusDetail"].label.contains("saved references only"))
    }

    func testPlanSupplyWorkspaceShowsFirstAidGapRecommendation() {
        let app = makePlanSuppliesReadyApp()

        launchApp(app)

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

        launchApp(app)

        let planRoot = app.scrollViews["plan.root"]
        XCTAssertTrue(planRoot.waitForExistence(timeout: 5))

        let toggle = app.switches["plan.checklist.firstAidKit"]
        setSwitch(toggle, in: planRoot, isOn: true)

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

    private func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement, maxSwipes: Int = 12) {
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

    private func launchApp(_ app: XCUIApplication) {
        terminateRunningAppIfNeeded()
        Thread.sleep(forTimeInterval: Self.launchSettleDelay)
        app.launch()
    }

    private func terminateRunningAppIfNeeded() {
        let app = XCUIApplication(bundleIdentifier: Self.appBundleIdentifier)
        guard app.state != .notRunning, app.state != .unknown else {
            return
        }

        app.terminate()
        _ = waitUntil(timeout: 5) {
            app.state == .notRunning || app.state == .unknown
        }
        Thread.sleep(forTimeInterval: Self.launchSettleDelay)
    }

    private func switchValueIsOn(_ element: XCUIElement) -> Bool {
        guard let value = element.value as? String else {
            return false
        }

        return value == "1" || value.caseInsensitiveCompare("on") == .orderedSame
    }

    private func setSwitch(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        isOn: Bool,
        maxAttempts: Int = 3
    ) {
        for _ in 0 ..< maxAttempts {
            scrollToElement(element, in: scrollView)
            XCTAssertTrue(element.waitForExistence(timeout: 2))
            XCTAssertTrue(waitUntil(timeout: 2) { element.isHittable })

            if switchValueIsOn(element) == isOn {
                return
            }

            if setSwitchStateViaTap(element, isOn: isOn) {
                return
            }
        }

        XCTFail(
            "Failed to set switch to expected value after \(maxAttempts) attempts. Final value: \(String(describing: element.value))"
        )
    }

    private func setSwitchStateViaTap(_ element: XCUIElement, isOn: Bool) -> Bool {
        let tapStrategies: [(XCUIElement) -> Void] = [
            { $0.tap() },
            { $0.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap() },
            { $0.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        ]

        for tap in tapStrategies {
            tap(element)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))

            if waitUntil(timeout: 0.75, condition: { switchValueIsOn(element) == isOn }) {
                return true
            }
        }

        return false
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
