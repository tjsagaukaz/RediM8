import XCTest
@testable import RediM8

final class GuideServiceTests: XCTestCase {
    func testEmergencyCardsPrioritizeScenarioSpecificGuides() {
        let service = GuideService(bundle: .main)

        let cards = service.emergencyCards(for: [.bushfires], limit: 4)

        XCTAssertEqual(cards.first?.id, "bushfire_leave_early_plan")
        XCTAssertTrue(cards.contains(where: { $0.id == "snake_bite_first_aid" }))
    }

    func testAllEmergencyCardsStayUnique() {
        let service = GuideService(bundle: .main)

        let cards = service.allEmergencyCards()

        XCTAssertEqual(cards.count, Set(cards.map(\.id)).count)
        XCTAssertTrue(cards.contains(where: { $0.id == "cyclone_pre_landfall_actions" }))
        XCTAssertTrue(cards.contains(where: { $0.id == "flood_evacuation_timing" }))
    }

    func testIllustratedGuidesIncludeRichOfflineDiagramContent() {
        let service = GuideService(bundle: .main)

        let illustrated = service.illustratedGuides()

        XCTAssertTrue(illustrated.contains(where: { $0.id == "snake_bite_first_aid" }))
        XCTAssertTrue(illustrated.contains(where: { $0.id == "basic_knot_selection" }))
        XCTAssertTrue(illustrated.contains(where: { $0.id == "pantry_damper_hotplate_method" }))
    }

    func testSearchGuidesFindsExpandedFoodLibraryContent() {
        let service = GuideService(bundle: .main)

        let matches = service.searchGuides(query: "damper")

        XCTAssertEqual(matches.first?.id, "pantry_damper_hotplate_method")
        XCTAssertTrue(matches.contains(where: { $0.category == .foodCooking }))
    }
}
