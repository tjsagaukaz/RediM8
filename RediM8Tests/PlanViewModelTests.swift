import Foundation
import XCTest
@testable import RediM8

@MainActor
final class PlanViewModelTests: XCTestCase {
    func testRapidChecklistChangesPersistLatestStateAndRefreshRecommendations() throws {
        let store = try SQLiteStore(filename: "PlanViewModelTests-\(UUID().uuidString).sqlite")
        let appState = AppState(store: store)
        let viewModel = PlanViewModel(appState: appState)

        XCTAssertTrue(viewModel.preparednessGearRecommendations.contains(where: { $0.id == "first_aid_gap" }))

        let firstAidIndex = try XCTUnwrap(
            viewModel.draft.checklistItems.firstIndex(where: { $0.kind == .firstAidKit })
        )

        viewModel.draft.checklistItems[firstAidIndex].isChecked = true
        viewModel.draft.checklistItems[firstAidIndex].isChecked = false
        viewModel.draft.checklistItems[firstAidIndex].isChecked = true

        XCTAssertFalse(viewModel.preparednessGearRecommendations.contains(where: { $0.id == "first_aid_gap" }))

        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        XCTAssertTrue(appState.profile.checklistState(for: .firstAidKit))
        XCTAssertEqual(appState.profile.checklistItems.filter { $0.kind == .firstAidKit }.count, 1)
    }

    func testPriorityModeSuppressesPreparednessRecommendationsUntilCleared() {
        let appState = AppState(store: nil)
        let viewModel = PlanViewModel(appState: appState)

        XCTAssertFalse(viewModel.preparednessGearRecommendations.isEmpty)

        appState.activatePriorityMode(for: .blackout)
        waitUntil("priority mode suppresses preparedness recommendations") {
            viewModel.isPreparednessGearSuppressed &&
                viewModel.preparednessGearRecommendations.isEmpty
        }

        XCTAssertTrue(viewModel.isPreparednessGearSuppressed)
        XCTAssertTrue(viewModel.preparednessGearRecommendations.isEmpty)

        appState.clearPriorityMode()
        waitUntil("priority mode clears and restores preparedness recommendations") {
            !viewModel.isPreparednessGearSuppressed &&
                !viewModel.preparednessGearRecommendations.isEmpty
        }

        XCTAssertFalse(viewModel.isPreparednessGearSuppressed)
        XCTAssertFalse(viewModel.preparednessGearRecommendations.isEmpty)
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 1.0,
        condition: () -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }

        XCTFail("Timed out waiting until \(description)")
    }
}
