import Foundation

final class AssistantAnswerComposer {
    private enum PlanningPolicyKind {
        case blackout
        case fireReadiness
        case stormPrep
        case floodPrep
        case navigation

        var title: String {
            switch self {
            case .blackout:
                "Blackout preparation"
            case .fireReadiness:
                "Fire readiness"
            case .stormPrep:
                "Storm preparation"
            case .floodPrep:
                "Flood preparation"
            case .navigation:
                "Navigation guidance"
            }
        }

        var topic: AssistantIntentTopic {
            switch self {
            case .floodPrep:
                .floodSafety
            case .navigation:
                .routePlanning
            case .blackout, .fireReadiness, .stormPrep:
                .preparednessPlanning
            }
        }
    }

    private let summarizer: GuideSummarizer

    init(summarizer: GuideSummarizer) {
        self.summarizer = summarizer
    }

    func compose(
        query: String,
        classification: AssistantIntentClassification,
        guides: [Guide],
        allowsSafeSummaries: Bool,
        offlineModel: (any OfflineAssistantModeling)? = nil,
        safetyFilter: AssistantSafetyFilter? = nil,
        interpretationNote: String? = nil,
        contextSections: [AssistantContextSection] = [],
        situationSnapshot: AssistantSituationSnapshot? = nil,
        advisorContextStatus: AdvisorContextStatus = .init(
            source: .generalGuidance,
            freshnessMinutes: nil,
            isOffline: false,
            hazard: nil,
            routeStatus: nil
        ),
        recentActionHint: AssistantRecentActionHint? = nil,
        clarifyingQuestion: AssistantClarifyingQuestion? = nil
    ) -> AssistantResponse {
        let relatedGuides = guides
        let sourceSummary = composeSourceSummary(from: relatedGuides)
        let lastReviewedSummary = composeLastReviewedSummary(classification: classification, guides: relatedGuides)
        let regionSummary = composeRegionSummary(classification: classification, guides: relatedGuides)
        let usesOperationalTrustContext = shouldShowOperationalTrustContext(
            contextSections: contextSections,
            situationSnapshot: situationSnapshot,
            advisorContextStatus: advisorContextStatus,
            recentActionHint: recentActionHint
        )

        guard let primaryGuide = relatedGuides.first else {
            return AssistantResponse(
                query: query,
                title: "Closest Offline Guidance",
                topic: classification.topic,
                confidence: classification.confidence,
                riskBand: classification.riskBand,
                trustLabel: classification.trustLabel,
                answerMode: .guideFallback,
                sourceMode: .fallback,
                summary: "I could not find an exact bundled offline match for that question. Start with the closest guide below, then open the full guide for verified steps.",
                steps: [],
                escalationNote: classification.escalationNote,
                relatedGuides: [],
                sourceSummary: "Bundled offline references",
                lastReviewedSummary: "Bundled offline references",
                regionSummary: classification.regionScope?.title ?? GuideRegionScope.general.title,
                fallbackExplanation: "No exact bundled match — showing the closest offline guides.",
                interpretationNote: interpretationNote,
                contextSections: contextSections,
                situationSnapshot: situationSnapshot,
                advisorContextStatus: advisorContextStatus,
                usesOperationalTrustContext: usesOperationalTrustContext,
                clarifyingQuestion: clarifyingQuestion
            )
        }

        let effectiveMode = resolvedAnswerMode(
            for: classification,
            allowsSafeSummaries: allowsSafeSummaries
        )

        switch effectiveMode {
        case .deterministicStepCard:
            let briefingTitle = composeTitle(
                primaryGuide: primaryGuide,
                classification: classification,
                contextSections: contextSections,
                situationSnapshot: situationSnapshot
            )
            let briefingSummary = composeSituationSummary(
                baseSummary: primaryGuide.summary,
                classification: classification,
                contextSections: contextSections,
                situationSnapshot: situationSnapshot,
                advisorContextStatus: advisorContextStatus,
                recentActionHint: recentActionHint
            )
            let briefingSafetyNotes = composeSafetyNotes(
                baseSafetyNotes: primaryGuide.notes.nilIfBlank.map { [$0] } ?? [],
                classification: classification,
                contextSections: contextSections,
                situationSnapshot: situationSnapshot
            )
            return AssistantResponse(
                query: query,
                title: briefingTitle,
                topic: classification.topic,
                confidence: classification.confidence,
                riskBand: classification.riskBand,
                trustLabel: classification.trustLabel,
                answerMode: effectiveMode,
                sourceMode: .deterministic,
                summary: briefingSummary,
                steps: presentationSteps(
                    from: primaryGuide.steps,
                    classification: classification,
                    situationSnapshot: situationSnapshot,
                    advisorContextStatus: advisorContextStatus,
                    recentActionHint: recentActionHint
                ),
                safetyNotes: briefingSafetyNotes,
                escalationNote: classification.escalationNote,
                relatedGuides: relatedGuides,
                sourceSummary: sourceSummary,
                lastReviewedSummary: lastReviewedSummary,
                regionSummary: regionSummary,
                interpretationNote: interpretationNote,
                contextSections: contextSections,
                situationSnapshot: situationSnapshot,
                advisorContextStatus: advisorContextStatus,
                usesOperationalTrustContext: usesOperationalTrustContext,
                clarifyingQuestion: clarifyingQuestion
            )
        case .summarizedRetrieval:
            let summary = summarizer.summarize(
                guides: relatedGuides,
                classification: classification,
                offlineModel: offlineModel,
                safetyFilter: safetyFilter
            )
            let briefingTitle = composeTitle(
                primaryGuide: primaryGuide,
                classification: classification,
                contextSections: contextSections,
                situationSnapshot: situationSnapshot
            )
            let briefingSummary = composeSituationSummary(
                baseSummary: summary.summary,
                classification: classification,
                contextSections: contextSections,
                situationSnapshot: situationSnapshot,
                advisorContextStatus: advisorContextStatus,
                recentActionHint: recentActionHint
            )
            let briefingSafetyNotes = composeSafetyNotes(
                baseSafetyNotes: summary.safetyNotes,
                classification: classification,
                contextSections: contextSections,
                situationSnapshot: situationSnapshot
            )
            return AssistantResponse(
                query: query,
                title: briefingTitle,
                topic: classification.topic,
                confidence: classification.confidence,
                riskBand: classification.riskBand,
                trustLabel: classification.trustLabel,
                answerMode: effectiveMode,
                sourceMode: .summarized,
                summary: briefingSummary,
                steps: presentationSteps(
                    from: summary.steps,
                    classification: classification,
                    situationSnapshot: situationSnapshot,
                    advisorContextStatus: advisorContextStatus,
                    recentActionHint: recentActionHint
                ),
                safetyNotes: briefingSafetyNotes,
                escalationNote: classification.escalationNote,
                relatedGuides: relatedGuides,
                sourceSummary: summary.usedOfflineModel ? "\(sourceSummary) + on-device AI clarification" : sourceSummary,
                lastReviewedSummary: lastReviewedSummary,
                regionSummary: regionSummary,
                interpretationNote: interpretationNote,
                usedOfflineModel: summary.usedOfflineModel,
                contextSections: contextSections,
                situationSnapshot: situationSnapshot,
                advisorContextStatus: advisorContextStatus,
                usesOperationalTrustContext: usesOperationalTrustContext,
                clarifyingQuestion: clarifyingQuestion
            )
        case .retrievalOnlyCard, .guideFallback:
            let fallbackExplanation: String
            if classification.topic == .unknown {
                fallbackExplanation = "No exact bundled match — showing the closest offline guides."
            } else {
                fallbackExplanation = "Showing direct guide steps without any AI rewriting."
            }

            let baseSummary: String
            if classification.topic == .unknown {
                baseSummary = "These are the closest bundled guides for your question. Open one to review the full offline steps."
            } else {
                baseSummary = primaryGuide.summary
            }

            let briefingTitle = composeTitle(
                primaryGuide: primaryGuide,
                classification: classification,
                contextSections: contextSections,
                situationSnapshot: situationSnapshot
            )
            let briefingSummary = composeSituationSummary(
                baseSummary: baseSummary,
                classification: classification,
                contextSections: contextSections,
                situationSnapshot: situationSnapshot,
                advisorContextStatus: advisorContextStatus,
                recentActionHint: recentActionHint
            )
            let briefingSafetyNotes = composeSafetyNotes(
                baseSafetyNotes: primaryGuide.notes.nilIfBlank.map { [$0] } ?? [],
                classification: classification,
                contextSections: contextSections,
                situationSnapshot: situationSnapshot
            )

            return AssistantResponse(
                query: query,
                title: briefingTitle,
                topic: classification.topic,
                confidence: classification.confidence,
                riskBand: classification.riskBand,
                trustLabel: classification.trustLabel,
                answerMode: effectiveMode,
                sourceMode: classification.topic == .unknown ? .fallback : .retrievalOnly,
                summary: briefingSummary,
                steps: classification.topic == .unknown
                    ? []
                    : presentationSteps(
                        from: Array(primaryGuide.steps.prefix(4)),
                        classification: classification,
                        situationSnapshot: situationSnapshot,
                        advisorContextStatus: advisorContextStatus,
                        recentActionHint: recentActionHint
                    ),
                safetyNotes: briefingSafetyNotes,
                escalationNote: classification.escalationNote,
                relatedGuides: relatedGuides,
                sourceSummary: sourceSummary,
                lastReviewedSummary: lastReviewedSummary,
                regionSummary: regionSummary,
                fallbackExplanation: fallbackExplanation,
                interpretationNote: interpretationNote,
                contextSections: contextSections,
                situationSnapshot: situationSnapshot,
                advisorContextStatus: advisorContextStatus,
                usesOperationalTrustContext: usesOperationalTrustContext,
                clarifyingQuestion: clarifyingQuestion
            )
        }
    }

    func composeContextDrivenFallback(
        query: String,
        classification: AssistantIntentClassification,
        guides: [Guide],
        interpretationNote: String? = nil,
        contextSections: [AssistantContextSection] = [],
        situationSnapshot: AssistantSituationSnapshot,
        advisorContextStatus: AdvisorContextStatus,
        recentActionHint: AssistantRecentActionHint? = nil,
        clarifyingQuestion: AssistantClarifyingQuestion? = nil
    ) -> AssistantResponse {
        let fallbackClassification = contextFallbackClassification(
            from: classification,
            situationSnapshot: situationSnapshot,
            advisorContextStatus: advisorContextStatus
        )
        let relatedGuides = Array(guides.prefix(3))
        let summary = composeSituationSummary(
            baseSummary: contextFallbackBaseSummary(for: situationSnapshot, advisorContextStatus: advisorContextStatus),
            classification: fallbackClassification,
            contextSections: contextSections,
            situationSnapshot: situationSnapshot,
            advisorContextStatus: advisorContextStatus,
            recentActionHint: recentActionHint
        )
        let safetyNotes = composeSafetyNotes(
            baseSafetyNotes: contextFallbackSafetyNotes(
                for: situationSnapshot,
                advisorContextStatus: advisorContextStatus
            ),
            classification: fallbackClassification,
            contextSections: contextSections,
            situationSnapshot: situationSnapshot
        )

        return AssistantResponse(
            query: query,
            title: composeContextFallbackTitle(
                classification: fallbackClassification,
                situationSnapshot: situationSnapshot
            ),
            topic: fallbackClassification.topic,
            confidence: max(fallbackClassification.confidence, minimumContextFallbackConfidence(for: situationSnapshot)),
            riskBand: fallbackClassification.riskBand,
            trustLabel: fallbackClassification.trustLabel,
            answerMode: .deterministicStepCard,
            sourceMode: .deterministic,
            summary: summary,
            steps: contextFallbackSteps(
                for: situationSnapshot,
                advisorContextStatus: advisorContextStatus,
                recentActionHint: recentActionHint
            ),
            safetyNotes: safetyNotes,
            escalationNote: fallbackClassification.escalationNote,
            relatedGuides: relatedGuides,
            sourceSummary: contextFallbackSourceSummary(advisorContextStatus: advisorContextStatus),
            lastReviewedSummary: relatedGuides.first?.lastReviewed ?? "Bundled offline rules",
            regionSummary: fallbackClassification.regionScope?.title ?? GuideRegionScope.general.title,
            interpretationNote: interpretationNote,
            contextSections: contextSections,
            situationSnapshot: situationSnapshot,
            advisorContextStatus: advisorContextStatus,
            usesOperationalTrustContext: true,
            clarifyingQuestion: clarifyingQuestion
        )
    }

    func composePlanningPolicyFallback(
        query: String,
        classification: AssistantIntentClassification,
        guides: [Guide],
        interpretationNote: String? = nil,
        contextSections: [AssistantContextSection] = [],
        situationSnapshot: AssistantSituationSnapshot? = nil,
        advisorContextStatus: AdvisorContextStatus = .init(
            source: .generalGuidance,
            freshnessMinutes: nil,
            isOffline: false,
            hazard: nil,
            routeStatus: nil
        )
    ) -> AssistantResponse? {
        let normalizedQuery = AssistantIntentClassifier.normalize(query)
        let mode = situationSnapshot?.mode ?? .normal
        guard mode == .normal || mode == .prep else {
            return nil
        }

        guard shouldUsePlanningPolicyFallback(
            normalizedQuery: normalizedQuery,
            classification: classification,
            guides: guides
        ) else {
            return nil
        }

        guard let policy = planningPolicyKind(
            for: normalizedQuery,
            classification: classification
        ) else {
            return nil
        }

        let template = planningPolicyTemplate(
            for: policy,
            situationSnapshot: situationSnapshot
        )
        let relatedGuides = Array(guides.prefix(3))
        let policyClassification = planningPolicyClassification(
            from: classification,
            policy: policy
        )

        return AssistantResponse(
            query: query,
            title: policy.title,
            topic: policyClassification.topic,
            confidence: max(policyClassification.confidence, 0.58),
            riskBand: policyClassification.riskBand,
            trustLabel: policyClassification.trustLabel,
            answerMode: .deterministicStepCard,
            sourceMode: .deterministic,
            summary: template.summary,
            steps: template.steps,
            safetyNotes: [template.avoid],
            escalationNote: policyClassification.escalationNote,
            relatedGuides: relatedGuides,
            sourceSummary: "Bundled RediM8 offline planning rules",
            lastReviewedSummary: relatedGuides.first?.lastReviewed ?? "Bundled offline rules",
            regionSummary: policyClassification.regionScope?.title ?? GuideRegionScope.general.title,
            interpretationNote: interpretationNote,
            contextSections: contextSections,
            situationSnapshot: situationSnapshot,
            advisorContextStatus: advisorContextStatus,
            usesOperationalTrustContext: false,
            clarifyingQuestion: nil
        )
    }

    private func resolvedAnswerMode(
        for classification: AssistantIntentClassification,
        allowsSafeSummaries: Bool
    ) -> AssistantAnswerMode {
        guard classification.preferredMode == .summarizedRetrieval else {
            return classification.preferredMode
        }

        guard allowsSafeSummaries, classification.riskBand != .critical else {
            return classification.modeWhenGenerationDisabled
        }

        return classification.preferredMode
    }

    private func composeSourceSummary(from guides: [Guide]) -> String {
        let publishers = guides
            .flatMap(\.sources)
            .map(\.publisher)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard let firstPublisher = publishers.first else {
            return "Bundled RediM8 offline guides"
        }

        let uniquePublishers = Array(Set(publishers)).sorted()
        if uniquePublishers.count == 1 {
            return firstPublisher
        }

        return "\(firstPublisher) + bundled offline references"
    }

    private func shouldShowOperationalTrustContext(
        contextSections: [AssistantContextSection],
        situationSnapshot: AssistantSituationSnapshot?,
        advisorContextStatus: AdvisorContextStatus,
        recentActionHint: AssistantRecentActionHint?
    ) -> Bool {
        if contextSections.contains(where: \.isHazardWarning) {
            return true
        }

        if let situationSnapshot,
           situationSnapshot.routeStatus != nil || situationSnapshot.hasEnvironmentalHazard {
            return advisorContextStatus.source != .generalGuidance || recentActionHint != nil
        }

        if recentActionHint != nil, advisorContextStatus.source != .generalGuidance {
            return true
        }

        return false
    }

    private func contextFallbackClassification(
        from classification: AssistantIntentClassification,
        situationSnapshot: AssistantSituationSnapshot,
        advisorContextStatus: AdvisorContextStatus
    ) -> AssistantIntentClassification {
        let fallbackTopic = classification.topic == .unknown
            ? inferredFallbackTopic(for: situationSnapshot)
            : classification.topic
        let fallbackRiskBand: AssistantIntentRiskBand = switch situationSnapshot.mode {
        case .crisis:
            .critical
        case .elevated:
            .advisory
        case .prep, .normal:
            classification.riskBand
        }
        let fallbackTrustLabel: AssistantTrustLabel? = if advisorContextStatus.source != .generalGuidance {
            .verified
        } else {
            classification.trustLabel
        }
        let fallbackEscalationNote: String? = if situationSnapshot.mode == .crisis, let hazard = situationSnapshot.hazard {
            switch hazard {
            case .bushfire:
                "Follow official warnings immediately and call emergency services if you are trapped or in immediate danger."
            case .flood:
                "Do not enter floodwater by foot or vehicle. Contact emergency services if escape routes are cut off."
            default:
                classification.escalationNote
            }
        } else {
            classification.escalationNote
        }

        return AssistantIntentClassification(
            policyID: classification.policyID,
            topic: fallbackTopic,
            riskBand: fallbackRiskBand,
            preferredMode: .deterministicStepCard,
            modeWhenGenerationDisabled: .deterministicStepCard,
            matchedGuideIDs: classification.matchedGuideIDs,
            matchedTerms: classification.matchedTerms,
            trustLabel: fallbackTrustLabel,
            lastReviewed: classification.lastReviewed,
            regionScope: classification.regionScope,
            confidence: classification.confidence,
            escalationNote: fallbackEscalationNote
        )
    }

    private func inferredFallbackTopic(for situationSnapshot: AssistantSituationSnapshot) -> AssistantIntentTopic {
        switch situationSnapshot.hazard {
        case .bushfire:
            return .bushfireEvacuation
        case .flood:
            return .floodSafety
        case .severeStorm, .cyclone:
            return .preparednessPlanning
        case .none:
            if situationSnapshot.routeStatus != nil {
                return .routePlanning
            }
            return .preparednessPlanning
        default:
            return .preparednessPlanning
        }
    }

    private func shouldUsePlanningPolicyFallback(
        normalizedQuery: String,
        classification: AssistantIntentClassification,
        guides: [Guide]
    ) -> Bool {
        let weakRetrieval = classification.topic == .unknown
            || guides.isEmpty
            || classification.confidence < 0.45

        guard weakRetrieval else {
            return false
        }

        return planningPolicyKind(
            for: normalizedQuery,
            classification: classification
        ) != nil
    }

    private func planningPolicyKind(
        for normalizedQuery: String,
        classification: AssistantIntentClassification
    ) -> PlanningPolicyKind? {
        if query(normalizedQuery, containsAny: [
            "blackout",
            "power outage",
            "power cut",
            "power out",
            "outage"
        ]) {
            return .blackout
        }

        if query(normalizedQuery, containsAny: [
            "lost",
            "no signal",
            "without signal",
            "no gps",
            "without gps",
            "navigation",
            "route",
            "map"
        ]) || classification.topic == .routePlanning {
            return .navigation
        }

        let hasPlanningCue = query(normalizedQuery, containsAny: [
            "prepare",
            "planning",
            "plan",
            "prep",
            "ready",
            "readiness",
            "get ready"
        ])

        if query(normalizedQuery, containsAny: [
            "flood",
            "floodwater",
            "flash flood"
        ]) && hasPlanningCue {
            return .floodPrep
        }

        if query(normalizedQuery, containsAny: [
            "storm",
            "cyclone",
            "hail",
            "wind",
            "weather"
        ]) && hasPlanningCue {
            return .stormPrep
        }

        if query(normalizedQuery, containsAny: [
            "bushfire",
            "fire",
            "ember",
            "smoke"
        ]) && hasPlanningCue {
            return .fireReadiness
        }

        if classification.topic == .preparednessPlanning && hasPlanningCue {
            return .stormPrep
        }

        return nil
    }

    private func planningPolicyClassification(
        from classification: AssistantIntentClassification,
        policy: PlanningPolicyKind
    ) -> AssistantIntentClassification {
        AssistantIntentClassification(
            policyID: classification.policyID,
            topic: policy.topic,
            riskBand: classification.riskBand,
            preferredMode: .deterministicStepCard,
            modeWhenGenerationDisabled: .deterministicStepCard,
            matchedGuideIDs: classification.matchedGuideIDs,
            matchedTerms: classification.matchedTerms,
            trustLabel: classification.trustLabel ?? .general,
            lastReviewed: classification.lastReviewed,
            regionScope: classification.regionScope,
            confidence: classification.confidence,
            escalationNote: classification.escalationNote
        )
    }

    private func planningPolicyTemplate(
        for policy: PlanningPolicyKind,
        situationSnapshot: AssistantSituationSnapshot?
    ) -> (summary: String, steps: [String], avoid: String) {
        var steps: [String]
        let summary: String
        let avoid: String

        switch policy {
        case .blackout:
            summary = "Prepare early so you can stay safe and maintain essentials during a power outage."
            steps = [
                "Store water and ready-to-eat food.",
                "Charge devices and prepare backup lighting.",
                "Plan for refrigeration and medication storage.",
                "Keep a radio or offline updates available."
            ]
            avoid = "Do not rely on power-dependent systems without backup."
        case .fireReadiness:
            summary = "Prepare early so you can leave quickly if conditions change."
            steps = [
                "Pack essential items and documents.",
                "Plan your evacuation route.",
                "Prepare pets and dependents.",
                "Monitor official alerts."
            ]
            avoid = "Do not wait until conditions worsen."
        case .stormPrep:
            summary = "Secure your home and prepare for possible disruption."
            steps = [
                "Secure loose outdoor items.",
                "Prepare backup lighting and supplies.",
                "Check drainage and water flow.",
                "Charge devices."
            ]
            avoid = "Do not travel unnecessarily during severe weather."
        case .floodPrep:
            summary = "Prepare early and avoid low-lying risk areas."
            steps = [
                "Move items to higher ground.",
                "Prepare evacuation essentials.",
                "Identify safe routes.",
                "Monitor water levels."
            ]
            avoid = "Do not drive through floodwater."
        case .navigation:
            summary = "Stay oriented and avoid unnecessary movement."
            steps = [
                "Stop and assess your surroundings.",
                "Use known landmarks or offline maps.",
                "Avoid moving without a clear direction.",
                "Signal for help if needed."
            ]
            avoid = "Do not continue moving if you are disoriented."
        }

        if let situationSnapshot, situationSnapshot.hasDependents {
            steps = planningStepsIncludingDependents(
                steps,
                for: policy
            )
        }

        return (summary, Array(steps.prefix(5)), avoid)
    }

    private func planningStepsIncludingDependents(
        _ steps: [String],
        for policy: PlanningPolicyKind
    ) -> [String] {
        let dependentStep: String
        switch policy {
        case .navigation:
            dependentStep = "Keep children, pets, medications, and anyone with you together before moving."
        default:
            dependentStep = "Prepare items for children, pets, and medications early."
        }

        guard !steps.contains(where: {
            $0.localizedCaseInsensitiveContains("children")
                || $0.localizedCaseInsensitiveContains("pets")
                || $0.localizedCaseInsensitiveContains("dependents")
                || $0.localizedCaseInsensitiveContains("medications")
        }) else {
            return steps
        }

        var adjusted = steps
        adjusted.insert(dependentStep, at: min(1, adjusted.count))
        return adjusted
    }

    private func query(
        _ normalizedQuery: String,
        containsAny fragments: [String]
    ) -> Bool {
        fragments.contains { fragment in
            normalizedQuery.contains(fragment)
        }
    }

    private func composeContextFallbackTitle(
        classification: AssistantIntentClassification,
        situationSnapshot: AssistantSituationSnapshot
    ) -> String {
        if let hazardTitle = situationSnapshot.hazardTitle {
            switch situationSnapshot.mode {
            case .crisis:
                return "\(hazardTitle) risk near your area"
            case .elevated:
                switch classification.topic {
                case .floodSafety:
                    return "Flood alert near your area"
                case .bushfireEvacuation:
                    return "Bushfire alert near your area"
                case .routePlanning:
                    return "Route guidance under current alerts"
                default:
                    return "Preparing under current alerts"
                }
            case .prep, .normal:
                break
            }
        }

        if situationSnapshot.routeStatus != nil {
            return situationSnapshot.mode == .crisis
                ? "Immediate route guidance"
                : "Route guidance under current conditions"
        }

        return classification.topic == .preparednessPlanning ? "Preparation guidance" : "Current guidance"
    }

    private func contextFallbackBaseSummary(
        for situationSnapshot: AssistantSituationSnapshot,
        advisorContextStatus _: AdvisorContextStatus
    ) -> String {
        switch situationSnapshot.mode {
        case .crisis:
            return "Focus on immediate safety actions."
        case .elevated:
            return "Prepare early and stay ready to move."
        case .prep:
            return "Use this to prepare before conditions tighten."
        case .normal:
            return "Start with the safest practical next step."
        }
    }

    private func contextFallbackSafetyNotes(
        for situationSnapshot: AssistantSituationSnapshot,
        advisorContextStatus: AdvisorContextStatus
    ) -> [String] {
        var notes: [String] = []

        if advisorContextStatus.source != .generalGuidance, situationSnapshot.hasEnvironmentalHazard {
            notes.append("Do not rely on cached alert data alone. Follow official warnings first and confirm conditions have not changed before travel.")
        }

        if situationSnapshot.mode == .crisis {
            notes.append("Do not wait for conditions to worsen before you move if a safer option is available now.")
        }

        return notes
    }

    private func contextFallbackSourceSummary(advisorContextStatus: AdvisorContextStatus) -> String {
        switch advisorContextStatus.source {
        case .officialAlerts, .lastSyncedAlerts:
            return "Official alerts + bundled offline rules"
        case .generalGuidance:
            return "Bundled RediM8 offline rules"
        }
    }

    private func minimumContextFallbackConfidence(for situationSnapshot: AssistantSituationSnapshot) -> Double {
        switch situationSnapshot.mode {
        case .crisis:
            return 0.82
        case .elevated:
            return 0.66
        case .prep, .normal:
            return 0.5
        }
    }

    private func contextFallbackSteps(
        for situationSnapshot: AssistantSituationSnapshot,
        advisorContextStatus: AdvisorContextStatus,
        recentActionHint: AssistantRecentActionHint?
    ) -> [String] {
        let confidence = phrasingConfidence(
            for: situationSnapshot,
            advisorContextStatus: advisorContextStatus
        )

        switch situationSnapshot.mode {
        case .crisis:
            var steps: [String] = []

            switch situationSnapshot.routeStatus {
            case .blocked:
                steps.append("Check the safest alternative route before you leave.")
            case .atRisk:
                steps.append(confidence == .assertive
                    ? "Leave now if it is safe to do so."
                    : "Prepare to leave if conditions worsen or official warnings escalate.")
            case .clear, .none:
                steps.append(confidence == .assertive
                    ? "Leave now if it is safe to do so."
                    : "Prepare to move if conditions worsen or official warnings escalate.")
            }

            if situationSnapshot.hasDependents {
                steps.append("Pack medicines, water, documents, and items for children or pets before optional gear.")
            } else {
                steps.append("Take medicines, water, documents, and essential items before optional gear.")
            }

            if let routeStep = contextFallbackRouteStep(
                for: situationSnapshot,
                advisorContextStatus: advisorContextStatus,
                recentActionHint: recentActionHint
            ) {
                steps.append(routeStep)
            } else {
                steps.append("Check the safest available route before you move.")
            }

            return Array(steps.prefix(3))

        case .elevated:
            var steps: [String] = []

            if situationSnapshot.hasDependents {
                steps.append("Prepare medicines, water, documents, and items for children or pets so you can move quickly.")
            } else {
                steps.append("Prepare water, documents, chargers, and essential items so you can move quickly.")
            }

            if let routeStep = contextFallbackRouteStep(
                for: situationSnapshot,
                advisorContextStatus: advisorContextStatus,
                recentActionHint: recentActionHint
            ) {
                steps.append(routeStep)
            } else {
                steps.append("Review your safest route options before conditions tighten.")
            }

            steps.append(confidence == .assertive
                ? "Monitor official warnings and be ready to move early."
                : "Monitor official warnings and be ready to move if conditions worsen.")

            return steps

        case .prep:
            return [
                "Set aside water, documents, chargers, and household essentials now.",
                "Review your route options and local official warning sources.",
                "Keep medicines and priority items together so you can move quickly if needed."
            ]
        case .normal:
            return [
                "Start with the safest practical next step for your household.",
                "Check official warning sources if conditions are changing nearby.",
                "Keep essential items together so you can respond quickly if needed."
            ]
        }
    }

    private func contextFallbackRouteStep(
        for situationSnapshot: AssistantSituationSnapshot,
        advisorContextStatus: AdvisorContextStatus,
        recentActionHint: AssistantRecentActionHint?
    ) -> String? {
        if let recentActionHint {
            return composeActionLead(
                recentActionHint,
                situationSnapshot: situationSnapshot,
                advisorContextStatus: advisorContextStatus
            )?.appendingPeriodIfNeeded()
        }

        return composeRouteLead(
            for: situationSnapshot,
            advisorContextStatus: advisorContextStatus
        )?.appendingPeriodIfNeeded()
    }

    private func composeLastReviewedSummary(
        classification: AssistantIntentClassification,
        guides: [Guide]
    ) -> String {
        if let lastReviewed = classification.lastReviewed {
            return DateFormatter.rediM8Short.string(from: lastReviewed)
        }

        return guides.first?.lastReviewed ?? "Bundled offline guide"
    }

    private func composeRegionSummary(
        classification: AssistantIntentClassification,
        guides: [Guide]
    ) -> String {
        if let regionScope = classification.regionScope {
            return regionScope.title
        }

        return guides.first?.regionScope.title ?? GuideRegionScope.general.title
    }

    private func composeTitle(
        primaryGuide: Guide,
        classification: AssistantIntentClassification,
        contextSections: [AssistantContextSection],
        situationSnapshot: AssistantSituationSnapshot?
    ) -> String {
        if let situationSnapshot {
            if let hazardTitle = situationSnapshot.hazardTitle,
               situationSnapshot.mode == .crisis,
               situationSnapshot.proximity == .inside || situationSnapshot.proximity == .near {
                return "\(hazardTitle) risk near your area"
            }

            if let operationalIntent = situationSnapshot.operationalIntent {
                switch operationalIntent {
                case .planningAhead:
                    if classification.topic == .preparednessPlanning || classification.topic == .unknown {
                        return "Planning guidance"
                    }
                case .stayingPut:
                    if classification.topic == .bushfireEvacuation || classification.topic == .floodSafety {
                        return "Shelter guidance under current conditions"
                    }
                case .leavingNow:
                    if classification.topic == .bushfireEvacuation || classification.topic == .floodSafety || classification.topic == .routePlanning {
                        return "Leave-ready guidance"
                    }
                }
            }
        }

        let hasHazardWarning = contextSections.contains(where: \.isHazardWarning)

        guard hasHazardWarning else {
            switch classification.topic {
            case .preparednessPlanning:
                return "Preparation guidance"
            case .waterPlanning:
                return "Water planning guidance"
            case .fieldComms:
                return "Communication guidance"
            case .vehicleSurvival:
                return "Vehicle survival guidance"
            default:
                return primaryGuide.title
            }
        }

        switch classification.topic {
        case .bushfireEvacuation:
            return "Bushfire alert near your area"
        case .floodSafety:
            return "Flood alert near your area"
        case .routePlanning:
            return "Route guidance under current alerts"
        case .preparednessPlanning:
            return "Preparing under current alerts"
        case .waterPlanning, .waterPurification:
            return "Water safety under current conditions"
        case .fieldComms:
            return "Communication guidance under current alerts"
        case .vehicleSurvival:
            return "Vehicle safety under current conditions"
        default:
            return classification.riskBand == .critical
                ? "Immediate guidance for current conditions"
                : primaryGuide.title
        }
    }

    private func composeSituationSummary(
        baseSummary: String,
        classification: AssistantIntentClassification,
        contextSections: [AssistantContextSection],
        situationSnapshot: AssistantSituationSnapshot?,
        advisorContextStatus: AdvisorContextStatus,
        recentActionHint: AssistantRecentActionHint?
    ) -> String {
        var fragments: [String] = []

        if let snapshotLead = composeSnapshotLead(
            situationSnapshot,
            advisorContextStatus: advisorContextStatus,
            recentActionHint: recentActionHint
        ) {
            fragments.append(snapshotLead)
        }

        if let lead = composeOperationalLead(classification: classification, contextSections: contextSections) {
            fragments.append(lead)
        }

        if let baseSummary = baseSummary.nilIfBlank {
            fragments.append(baseSummary)
        }

        let summary = stitchedSummary(from: fragments)
        return presentationSummary(summary, for: situationSnapshot)
    }

    private func composeSafetyNotes(
        baseSafetyNotes: [String],
        classification: AssistantIntentClassification,
        contextSections: [AssistantContextSection],
        situationSnapshot: AssistantSituationSnapshot?
    ) -> [String] {
        var notes = baseSafetyNotes

        if contextSections.contains(where: \.isHazardWarning) {
            let officialAlertGuardrail = "Do not rely on cached alert data alone. Follow official warnings first and confirm conditions have not changed before travel."
            if !notes.contains(where: { $0.localizedCaseInsensitiveContains("official warnings first") || $0.localizedCaseInsensitiveContains("cached alert") }) {
                notes.insert(officialAlertGuardrail, at: 0)
            }
        }

        if classification.riskBand == .critical,
           notes.isEmpty,
           let escalationNote = classification.escalationNote?.nilIfBlank {
            notes.append(escalationNote)
        }

        if let situationSnapshot,
           situationSnapshot.mode == .crisis,
           situationSnapshot.hasEnvironmentalHazard,
           !notes.contains(where: { $0.localizedCaseInsensitiveContains("conditions worsen") || $0.localizedCaseInsensitiveContains("reassess") }) {
            notes.append("Do not keep moving if conditions worsen or routes stop looking safe. Reassess before continuing.")
        }

        return Array(notes.prefix(3))
    }

    private func composeSnapshotLead(
        _ situationSnapshot: AssistantSituationSnapshot?,
        advisorContextStatus: AdvisorContextStatus,
        recentActionHint: AssistantRecentActionHint?
    ) -> String? {
        guard let situationSnapshot else {
            return nil
        }

        var fragments: [String] = []

        if let actionLead = composeActionLead(
            recentActionHint,
            situationSnapshot: situationSnapshot,
            advisorContextStatus: advisorContextStatus
        ) {
            fragments.append(actionLead)
        }

        if let routeLead = composeRouteLead(
            for: situationSnapshot,
            advisorContextStatus: advisorContextStatus
        ) {
            fragments.append(routeLead)
        }

        if let operationalIntent = situationSnapshot.operationalIntent {
            fragments.append(operationalIntent.lead)
        }

        if let hazardTitle = situationSnapshot.hazardTitle {
            let severityText = situationSnapshot.severity?.title.lowercased() ?? "official alert"
            let confidence = phrasingConfidence(
                for: situationSnapshot,
                advisorContextStatus: advisorContextStatus
            )
            switch situationSnapshot.proximity {
            case .inside:
                fragments.append(hazardLead(
                    proximityPhrase: "overlaps your area",
                    severityText: severityText,
                    hazardTitle: hazardTitle,
                    confidence: confidence
                ))
            case .near:
                fragments.append(hazardLead(
                    proximityPhrase: "is active near your area",
                    severityText: severityText,
                    hazardTitle: hazardTitle,
                    confidence: confidence
                ))
            case .far, .unknown:
                fragments.append(hazardLead(
                    proximityPhrase: "is part of your current context",
                    severityText: severityText,
                    hazardTitle: hazardTitle,
                    confidence: confidence
                ))
            }
        }

        if situationSnapshot.hasDependents,
           !fragments.contains(where: { $0.localizedCaseInsensitiveContains("dependents") }) {
            fragments.append("Account for dependents, pets, medications, and comfort items before optional gear.")
        }

        if let lastSyncMinutes = situationSnapshot.lastSyncMinutes,
           situationSnapshot.hasEnvironmentalHazard,
           situationSnapshot.mode == .normal || situationSnapshot.mode == .prep {
            fragments.append("Official alert context was last synced \(lastSyncMinutes) minute\(lastSyncMinutes == 1 ? "" : "s") ago.")
        }

        return fragments.isEmpty ? nil : fragments.joined(separator: " ")
    }

    private func composeActionLead(
        _ recentActionHint: AssistantRecentActionHint?,
        situationSnapshot: AssistantSituationSnapshot,
        advisorContextStatus: AdvisorContextStatus
    ) -> String? {
        guard recentActionHint == .reviewedRoute else {
            return nil
        }

        let confidence = phrasingConfidence(
            for: situationSnapshot,
            advisorContextStatus: advisorContextStatus
        )

        switch situationSnapshot.routeStatus {
        case .blocked:
            switch confidence {
            case .assertive:
                return "Use the highlighted alternative route and avoid blocked or closed roads."
            case .guarded:
                return "Use the highlighted alternative route and keep checking conditions before you move."
            }
        case .atRisk:
            switch confidence {
            case .assertive:
                return "Use the highlighted route and avoid low-visibility or blocked roads."
            case .guarded:
                return "Use the highlighted route carefully and keep checking conditions before you move."
            }
        case .clear, .none:
            return "Use the highlighted route and keep checking conditions as you move."
        }
    }

    private func composeRouteLead(
        for situationSnapshot: AssistantSituationSnapshot,
        advisorContextStatus: AdvisorContextStatus
    ) -> String? {
        guard let routeStatus = situationSnapshot.routeStatus else {
            return nil
        }

        let confidence = phrasingConfidence(
            for: situationSnapshot,
            advisorContextStatus: advisorContextStatus
        )

        switch routeStatus {
        case .clear:
            return nil
        case .atRisk:
            if situationSnapshot.mode == .crisis || situationSnapshot.mode == .elevated {
                switch confidence {
                case .assertive:
                    return "Your usual route may be affected, so leave using the safest available alternative."
                case .guarded:
                    return "Your usual route may be affected, so prepare to leave using a safe alternative if conditions worsen."
                }
            }
            return "Treat saved routes as at risk until you confirm the safest way out."
        case .blocked:
            if situationSnapshot.mode == .crisis || situationSnapshot.mode == .elevated {
                switch confidence {
                case .assertive:
                    return "Your primary route may be blocked, so check an alternative route before leaving."
                case .guarded:
                    return "Your primary route may be blocked, so prepare an alternative route before leaving."
                }
            }
            return "Your route is blocked. Switch to fallback movement options immediately."
        }
    }

    private func presentationSteps(
        from steps: [String],
        classification: AssistantIntentClassification,
        situationSnapshot: AssistantSituationSnapshot?,
        advisorContextStatus: AdvisorContextStatus,
        recentActionHint: AssistantRecentActionHint?
    ) -> [String] {
        guard let situationSnapshot else {
            return steps
        }

        let prioritized = prioritizedSteps(
            steps,
            classification: classification,
            situationSnapshot: situationSnapshot
        )
        let contextualized = contextualizedSteps(
            prioritized,
            classification: classification,
            situationSnapshot: situationSnapshot,
            advisorContextStatus: advisorContextStatus,
            recentActionHint: recentActionHint
        )

        guard shouldCompressSteps(for: classification, situationSnapshot: situationSnapshot) else {
            return contextualized
        }

        return contextualized.map { compressedStep($0, for: situationSnapshot.mode) }
    }

    private func shouldCompressSteps(
        for classification: AssistantIntentClassification,
        situationSnapshot: AssistantSituationSnapshot
    ) -> Bool {
        guard situationSnapshot.mode == .crisis || situationSnapshot.mode == .elevated else {
            return false
        }

        switch classification.topic {
        case .bushfireEvacuation,
             .floodSafety,
             .routePlanning,
             .preparednessPlanning,
             .waterPlanning,
             .fieldComms,
             .vehicleSurvival:
            return true
        default:
            return situationSnapshot.hasEnvironmentalHazard
        }
    }

    private func composeOperationalLead(
        classification: AssistantIntentClassification,
        contextSections: [AssistantContextSection]
    ) -> String? {
        if let hazardSection = contextSections.first(where: \.isHazardWarning),
           let hazardLead = hazardSection.detail.nilIfBlank {
            return hazardLead
        }

        if let priorityContext = contextSections.first(where: { !$0.isHazardWarning && ($0.tone == .danger || $0.tone == .warning) }),
           let detail = priorityContext.detail.nilIfBlank {
            return detail
        }

        return nil
    }

    private func stitchedSummary(from fragments: [String]) -> String {
        var uniqueFragments: [String] = []
        var seen = Set<String>()

        for fragment in fragments {
            let normalized = fragment
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

            guard !normalized.isEmpty else { continue }

            let key = normalized.lowercased()
            if seen.insert(key).inserted {
                uniqueFragments.append(normalized)
            }
        }

        let combined = uniqueFragments.joined(separator: " ")
        guard combined.count > 360 else {
            return combined
        }

        let clippedIndex = combined.index(combined.startIndex, offsetBy: 360)
        return String(combined[..<clippedIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func presentationSummary(
        _ summary: String,
        for situationSnapshot: AssistantSituationSnapshot?
    ) -> String {
        guard let situationSnapshot else {
            return summary
        }

        switch situationSnapshot.mode {
        case .crisis:
            return compressedSummary(summary, maxSentences: 1, maxCharacters: 170)
        case .elevated:
            return compressedSummary(summary, maxSentences: 2, maxCharacters: 240)
        case .prep, .normal:
            return summary
        }
    }

    private func compressedSummary(
        _ summary: String,
        maxSentences: Int,
        maxCharacters: Int
    ) -> String {
        let normalized = summary
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        let sentenceMatches = normalized.matches(of: /[^.!?]+[.!?]?/)
        let trimmedSentences = sentenceMatches
            .map { String($0.output).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let candidate = trimmedSentences.isEmpty
            ? normalized
            : trimmedSentences.prefix(maxSentences).joined(separator: " ")

        guard candidate.count > maxCharacters else {
            return candidate
        }

        let cutoff = candidate.index(candidate.startIndex, offsetBy: maxCharacters)
        return String(candidate[..<cutoff]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func prioritizedSteps(
        _ steps: [String],
        classification: AssistantIntentClassification,
        situationSnapshot: AssistantSituationSnapshot
    ) -> [String] {
        steps
            .enumerated()
            .sorted { lhs, rhs in
                let lhsPriority = stepPriority(
                    lhs.element,
                    classification: classification,
                    situationSnapshot: situationSnapshot
                )
                let rhsPriority = stepPriority(
                    rhs.element,
                    classification: classification,
                    situationSnapshot: situationSnapshot
                )

                if lhsPriority == rhsPriority {
                    return lhs.offset < rhs.offset
                }

                return lhsPriority > rhsPriority
            }
            .map(\.element)
    }

    private func contextualizedSteps(
        _ steps: [String],
        classification: AssistantIntentClassification,
        situationSnapshot: AssistantSituationSnapshot,
        advisorContextStatus: AdvisorContextStatus,
        recentActionHint: AssistantRecentActionHint?
    ) -> [String] {
        var usedDependentRewrite = false
        var usedRouteRewrite = false

        return steps.map { step in
            let normalized = step.normalizedForAssistantMatching()

            if !usedDependentRewrite,
               situationSnapshot.hasDependents,
               isPackOrEssentialsStep(normalized),
               !isDependentsStep(normalized) {
                usedDependentRewrite = true
                return "Pack medicines, water, documents, and items for children or pets before optional gear."
            }

            if !usedRouteRewrite,
               isDirectRouteDecisionStep(normalized),
               let routeStep = contextualizedRouteStep(
                   originalStep: step,
                   normalizedStep: normalized,
                   classification: classification,
                   situationSnapshot: situationSnapshot,
                   advisorContextStatus: advisorContextStatus,
                   recentActionHint: recentActionHint
               ) {
                usedRouteRewrite = true
                return routeStep
            }

            return step
        }
    }

    private func contextualizedRouteStep(
        originalStep: String,
        normalizedStep: String,
        classification _: AssistantIntentClassification,
        situationSnapshot: AssistantSituationSnapshot,
        advisorContextStatus: AdvisorContextStatus,
        recentActionHint: AssistantRecentActionHint?
    ) -> String? {
        guard let routeStatus = situationSnapshot.routeStatus else {
            return nil
        }

        let confidence = phrasingConfidence(
            for: situationSnapshot,
            advisorContextStatus: advisorContextStatus
        )
        let keepsContact = normalizedStep.contains("contact")
        let routeInstruction: String

        if recentActionHint == .reviewedRoute {
            switch routeStatus {
            case .blocked:
                routeInstruction = "Use the highlighted alternative route and avoid blocked or closed roads"
            case .atRisk:
                switch confidence {
                case .assertive:
                    routeInstruction = "Use the highlighted route and avoid low-visibility or blocked roads"
                case .guarded:
                    routeInstruction = "Use the highlighted route carefully and keep checking conditions before you move"
                }
            case .clear:
                routeInstruction = "Use the highlighted route and keep checking conditions as you move"
            }
        } else if situationSnapshot.mode == .crisis || situationSnapshot.mode == .elevated {
            switch routeStatus {
            case .blocked:
                routeInstruction = confidence == .assertive
                    ? "Check the safest alternative route before you leave"
                    : "Prepare an alternative route before you leave"
            case .atRisk:
                routeInstruction = confidence == .assertive
                    ? "Check the safest available route before you leave"
                    : "Prepare a safe alternative route before you leave"
            case .clear:
                return nil
            }
        } else {
            return nil
        }

        if keepsContact {
            return "\(routeInstruction), then tell your contact once you are safe."
        }

        return routeInstruction + "."
    }

    private func stepPriority(
        _ step: String,
        classification: AssistantIntentClassification,
        situationSnapshot: AssistantSituationSnapshot
    ) -> Int {
        let normalized = step.normalizedForAssistantMatching()
        var priority = 0

        if situationSnapshot.mode == .crisis {
            if isImmediateDepartureStep(normalized) {
                priority += 260
            }

            if isMovementStep(normalized) {
                priority += 320
            }

            if isImmediateSafetyStep(normalized) {
                priority += 170
            }
        } else if situationSnapshot.mode == .elevated {
            if isMovementStep(normalized) {
                priority += 80
            }
        }

        if situationSnapshot.hasDependents, isDependentsStep(normalized) {
            priority += situationSnapshot.mode == .crisis ? 240 : 110
        }

        if let routeStatus = situationSnapshot.routeStatus {
            switch routeStatus {
            case .blocked:
                if isRouteStep(normalized) {
                    priority += situationSnapshot.mode == .crisis ? 135 : 200
                }
            case .atRisk:
                if isRouteStep(normalized) {
                    priority += situationSnapshot.mode == .crisis ? 110 : 140
                }
            case .clear:
                break
            }
        }

        switch classification.topic {
        case .routePlanning:
            if isRouteStep(normalized) {
                priority += 90
            }
        case .preparednessPlanning:
            if isDependentsStep(normalized) {
                priority += 45
            }
        case .fieldComms:
            if normalized.contains("contact") || normalized.contains("signal") {
                priority += 60
            }
        default:
            break
        }

        if normalized.contains("low priority") || normalized.contains("optional") {
            priority -= 120
        }

        return priority
    }

    private func compressedStep(
        _ step: String,
        for mode: AssistantSituationMode
    ) -> String {
        let normalized = step
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        guard mode == .crisis else {
            return normalized
        }

        let sentenceMatches = normalized.matches(of: /[^.!?]+[.!?]?/)
        let trimmedSentences = sentenceMatches
            .map { String($0.output).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if trimmedSentences.count > 1, let firstSentence = trimmedSentences.first {
            return firstSentence
        }

        guard normalized.count > 110 else {
            return normalized
        }

        return normalized
    }

    private func hazardLead(
        proximityPhrase: String,
        severityText: String,
        hazardTitle: String,
        confidence: SnapshotPhrasingConfidence
    ) -> String {
        let base = "A recent \(severityText) for \(hazardTitle.lowercased()) \(proximityPhrase)"

        switch confidence {
        case .assertive:
            return "\(base), so focus on the next immediate safety step."
        case .guarded:
            return "\(base), so prepare to move if conditions worsen."
        }
    }

    private func phrasingConfidence(
        for situationSnapshot: AssistantSituationSnapshot,
        advisorContextStatus: AdvisorContextStatus
    ) -> SnapshotPhrasingConfidence {
        guard situationSnapshot.hasEnvironmentalHazard else {
            return .assertive
        }

        let freshnessMinutes = advisorContextStatus.freshnessMinutes ?? situationSnapshot.lastSyncMinutes ?? .max

        if freshnessMinutes <= 30 {
            return .assertive
        }

        return .guarded
    }

    private func isMovementStep(_ step: String) -> Bool {
        step.containsAnyAssistantKeyword([
            "leave",
            "leaving",
            "evac",
            "move",
            "get out",
            "higher ground",
            "safe location",
            "planned route"
        ])
    }

    private func isImmediateDepartureStep(_ step: String) -> Bool {
        step.containsAnyAssistantKeyword([
            "leave now",
            "leave early",
            "evacuate now",
            "depart now",
            "get out now",
            "move now"
        ])
    }

    private func isImmediateSafetyStep(_ step: String) -> Bool {
        step.containsAnyAssistantKeyword([
            "call",
            "do not",
            "dont",
            "wait",
            "apply",
            "cool",
            "keep still",
            "switch to",
            "follow official",
            "seek"
        ])
    }

    private func isDependentsStep(_ step: String) -> Bool {
        step.containsAnyAssistantKeyword([
            "people",
            "child",
            "children",
            "baby",
            "pets",
            "medic",
            "inhaler",
            "comfort",
            "family"
        ])
    }

    private func isPackOrEssentialsStep(_ step: String) -> Bool {
        step.containsAnyAssistantKeyword([
            "pack",
            "load",
            "go bag",
            "go bags",
            "grab bag",
            "grab",
            "essential",
            "essentials",
            "document",
            "documents"
        ])
    }

    private func isRouteStep(_ step: String) -> Bool {
        step.containsAnyAssistantKeyword([
            "route",
            "road",
            "crossing",
            "alternate",
            "safe location",
            "shelter",
            "high ground",
            "hospital"
        ])
    }

    private func isDirectRouteDecisionStep(_ step: String) -> Bool {
        guard isRouteStep(step) else {
            return false
        }

        return step.containsAnyAssistantKeyword([
            "use the planned route",
            "check the route",
            "review the main route",
            "alternate",
            "before departure",
            "before leaving"
        ])
    }
}

private enum SnapshotPhrasingConfidence {
    case assertive
    case guarded
}

private extension String {
    func normalizedForAssistantMatching() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    func containsAnyAssistantKeyword(_ keywords: [String]) -> Bool {
        keywords.contains { contains($0) }
    }

    func appendingPeriodIfNeeded() -> String {
        guard !isEmpty else {
            return self
        }

        if hasSuffix(".") || hasSuffix("!") || hasSuffix("?") {
            return self
        }

        return self + "."
    }
}
