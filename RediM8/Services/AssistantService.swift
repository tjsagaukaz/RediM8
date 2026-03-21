import Foundation

final class AssistantService {
    private enum InputDisposition {
        case greeting
        case lowSignal
    }

    private let classifier: AssistantIntentClassifier
    private let guideService: GuideService
    private let composer: AssistantAnswerComposer
    private let protocolRouter: AssistantProtocolRouter
    private let protocolResponseBuilder: AssistantProtocolResponseBuilder
    private let assistantModel: (any OfflineAssistantModeling)?
    private let safetyFilter: AssistantSafetyFilter
    private let contextProvider: (any AssistantContextProviding)?
    let sessionState = AssistantSessionState()

    init(
        classifier: AssistantIntentClassifier,
        guideService: GuideService,
        composer: AssistantAnswerComposer,
        protocolRouter: AssistantProtocolRouter? = nil,
        protocolResponseBuilder: AssistantProtocolResponseBuilder? = nil,
        assistantModel: (any OfflineAssistantModeling)? = nil,
        safetyFilter: AssistantSafetyFilter = AssistantSafetyFilter(),
        contextProvider: (any AssistantContextProviding)? = nil
    ) {
        self.classifier = classifier
        self.guideService = guideService
        self.composer = composer
        self.protocolRouter = protocolRouter ?? AssistantProtocolRouter()
        self.protocolResponseBuilder = protocolResponseBuilder ?? AssistantProtocolResponseBuilder(
            guideService: guideService
        )
        self.assistantModel = assistantModel
        self.safetyFilter = safetyFilter
        self.contextProvider = contextProvider
    }

    convenience init(
        classifier: AssistantIntentClassifier,
        guideService: GuideService,
        composer: AssistantAnswerComposer,
        assistantModel: (any OfflineAssistantModeling)? = nil,
        safetyFilter: AssistantSafetyFilter = AssistantSafetyFilter(),
        contextProvider: (any AssistantContextProviding)? = nil
    ) {
        self.init(
            classifier: classifier,
            guideService: guideService,
            composer: composer,
            protocolRouter: nil,
            protocolResponseBuilder: nil,
            assistantModel: assistantModel,
            safetyFilter: safetyFilter,
            contextProvider: contextProvider
        )
    }

    func noteContextAction(_ action: AssistantContextAction) {
        sessionState.noteContextAction(action)
    }

    @MainActor
    func ask(_ query: String, allowsSafeSummaries: Bool = true) -> AssistantResponse {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = AssistantIntentClassifier.normalize(trimmedQuery)

        let clarificationResolution = sessionState.consumeClarificationIfPossible(trimmedQuery)

        if clarificationResolution == nil {
            let initialClassification = classifier.classify(trimmedQuery)
            let initialContextPayload = contextProvider?.contextPayload(
                for: trimmedQuery,
                classification: initialClassification
            ) ?? .empty
            let initialSnapshot = sessionState.applyOperationalIntent(
                to: initialContextPayload.snapshot,
                classification: initialClassification
            )
            let initialRecentActionHint = sessionState.actionHint(
                for: initialClassification,
                snapshot: initialSnapshot
            )

            if let protocolResponse = composeProtocolResponse(
                query: trimmedQuery,
                match: protocolRouter.fastPathMatch(
                    query: trimmedQuery,
                    snapshot: initialSnapshot
                ),
                situationSnapshot: initialSnapshot,
                advisorContextStatus: initialContextPayload.status,
                contextSections: initialContextPayload.sections,
                recentActionHint: initialRecentActionHint
            ) {
                return protocolResponse
            }

            if let inputDisposition = inputDisposition(
                for: normalizedQuery,
                classification: initialClassification,
                snapshot: initialSnapshot
            ) {
                let response = entryResponse(
                    for: trimmedQuery,
                    disposition: inputDisposition
                )

                sessionState.record(
                    query: trimmedQuery,
                    classification: initialClassification,
                    guideIDs: [],
                    situationSnapshot: initialSnapshot,
                    pendingQuestion: response.clarifyingQuestion
                )

                return response
            }
        }

        // Check for follow-up queries that should inherit previous context
        let resolvedRouting: (classification: AssistantIntentClassification, routingQuery: String, interpretationNote: String?)
        if let clarificationResolution {
            let baseQuery = sessionState.lastQuery ?? trimmedQuery
            let clarifiedQuery = [baseQuery, clarificationResolution.routingTerms]
                .compactMap { $0.nilIfBlank }
                .joined(separator: " ")
            let clarifiedRouting = resolvedClassification(
                for: clarifiedQuery,
                allowsSafeSummaries: allowsSafeSummaries
            )
            let combinedNote = [clarificationResolution.note as String?, clarifiedRouting.interpretationNote]
                .compactMap { note in note?.nilIfBlank }
                .joined(separator: " ")
                .nilIfBlank
            resolvedRouting = (clarifiedRouting.classification, clarifiedQuery, combinedNote)
        } else if sessionState.isFollowUp(normalizedQuery),
                  let followUp = sessionState.followUpClassification() {
            resolvedRouting = (followUp, trimmedQuery, "Continuing from your previous question.")
        } else {
            resolvedRouting = resolvedClassification(for: trimmedQuery, allowsSafeSummaries: allowsSafeSummaries)
        }

        let contextPayload = contextProvider?.contextPayload(
            for: trimmedQuery,
            classification: resolvedRouting.classification
        ) ?? .empty
        let situationSnapshot = sessionState.applyOperationalIntent(
            to: contextPayload.snapshot,
            classification: resolvedRouting.classification
        )
        let matchedGuides = resolvedGuides(
            for: resolvedRouting.classification,
            query: resolvedRouting.routingQuery,
            snapshot: situationSnapshot
        )
        let recentActionHint = sessionState.actionHint(
            for: resolvedRouting.classification,
            snapshot: situationSnapshot
        )

        if let protocolResponse = composeProtocolResponse(
            query: trimmedQuery,
            match: protocolRouter.overrideMatch(
                query: resolvedRouting.routingQuery,
                classification: resolvedRouting.classification,
                guides: matchedGuides,
                snapshot: situationSnapshot
            ),
            situationSnapshot: situationSnapshot,
            advisorContextStatus: contextPayload.status,
            contextSections: contextPayload.sections,
            recentActionHint: recentActionHint
        ) {
            return protocolResponse
        }

        let clarifyingQuestion = clarificationQuestion(
            for: trimmedQuery,
            normalizedQuery: normalizedQuery,
            classification: resolvedRouting.classification,
            snapshot: situationSnapshot
        )

        if shouldUseContextDrivenFallback(
            normalizedQuery: AssistantIntentClassifier.normalize(resolvedRouting.routingQuery),
            classification: resolvedRouting.classification,
            guides: matchedGuides,
            snapshot: situationSnapshot
        ), let situationSnapshot {
            let response = composer.composeContextDrivenFallback(
                query: trimmedQuery,
                classification: resolvedRouting.classification,
                guides: matchedGuides,
                interpretationNote: resolvedRouting.interpretationNote,
                contextSections: contextPayload.sections,
                situationSnapshot: situationSnapshot,
                advisorContextStatus: contextPayload.status,
                recentActionHint: recentActionHint,
                clarifyingQuestion: clarifyingQuestion
            )

            sessionState.record(
                query: trimmedQuery,
                classification: resolvedRouting.classification,
                guideIDs: matchedGuides.map(\.id),
                situationSnapshot: situationSnapshot,
                pendingQuestion: clarifyingQuestion
            )

            if recentActionHint != nil {
                sessionState.clearRecentActionHint()
            }

            return response
        }

        if let response = composer.composePlanningPolicyFallback(
            query: resolvedRouting.routingQuery,
            classification: resolvedRouting.classification,
            guides: matchedGuides,
            interpretationNote: resolvedRouting.interpretationNote,
            contextSections: contextPayload.sections,
            situationSnapshot: situationSnapshot,
            advisorContextStatus: contextPayload.status
        ) {
            sessionState.record(
                query: trimmedQuery,
                classification: resolvedRouting.classification,
                guideIDs: matchedGuides.map(\.id),
                situationSnapshot: situationSnapshot,
                pendingQuestion: nil
            )

            if recentActionHint != nil {
                sessionState.clearRecentActionHint()
            }

            return response
        }

        let response = composer.compose(
            query: resolvedRouting.routingQuery,
            classification: resolvedRouting.classification,
            guides: matchedGuides,
            allowsSafeSummaries: allowsSafeSummaries,
            offlineModel: allowsSafeSummaries ? assistantModel : nil,
            safetyFilter: safetyFilter,
            interpretationNote: resolvedRouting.interpretationNote,
            contextSections: contextPayload.sections,
            situationSnapshot: situationSnapshot,
            advisorContextStatus: contextPayload.status,
            recentActionHint: recentActionHint,
            clarifyingQuestion: clarifyingQuestion
        )

        // Record this turn for future follow-up detection
        sessionState.record(
            query: trimmedQuery,
            classification: resolvedRouting.classification,
            guideIDs: matchedGuides.map(\.id),
            situationSnapshot: situationSnapshot,
            pendingQuestion: clarifyingQuestion
        )

        if recentActionHint != nil {
            sessionState.clearRecentActionHint()
        }

        return response
    }

    private func composeProtocolResponse(
        query: String,
        match: AssistantProtocolMatch?,
        situationSnapshot: AssistantSituationSnapshot?,
        advisorContextStatus: AdvisorContextStatus,
        contextSections: [AssistantContextSection],
        recentActionHint: AssistantRecentActionHint? = nil
    ) -> AssistantResponse? {
        guard let match else {
            return nil
        }

        let build = protocolResponseBuilder.build(
            query: query,
            match: match,
            situationSnapshot: situationSnapshot,
            advisorContextStatus: advisorContextStatus,
            contextSections: contextSections,
            recentActionHint: recentActionHint
        )

        sessionState.record(
            query: query,
            classification: build.classification,
            guideIDs: build.relatedGuideIDs,
            situationSnapshot: build.response.situationSnapshot,
            pendingQuestion: nil
        )

        if recentActionHint != nil {
            sessionState.clearRecentActionHint()
        }

        return build.response
    }

    private func inputDisposition(
        for normalizedQuery: String,
        classification: AssistantIntentClassification,
        snapshot: AssistantSituationSnapshot?
    ) -> InputDisposition? {
        if Self.greetingPhrases.contains(normalizedQuery) {
            return .greeting
        }

        guard classification.topic == .unknown else {
            return nil
        }

        if let snapshot,
           snapshot.hasEnvironmentalHazard || snapshot.mode == .elevated || snapshot.mode == .crisis {
            return nil
        }

        if shouldBypassEntryPromptForSpecificTopic(normalizedQuery) {
            return nil
        }

        if isLowSignalInput(normalizedQuery) {
            return .lowSignal
        }

        return nil
    }

    private func entryResponse(
        for query: String,
        disposition: InputDisposition
    ) -> AssistantResponse {
        let summary: String

        switch disposition {
        case .greeting:
            summary = "Hey — what do you need help with?"
        case .lowSignal:
            summary = "I can help with emergencies, preparation, or navigation. Choose a direction below or tell me what is happening."
        }

        return AssistantResponse(
            query: query,
            title: disposition == .greeting ? "Ready" : "Start Here",
            topic: .unknown,
            confidence: 1.0,
            riskBand: .unknown,
            trustLabel: nil,
            answerMode: .guideFallback,
            sourceMode: .fallback,
            presentationStyle: .entryPrompt,
            summary: summary,
            steps: [],
            escalationNote: nil,
            relatedGuides: [],
            sourceSummary: "",
            lastReviewedSummary: "",
            regionSummary: GuideRegionScope.general.title,
            clarifyingQuestion: AssistantClarifyingQuestion(
                kind: .entryDirection,
                prompt: "What do you need help with?",
                options: ["Emergency right now", "Planning ahead", "Navigation help"]
            )
        )
    }

    private func resolvedClassification(
        for query: String,
        allowsSafeSummaries: Bool
    ) -> (classification: AssistantIntentClassification, routingQuery: String, interpretationNote: String?) {
        let initialClassification = classifier.classify(query)

        guard allowsSafeSummaries,
              initialClassification.topic == .unknown,
              let interpretedQuery = assistantModel?.interpret(query: query),
              let safeInterpretedQuery = safetyFilter.filteredInterpretation(interpretedQuery, classifier: classifier)
        else {
            return (initialClassification, query, nil)
        }

        let reclassified = classifier.classify(safeInterpretedQuery)
        guard reclassified.topic != .unknown, reclassified.confidence >= initialClassification.confidence else {
            return (initialClassification, query, nil)
        }

        return (
            reclassified,
            safeInterpretedQuery,
            "Interpreted your question as \"\(safeInterpretedQuery)\" to route the closest trusted offline guide."
        )
    }

    private func resolvedGuides(
        for classification: AssistantIntentClassification,
        query: String,
        snapshot: AssistantSituationSnapshot?
    ) -> [Guide] {
        let policyGuides = classification.policyID != nil
            ? classifier.matchedGuides(for: classification)
            : []
        if !policyGuides.isEmpty {
            let primaryIDs = Set(policyGuides.map(\.id))
            let supportingGuides = supportingGuideIDs(for: classification.topic)
                .filter { !primaryIDs.contains($0) }
            let supporting = guideService.guides(ids: supportingGuides)
            return policyGuides + supporting
        }

        let fallbackGuides = fallbackSearchGuides(
            query: query,
            classification: classification,
            snapshot: snapshot
        )
        guard !fallbackGuides.isEmpty else {
            return []
        }

        return Array(fallbackGuides.prefix(3))
    }

    private func fallbackSearchGuides(
        query: String,
        classification: AssistantIntentClassification,
        snapshot: AssistantSituationSnapshot?
    ) -> [Guide] {
        let normalizedQuery = AssistantIntentClassifier.normalize(query)
        let categoryScopedFallback = fallbackSearchCategories(for: normalizedQuery)
            .flatMap { guideService.searchGuides(query: query, category: $0) }

        let primaryFallback = categoryScopedFallback.isEmpty
            ? guideService.searchGuides(query: query)
            : categoryScopedFallback

        let shouldRestrict = shouldRestrictFallbackGuides(
            normalizedQuery: normalizedQuery,
            classification: classification,
            snapshot: snapshot
        )
        let filteredFallback = shouldRestrict
            ? primaryFallback.filter { $0.category.isAssistantFallbackSafe }
            : primaryFallback

        return orderedUniqueGuides(filteredFallback)
    }

    private func fallbackSearchCategories(for normalizedQuery: String) -> [GuideCategory] {
        if normalizedQuery.containsAnyAssistantQueryFragment(["blackout", "power outage", "power cut", "power out", "outage"]) {
            return [.disasterResponse, .stormSafety, .fieldComms, .vehicleSurvival, .waterSafety]
        }

        if normalizedQuery.containsAnyAssistantQueryFragment(["route", "leave", "evacuate", "navigation", "map", "gps"]) {
            return [.disasterResponse, .navigation, .floodSafety, .stormSafety, .fireSafety, .vehicleSurvival]
        }

        return []
    }

    private func shouldRestrictFallbackGuides(
        normalizedQuery: String,
        classification: AssistantIntentClassification,
        snapshot: AssistantSituationSnapshot?
    ) -> Bool {
        guard classification.topic == .unknown else {
            return false
        }

        if let snapshot, snapshot.mode == .elevated || snapshot.mode == .crisis || snapshot.hasEnvironmentalHazard {
            return true
        }

        return normalizedQuery.containsAnyAssistantQueryFragment([
            "blackout",
            "outage",
            "power",
            "storm",
            "flood",
            "fire",
            "emergency",
            "leave",
            "evacuate",
            "route",
            "shelter",
            "alert",
            "warning"
        ])
    }

    private func shouldUseContextDrivenFallback(
        normalizedQuery: String,
        classification: AssistantIntentClassification,
        guides: [Guide],
        snapshot: AssistantSituationSnapshot?
    ) -> Bool {
        guard let snapshot else {
            return false
        }

        guard snapshot.mode == .elevated || snapshot.mode == .crisis else {
            return false
        }

        guard isGenericHighRiskQuery(normalizedQuery) else {
            return false
        }

        if classification.topic == .unknown {
            return true
        }

        return guides.isEmpty || classification.confidence < 0.45
    }

    private func isLowSignalInput(_ normalizedQuery: String) -> Bool {
        if Self.lowSignalPhrases.contains(normalizedQuery) {
            return true
        }

        return normalizedQuery.containsAnyAssistantQueryFragment(Self.lowSignalFragments)
    }

    private func isGenericHighRiskQuery(_ normalizedQuery: String) -> Bool {
        if isMovementDecisionQuery(normalizedQuery) {
            return true
        }

        if Self.lowSignalPhrases.contains(normalizedQuery) {
            return true
        }

        return normalizedQuery.containsAnyAssistantQueryFragment(Self.genericHighRiskFragments)
    }

    private func isMovementDecisionQuery(_ normalizedQuery: String) -> Bool {
        normalizedQuery.containsAnyAssistantQueryFragment(Self.movementDecisionFragments)
    }

    private func shouldBypassEntryPromptForSpecificTopic(_ normalizedQuery: String) -> Bool {
        normalizedQuery.containsAnyAssistantQueryFragment([
            "blackout",
            "power outage",
            "power cut",
            "power out",
            "outage",
            "bushfire",
            "fire",
            "ember",
            "smoke",
            "storm",
            "cyclone",
            "hail",
            "wind",
            "weather",
            "flood",
            "floodwater",
            "flash flood",
            "lost",
            "no signal",
            "without signal",
            "no gps",
            "without gps",
            "navigation",
            "route",
            "map"
        ])
    }

    private func orderedUniqueGuides(_ guides: [Guide]) -> [Guide] {
        var seen = Set<String>()
        var ordered: [Guide] = []

        for guide in guides where seen.insert(guide.id).inserted {
            ordered.append(guide)
        }

        return ordered
    }

    /// Returns guide IDs from related policies that complement the primary match.
    private func supportingGuideIDs(for topic: AssistantIntentTopic) -> [String] {
        switch topic {
        case .waterSourcingSurvival:
            ["boil_filter_disinfect_water", "ration_water_without_dehydration"]
        case .firecraft:
            ["fire_starting_methods"]
        case .shelterBuildingSurvival:
            ["shelter_building_basics"]
        case .trappingForaging:
            ["native_edible_plants_basics"]
        case .fieldSanitation:
            ["prevent_dehydration_in_extreme_heat"]
        case .vehicleSurvival:
            ["route_planning_without_gps"]
        case .navigationNoTools:
            ["route_planning_without_gps", "set_simple_rally_points"]
        case .waterPurification:
            ["find_water_from_terrain", "water_rationing_survival"]
        case .waterPlanning:
            ["find_water_from_terrain"]
        default:
            []
        }
    }

    private func clarificationQuestion(
        for query: String,
        normalizedQuery: String,
        classification: AssistantIntentClassification,
        snapshot: AssistantSituationSnapshot?
    ) -> AssistantClarifyingQuestion? {
        guard sessionState.pendingQuestion == nil else {
            return nil
        }

        guard shouldAskClarifyingQuestion(
            classification: classification,
            snapshot: snapshot
        ) else {
            return nil
        }

        if isMovementDecisionQuery(normalizedQuery) {
            return nil
        }

        if needsMovementIntentQuestion(classification: classification, snapshot: snapshot) {
            return AssistantClarifyingQuestion(
                kind: .movementIntent,
                prompt: "Are you leaving now or staying for the moment?",
                options: ["Leaving now", "Staying put"]
            )
        }

        if needsSituationTimingQuestion(
            normalizedQuery: normalizedQuery,
            classification: classification,
            query: query,
            snapshot: snapshot
        ) {
            return AssistantClarifyingQuestion(
                kind: .currentSituation,
                prompt: "Is this happening right now or are you planning ahead?",
                options: ["Right now", "Planning ahead"]
            )
        }

        return nil
    }

    private func shouldAskClarifyingQuestion(
        classification: AssistantIntentClassification,
        snapshot: AssistantSituationSnapshot?
    ) -> Bool {
        guard classification.riskBand != .critical else {
            return false
        }

        guard let snapshot else {
            return true
        }

        switch snapshot.mode {
        case .crisis:
            return false
        case .elevated:
            return snapshot.routeStatus == .atRisk
                || snapshot.routeStatus == .blocked
                || snapshot.proximity == .inside
                || snapshot.proximity == .near
        case .prep:
            return false
        case .normal:
            return true
        }
    }

    private func needsMovementIntentQuestion(
        classification: AssistantIntentClassification,
        snapshot: AssistantSituationSnapshot?
    ) -> Bool {
        guard sessionState.operationalIntent == nil else {
            return false
        }

        guard let snapshot else {
            return false
        }

        let hazardDrivenMovement = snapshot.mode == .elevated
            || snapshot.routeStatus == .atRisk
            || snapshot.routeStatus == .blocked
            || snapshot.proximity == .inside
            || snapshot.proximity == .near

        switch classification.topic {
        case .bushfireEvacuation, .floodSafety, .routePlanning, .vehicleSurvival:
            return hazardDrivenMovement || snapshot.hazard != nil
        case .unknown, .preparednessPlanning:
            switch snapshot.hazard {
            case .bushfire, .flood, .severeStorm, .cyclone:
                return hazardDrivenMovement
            default:
                return false
            }
        default:
            return false
        }
    }

    private func needsSituationTimingQuestion(
        normalizedQuery: String,
        classification: AssistantIntentClassification,
        query: String,
        snapshot: AssistantSituationSnapshot?
    ) -> Bool {
        guard sessionState.operationalIntent == nil else {
            return false
        }

        if let snapshot,
           snapshot.hasEnvironmentalHazard,
           snapshot.mode == .prep || snapshot.mode == .elevated || snapshot.mode == .crisis {
            return false
        }

        let genericPhrases = [
            "what should i do",
            "what do i do",
            "help me",
            "where do i start",
            "how do i start"
        ]

        let isGeneric = genericPhrases.contains(where: normalizedQuery.contains)
            || query.split(separator: " ").count <= 4

        guard isGeneric else {
            return false
        }

        switch classification.topic {
        case .preparednessPlanning, .unknown, .waterPlanning, .fieldComms:
            return true
        default:
            return false
        }
    }

    private static let greetingPhrases: Set<String> = [
        "hi",
        "hello",
        "hey",
        "gday",
        "good morning",
        "good afternoon",
        "good evening"
    ]

    private static let lowSignalPhrases: Set<String> = [
        "help",
        "idk",
        "i dont know",
        "not sure",
        "unsure",
        "what now",
        "what do i do",
        "what should i do",
        "where do i start",
        "how do i start",
        "can you help me"
    ]

    private static let lowSignalFragments: [String] = [
        "what do i do",
        "what should i do",
        "where do i start",
        "how do i start",
        "can you help me",
        "dont know what to do",
        "do not know what to do",
        "something feels wrong",
        "feels wrong",
        "not sure whats happening",
        "not sure what s happening",
        "i need help"
    ]

    private static let genericHighRiskFragments: [String] = [
        "what do i do",
        "what should i do",
        "help",
        "help me",
        "what now",
        "what next",
        "something feels wrong"
    ]

    private static let movementDecisionFragments: [String] = [
        "should i leave",
        "do i need to leave",
        "is it safe to leave",
        "leave or stay",
        "evacuate now",
        "should we evacuate",
        "should we leave"
    ]
}

private extension String {
    func containsAnyAssistantQueryFragment(_ fragments: [String]) -> Bool {
        fragments.contains { contains($0) }
    }
}
