import XCTest
@testable import RediM8

@MainActor
final class AssistantServiceTests: XCTestCase {
    func testSnakeBiteUsesDeterministicGuideStepsExactly() throws {
        let service = makeService()
        let guideService = makeGuideService()

        let response = service.ask("How do I treat a snake bite in Australia?")
        let primaryGuide = try XCTUnwrap(guideService.guide(id: "snake_bite_first_aid"))

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertTrue(response.title.localizedCaseInsensitiveContains("snake bite"))
        XCTAssertFalse(response.steps.isEmpty)
        XCTAssertTrue(response.relatedGuides.contains(where: { $0.id == primaryGuide.id }))
        XCTAssertEqual(response.riskBand, .critical)
        XCTAssertEqual(response.trustLabel, .verified)
    }

    func testBushfireEvacuationStaysDeterministic() throws {
        let service = makeService()
        let guideService = makeGuideService()

        let response = service.ask("What should I do during bushfire evacuation?")
        let primaryGuide = try XCTUnwrap(guideService.guide(id: "bushfire_leave_early_plan"))

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertTrue(
            response.title.localizedCaseInsensitiveContains("fire")
                || response.title.localizedCaseInsensitiveContains("evacuation")
                || response.title.localizedCaseInsensitiveContains("route")
        )
        XCTAssertFalse(response.steps.isEmpty)
        XCTAssertTrue(response.relatedGuides.contains(where: { $0.id == primaryGuide.id }))
        XCTAssertNotNil(response.escalationNote)
    }

    func testWaterPurificationUsesSafeSummarizedRetrieval() {
        let service = makeService()

        let response = service.ask("How do I purify water safely?")

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertTrue(response.title.localizedCaseInsensitiveContains("water"))
        XCTAssertFalse(response.steps.isEmpty)
        XCTAssertTrue(response.relatedGuides.contains(where: { $0.id == "boil_filter_disinfect_water" }))
        XCTAssertNil(response.fallbackExplanation)
    }

    func testUnknownQueryFallsBackToClosestGuides() {
        let service = makeService()

        let response = service.ask("How do I use a generator safely after a storm?")

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertTrue(response.title.localizedCaseInsensitiveContains("generator"))
        XCTAssertTrue(response.relatedGuides.contains(where: { $0.id == "generator_safety_after_storm" }))
        XCTAssertNil(response.fallbackExplanation)
    }

    func testGreetingReturnsEntryPromptInsteadOfFallbackGuidance() {
        let service = makeService()

        let response = service.ask("hi")

        XCTAssertTrue(response.isEntryPromptPresentation)
        XCTAssertEqual(response.title, "Ready")
        XCTAssertEqual(response.summary, "Hey — what do you need help with?")
        XCTAssertTrue(response.steps.isEmpty)
        XCTAssertTrue(response.relatedGuides.isEmpty)
        XCTAssertEqual(response.situationHeading, "Start Here")
        XCTAssertFalse(response.shouldShowTrustStrip)
        XCTAssertEqual(response.clarifyingQuestion?.kind, .entryDirection)
        XCTAssertEqual(response.clarifyingQuestion?.options, ["Emergency right now", "Planning ahead", "Navigation help"])
    }

    func testLowSignalPromptReturnsEntryPromptInsteadOfClosestGuide() {
        let service = makeService()

        let response = service.ask("help")

        XCTAssertTrue(response.isEntryPromptPresentation)
        XCTAssertEqual(response.title, "Start Here")
        XCTAssertTrue(response.summary.contains("emergencies, preparation, or navigation"))
        XCTAssertTrue(response.steps.isEmpty)
        XCTAssertTrue(response.relatedGuides.isEmpty)
        XCTAssertNil(response.fallbackExplanation)
        XCTAssertEqual(response.clarifyingQuestion?.kind, .entryDirection)
    }

    func testEntryDirectionNavigationRoutesIntoOperationalGuidance() {
        let service = makeService()

        _ = service.ask("hello")
        let response = service.ask("Navigation help")

        XCTAssertFalse(response.isEntryPromptPresentation)
        XCTAssertNotEqual(response.answerMode, .guideFallback)
        XCTAssertFalse(response.steps.isEmpty)
    }

    func testAlertContextReshapesResponse() throws {
        let contextProvider = MockContextProvider(sections: [
            AssistantContextSection(
                id: "official-alerts",
                title: "Hazard Alert",
                detail: "Bushfire emergency warning active. Evacuation recommended. Follow official warnings and leave early if safe to do so.",
                tone: .danger,
                items: [
                    AssistantContextItem(
                        title: "Emergency Warning",
                        detail: "Emergency warning • Brisbane Hills",
                        caption: "Updated 6 min ago",
                        actions: [.openMap]
                    )
                ],
                isHazardWarning: true
            )
        ], status: AdvisorContextStatus(
            source: .officialAlerts,
            freshnessMinutes: 12,
            isOffline: false,
            hazard: .bushfire,
            routeStatus: .atRisk
        ))
        let service = makeService(contextProvider: contextProvider)

        let response = service.ask("What should I do during bushfire evacuation?")

        XCTAssertTrue(
            response.title.localizedCaseInsensitiveContains("route")
                || response.title.localizedCaseInsensitiveContains("bushfire")
        )
        XCTAssertTrue(
            response.summary.localizedCaseInsensitiveContains("route")
                || response.summary.localizedCaseInsensitiveContains("bushfire")
        )
        XCTAssertTrue(response.trustStripTitle.contains("Using official alerts"))
        XCTAssertTrue(response.trustStripTitle.contains("Route risk detected"))
        XCTAssertNil(response.trustStripDetail)
    }

    func testElevatedEvacuationContextAsksMovementQuestion() {
        let contextProvider = MockContextProvider(
            sections: [],
            snapshot: AssistantSituationSnapshot(
                hazard: .bushfire,
                severity: .watchAndAct,
                proximity: .near,
                mode: .elevated,
                routeStatus: .atRisk,
                lastSyncMinutes: 9,
                hasDependents: true
            )
        )
        let service = makeService(contextProvider: contextProvider)

        let response = service.ask("Bushfire nearby — what do I do?")

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertNil(response.clarifyingQuestion)
        XCTAssertFalse(response.steps.isEmpty)
    }

    func testCrisisContextSkipsClarifyingQuestion() {
        let contextProvider = MockContextProvider(
            sections: [],
            snapshot: AssistantSituationSnapshot(
                hazard: .bushfire,
                severity: .emergencyWarning,
                proximity: .inside,
                mode: .crisis,
                routeStatus: .blocked,
                lastSyncMinutes: 4,
                hasDependents: true
            )
        )
        let service = makeService(contextProvider: contextProvider)

        let response = service.ask("Bushfire nearby — what do I do?")

        XCTAssertNil(response.clarifyingQuestion)
    }

    func testClarificationAnswerReframesNextTurn() {
        let service = makeService()

        _ = service.ask("help")
        let refinedResponse = service.ask("Planning ahead")

        XCTAssertFalse(refinedResponse.isEntryPromptPresentation)
        XCTAssertEqual(refinedResponse.situationSnapshot?.operationalIntent, .planningAhead)
        XCTAssertFalse(refinedResponse.steps.isEmpty)
    }

    func testRouteActionHintShapesNextTurnThenClears() {
        let contextProvider = MockContextProvider(
            sections: [],
            snapshot: AssistantSituationSnapshot(
                hazard: .bushfire,
                severity: .watchAndAct,
                proximity: .near,
                mode: .elevated,
                routeStatus: .atRisk,
                lastSyncMinutes: 8,
                hasDependents: false
            ),
            status: AdvisorContextStatus(
                source: .officialAlerts,
                freshnessMinutes: 8,
                isOffline: false,
                hazard: .bushfire,
                routeStatus: .atRisk
            )
        )
        let service = makeService(contextProvider: contextProvider)

        service.noteContextAction(.openMap)
        let adaptedResponse = service.ask("What should I do during bushfire evacuation?")
        let followUpResponse = service.ask("What should I do during bushfire evacuation?")

        XCTAssertTrue(adaptedResponse.summary.localizedCaseInsensitiveContains("route"))
        XCTAssertTrue(
            adaptedResponse.summary.localizedCaseInsensitiveContains("reviewed")
                || adaptedResponse.summary.localizedCaseInsensitiveContains("use the")
        )
        XCTAssertNotEqual(adaptedResponse.summary, followUpResponse.summary)
    }

    func testGenericQuestionUsesEntryDirectionPrompt() {
        let contextProvider = MockContextProvider(
            sections: [],
            snapshot: AssistantSituationSnapshot(
                hazard: nil,
                severity: nil,
                proximity: .unknown,
                mode: .normal,
                routeStatus: nil,
                lastSyncMinutes: nil,
                hasDependents: false
            )
        )
        let service = makeService(contextProvider: contextProvider)

        let response = service.ask("What should I do?")

        XCTAssertTrue(response.isEntryPromptPresentation)
        XCTAssertEqual(response.clarifyingQuestion?.kind, .entryDirection)
        XCTAssertEqual(response.clarifyingQuestion?.options, ["Emergency right now", "Planning ahead", "Navigation help"])
    }

    func testAmbiguousDistressReturnsEntryPromptInsteadOfFallbackGuidance() {
        let contextProvider = MockContextProvider(
            sections: [],
            snapshot: AssistantSituationSnapshot(
                hazard: nil,
                severity: nil,
                proximity: .unknown,
                mode: .normal,
                routeStatus: nil,
                lastSyncMinutes: nil,
                hasDependents: false
            )
        )
        let service = makeService(contextProvider: contextProvider)

        let response = service.ask("Something feels wrong what do I do")

        XCTAssertTrue(response.isEntryPromptPresentation)
        XCTAssertEqual(response.title, "Start Here")
        XCTAssertFalse(response.shouldShowTrustStrip)
        XCTAssertEqual(response.clarifyingQuestion?.kind, .entryDirection)
    }

    func testGenericCrisisQueryUsesContextDrivenFallback() {
        let contextProvider = MockContextProvider(
            sections: [
                AssistantContextSection(
                    id: "official-alerts",
                    title: "Hazard Alert",
                    detail: "Bushfire emergency warning active near your area.",
                    tone: .danger,
                    items: [
                        AssistantContextItem(
                            title: "Route",
                            detail: "Safe route overlay available",
                            actions: [.openMap]
                        )
                    ],
                    isHazardWarning: true
                )
            ],
            snapshot: AssistantSituationSnapshot(
                hazard: .bushfire,
                severity: .emergencyWarning,
                proximity: .near,
                mode: .crisis,
                routeStatus: .atRisk,
                lastSyncMinutes: 8,
                hasDependents: true
            ),
            status: AdvisorContextStatus(
                source: .officialAlerts,
                freshnessMinutes: 8,
                isOffline: false,
                hazard: .bushfire,
                routeStatus: .atRisk
            )
        )
        let service = makeService(contextProvider: contextProvider)

        let response = service.ask("What do I do?")

        XCTAssertFalse(response.isEntryPromptPresentation)
        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertEqual(response.title, "Bushfire risk near your area")
        XCTAssertTrue(response.summary.contains("route"))
        XCTAssertLessThanOrEqual(response.visibleSteps.count, 3)
        XCTAssertTrue(Array(response.visibleSteps.prefix(2)).contains(where: { $0.localizedCaseInsensitiveContains("children") || $0.localizedCaseInsensitiveContains("pets") }))
        XCTAssertNil(response.clarifyingQuestion)
        XCTAssertTrue(response.shouldShowTrustStrip)
    }

    func testElevatedMovementQuestionUsesGuardedContextFallbackWithoutClarification() {
        let contextProvider = MockContextProvider(
            sections: [],
            snapshot: AssistantSituationSnapshot(
                hazard: .severeStorm,
                severity: .watchAndAct,
                proximity: .near,
                mode: .elevated,
                routeStatus: .atRisk,
                lastSyncMinutes: 90,
                hasDependents: false
            ),
            status: AdvisorContextStatus(
                source: .lastSyncedAlerts,
                freshnessMinutes: 90,
                isOffline: false,
                hazard: .severeStorm,
                routeStatus: .atRisk
            )
        )
        let service = makeService(contextProvider: contextProvider)

        let response = service.ask("Is it safe to leave?")

        XCTAssertFalse(response.isEntryPromptPresentation)
        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertTrue(response.summary.localizedCaseInsensitiveContains("prepare"))
        XCTAssertEqual(response.trustStripDetail, "Conditions may have changed since the last update.")
        XCTAssertNil(response.clarifyingQuestion)
    }

    func testBlackoutQueryFiltersOutCookingFallbackGuides() {
        let service = makeService()

        let response = service.ask("How do I prepare for a blackout?")

        XCTAssertFalse(response.relatedGuides.contains(where: { $0.id == "blackout_scones_basic_pantry" }))
        XCTAssertFalse(response.shouldShowTrustStrip)
        XCTAssertTrue(response.relatedGuides.allSatisfy { $0.category.isAssistantFallbackSafe })
    }

    func testBlackoutPlanningUsesDeterministicPlanningPolicy() {
        let contextProvider = MockContextProvider(
            sections: [],
            snapshot: AssistantSituationSnapshot(
                hazard: nil,
                severity: nil,
                proximity: .unknown,
                mode: .normal,
                routeStatus: nil,
                lastSyncMinutes: nil,
                hasDependents: true
            )
        )
        let service = makeService(contextProvider: contextProvider)

        let response = service.ask("How do I prepare for a blackout?")

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertEqual(response.title, "Blackout preparation")
        XCTAssertTrue(response.steps.contains(where: { $0.localizedCaseInsensitiveContains("charge devices") }))
        XCTAssertEqual(response.safetyNotes.first, "Do not rely on power-dependent systems without backup.")
        XCTAssertFalse(response.shouldShowTrustStrip)
    }

    func testStormPlanningUsesDeterministicPlanningPolicy() {
        let service = makeService()

        let response = service.ask("How do I prepare for a severe storm?")

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertEqual(response.title, "Storm preparation")
        XCTAssertTrue(response.steps.contains(where: { $0.localizedCaseInsensitiveContains("secure loose outdoor items") }))
        XCTAssertTrue(
            response.safetyNotes.first?.localizedCaseInsensitiveContains("storm")
                == true
                || response.safetyNotes.first?.localizedCaseInsensitiveContains("weather")
                == true
                || response.safetyNotes.first?.localizedCaseInsensitiveContains("wind")
                == true
        )
        XCTAssertFalse(response.shouldShowTrustStrip)
    }

    func testFloodPlanningUsesDeterministicPlanningPolicy() {
        let service = makeService()

        let response = service.ask("How do I prepare for flooding?")

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertEqual(response.title, "Flood preparation")
        XCTAssertTrue(response.steps.contains(where: { $0.localizedCaseInsensitiveContains("higher ground") }))
        XCTAssertEqual(response.safetyNotes.first, "Do not drive through floodwater.")
        XCTAssertFalse(response.shouldShowTrustStrip)
    }

    func testFirePlanningUsesDeterministicPlanningPolicy() {
        let service = makeService()

        let response = service.ask("How do I prepare for bushfire season?")

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertTrue(response.title.localizedCaseInsensitiveContains("bushfire") || response.title.localizedCaseInsensitiveContains("fire"))
        XCTAssertTrue(
            response.steps.contains(where: {
                $0.localizedCaseInsensitiveContains("route")
                    || $0.localizedCaseInsensitiveContains("vehicle")
                    || $0.localizedCaseInsensitiveContains("warning")
            })
        )
        XCTAssertFalse(response.safetyNotes.isEmpty)
        XCTAssertFalse(response.shouldShowTrustStrip)
    }

    func testNavigationPlanningUsesDeterministicPlanningPolicy() {
        let service = makeService()

        let response = service.ask("What do I do if I get lost with no signal?")

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertTrue(
            response.title.localizedCaseInsensitiveContains("signal")
                || response.title.localizedCaseInsensitiveContains("gps")
                || response.title.localizedCaseInsensitiveContains("lost")
        )
        XCTAssertTrue(
            response.steps.contains(where: {
                $0.localizedCaseInsensitiveContains("offline maps")
                    || $0.localizedCaseInsensitiveContains("landmarks")
                    || $0.localizedCaseInsensitiveContains("battery")
                    || $0.localizedCaseInsensitiveContains("assess")
            })
        )
        XCTAssertFalse(response.safetyNotes.isEmpty)
        XCTAssertFalse(response.shouldShowTrustStrip)
    }

    func testOfflineTrustStripUsesLastSyncedLanguage() {
        let contextProvider = MockContextProvider(
            sections: [],
            snapshot: AssistantSituationSnapshot(
                hazard: .bushfire,
                severity: .watchAndAct,
                proximity: .near,
                mode: .elevated,
                routeStatus: .atRisk,
                lastSyncMinutes: 48,
                hasDependents: false
            ),
            status: AdvisorContextStatus(
                source: .lastSyncedAlerts,
                freshnessMinutes: 48,
                isOffline: true,
                hazard: .bushfire,
                routeStatus: .atRisk
            )
        )
        let service = makeService(contextProvider: contextProvider)

        let response = service.ask("Bushfire nearby — what do I do?")

        XCTAssertEqual(response.trustStripTitle, "Offline mode • Using last synced alerts • Route risk detected • Updated 48 min ago")
        XCTAssertEqual(response.trustStripDetail, "Conditions may have changed since the last update.")
    }

    func testAdvisorContextStatusFreshnessUsesHumanTiers() {
        let fresh = AdvisorContextStatus(
            source: .officialAlerts,
            freshnessMinutes: 12,
            isOffline: false,
            hazard: .bushfire,
            routeStatus: nil
        )
        let medium = AdvisorContextStatus(
            source: .officialAlerts,
            freshnessMinutes: 48,
            isOffline: false,
            hazard: .bushfire,
            routeStatus: nil
        )
        let stale = AdvisorContextStatus(
            source: .lastSyncedAlerts,
            freshnessMinutes: 84,
            isOffline: false,
            hazard: .bushfire,
            routeStatus: nil
        )

        XCTAssertEqual(fresh.title, "Using official alerts • Bushfire nearby • Updated just now")
        XCTAssertEqual(medium.title, "Using official alerts • Bushfire nearby • Updated 48 min ago")
        XCTAssertEqual(stale.title, "Using last synced alerts • Bushfire nearby • Updated over 1 hour ago")
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

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertTrue(response.title.localizedCaseInsensitiveContains("water"))
        XCTAssertNil(response.interpretationNote)
        XCTAssertEqual(model.interpretCallCount, 0)
    }

    func testCriticalTopicsBypassOfflineModelSummaries() {
        let model = MockOfflineAssistantModel(summary: "Unsafe rewritten summary")
        let service = makeService(assistantModel: model)

        let response = service.ask("How do I treat a snake bite in Australia?")

        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertEqual(model.summarizeCallCount, 0)
    }

    func testUnavailableModelFallsBackSafely() {
        let model = MockOfflineAssistantModel()
        let service = makeService(assistantModel: model)

        let response = service.ask("How do I purify water safely?")

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertFalse(response.steps.isEmpty)
        XCTAssertFalse(response.usedOfflineModel)
    }

    func testMedicalFastPathPersonNotBreathingUsesProtocolAndEmergencyAction() {
        let service = makeService()

        let response = service.ask("person not breathing")

        XCTAssertEqual(response.title, "CPR / not breathing")
        XCTAssertEqual(response.topic, .cpr)
        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertLessThanOrEqual(response.visibleSteps.count, 3)
        XCTAssertNil(response.clarifyingQuestion)
        XCTAssertFalse(response.shouldShowTrustStrip)
        XCTAssertTrue(
            response.contextSections.contains(where: { section in
                section.items.contains(where: { item in
                    item.title == "Emergency services"
                        && item.detail.localizedCaseInsensitiveContains("call 000")
                })
            })
        )
    }

    func testAsthmaAttackBystanderFastPathUsesProtocol() {
        let service = makeService()

        let response = service.ask("he's having an asthma attack")

        XCTAssertEqual(response.title, "Asthma attack")
        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertFalse(response.steps.isEmpty)
        XCTAssertFalse(response.shouldShowTrustStrip)
        XCTAssertNil(response.clarifyingQuestion)
    }

    func testFastPathToleratesChokingTypo() {
        let service = makeService()

        let response = service.ask("child chnoking")

        XCTAssertEqual(response.title, "Choking")
        XCTAssertEqual(response.answerMode, .deterministicStepCard)
    }

    func testFastPathToleratesBleedingTypo() {
        let service = makeService()

        let response = service.ask("bleading badly")

        XCTAssertEqual(response.title, "Severe bleeding")
        XCTAssertEqual(response.answerMode, .deterministicStepCard)
    }

    func testFastPathToleratesAnaphylaxisTypo() {
        let service = makeService()

        let response = service.ask("anaphalaxis")

        XCTAssertEqual(response.title, "Anaphylaxis / severe allergic reaction")
        XCTAssertEqual(response.answerMode, .deterministicStepCard)
    }

    func testPoisoningFastPathShowsPoisonsCallAction() {
        let service = makeService()

        let response = service.ask("child swallowed bleach")

        XCTAssertEqual(response.title, "Poisoning / swallowed substance / chemical exposure")
        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertTrue(
            response.contextSections.contains(where: { section in
                section.items.contains(where: { item in
                    item.title == "Poisons Information Centre"
                        && item.detail.localizedCaseInsensitiveContains("13 11 26")
                })
            })
        )
        XCTAssertNil(response.clarifyingQuestion)
    }

    func testLostNoSignalUsesDeterministicSurvivalProtocol() {
        let service = makeService()

        let response = service.ask("lost and no signal")

        XCTAssertTrue(
            response.title.localizedCaseInsensitiveContains("signal")
                || response.title.localizedCaseInsensitiveContains("gps")
                || response.title.localizedCaseInsensitiveContains("lost")
        )
        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertFalse(response.steps.isEmpty)
        XCTAssertFalse(response.shouldShowTrustStrip)
        XCTAssertNil(response.fallbackExplanation)
    }

    func testFloodWaterEnteringHouseUsesRouteAwareSurvivalProtocol() {
        let contextProvider = MockContextProvider(
            sections: [],
            snapshot: AssistantSituationSnapshot(
                hazard: .flood,
                severity: .emergencyWarning,
                proximity: .inside,
                mode: .crisis,
                routeStatus: .blocked,
                lastSyncMinutes: 6,
                hasDependents: true
            ),
            status: AdvisorContextStatus(
                source: .officialAlerts,
                freshnessMinutes: 6,
                isOffline: false,
                hazard: .flood,
                routeStatus: .blocked
            )
        )
        let service = makeService(contextProvider: contextProvider)

        let response = service.ask("flood water entering house")

        XCTAssertEqual(response.answerMode, .deterministicStepCard)
        XCTAssertEqual(response.sourceMode, .deterministic)
        XCTAssertTrue(response.summary.localizedCaseInsensitiveContains("route"))
        XCTAssertTrue(response.shouldShowTrustStrip)
        XCTAssertTrue(
            response.contextSections.contains(where: { section in
                section.items.contains { item in
                    item.actions.contains(.openTab("map"))
                }
            })
        )
        XCTAssertLessThanOrEqual(response.visibleSteps.count, 3)
    }

    func testMedicalProtocolsDoNotLeakTrustStripFromGeneralFallbackContext() {
        let contextProvider = MockContextProvider(
            sections: [],
            snapshot: AssistantSituationSnapshot(
                hazard: .bushfire,
                severity: .watchAndAct,
                proximity: .near,
                mode: .elevated,
                routeStatus: .atRisk,
                lastSyncMinutes: 10,
                hasDependents: false
            ),
            status: AdvisorContextStatus(
                source: .officialAlerts,
                freshnessMinutes: 10,
                isOffline: false,
                hazard: .bushfire,
                routeStatus: .atRisk
            )
        )
        let service = makeService(contextProvider: contextProvider)

        let response = service.ask("child choking")

        XCTAssertEqual(response.title, "Choking")
        XCTAssertFalse(response.shouldShowTrustStrip)
    }

    private func makeService(
        assistantModel: (any OfflineAssistantModeling)? = nil,
        contextProvider: (any AssistantContextProviding)? = nil
    ) -> AssistantService {
        let guideService = makeGuideService()
        let dataService = PreparednessDataService(store: nil, bundle: .main)
        let classifier = AssistantIntentClassifier(dataService: dataService, guideService: guideService)
        let summarizer = GuideSummarizer()
        let composer = AssistantAnswerComposer(summarizer: summarizer)

        return AssistantService(
            classifier: classifier,
            guideService: guideService,
            composer: composer,
            assistantModel: assistantModel,
            contextProvider: contextProvider
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

@MainActor
private final class MockContextProvider: AssistantContextProviding {
    private let sections: [AssistantContextSection]
    private let snapshot: AssistantSituationSnapshot?
    private let status: AdvisorContextStatus

    init(
        sections: [AssistantContextSection],
        snapshot: AssistantSituationSnapshot? = nil,
        status: AdvisorContextStatus = AdvisorContextStatus(
            source: .generalGuidance,
            freshnessMinutes: nil,
            isOffline: false,
            hazard: nil,
            routeStatus: nil
        )
    ) {
        self.sections = sections
        self.snapshot = snapshot
        self.status = status
    }

    func contextPayload(
        for _: String,
        classification _: AssistantIntentClassification
    ) -> AssistantContextPayload {
        AssistantContextPayload(sections: sections, snapshot: snapshot, status: status)
    }
}
