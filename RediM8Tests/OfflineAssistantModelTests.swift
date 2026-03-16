import XCTest
@testable import RediM8

final class OfflineAssistantModelTests: XCTestCase {
    func testSummarizationPreservesGuideStepsWhenModelClarifiesNarrative() throws {
        let guideService = GuideService(dataService: PreparednessDataService(store: nil, bundle: .main))
        let primaryGuide = try XCTUnwrap(guideService.guide(id: "boil_filter_disinfect_water"))
        let classification = AssistantIntentClassification(
            policyID: "water_purification",
            topic: .waterPurification,
            riskBand: .advisory,
            preferredMode: .summarizedRetrieval,
            modeWhenGenerationDisabled: .retrievalOnlyCard,
            matchedGuideIDs: [primaryGuide.id],
            matchedTerms: ["water purification"],
            trustLabel: .general,
            lastReviewed: nil,
            regionScope: .general,
            confidence: 0.82,
            escalationNote: nil
        )

        let runtime = MockOfflineAssistantRuntime(
            output: "Use the bundled treatment guide to pick the safest method for the water source and gear you have."
        )
        let model = OfflineAssistantModel(runtime: runtime)
        let summarizer = GuideSummarizer()
        let safetyFilter = AssistantSafetyFilter()

        let summary = summarizer.summarize(
            guides: [primaryGuide],
            classification: classification,
            offlineModel: model,
            safetyFilter: safetyFilter
        )

        XCTAssertEqual(summary.steps, Array(primaryGuide.steps.prefix(4)))
        XCTAssertTrue(summary.usedOfflineModel)
        XCTAssertFalse(summary.summary.isEmpty)
    }

    func testInterpretationMapsQueriesToShortTopicPhrase() {
        let runtime = MockOfflineAssistantRuntime(output: "water purification")
        let model = OfflineAssistantModel(runtime: runtime)

        let result = model.interpret(query: "how do I clean dirty creek water")

        XCTAssertEqual(result, "water purification")
    }

    func testModelFailureReturnsNilWithoutBreakingAssistant() {
        let runtime = MockOfflineAssistantRuntime(output: nil)
        let model = OfflineAssistantModel(runtime: runtime)

        XCTAssertNil(model.summarize(text: "Purify collected water before drinking."))
        XCTAssertNil(model.interpret(query: "where can I get water"))
    }
}

private struct MockOfflineAssistantRuntime: OfflineAssistantModelRuntime {
    let output: String?

    var isAvailable: Bool {
        output != nil
    }

    func generate(task _: OfflineAssistantModel.Task, input _: String, maxOutputTokens _: Int) -> String? {
        output
    }
}
