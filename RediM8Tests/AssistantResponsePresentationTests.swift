import XCTest
@testable import RediM8

final class AssistantResponsePresentationTests: XCTestCase {
    func testCrisisPresentationCollapsesSecondaryContentAndCapsVisibleSteps() {
        let response = makeResponse(
            mode: .crisis,
            steps: ["One", "Two", "Three", "Four"],
            safetyNotes: ["Avoid one", "Avoid two"]
        )

        XCTAssertTrue(response.shouldCollapseSecondaryContentByDefault)
        XCTAssertTrue(response.shouldPrioritizePrimaryActionRow)
        XCTAssertEqual(response.visibleSteps, ["One", "Two", "Three"])
        XCTAssertEqual(response.visibleSafetyNotes, ["Avoid one"])
    }

    func testElevatedPresentationCollapsesSecondaryContentButKeepsMoreSteps() {
        let response = makeResponse(
            mode: .elevated,
            steps: ["One", "Two", "Three", "Four", "Five", "Six"],
            safetyNotes: ["Avoid one", "Avoid two", "Avoid three"]
        )

        XCTAssertTrue(response.shouldCollapseSecondaryContentByDefault)
        XCTAssertEqual(response.visibleSteps, ["One", "Two", "Three", "Four", "Five"])
        XCTAssertEqual(response.visibleSafetyNotes, ["Avoid one", "Avoid two"])
    }

    func testPrepPresentationKeepsFullStepsButCollapsesSecondaryContentByDefault() {
        let response = makeResponse(
            mode: .prep,
            steps: ["One", "Two", "Three", "Four"],
            safetyNotes: ["Avoid one", "Avoid two"]
        )

        XCTAssertTrue(response.shouldCollapseSecondaryContentByDefault)
        XCTAssertEqual(response.visibleSteps, ["One", "Two", "Three", "Four"])
        XCTAssertEqual(response.visibleSafetyNotes, ["Avoid one", "Avoid two"])
    }

    func testNormalPresentationAlsoCollapsesSecondaryContentByDefault() {
        let response = makeResponse(
            mode: .normal,
            steps: ["One", "Two"],
            safetyNotes: ["Avoid one"]
        )

        XCTAssertTrue(response.shouldCollapseSecondaryContentByDefault)
        XCTAssertEqual(response.visibleSteps, ["One", "Two"])
    }

    func testGeneralGuidanceDoesNotShowTrustStripByDefault() {
        let response = AssistantResponse(
            query: "test",
            title: "Response",
            topic: .unknown,
            confidence: 0.32,
            riskBand: .unknown,
            trustLabel: nil,
            answerMode: .guideFallback,
            sourceMode: .fallback,
            summary: "Summary",
            steps: [],
            escalationNote: nil,
            relatedGuides: [],
            sourceSummary: "Bundled offline references",
            lastReviewedSummary: "Today",
            regionSummary: "General guidance"
        )

        XCTAssertFalse(response.shouldShowTrustStrip)
    }

    func testOperationalContextEnablesTrustStrip() {
        let response = AssistantResponse(
            query: "test",
            title: "Response",
            topic: .bushfireEvacuation,
            confidence: 0.88,
            riskBand: .critical,
            trustLabel: .verified,
            answerMode: .deterministicStepCard,
            sourceMode: .deterministic,
            summary: "Summary",
            steps: ["One"],
            escalationNote: nil,
            relatedGuides: [],
            sourceSummary: "Bundled offline references",
            lastReviewedSummary: "Today",
            regionSummary: "Australia-specific",
            situationSnapshot: AssistantSituationSnapshot(
                hazard: .bushfire,
                severity: .watchAndAct,
                proximity: .near,
                mode: .elevated,
                routeStatus: .atRisk,
                lastSyncMinutes: 10,
                hasDependents: false
            ),
            advisorContextStatus: AdvisorContextStatus(
                source: .officialAlerts,
                freshnessMinutes: 10,
                isOffline: false,
                hazard: .bushfire,
                routeStatus: .atRisk
            ),
            usesOperationalTrustContext: true
        )

        XCTAssertTrue(response.shouldShowTrustStrip)
    }

    private func makeResponse(
        mode: AssistantSituationMode,
        steps: [String],
        safetyNotes: [String]
    ) -> AssistantResponse {
        AssistantResponse(
            query: "test",
            title: "Response",
            topic: .bushfireEvacuation,
            confidence: 0.88,
            riskBand: .advisory,
            trustLabel: .verified,
            answerMode: .deterministicStepCard,
            sourceMode: .deterministic,
            summary: "Summary",
            steps: steps,
            safetyNotes: safetyNotes,
            escalationNote: nil,
            relatedGuides: [],
            sourceSummary: "Bundled offline references",
            lastReviewedSummary: "Today",
            regionSummary: "Australia-specific",
            situationSnapshot: AssistantSituationSnapshot(
                hazard: .bushfire,
                severity: .watchAndAct,
                proximity: .near,
                mode: mode,
                routeStatus: .atRisk,
                lastSyncMinutes: 10,
                hasDependents: true
            )
        )
    }
}
