import Foundation

// MARK: - Assistant Session State

/// Lightweight in-memory session state for the assistant.
/// Enables multi-turn context: "what now", "next step", "keep going".
/// NOT persisted to disk. Cleared on app restart.
final class AssistantSessionState: @unchecked Sendable {
    private(set) var lastClassification: AssistantIntentClassification?
    private(set) var lastGuideIDs: [String] = []
    private(set) var lastRiskState: SurvivalContextState?
    private(set) var lastQuery: String?
    private(set) var turnCount: Int = 0

    /// Records state from a completed assistant turn.
    func record(
        query: String,
        classification: AssistantIntentClassification,
        guideIDs: [String],
        riskState: SurvivalContextState? = nil
    ) {
        lastQuery = query
        lastClassification = classification
        lastGuideIDs = guideIDs
        lastRiskState = riskState
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
        lastQuery = nil
        turnCount = 0
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
}
