import Foundation

final class AssistantService {
    private let classifier: AssistantIntentClassifier
    private let guideService: GuideService
    private let composer: AssistantAnswerComposer
    private let assistantModel: (any OfflineAssistantModeling)?
    private let safetyFilter: AssistantSafetyFilter
    private let contextProvider: (any AssistantContextProviding)?
    let sessionState = AssistantSessionState()

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
        let normalizedQuery = AssistantIntentClassifier.normalize(trimmedQuery)

        // Check for follow-up queries that should inherit previous context
        let resolvedRouting: (classification: AssistantIntentClassification, routingQuery: String, interpretationNote: String?)
        if sessionState.isFollowUp(normalizedQuery),
           let followUp = sessionState.followUpClassification() {
            resolvedRouting = (followUp, trimmedQuery, "Continuing from your previous question.")
        } else {
            resolvedRouting = resolvedClassification(for: trimmedQuery, allowsSafeSummaries: allowsSafeSummaries)
        }

        let matchedGuides = resolvedGuides(for: resolvedRouting.classification, query: resolvedRouting.routingQuery)
        let contextSections = contextProvider?.contextSections(
            for: trimmedQuery,
            classification: resolvedRouting.classification
        ) ?? []

        let response = composer.compose(
            query: trimmedQuery,
            classification: resolvedRouting.classification,
            guides: matchedGuides,
            allowsSafeSummaries: allowsSafeSummaries,
            offlineModel: allowsSafeSummaries ? assistantModel : nil,
            safetyFilter: safetyFilter,
            interpretationNote: resolvedRouting.interpretationNote,
            contextSections: contextSections
        )

        // Record this turn for future follow-up detection
        sessionState.record(
            query: trimmedQuery,
            classification: resolvedRouting.classification,
            guideIDs: matchedGuides.map(\.id)
        )

        return response
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
            let primaryIDs = Set(policyGuides.map(\.id))
            let supportingGuides = supportingGuideIDs(for: classification.topic)
                .filter { !primaryIDs.contains($0) }
            let supporting = guideService.guides(ids: supportingGuides)
            return policyGuides + supporting
        }

        let fallbackGuides = guideService.searchGuides(query: query)
        guard !fallbackGuides.isEmpty else {
            return []
        }

        return Array(fallbackGuides.prefix(3))
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
}
