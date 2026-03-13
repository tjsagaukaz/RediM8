import XCTest
@testable import RediM8

final class AppStateQuickActionTests: XCTestCase {
    @MainActor
    func testValidShortcutQueuesEmergencyAction() {
        let appState = AppState(store: nil)

        let handled = appState.handleShortcut(type: EmergencyQuickAction.blackoutMode.rawValue)

        XCTAssertTrue(handled)
        XCTAssertTrue(appState.isEmergencyAccessActive)
        XCTAssertEqual(appState.consumePendingQuickAction(), .blackoutMode)
        XCTAssertNil(appState.consumePendingQuickAction())
    }

    @MainActor
    func testStealthShortcutQueuesStealthAction() {
        let appState = AppState(store: nil)

        let handled = appState.handleShortcut(type: EmergencyQuickAction.stealthMode.rawValue)

        XCTAssertTrue(handled)
        XCTAssertTrue(appState.isEmergencyAccessActive)
        XCTAssertEqual(appState.consumePendingQuickAction(), .stealthMode)
        XCTAssertNil(appState.consumePendingQuickAction())
    }

    @MainActor
    func testUnknownShortcutIsIgnored() {
        let appState = AppState(store: nil)

        let handled = appState.handleShortcut(type: "unknown_action")

        XCTAssertFalse(handled)
        XCTAssertFalse(appState.isEmergencyAccessActive)
        XCTAssertNil(appState.consumePendingQuickAction())
    }
}
