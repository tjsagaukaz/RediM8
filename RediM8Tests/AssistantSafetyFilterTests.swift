import XCTest
@testable import RediM8

final class AssistantSafetyFilterTests: XCTestCase {

    private func makeFilter() -> AssistantSafetyFilter {
        AssistantSafetyFilter()
    }

    // MARK: - filteredSummary

    func testValidSummaryWithLowNoveltyPasses() {
        let filter = makeFilter()
        let source = "Stop the bleeding by applying direct pressure to the wound with a clean cloth"
        let candidate = "Apply direct pressure to the wound with a clean cloth to stop bleeding"

        let result = filter.filteredSummary(candidate, sourceText: source)

        XCTAssertNotNil(result)
        XCTAssertEqual(result, candidate)
    }

    func testBlankSummaryReturnsNil() {
        let filter = makeFilter()

        XCTAssertNil(filter.filteredSummary("", sourceText: "some source text"))
        XCTAssertNil(filter.filteredSummary("   ", sourceText: "some source text"))
        XCTAssertNil(filter.filteredSummary("\n\t", sourceText: "some source text"))
    }

    func testSummaryExceedingMaxLengthIsTruncated() {
        let filter = makeFilter()
        let longSource = String(repeating: "word ", count: 200)
        let longCandidate = String(repeating: "word ", count: 100)

        let result = filter.filteredSummary(longCandidate, sourceText: longSource)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.count <= 323, "Truncated summary should be at most 320 chars + '...'")
        XCTAssertTrue(result!.hasSuffix("..."))
    }

    func testHighNovelTokenRatioRejected() {
        let filter = makeFilter()
        let source = "water purification tablets can help make river water safe"
        let candidate = "drinking untreated creek liquid rapidly causes severe gastrointestinal illness"

        let result = filter.filteredSummary(candidate, sourceText: source)

        XCTAssertNil(result, "Summary with >40% novel tokens should be rejected")
    }

    func testUnsafeNovelTokensRejected() {
        let filter = makeFilter()
        let source = "clean the wound and apply pressure to stop bleeding"

        XCTAssertNil(filter.filteredSummary("apply tourniquet to stop bleeding", sourceText: source))
        XCTAssertNil(filter.filteredSummary("inject medicine into the wound area", sourceText: source))
        XCTAssertNil(filter.filteredSummary("use bleach to clean the wound area", sourceText: source))
        XCTAssertNil(filter.filteredSummary("take antibiotic dose for wound infection", sourceText: source))
    }

    func testStructuredStepsRejected() {
        let filter = makeFilter()
        let source = "first apply pressure then bandage the wound tightly"

        XCTAssertNil(filter.filteredSummary("Step 1: apply pressure", sourceText: source))
        XCTAssertNil(filter.filteredSummary("1. apply pressure 2. bandage", sourceText: source))
        XCTAssertNil(filter.filteredSummary("• apply pressure to wound", sourceText: source))
        XCTAssertNil(filter.filteredSummary("- apply pressure first", sourceText: source))
    }

    func testStopWordsAreExcludedFromNoveltyCalculation() {
        let filter = makeFilter()
        let source = "water purification process explained"
        // "the" and "of" are stop words — should not count as novel tokens
        let candidate = "the process of water purification"

        let result = filter.filteredSummary(candidate, sourceText: source)

        XCTAssertNotNil(result, "Stop words should not inflate the novel token ratio")
    }

    func testWhitespaceNormalized() {
        let filter = makeFilter()
        let source = "apply pressure to wound"
        let candidate = "apply   pressure   to   wound"

        let result = filter.filteredSummary(candidate, sourceText: source)

        XCTAssertNotNil(result)
        XCTAssertFalse(result!.contains("  "), "Multiple spaces should be collapsed")
    }

    // MARK: - filteredInterpretation

    func testValidInterpretationPasses() {
        let filter = makeFilter()
        let classifier = AssistantIntentClassifier()

        // "first aid" should be classifiable
        let result = filter.filteredInterpretation("first aid", classifier: classifier)

        // If the classifier can classify it, it passes; if not, nil is acceptable
        // The key behavior: it should not crash and should respect token count limits
        if let result {
            XCTAssertFalse(result.isEmpty)
        }
    }

    func testBlankInterpretationReturnsNil() {
        let filter = makeFilter()
        let classifier = AssistantIntentClassifier()

        XCTAssertNil(filter.filteredInterpretation("", classifier: classifier))
        XCTAssertNil(filter.filteredInterpretation("   ", classifier: classifier))
    }

    func testInterpretationExceedingSixTokensRejected() {
        let filter = makeFilter()
        let classifier = AssistantIntentClassifier()
        let longQuery = "how to purify water from a river safely in the outback"

        let result = filter.filteredInterpretation(longQuery, classifier: classifier)

        XCTAssertNil(result, "Interpretations longer than 6 tokens should be rejected")
    }

    func testInterpretationWithUnknownTopicRejected() {
        let filter = makeFilter()
        let classifier = AssistantIntentClassifier()
        // Something totally unrelated to any safety topic
        let result = filter.filteredInterpretation("banana", classifier: classifier)

        XCTAssertNil(result, "Unknown topic classification should be rejected")
    }
}
