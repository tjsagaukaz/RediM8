import Foundation

// MARK: - Assistant Session State

/// Lightweight in-memory session state for the assistant.
/// Enables multi-turn context: "what now", "next step", "keep going".
/// NOT persisted to disk. Cleared on app restart.
final class AssistantSessionState: @unchecked Sendable {
    struct ClarificationResolution {
        let routingTerms: String
        let note: String
    }

    private(set) var lastClassification: AssistantIntentClassification?
    private(set) var lastGuideIDs: [String] = []
    private(set) var lastRiskState: SurvivalContextState?
    private(set) var lastSituationSnapshot: AssistantSituationSnapshot?
    private(set) var lastQuery: String?
    private(set) var pendingQuestion: AssistantClarifyingQuestion?
    private(set) var operationalIntent: AssistantOperationalIntent?
    private(set) var recentActionHint: AssistantRecentActionHint?
    private(set) var turnCount: Int = 0

    /// Records state from a completed assistant turn.
    func record(
        query: String,
        classification: AssistantIntentClassification,
        guideIDs: [String],
        riskState: SurvivalContextState? = nil,
        situationSnapshot: AssistantSituationSnapshot? = nil,
        pendingQuestion: AssistantClarifyingQuestion? = nil
    ) {
        lastQuery = query
        lastClassification = classification
        lastGuideIDs = guideIDs
        lastRiskState = riskState
        lastSituationSnapshot = situationSnapshot
        self.pendingQuestion = pendingQuestion
        turnCount += 1
    }

    /// Whether the session has prior context to draw from.
    var hasContext: Bool {
        lastClassification != nil
    }

    /// The most recent topic the user was asking about.
    var lastTopic: AssistantIntentTopic? {
        lastClassification?.topic
    }

    /// Resets session state (e.g., when user explicitly starts fresh).
    func reset() {
        lastClassification = nil
        lastGuideIDs = []
        lastRiskState = nil
        lastSituationSnapshot = nil
        lastQuery = nil
        pendingQuestion = nil
        operationalIntent = nil
        recentActionHint = nil
        turnCount = 0
    }

    func noteContextAction(_ action: AssistantContextAction) {
        switch action {
        case .openMap, .navigateToCoordinate:
            recentActionHint = .reviewedRoute
        case let .openTab(tab):
            if tab.lowercased() == "map" {
                recentActionHint = .reviewedRoute
            }
        case .openGuide, .openPlanFocus, .callNumber:
            break
        }
    }

    func actionHint(
        for classification: AssistantIntentClassification,
        snapshot: AssistantSituationSnapshot?
    ) -> AssistantRecentActionHint? {
        guard let recentActionHint else {
            return nil
        }

        switch recentActionHint {
        case .reviewedRoute:
            if snapshot?.routeStatus != nil {
                return recentActionHint
            }

            switch classification.topic {
            case .bushfireEvacuation, .floodSafety, .routePlanning, .vehicleSurvival:
                return recentActionHint
            default:
                return nil
            }
        }
    }

    func clearRecentActionHint() {
        recentActionHint = nil
    }

    func applyOperationalIntent(
        to snapshot: AssistantSituationSnapshot?,
        classification: AssistantIntentClassification
    ) -> AssistantSituationSnapshot? {
        guard let operationalIntent else {
            return snapshot
        }

        if snapshot == nil, operationalIntent == .planningAhead {
            return AssistantSituationSnapshot(
                hazard: nil,
                severity: nil,
                proximity: .unknown,
                mode: .prep,
                routeStatus: nil,
                lastSyncMinutes: nil,
                hasDependents: false,
                operationalIntent: .planningAhead
            )
        }

        switch classification.topic {
        case .bushfireEvacuation,
             .floodSafety,
             .routePlanning,
             .preparednessPlanning,
             .waterPlanning,
             .fieldComms,
             .vehicleSurvival,
             .unknown:
            return snapshot?.with(operationalIntent: operationalIntent)
        default:
            return snapshot
        }
    }

    func consumeClarificationIfPossible(_ query: String) -> ClarificationResolution? {
        guard let pendingQuestion else {
            return nil
        }

        let normalizedQuery = AssistantIntentClassifier.normalize(query)

        switch pendingQuestion.kind {
        case .entryDirection:
            if isEmergencyDirectionAnswer(normalizedQuery) {
                operationalIntent = .stayingPut
                self.pendingQuestion = nil
                return ClarificationResolution(
                    routingTerms: "current emergency what should i do right now",
                    note: "Using your update that you need help with an active situation."
                )
            }

            if isPlanningAnswer(normalizedQuery) {
                operationalIntent = .planningAhead
                self.pendingQuestion = nil
                return ClarificationResolution(
                    routingTerms: "home emergency basics planning ahead preparation",
                    note: "Using your update that you are planning ahead."
                )
            }

            if isNavigationDirectionAnswer(normalizedQuery) {
                self.pendingQuestion = nil
                return ClarificationResolution(
                    routingTerms: "route planning navigate without gps",
                    note: "Using your update that you need navigation guidance."
                )
            }

        case .movementIntent:
            if isLeavingAnswer(normalizedQuery) {
                operationalIntent = .leavingNow
                self.pendingQuestion = nil
                return ClarificationResolution(
                    routingTerms: "leaving now evacuation",
                    note: "Using your update that you are leaving now."
                )
            }

            if isStayingAnswer(normalizedQuery) {
                operationalIntent = .stayingPut
                self.pendingQuestion = nil
                return ClarificationResolution(
                    routingTerms: "staying put shelter in place",
                    note: "Using your update that you are staying for the moment."
                )
            }

        case .currentSituation:
            if isPlanningAnswer(normalizedQuery) {
                operationalIntent = .planningAhead
                self.pendingQuestion = nil
                return ClarificationResolution(
                    routingTerms: "home emergency basics planning ahead preparation",
                    note: "Using your update that this is planning ahead."
                )
            }

            if isCurrentSituationAnswer(normalizedQuery) {
                operationalIntent = .stayingPut
                self.pendingQuestion = nil
                return ClarificationResolution(
                    routingTerms: "current situation right now",
                    note: "Using your update that this is happening right now."
                )
            }
        }

        return nil
    }

    // MARK: - Follow-Up Detection

    /// Detects whether a query is a follow-up to the previous turn.
    /// Follow-ups inherit the previous classification's topic and guides.
    func isFollowUp(_ normalizedQuery: String) -> Bool {
        guard hasContext else { return false }

        let followUpPhrases: Set<String> = [
            "what now",
            "what next",
            "next step",
            "keep going",
            "continue",
            "then what",
            "what else",
            "more detail",
            "tell me more",
            "go on",
            "what should i do now",
            "what do i do next",
            "and then",
            "ok now what",
            "ok what next",
        ]

        for phrase in followUpPhrases where normalizedQuery.contains(phrase) {
            return true
        }

        // Very short queries after context are likely follow-ups
        let wordCount = normalizedQuery.split(separator: " ").count
        if wordCount <= 3 && hasContext {
            let shortFollowUps: Set<String> = [
                "now what", "next", "more", "go", "continue", "how",
                "ok", "then", "step 2", "step 3", "step 4", "step 5",
            ]
            for phrase in shortFollowUps where normalizedQuery.contains(phrase) {
                return true
            }
        }

        return false
    }

    /// Builds a classification for a follow-up query using the previous turn's context.
    func followUpClassification() -> AssistantIntentClassification? {
        guard let last = lastClassification else { return nil }

        return AssistantIntentClassification(
            policyID: last.policyID,
            topic: last.topic,
            riskBand: last.riskBand,
            preferredMode: last.preferredMode,
            modeWhenGenerationDisabled: last.modeWhenGenerationDisabled,
            matchedGuideIDs: lastGuideIDs,
            matchedTerms: last.matchedTerms,
            trustLabel: last.trustLabel,
            lastReviewed: last.lastReviewed,
            regionScope: last.regionScope,
            confidence: max(last.confidence, 0.70),
            escalationNote: last.escalationNote
        )
    }

    private func isLeavingAnswer(_ normalizedQuery: String) -> Bool {
        normalizedQuery == "leaving"
            || normalizedQuery == "leave"
            || normalizedQuery == "leaving now"
            || normalizedQuery == "leave now"
            || normalizedQuery == "evacuating"
            || normalizedQuery == "evacuating now"
    }

    private func isStayingAnswer(_ normalizedQuery: String) -> Bool {
        normalizedQuery == "staying"
            || normalizedQuery == "staying put"
            || normalizedQuery == "stay"
            || normalizedQuery == "staying for now"
            || normalizedQuery == "sheltering"
            || normalizedQuery == "sheltering in place"
    }

    private func isPlanningAnswer(_ normalizedQuery: String) -> Bool {
        normalizedQuery == "planning"
            || normalizedQuery == "planning ahead"
            || normalizedQuery == "prep"
            || normalizedQuery == "preparing"
    }

    private func isEmergencyDirectionAnswer(_ normalizedQuery: String) -> Bool {
        normalizedQuery == "emergency right now"
            || normalizedQuery == "current emergency"
            || normalizedQuery == "emergency help"
            || normalizedQuery == "help right now"
    }

    private func isNavigationDirectionAnswer(_ normalizedQuery: String) -> Bool {
        normalizedQuery == "navigation help"
            || normalizedQuery == "route help"
            || normalizedQuery == "map help"
            || normalizedQuery == "navigation"
    }

    private func isCurrentSituationAnswer(_ normalizedQuery: String) -> Bool {
        normalizedQuery == "right now"
            || normalizedQuery == "current"
            || normalizedQuery == "current situation"
            || normalizedQuery == "now"
            || normalizedQuery == "active situation"
    }
}
