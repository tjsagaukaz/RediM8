import XCTest
@testable import RediM8

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testPreparednessChangesRefreshHomeReadinessState() {
        let appState = AppState(store: nil)
        let viewModel = HomeViewModel(appState: appState, disablesAutomaticAlertRefresh: true)
        let initialScore = viewModel.prepScore.overall

        var profile = UserProfile.empty
        profile.selectedScenarios = [.generalEmergencies, .powerOutages]
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 1)
        profile.supplies = Supplies(waterLitres: 52, foodDays: 8, fuelLitres: 24, batteryCapacity: 88)
        profile.checklistItems = ChecklistItemKind.allCases.map { ChecklistItem(kind: $0, isChecked: true) }
        profile.emergencyContacts = [EmergencyContact(name: "Alex", phone: "0400 123 456")]
        profile.meetingPoints = MeetingPoints(primary: "Front gate", secondary: "Oval", fallback: "Town hall")
        profile.evacuationRoutes = ["South via Main Road"]

        appState.applyProfile(profile)

        XCTAssertGreaterThan(viewModel.prepScore.overall, initialScore)
        XCTAssertEqual(viewModel.prepScore, appState.prepScore)
        XCTAssertEqual(viewModel.readinessReport.overallScore, appState.currentReadinessReport().overallScore)
        XCTAssertEqual(viewModel.readinessReport.focusAreas, appState.currentReadinessReport().focusAreas)
        XCTAssertEqual(viewModel.readinessReport.planSummary.evacuationRoutes, ["South via Main Road"])
        XCTAssertEqual(viewModel.readinessReport.suggestions.map(\.title), appState.currentReadinessReport().suggestions.map(\.title))
    }
}
