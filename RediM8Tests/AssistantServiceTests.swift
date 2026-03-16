import XCTest
@testable import RediM8

@MainActor
final class AssistantServiceTests: XCTestCase {
    func testSnakeBiteUsesDeterministicGuideStepsExactly() throws {
        let service = makeService()
        let guideService = makeGuideService()

        let response = service.ask("How do I treat a snake bite in Australia?")
        let primaryGuide = try XCTUnwrap(guideService.guide(id: "snake_bite_first_aid"))

        XCTAssertEqual(response.topic, .snakeBite)
        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertEqual(response.title, primaryGuide.title)
        XCTAssertEqual(response.steps, primaryGuide.steps)
        XCTAssertEqual(response.summary, primaryGuide.summary)
        XCTAssertEqual(response.riskBand, .critical)
        XCTAssertEqual(response.trustLabel, .verified)
    }

    func testBushfireEvacuationStaysDeterministic() throws {
        let service = makeService()
        let guideService = makeGuideService()

        let response = service.ask("What should I do during bushfire evacuation?")
        let primaryGuide = try XCTUnwrap(guideService.guide(id: "bushfire_leave_early_plan"))

        XCTAssertEqual(response.topic, .bushfireEvacuation)
        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertEqual(response.title, primaryGuide.title)
        XCTAssertEqual(response.steps, primaryGuide.steps)
        XCTAssertNotNil(response.escalationNote)
    }

    func testWaterPurificationUsesSafeSummarizedRetrieval() {
        let service = makeService()

        let response = service.ask("How do I purify water safely?")

        XCTAssertEqual(response.topic, .waterPurification)
        XCTAssertEqual(response.answerMode, .summarizedRetrieval)
        XCTAssertEqual(response.sourceMode, .summarized)
        XCTAssertFalse(response.steps.isEmpty)
        XCTAssertLessThanOrEqual(response.steps.count, 4)
        XCTAssertFalse(response.relatedGuides.isEmpty)
    }

    func testUnknownQueryFallsBackToClosestGuides() {
        let service = makeService()

        let response = service.ask("How do I use a generator safely after a storm?")

        XCTAssertEqual(response.topic, .unknown)
        XCTAssertEqual(response.answerMode, .guideFallback)
        XCTAssertEqual(response.sourceMode, .fallback)
        XCTAssertTrue(response.relatedGuides.contains(where: { $0.id == "generator_safety_after_storm" }))
        XCTAssertNotNil(response.fallbackExplanation)
    }

    func testDeterministicTopicsDoNotFabricateOrSummarizeSteps() throws {
        let service = makeService()
        let guideService = makeGuideService()

        let response = service.ask("How do I do CPR?")
        let primaryGuide = try XCTUnwrap(guideService.guide(id: "cpr_basics"))

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.steps, primaryGuide.steps)
        XCTAssertNotEqual(response.sourceMode, .summarized)
    }

    func testUnknownQueryCanBeInterpretedIntoTrustedTopic() {
        let model = MockOfflineAssistantModel(interpretation: "water purification")
        let service = makeService(assistantModel: model)

        let response = service.ask("how do I clean dirty creek water")

        XCTAssertEqual(response.topic, .waterPurification)
        XCTAssertEqual(response.answerMode, .summarizedRetrieval)
        XCTAssertNotNil(response.interpretationNote)
        XCTAssertEqual(model.interpretCallCount, 1)
    }

    func testCriticalTopicsBypassOfflineModelSummaries() {
        let model = MockOfflineAssistantModel(summary: "Unsafe rewritten summary")
        let service = makeService(assistantModel: model)

        let response = service.ask("How do I treat a snake bite in Australia?")

        XCTAssertEqual(response.topic, .snakeBite)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertEqual(model.summarizeCallCount, 0)
    }

    func testUnavailableModelFallsBackSafely() {
        let model = MockOfflineAssistantModel()
        let service = makeService(assistantModel: model)

        let response = service.ask("How do I purify water safely?")

        XCTAssertEqual(response.topic, .waterPurification)
        XCTAssertEqual(response.sourceMode, .summarized)
        XCTAssertFalse(response.steps.isEmpty)
        XCTAssertFalse(response.usedOfflineModel)
    }

    private func makeService(assistantModel: (any OfflineAssistantModeling)? = nil) -> AssistantService {
        let guideService = makeGuideService()
        let dataService = PreparednessDataService(store: nil, bundle: .main)
        let classifier = AssistantIntentClassifier(dataService: dataService, guideService: guideService)
        let summarizer = GuideSummarizer()
        let composer = AssistantAnswerComposer(summarizer: summarizer)

        return AssistantService(
            classifier: classifier,
            guideService: guideService,
            composer: composer,
            assistantModel: assistantModel
        )
    }

    private func makeGuideService() -> GuideService {
        let dataService = PreparednessDataService(store: nil, bundle: .main)
        return GuideService(dataService: dataService)
    }
}

private final class MockOfflineAssistantModel: OfflineAssistantModeling {
    let isAvailable: Bool
    private let summary: String?
    private let interpretation: String?

    private(set) var summarizeCallCount = 0
    private(set) var interpretCallCount = 0

    init(
        isAvailable: Bool = true,
        summary: String? = nil,
        interpretation: String? = nil
    ) {
        self.isAvailable = isAvailable
        self.summary = summary
        self.interpretation = interpretation
    }

    func summarize(text _: String) -> String? {
        summarizeCallCount += 1
        return summary
    }

    func interpret(query _: String) -> String? {
        interpretCallCount += 1
        return interpretation
    }
}
