import XCTest
@testable import RediM8

final class NavigationRouterTests: XCTestCase {
    @MainActor
    func testOpenSignalNearbySelectsSignalTabAndClearsTransientState() {
        let router = NavigationRouter()
        router.activeOverlay = .emergencyGuides
        router.highlightedGuideCategory = .firstAid
        router.activeOverlay = .blackout

        router.openSignalNearby()

        XCTAssertEqual(router.selectedTab, .signal)
        XCTAssertFalse(router.isShowingEmergencyGuides)
        XCTAssertNil(router.highlightedGuideCategory)
        XCTAssertFalse(router.isShowingBlackout)
    }

    @MainActor
    func testPresentEmergencyModeStartsEmergencySession() {
        let router = NavigationRouter()
        let appState = AppState(store: nil)

        router.presentEmergencyMode(appState: appState)

        XCTAssertTrue(appState.isEmergencyAccessActive)
        XCTAssertTrue(router.isShowingEmergencyMode)
        XCTAssertFalse(router.isShowingEmergencyGuides)
        XCTAssertFalse(router.isShowingBlackout)
    }

    @MainActor
    func testPresentLeaveNowModeStartsEmergencySession() {
        let router = NavigationRouter()
        let appState = AppState(store: nil)

        router.presentLeaveNowMode(appState: appState)

        XCTAssertTrue(appState.isEmergencyAccessActive)
        XCTAssertTrue(router.isShowingLeaveNowMode)
        XCTAssertFalse(router.isShowingEmergencyMode)
        XCTAssertFalse(router.isShowingBlackout)
    }

    @MainActor
    func testOpenVehicleReadinessSelectsPlanTabAndRequestsVehicleFocus() {
        let router = NavigationRouter()

        router.openVehicleReadiness()

        XCTAssertEqual(router.selectedTab, .plan)
        XCTAssertEqual(router.requestedPlanFocus, .vehicleKit)
    }

    @MainActor
    func testOpenWaterRuntimeSelectsPlanTabAndRequestsWaterFocus() {
        let router = NavigationRouter()

        router.openWaterRuntime()

        XCTAssertEqual(router.selectedTab, .plan)
        XCTAssertEqual(router.requestedPlanFocus, .waterRuntime)
    }

    @MainActor
    func testOpenEvacuationRoutesSelectsPlanTabAndRequestsRouteFocus() {
        let router = NavigationRouter()

        router.openEvacuationRoutes()

        XCTAssertEqual(router.selectedTab, .plan)
        XCTAssertEqual(router.requestedPlanFocus, .evacuationRoutes)
    }

    @MainActor
    func testOpenVaultSelectsVaultTabAndClearsPlanFocus() {
        let router = NavigationRouter()
        router.requestedPlanFocus = .vehicleKit

        router.openVault()

        XCTAssertEqual(router.selectedTab, .vault)
        XCTAssertNil(router.requestedPlanFocus)
    }

    @MainActor
    func testOpenLibraryResolvesToMoreAndClearsPlanFocus() {
        let router = NavigationRouter()
        router.requestedPlanFocus = .householdOverview

        router.openLibrary()

        XCTAssertEqual(router.selectedTab, .more)
        XCTAssertNil(router.requestedPlanFocus)
    }

    @MainActor
    func testOpenTabFromEmergencyKeepsEmergencyAccessActiveForToolHandoff() {
        let router = NavigationRouter()
        let appState = AppState(store: nil)
        router.presentEmergencyMode(appState: appState)

        router.openTabFromEmergency(.map, appState: appState)

        XCTAssertFalse(router.isShowingEmergencyMode)
        XCTAssertEqual(router.selectedTab, .map)
        XCTAssertTrue(appState.isEmergencyAccessActive)
    }

    @MainActor
    func testOpenTabFromLeaveNowKeepsEmergencyAccessActiveForToolHandoff() {
        let router = NavigationRouter()
        let appState = AppState(store: nil)
        router.presentLeaveNowMode(appState: appState)

        router.openTabFromLeaveNow(.signal, appState: appState)

        XCTAssertFalse(router.isShowingLeaveNowMode)
        XCTAssertEqual(router.selectedTab, .signal)
        XCTAssertTrue(appState.isEmergencyAccessActive)
    }

    // MARK: - State Machine Exclusivity

    @MainActor
    func testOverlayModeIsMutuallyExclusive() {
        let router = NavigationRouter()
        let appState = AppState(store: nil)

        router.presentEmergencyMode(appState: appState)
        XCTAssertEqual(router.activeOverlay, .emergencyMode)

        router.presentBlackout(appState: appState)
        XCTAssertEqual(router.activeOverlay, .blackout)
        XCTAssertFalse(router.isShowingEmergencyMode, "Emergency mode should be cleared when blackout is presented")
    }

    @MainActor
    func testPresentLeaveNowClearsEmergencyMode() {
        let router = NavigationRouter()
        let appState = AppState(store: nil)

        router.presentEmergencyMode(appState: appState)
        router.presentLeaveNowMode(appState: appState)

        XCTAssertTrue(router.isShowingLeaveNowMode)
        XCTAssertFalse(router.isShowingEmergencyMode)
        XCTAssertFalse(router.isShowingBlackout)
    }

    @MainActor
    func testDismissEmergencyModeEndsSessionWhenNoOverlayActive() {
        let router = NavigationRouter()
        let appState = AppState(store: nil)

        router.presentEmergencyMode(appState: appState)
        router.dismissEmergencyMode(appState: appState)

        XCTAssertNil(router.activeOverlay)
        XCTAssertFalse(appState.isEmergencyAccessActive)
    }

    @MainActor
    func testDismissBlackoutEndsSessionWhenNoOverlayActive() {
        let router = NavigationRouter()
        let appState = AppState(store: nil)

        router.presentBlackout(appState: appState)
        router.dismissBlackout(appState: appState)

        XCTAssertNil(router.activeOverlay)
        XCTAssertFalse(appState.isEmergencyAccessActive)
    }

    @MainActor
    func testPresentEmergencyModeTwiceKeepsSingleOverlayAndSessionActive() {
        let router = NavigationRouter()
        let appState = AppState(store: nil)

        router.presentEmergencyMode(appState: appState)
        router.presentEmergencyMode(appState: appState)

        XCTAssertEqual(router.activeOverlay, .emergencyMode)
        XCTAssertTrue(appState.isEmergencyAccessActive)
    }

    @MainActor
    func testEmergencyModeCanBeDismissedAndPresentedAgainQuickly() {
        let router = NavigationRouter()
        let appState = AppState(store: nil)

        router.presentEmergencyMode(appState: appState)
        router.dismissEmergencyMode(appState: appState)
        router.presentEmergencyMode(appState: appState)

        XCTAssertEqual(router.activeOverlay, .emergencyMode)
        XCTAssertTrue(appState.isEmergencyAccessActive)
    }

    @MainActor
    func testForegroundRestoreReactivatesEmergencySessionWhenOverlayRemainsVisible() {
        let router = NavigationRouter()
        let appState = AppState(store: nil)

        router.presentEmergencyMode(appState: appState)
        router.handleBackgroundTransition(appState: appState)

        XCTAssertTrue(router.isShowingEmergencyMode)
        XCTAssertFalse(appState.isEmergencyAccessActive)

        router.restoreEmergencyAccessSessionIfNeeded(appState: appState)

        XCTAssertTrue(router.isShowingEmergencyMode)
        XCTAssertTrue(appState.isEmergencyAccessActive)
    }
}
