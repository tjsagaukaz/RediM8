import XCTest
@testable import RediM8

final class SettingsViewModelTests: XCTestCase {
    @MainActor
    func testToggleStealthModeUpdatesStateAndNotice() {
        let appState = AppState(store: nil)
        let viewModel = SettingsViewModel(appState: appState)

        viewModel.toggleStealthMode(true)

        XCTAssertTrue(appState.isStealthModeEnabled)
        XCTAssertEqual(viewModel.notice?.title, "Stealth Mode Enabled")
    }

    @MainActor
    func testResetLocalNodeIDPublishesConfirmationNotice() {
        let appState = AppState(store: nil)
        let viewModel = SettingsViewModel(appState: appState)

        viewModel.resetLocalNodeID()

        XCTAssertEqual(viewModel.notice?.title, "Node ID Reset")
        XCTAssertTrue(viewModel.notice?.message.contains("Nearby users will now see Node") == true)
    }
}
