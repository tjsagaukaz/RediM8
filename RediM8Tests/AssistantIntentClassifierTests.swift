import XCTest
@testable import RediM8

final class AssistantIntentClassifierTests: XCTestCase {
    func testBundledPolicyLibraryLoadsReviewAndTrustMetadata() {
        let dataService = PreparednessDataService(store: nil, bundle: .main)

        let library = dataService.assistantPolicyLibrary()

        XCTAssertFalse(library.policies.isEmpty)
        let snakeBitePolicy = try? XCTUnwrap(library.policies.first(where: { $0.id == "snake_bite" }))
        XCTAssertEqual(snakeBitePolicy?.trustLabel, .verified)
        XCTAssertEqual(snakeBitePolicy?.regionScope, .australia)
        XCTAssertEqual(snakeBitePolicy?.guideIDs, ["snake_bite_first_aid"])
    }

    func testSnakeBiteQueryRoutesToDeterministicGuide() {
        let classifier = AssistantIntentClassifier(bundle: .main)

        let classification = classifier.classify("How do I treat a snake bite in Australia?")

        XCTAssertEqual(classification.policyID, "snake_bite")
        XCTAssertEqual(classification.topic, .snakeBite)
        XCTAssertEqual(classification.riskBand, .critical)
        XCTAssertEqual(classification.preferredMode, .deterministicStepCard)
        XCTAssertEqual(classification.modeWhenGenerationDisabled, .deterministicStepCard)
        XCTAssertEqual(classification.matchedGuideIDs.first, "snake_bite_first_aid")
        XCTAssertEqual(classification.trustLabel, .verified)
        XCTAssertEqual(classification.regionScope, .australia)
        XCTAssertNotNil(classification.lastReviewed)
        XCTAssertTrue(classification.bypassesGeneration)
        XCTAssertEqual(classification.confidenceBand, .high)
    }

    func testBushfireEvacuationQueryStaysDeterministic() {
        let classifier = AssistantIntentClassifier(bundle: .main)

        let classification = classifier.classify("What should I do during bushfire evacuation?")

        XCTAssertEqual(classification.topic, .bushfireEvacuation)
        XCTAssertEqual(classification.preferredMode, .deterministicStepCard)
        XCTAssertTrue(classification.matchedGuideIDs.contains("bushfire_leave_early_plan"))
        XCTAssertTrue(classification.matchedGuideIDs.contains("household_evacuation_quick_start"))
        XCTAssertEqual(classification.trustLabel, .verified)
        XCTAssertEqual(classification.regionScope, .australia)
        XCTAssertNotNil(classification.escalationNote)
    }

    func testWaterPlanningQueryAllowsSummaryButHasRetrievalFallbackWhenGenerationIsDisabled() {
        let classifier = AssistantIntentClassifier(bundle: .main)

        let classification = classifier.classify("How much water do I need for 3 days in extreme heat?")

        XCTAssertEqual(classification.topic, .waterPlanning)
        XCTAssertEqual(classification.riskBand, .advisory)
        XCTAssertEqual(classification.preferredMode, .summarizedRetrieval)
        XCTAssertEqual(classification.modeWhenGenerationDisabled, .retrievalOnlyCard)
        XCTAssertTrue(classification.matchedGuideIDs.contains("ration_water_without_dehydration"))
        XCTAssertEqual(classification.trustLabel, .general)
        XCTAssertEqual(classification.regionScope, .general)
        XCTAssertFalse(classification.bypassesGeneration)
    }

    func testUnknownQueryFallsBackToClosestGuideInsteadOfGuessing() {
        let classifier = AssistantIntentClassifier(bundle: .main)

        let classification = classifier.classify("How do I use a generator safely after a storm?")

        XCTAssertEqual(classification.topic, .unknown)
        XCTAssertEqual(classification.riskBand, .unknown)
        XCTAssertEqual(classification.preferredMode, .guideFallback)
        XCTAssertEqual(classification.modeWhenGenerationDisabled, .guideFallback)
        XCTAssertEqual(classification.matchedGuideIDs.first, "generator_safety_after_storm")
        XCTAssertNil(classification.trustLabel)
        XCTAssertNil(classification.lastReviewed)
        XCTAssertEqual(classification.confidenceBand, .low)
    }
}
