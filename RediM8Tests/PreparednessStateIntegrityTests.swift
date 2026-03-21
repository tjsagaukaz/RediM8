import Foundation
import XCTest
@testable import RediM8

final class PreparednessStateIntegrityTests: XCTestCase {
    func testUserProfileDecodeNormalizesDuplicateChecklistItemsWithStableOrder() throws {
        var profile = UserProfile.empty
        profile.checklistItems = [
            ChecklistItem(kind: .firstAidKit, isChecked: true),
            ChecklistItem(kind: .firstAidKit, isChecked: false),
            ChecklistItem(kind: .batteryRadio, isChecked: true)
        ]

        let encoded = try JSONEncoder.rediM8.encode(profile)
        let decoded = try JSONDecoder.rediM8.decode(UserProfile.self, from: encoded)

        XCTAssertEqual(decoded.checklistItems.map(\.kind), ChecklistItemKind.allCases)
        XCTAssertEqual(decoded.checklistItems.count, ChecklistItemKind.allCases.count)
        XCTAssertFalse(decoded.checklistState(for: .firstAidKit))
        XCTAssertTrue(decoded.checklistState(for: .batteryRadio))
        XCTAssertFalse(decoded.checklistState(for: .torch))
    }

    @MainActor
    func testAppStateApplyProfileNormalizesChecklistStateBeforeScoring() {
        let appState = AppState(store: nil)

        var profile = UserProfile.empty
        profile.selectedScenarios = [.generalEmergencies]
        profile.checklistItems = [
            ChecklistItem(kind: .firstAidKit, isChecked: false),
            ChecklistItem(kind: .firstAidKit, isChecked: true),
            ChecklistItem(kind: .batteryRadio, isChecked: false)
        ]

        appState.applyProfile(profile)

        XCTAssertEqual(appState.profile.checklistItems.map(\.kind), ChecklistItemKind.allCases)
        XCTAssertEqual(appState.profile.checklistItems.filter { $0.kind == .firstAidKit }.count, 1)
        XCTAssertTrue(appState.profile.checklistState(for: .firstAidKit))
        XCTAssertFalse(appState.prepScore.suggestions.contains(where: { $0.title == "Add a first aid kit" }))
        XCTAssertFalse(appState.profile.checklistState(for: .batteryRadio))
    }

    @MainActor
    func testPreparednessChecklistStatePersistsAcrossSessionsWithoutDuplicates() throws {
        let store = try SQLiteStore(filename: "PreparednessStateIntegrity-\(UUID().uuidString).sqlite")
        let appState = AppState(store: store)

        var profile = UserProfile.empty
        profile.checklistItems = [
            ChecklistItem(kind: .firstAidKit, isChecked: false),
            ChecklistItem(kind: .firstAidKit, isChecked: true),
            ChecklistItem(kind: .powerBank, isChecked: true)
        ]

        appState.applyProfile(profile)

        let reloaded = AppState(store: store)

        XCTAssertEqual(reloaded.profile.checklistItems.map(\.kind), ChecklistItemKind.allCases)
        XCTAssertEqual(reloaded.profile.checklistItems.filter { $0.kind == .firstAidKit }.count, 1)
        XCTAssertTrue(reloaded.profile.checklistState(for: .firstAidKit))
        XCTAssertTrue(reloaded.profile.checklistState(for: .powerBank))
    }
}
