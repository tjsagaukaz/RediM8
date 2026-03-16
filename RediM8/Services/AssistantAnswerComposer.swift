import Foundation

final class AssistantAnswerComposer {
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
        contextSections: [AssistantContextSection] = []
    ) -> AssistantResponse {
        let relatedGuides = guides
        let sourceSummary = composeSourceSummary(from: relatedGuides)
        let lastReviewedSummary = composeLastReviewedSummary(classification: classification, guides: relatedGuides)
        let regionSummary = composeRegionSummary(classification: classification, guides: relatedGuides)

        guard let primaryGuide = relatedGuides.first else {
            return AssistantResponse(
                query: query,
                title: "Closest Offline References",
                topic: classification.topic,
                confidence: classification.confidence,
                riskBand: classification.riskBand,
                trustLabel: classification.trustLabel,
                answerMode: .guideFallback,
                sourceMode: .fallback,
                summary: "RediM8 could not safely classify that question into a trusted survival workflow. Try a more specific search, or open a nearby guide directly.",
                steps: [],
                escalationNote: classification.escalationNote,
                relatedGuides: [],
                sourceSummary: "Bundled offline references",
                lastReviewedSummary: "Bundled offline references",
                regionSummary: classification.regionScope?.title ?? GuideRegionScope.general.title,
                fallbackExplanation: "No guide match was strong enough to compose advice.",
                interpretationNote: interpretationNote,
                contextSections: contextSections
            )
        }

        let effectiveMode = resolvedAnswerMode(
            for: classification,
            allowsSafeSummaries: allowsSafeSummaries
        )

        switch effectiveMode {
        case .deterministicStepCard:
            return AssistantResponse(
                query: query,
                title: primaryGuide.title,
                topic: classification.topic,
                confidence: classification.confidence,
                riskBand: classification.riskBand,
                trustLabel: classification.trustLabel,
                answerMode: effectiveMode,
                sourceMode: .deterministic,
                summary: primaryGuide.summary,
                steps: primaryGuide.steps,
                safetyNotes: primaryGuide.notes.nilIfBlank.map { [$0] } ?? [],
                escalationNote: classification.escalationNote,
                relatedGuides: relatedGuides,
                sourceSummary: sourceSummary,
                lastReviewedSummary: lastReviewedSummary,
                regionSummary: regionSummary,
                interpretationNote: interpretationNote,
                contextSections: contextSections
            )
        case .summarizedRetrieval:
            let summary = summarizer.summarize(
                guides: relatedGuides,
                classification: classification,
                offlineModel: offlineModel,
                safetyFilter: safetyFilter
            )
            return AssistantResponse(
                query: query,
                title: primaryGuide.title,
                topic: classification.topic,
                confidence: classification.confidence,
                riskBand: classification.riskBand,
                trustLabel: classification.trustLabel,
                answerMode: effectiveMode,
                sourceMode: .summarized,
                summary: summary.summary,
                steps: summary.steps,
                safetyNotes: summary.safetyNotes,
                escalationNote: classification.escalationNote,
                relatedGuides: relatedGuides,
                sourceSummary: summary.usedOfflineModel ? "\(sourceSummary) + on-device AI clarification" : sourceSummary,
                lastReviewedSummary: lastReviewedSummary,
                regionSummary: regionSummary,
                interpretationNote: interpretationNote,
                usedOfflineModel: summary.usedOfflineModel,
                contextSections: contextSections
            )
        case .retrievalOnlyCard, .guideFallback:
            let fallbackExplanation: String
            if classification.topic == .unknown {
                fallbackExplanation = "RediM8 did not find a strong trusted intent match, so it is showing the closest offline guides instead of guessing."
            } else {
                fallbackExplanation = "Safe summaries are not being used for this answer, so RediM8 is showing direct guide retrieval."
            }

            return AssistantResponse(
                query: query,
                title: primaryGuide.title,
                topic: classification.topic,
                confidence: classification.confidence,
                riskBand: classification.riskBand,
                trustLabel: classification.trustLabel,
                answerMode: effectiveMode,
                sourceMode: classification.topic == .unknown ? .fallback : .retrievalOnly,
                summary: classification.topic == .unknown
                    ? "These are the closest bundled guides for your question. Open one to review the full offline steps."
                    : primaryGuide.summary,
                steps: classification.topic == .unknown ? [] : Array(primaryGuide.steps.prefix(4)),
                safetyNotes: primaryGuide.notes.nilIfBlank.map { [$0] } ?? [],
                escalationNote: classification.escalationNote,
                relatedGuides: relatedGuides,
                sourceSummary: sourceSummary,
                lastReviewedSummary: lastReviewedSummary,
                regionSummary: regionSummary,
                fallbackExplanation: fallbackExplanation,
                interpretationNote: interpretationNote,
                contextSections: contextSections
            )
        }
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
}
