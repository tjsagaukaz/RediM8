import XCTest
@testable import RediM8

final class ScenarioEngineTests: XCTestCase {
    func testPersonalizedTasksAreDeduplicated() {
        let repeatedTask = PreparednessTask(
            id: "store-water",
            title: "Store water",
            description: "Keep extra water available.",
            prepScoreValue: 5,
            category: .waterStorage,
            recommendedScenarios: [.bushfires, .floods]
        )
        let engine = ScenarioEngine(
            scenarios: [
                PrepScenario(
                    kind: .bushfires,
                    name: "Bushfire",
                    description: "Bushfire scenario",
                    tasks: [repeatedTask.id],
                    gear: [],
                    guides: [],
                    priorityCategories: [.water]
                ),
                PrepScenario(
                    kind: .floods,
                    name: "Flood",
                    description: "Flood scenario",
                    tasks: [repeatedTask.id],
                    gear: [],
                    guides: [],
                    priorityCategories: [.water]
                )
            ],
            tasks: [repeatedTask]
        )

        var profile = UserProfile.empty
        profile.selectedScenarios = [.bushfires, .floods]

        let tasks = engine.personalizedTasks(for: profile)

        XCTAssertEqual(tasks.filter { $0.id == repeatedTask.id }.count, 1)
        XCTAssertTrue(tasks.contains(where: { $0.title == "Store water" }))
    }

    func testWeightMultiplierAveragesScenarioWeights() {
        let engine = ScenarioEngine(
            scenarios: [
                PrepScenario(
                    kind: .bushfires,
                    name: "Bushfire",
                    description: "Bushfire scenario",
                    tasks: [],
                    gear: [],
                    guides: [],
                    priorityCategories: [.water]
                ),
                PrepScenario(
                    kind: .floods,
                    name: "Flood",
                    description: "Flood scenario",
                    tasks: [],
                    gear: [],
                    guides: [],
                    priorityCategories: []
                )
            ]
        )

        let selected = engine.selectedScenarios(for: [.bushfires, .floods])
        XCTAssertEqual(engine.weightMultiplier(for: .water, scenarios: selected), 1.125, accuracy: 0.001)
    }

    func testWaterPointReviewTaskAppearsForRemoteTravelScenarios() {
        let engine = ScenarioEngine(
            scenarios: [
                PrepScenario(
                    kind: .remoteTravel,
                    name: "Remote Travel",
                    description: "Remote travel scenario",
                    tasks: [],
                    gear: [],
                    guides: [],
                    priorityCategories: [.water, .evacuation]
                )
            ]
        )

        var profile = UserProfile.empty
        profile.selectedScenarios = [.remoteTravel]

        let tasks = engine.personalizedTasks(for: profile)

        XCTAssertTrue(tasks.contains(where: { $0.id == "review_offline_water_points" }))
    }

    func testEvacuationPointReviewTaskAppearsForCycloneScenarios() {
        let engine = ScenarioEngine(
            scenarios: [
                PrepScenario(
                    kind: .cyclones,
                    name: "Cyclone",
                    description: "Cyclone scenario",
                    tasks: [],
                    gear: [],
                    guides: [],
                    priorityCategories: [.evacuation]
                )
            ]
        )

        var profile = UserProfile.empty
        profile.selectedScenarios = [.cyclones]

        let tasks = engine.personalizedTasks(for: profile)

        XCTAssertTrue(tasks.contains(where: { $0.id == "review_offline_evacuation_points" }))
    }
}
