import Foundation

final class AssistantService {
    private let classifier: AssistantIntentClassifier
    private let guideService: GuideService
    private let composer: AssistantAnswerComposer
    private let assistantModel: (any OfflineAssistantModeling)?
    private let safetyFilter: AssistantSafetyFilter
    private let contextProvider: (any AssistantContextProviding)?

    init(
        classifier: AssistantIntentClassifier,
        guideService: GuideService,
        composer: AssistantAnswerComposer,
        assistantModel: (any OfflineAssistantModeling)? = nil,
        safetyFilter: AssistantSafetyFilter = AssistantSafetyFilter(),
        contextProvider: (any AssistantContextProviding)? = nil
    ) {
        self.classifier = classifier
        self.guideService = guideService
        self.composer = composer
        self.assistantModel = assistantModel
        self.safetyFilter = safetyFilter
        self.contextProvider = contextProvider
    }

    @MainActor
    func ask(_ query: String, allowsSafeSummaries: Bool = true) -> AssistantResponse {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedRouting = resolvedClassification(for: trimmedQuery, allowsSafeSummaries: allowsSafeSummaries)
        let matchedGuides = resolvedGuides(for: resolvedRouting.classification, query: resolvedRouting.routingQuery)
        let contextSections = contextProvider?.contextSections(
            for: trimmedQuery,
            classification: resolvedRouting.classification
        ) ?? []

        return composer.compose(
            query: trimmedQuery,
            classification: resolvedRouting.classification,
            guides: matchedGuides,
            allowsSafeSummaries: allowsSafeSummaries,
            offlineModel: allowsSafeSummaries ? assistantModel : nil,
            safetyFilter: safetyFilter,
            interpretationNote: resolvedRouting.interpretationNote,
            contextSections: contextSections
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
        query: String
    ) -> [Guide] {
        let policyGuides = classifier.matchedGuides(for: classification)
        if !policyGuides.isEmpty {
            return policyGuides
        }

        let fallbackGuides = guideService.searchGuides(query: query)
        guard !fallbackGuides.isEmpty else {
            return []
        }

        return Array(fallbackGuides.prefix(3))
    }
}
