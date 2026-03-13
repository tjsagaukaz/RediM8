import XCTest
@testable import RediM8

final class PrepServiceTests: XCTestCase {
    func testScoreImprovesWithCoreGearAndSupplies() {
        let service = PrepService()
        let engine = ScenarioEngine(scenarios: [sampleScenario], tasks: [sampleTask], gear: [sampleGear])
        let scenarios = engine.selectedScenarios(for: [.generalEmergencies])

        var profile = UserProfile.empty
        profile.selectedScenarios = [.generalEmergencies]
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 0)
        profile.supplies = Supplies(waterLitres: 45, foodDays: 8, fuelLitres: 20, batteryCapacity: 70)
        profile.checklistItems = ChecklistItemKind.allCases.map { ChecklistItem(kind: $0, isChecked: true) }
        profile.emergencyContacts = [EmergencyContact(name: "ICE", phone: "000")]
        profile.meetingPoints = MeetingPoints(primary: "Home mailbox", secondary: "Park", fallback: "Town hall")
        profile.evacuationRoutes = ["South via Main Rd"]

        let score = service.calculateScore(for: profile, scenarios: scenarios, engine: engine)

        XCTAssertGreaterThanOrEqual(score.overall, 70)
        XCTAssertTrue([PrepTier.prepared, .highlyPrepared].contains(score.tier))
    }

    func testMissingWaterProducesWaterSuggestion() {
        let service = PrepService()
        var profile = UserProfile.empty
        profile.selectedScenarios = [.generalEmergencies]
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 0)
        profile.supplies = Supplies(waterLitres: 5, foodDays: 2, fuelLitres: 5, batteryCapacity: 10)

        let engine = ScenarioEngine(scenarios: [sampleScenario], tasks: [sampleTask], gear: [sampleGear])
        let score = service.calculateScore(for: profile, scenarios: engine.selectedScenarios(for: [.generalEmergencies]), engine: engine)

        XCTAssertTrue(score.suggestions.contains(where: { $0.category == .water }))
        XCTAssertTrue(score.suggestions.contains(where: { $0.detail.contains("Water Points") }))
    }

    func testBushfireReadinessImprovesEvacuationScore() {
        let service = PrepService()
        let engine = ScenarioEngine(scenarios: [sampleBushfireScenario], tasks: [sampleTask], gear: [sampleGear])
        let scenarios = engine.selectedScenarios(for: [.bushfires])

        var baseProfile = UserProfile.empty
        baseProfile.selectedScenarios = [.bushfires]
        baseProfile.household = HouseholdDetails(peopleCount: 2, petCount: 1)
        baseProfile.supplies = Supplies(waterLitres: 30, foodDays: 7, fuelLitres: 12, batteryCapacity: 60)
        baseProfile.checklistItems = ChecklistItemKind.allCases.map { ChecklistItem(kind: $0, isChecked: $0 != .fireBlanket) }
        baseProfile.emergencyContacts = [EmergencyContact(name: "ICE", phone: "000")]

        var readyProfile = baseProfile
        readyProfile.checklistItems = ChecklistItemKind.allCases.map { ChecklistItem(kind: $0, isChecked: true) }
        readyProfile.bushfireReadiness.checklist = BushfireChecklistItemKind.allCases.map { BushfireChecklistItem(kind: $0, isChecked: true) }
        readyProfile.bushfireReadiness.propertyItems = BushfirePropertyItemKind.allCases.map { BushfirePropertyItem(kind: $0, isChecked: true) }
        readyProfile.bushfireReadiness.petEvacuationPlan = "Carrier by front door, medication in go bag."
        readyProfile.meetingPoints = MeetingPoints(primary: "Front gate", secondary: "Creek bridge", fallback: "Showgrounds")
        readyProfile.evacuationRoutes = ["South via Main Road", "North via Ridge Track"]

        let baseScore = service.calculateScore(for: baseProfile, scenarios: scenarios, engine: engine)
        let readyScore = service.calculateScore(for: readyProfile, scenarios: scenarios, engine: engine)

        let baseEvacuation = baseScore.categoryScores.first(where: { $0.category == .evacuation })?.score ?? 0
        let readyEvacuation = readyScore.categoryScores.first(where: { $0.category == .evacuation })?.score ?? 0

        XCTAssertGreaterThan(readyEvacuation, baseEvacuation)
        XCTAssertGreaterThan(readyScore.overall, baseScore.overall)
    }

    func testBushfireSuggestionsIncludePetPlanWhenPetsArePresent() {
        let service = PrepService()
        let engine = ScenarioEngine(scenarios: [sampleBushfireScenario], tasks: [sampleTask], gear: [sampleGear])

        var profile = UserProfile.empty
        profile.selectedScenarios = [.bushfires]
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 2)

        let score = service.calculateScore(for: profile, scenarios: engine.selectedScenarios(for: [.bushfires]), engine: engine)

        XCTAssertTrue(score.suggestions.contains(where: { $0.title == "Add a pet evacuation plan" }))
        XCTAssertTrue(score.suggestions.contains(where: { $0.title == "Save a primary evacuation route" }))
    }

    private var sampleScenario: PrepScenario {
        PrepScenario(
            kind: .generalEmergencies,
            name: "General Emergency",
            description: "Baseline scenario.",
            tasks: [sampleTask.id],
            gear: [sampleGear.id],
            guides: ["cpr_basics"],
            priorityCategories: [.communication]
        )
    }

    private var sampleTask: PreparednessTask {
        PreparednessTask(
            id: "review_plan",
            title: "Review plan",
            description: "Keep it current.",
            prepScoreValue: 4,
            category: .familyCoordination,
            recommendedScenarios: [.generalEmergencies]
        )
    }

    private var sampleBushfireScenario: PrepScenario {
        PrepScenario(
            kind: .bushfires,
            name: "Bushfire",
            description: "Bushfire scenario.",
            tasks: [sampleTask.id],
            gear: [sampleGear.id],
            guides: ["bushfire_leave_early_plan"],
            priorityCategories: [.water, .evacuation, .communication]
        )
    }

    private var sampleGear: GearItem {
        GearItem(
            id: "torch",
            name: "Torch",
            category: .lighting,
            description: "Core item.",
            recommendedScenarios: [.generalEmergencies]
        )
    }
}
