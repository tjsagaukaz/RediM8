import XCTest
@testable import RediM8

final class NavigationRouterTests: XCTestCase {
    @MainActor
    func testOpenSignalNearbySelectsSignalTabAndClearsTransientState() {
        let router = NavigationRouter()
        router.isShowingEmergencyGuides = true
        router.highlightedGuideCategory = .firstAid
        router.isShowingBlackout = true

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
    func testOpenLibrarySelectsLibraryTabAndClearsPlanFocus() {
        let router = NavigationRouter()
        router.requestedPlanFocus = .householdOverview

        router.openLibrary()

        XCTAssertEqual(router.selectedTab, .library)
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
}
