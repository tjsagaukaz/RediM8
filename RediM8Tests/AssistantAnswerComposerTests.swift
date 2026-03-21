import XCTest
@testable import RediM8

final class AssistantAnswerComposerTests: XCTestCase {
    func testCrisisSummaryIsCompressedToSingleSentence() {
        let composer = makeComposer()
        let guide = makeGuide(
            summary: "A warning is active near your area. Leave early while routes are still open. Keep pets and medications ready."
        )

        let response = composer.compose(
            query: "Bushfire nearby",
            classification: makeClassification(topic: .bushfireEvacuation),
            guides: [guide],
            allowsSafeSummaries: false,
            situationSnapshot: AssistantSituationSnapshot(
                hazard: .bushfire,
                severity: .emergencyWarning,
                proximity: .near,
                mode: .crisis,
                routeStatus: .clear,
                lastSyncMinutes: 8,
                hasDependents: true
            ),
            advisorContextStatus: AdvisorContextStatus(
                source: .officialAlerts,
                freshnessMinutes: 8,
                isOffline: false,
                hazard: .bushfire,
                routeStatus: .clear
            )
        )

        XCTAssertEqual(response.summary, "A recent emergency warning for bushfire is active near your area, so focus on the next immediate safety step.")
    }

    func testCrisisSummaryPrefersRouteRiskWhenRouteAtRisk() {
        let composer = makeComposer()
        let guide = makeGuide(
            summary: "A warning is active near your area. Leave early while routes are still open. Keep pets and medications ready."
        )

        let response = composer.compose(
            query: "Bushfire nearby",
            classification: makeClassification(topic: .bushfireEvacuation),
            guides: [guide],
            allowsSafeSummaries: false,
            situationSnapshot: AssistantSituationSnapshot(
                hazard: .bushfire,
                severity: .emergencyWarning,
                proximity: .near,
                mode: .crisis,
                routeStatus: .atRisk,
                lastSyncMinutes: 8,
                hasDependents: true
            ),
            advisorContextStatus: AdvisorContextStatus(
                source: .officialAlerts,
                freshnessMinutes: 8,
                isOffline: false,
                hazard: .bushfire,
                routeStatus: .atRisk
            )
        )

        XCTAssertEqual(response.summary, "Your usual route may be affected, so leave using the safest available alternative.")
    }

    func testCrisisStepOrderingPromotesMovementAndDependents() {
        let composer = makeComposer()
        let guide = makeGuide(steps: [
            "Collect low-priority items from the spare room if time allows.",
            "Check the route and alternate road before departure.",
            "Take children, pets, medications, and documents first.",
            "Leave now while roads remain open."
        ])

        let response = composer.compose(
            query: "Bushfire nearby",
            classification: makeClassification(topic: .bushfireEvacuation),
            guides: [guide],
            allowsSafeSummaries: false,
            situationSnapshot: AssistantSituationSnapshot(
                hazard: .bushfire,
                severity: .emergencyWarning,
                proximity: .near,
                mode: .crisis,
                routeStatus: .atRisk,
                lastSyncMinutes: 8,
                hasDependents: true
            ),
            advisorContextStatus: AdvisorContextStatus(
                source: .officialAlerts,
                freshnessMinutes: 8,
                isOffline: false,
                hazard: .bushfire,
                routeStatus: .atRisk
            )
        )

        XCTAssertEqual(response.steps.first, "Leave now while roads remain open.")
        XCTAssertTrue(Array(response.steps.prefix(2)).contains("Take children, pets, medications, and documents first."))
        let routeStepIndex = response.steps.firstIndex(where: { $0.localizedCaseInsensitiveContains("route") || $0.localizedCaseInsensitiveContains("safest") }) ?? .max
        XCTAssertLessThan(
            routeStepIndex,
            response.steps.firstIndex(of: "Collect low-priority items from the spare room if time allows.") ?? .max
        )
    }

    func testCrisisStepCompressionKeepsGuidanceShort() {
        let composer = makeComposer()
        let guide = makeGuide(steps: [
            "Leave now while roads remain open. Do not stop for low-priority items or optional gear once conditions worsen."
        ])

        let response = composer.compose(
            query: "Bushfire nearby",
            classification: makeClassification(topic: .bushfireEvacuation),
            guides: [guide],
            allowsSafeSummaries: false,
            situationSnapshot: AssistantSituationSnapshot(
                hazard: .bushfire,
                severity: .emergencyWarning,
                proximity: .near,
                mode: .crisis,
                routeStatus: .atRisk,
                lastSyncMinutes: 5,
                hasDependents: false
            ),
            advisorContextStatus: AdvisorContextStatus(
                source: .officialAlerts,
                freshnessMinutes: 5,
                isOffline: false,
                hazard: .bushfire,
                routeStatus: .atRisk
            )
        )

        XCTAssertEqual(response.steps, ["Leave now while roads remain open."])
    }

    func testStaleRouteRiskUsesGuardedPhrasing() {
        let composer = makeComposer()
        let guide = makeGuide(
            summary: "A warning is active near your area. Leave early while routes are still open."
        )

        let response = composer.compose(
            query: "Bushfire nearby",
            classification: makeClassification(topic: .bushfireEvacuation),
            guides: [guide],
            allowsSafeSummaries: false,
            situationSnapshot: AssistantSituationSnapshot(
                hazard: .bushfire,
                severity: .emergencyWarning,
                proximity: .near,
                mode: .crisis,
                routeStatus: .atRisk,
                lastSyncMinutes: 84,
                hasDependents: false
            ),
            advisorContextStatus: AdvisorContextStatus(
                source: .lastSyncedAlerts,
                freshnessMinutes: 84,
                isOffline: true,
                hazard: .bushfire,
                routeStatus: .atRisk
            )
        )

        XCTAssertEqual(response.summary, "Your usual route may be affected, so prepare to leave using a safe alternative if conditions worsen.")
    }

    func testDependentsSharpenGenericPackingStep() {
        let composer = makeComposer()
        let guide = makeGuide(steps: [
            "Pack essential items and leave when ready.",
            "Check the route and alternate road before departure."
        ])

        let response = composer.compose(
            query: "What should I do?",
            classification: makeClassification(topic: .preparednessPlanning),
            guides: [guide],
            allowsSafeSummaries: false,
            situationSnapshot: AssistantSituationSnapshot(
                hazard: nil,
                severity: nil,
                proximity: .unknown,
                mode: .prep,
                routeStatus: nil,
                lastSyncMinutes: nil,
                hasDependents: true
            ),
            advisorContextStatus: AdvisorContextStatus(
                source: .generalGuidance,
                freshnessMinutes: nil,
                isOffline: false,
                hazard: nil,
                routeStatus: nil
            )
        )

        XCTAssertEqual(response.steps.first, "Pack medicines, water, documents, and items for children or pets before optional gear.")
    }

    private func makeComposer() -> AssistantAnswerComposer {
        AssistantAnswerComposer(summarizer: GuideSummarizer())
    }

    private func makeClassification(topic: AssistantIntentTopic) -> AssistantIntentClassification {
        AssistantIntentClassification(
            policyID: "test_policy",
            topic: topic,
            riskBand: .advisory,
            preferredMode: .deterministicStepCard,
            modeWhenGenerationDisabled: .deterministicStepCard,
            matchedGuideIDs: ["test_guide"],
            matchedTerms: [],
            trustLabel: .verified,
            lastReviewed: nil,
            regionScope: .australia,
            confidence: 0.92,
            escalationNote: nil
        )
    }

    private func makeGuide(
        summary: String = "Base guide summary.",
        steps: [String] = ["Step one.", "Step two.", "Step three.", "Step four."]
    ) -> Guide {
        Guide(
            id: "test_guide",
            title: "Test Guide",
            category: .disasterResponse,
            summary: summary,
            steps: steps,
            notes: "Keep this note in mind."
        )
    }
}
