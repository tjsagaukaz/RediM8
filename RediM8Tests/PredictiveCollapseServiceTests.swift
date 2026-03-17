import CoreLocation
import XCTest
@testable import RediM8

final class PredictiveCollapseServiceTests: XCTestCase {

    // MARK: - Initial State

    @MainActor
    func testInitialStateHasNoAssessment() {
        let service = makeService()
        XCTAssertNil(service.lastAssessment)
    }

    // MARK: - Basic Assessment

    @MainActor
    func testFirstAssessmentReturnsStableWithNoHazards() {
        let service = makeService()
        let assessment = service.assess()

        XCTAssertEqual(assessment.level, .stable)
        XCTAssertEqual(assessment.probability, 0, accuracy: 0.01)
        XCTAssertNil(assessment.estimatedTimeToFailure)
        XCTAssertFalse(assessment.shouldAutoTrigger)
    }

    @MainActor
    func testAssessmentIsCached() {
        let service = makeService()
        let first = service.assess()
        let second = service.assess()

        XCTAssertEqual(first.timestamp, second.timestamp, "Second call should return cached result")
    }

    @MainActor
    func testResetHistoryClearsState() {
        let service = makeService()
        _ = service.assess()
        service.resetHistory()

        XCTAssertNil(service.lastAssessment)
    }

    // MARK: - Predictive Level Classification

    @MainActor
    func testPredictiveLevelOrdering() {
        XCTAssertTrue(PredictiveCollapseService.PredictiveLevel.stable < .degrading)
        XCTAssertTrue(PredictiveCollapseService.PredictiveLevel.degrading < .critical)
        XCTAssertTrue(PredictiveCollapseService.PredictiveLevel.critical < .imminent)
    }

    // MARK: - Time to Failure Text

    @MainActor
    func testTimeToFailureTextFormatting() {
        // Test "NOW"
        let nowAssessment = makeAssessment(ttf: 0)
        XCTAssertEqual(nowAssessment.timeToFailureText, "NOW")

        // Test minutes
        let minuteAssessment = makeAssessment(ttf: 1800) // 30 min
        XCTAssertEqual(minuteAssessment.timeToFailureText, "30 MIN")

        // Test hours
        let hourAssessment = makeAssessment(ttf: 5400) // 1h 30m
        XCTAssertEqual(hourAssessment.timeToFailureText, "1H 30M")

        // Test nil
        let nilAssessment = makeAssessment(ttf: nil)
        XCTAssertNil(nilAssessment.timeToFailureText)
    }

    // MARK: - Should Auto Trigger

    @MainActor
    func testShouldAutoTriggerWhenCritical() {
        let assessment = makeAssessment(level: .critical, probability: 0.5)
        XCTAssertTrue(assessment.shouldAutoTrigger)
    }

    @MainActor
    func testShouldAutoTriggerWhenHighProbability() {
        let assessment = makeAssessment(level: .degrading, probability: 0.75)
        XCTAssertTrue(assessment.shouldAutoTrigger)
    }

    @MainActor
    func testShouldNotAutoTriggerWhenStable() {
        let assessment = makeAssessment(level: .stable, probability: 0.1)
        XCTAssertFalse(assessment.shouldAutoTrigger)
    }

    // MARK: - Reason Building

    @MainActor
    func testStableAssessmentHasRelevantReasons() {
        let service = makeService()
        let assessment = service.assess()

        // With no hazards, reasons should be informational (stable or data freshness)
        XCTAssertFalse(assessment.reasons.isEmpty, "Should have at least one reason")
        // Should NOT contain escalation language
        XCTAssertFalse(assessment.reasons.contains(where: { $0.contains("surging") }))
        XCTAssertFalse(assessment.reasons.contains(where: { $0.contains("escalating") }))
    }

    // MARK: - Helpers

    @MainActor
    private func makeService() -> PredictiveCollapseService {
        let hazardService = HazardIntelligenceService(store: nil)
        let feedService = HazardFeedService()
        return PredictiveCollapseService(
            hazardIntelligenceService: hazardService,
            hazardFeedService: feedService
        )
    }

    private func makeAssessment(
        level: PredictiveCollapseService.PredictiveLevel = .stable,
        probability: Double = 0.0,
        ttf: TimeInterval? = nil
    ) -> PredictiveCollapseService.PredictiveAssessment {
        PredictiveCollapseService.PredictiveAssessment(
            level: level,
            probability: probability,
            estimatedTimeToFailure: ttf,
            hazardGrowthRate: 0,
            severityTrend: 0,
            routeDegradationRate: 0,
            reasons: [],
            timestamp: .now
        )
    }
}
