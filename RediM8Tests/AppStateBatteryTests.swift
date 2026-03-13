import UIKit
import XCTest
@testable import RediM8

final class AppStateBatteryTests: XCTestCase {
    @MainActor
    func testLowBatteryPromptsForSurvivalMode() {
        let appState = AppState(store: nil)

        appState.applyBatteryStatus(BatteryStatus(level: 0.14, state: .unplugged))

        XCTAssertTrue(appState.shouldPromptForSurvivalMode)
        XCTAssertFalse(appState.isLowBatterySurvivalModeEnabled)
    }

    @MainActor
    func testEnablingSurvivalModeClearsPrompt() {
        let appState = AppState(store: nil)
        appState.applyBatteryStatus(BatteryStatus(level: 0.12, state: .unplugged))

        appState.enableLowBatterySurvivalMode()

        XCTAssertTrue(appState.isLowBatterySurvivalModeEnabled)
        XCTAssertFalse(appState.shouldPromptForSurvivalMode)
        XCTAssertTrue(appState.isEmergencyAccessActive)
    }

    @MainActor
    func testPromptCanTriggerAgainAfterBatteryRecovers() {
        let appState = AppState(store: nil)

        appState.applyBatteryStatus(BatteryStatus(level: 0.10, state: .unplugged))
        appState.dismissSurvivalModePrompt()
        XCTAssertFalse(appState.shouldPromptForSurvivalMode)

        appState.applyBatteryStatus(BatteryStatus(level: 0.45, state: .charging))
        appState.applyBatteryStatus(BatteryStatus(level: 0.10, state: .unplugged))

        XCTAssertTrue(appState.shouldPromptForSurvivalMode)
    }
}
