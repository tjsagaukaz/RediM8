import Foundation

final class AssistantIntentClassifier {
    private struct EvaluatedMatch {
        let classification: AssistantIntentClassification
        let minimumConfidence: Double
    }

    private struct Rule {
        let policy: AssistantPolicy
        let normalizedPhrases: [String]
        let tokenGroups: [Set<String>]

        init(policy: AssistantPolicy) {
            self.policy = policy
            normalizedPhrases = policy.matchPhrases.map(AssistantIntentClassifier.normalize)
            tokenGroups = policy.tokenGroups.map { Set($0.map(AssistantIntentClassifier.normalize)) }
        }

        func evaluate(normalizedQuery: String, tokens: Set<String>) -> EvaluatedMatch? {
            var matchedTerms = Set<String>()
            var score = 0.0

            for phrase in normalizedPhrases where normalizedQuery.contains(phrase) {
                matchedTerms.insert(phrase)
                score += phrase.contains(" ") ? 2.8 : 1.8
            }

            for tokenGroup in tokenGroups where tokenGroup.isSubset(of: tokens) {
                matchedTerms.insert(tokenGroup.sorted().joined(separator: " "))
                score += Double(max(tokenGroup.count, 2))
            }

            guard !matchedTerms.isEmpty else {
                return nil
            }

            let confidence = min(0.98, policy.baseConfidence + min(score, 5.0) * 0.07)
            let classification = AssistantIntentClassification(
                policyID: policy.id,
                topic: policy.intent,
                riskBand: policy.riskBand,
                preferredMode: policy.answerMode,
                modeWhenGenerationDisabled: policy.fallbackMode,
                matchedGuideIDs: policy.guideIDs,
                matchedTerms: matchedTerms.sorted(),
                trustLabel: policy.trustLabel,
                lastReviewed: policy.lastReviewed,
                regionScope: policy.regionScope,
                confidence: confidence,
                escalationNote: policy.escalationNote
            )

            return EvaluatedMatch(
                classification: classification,
                minimumConfidence: policy.minimumConfidence
            )
        }
    }

    private struct IndexedGuide {
        let guide: Guide
        let titleTokens: Set<String>
        let bodyTokens: Set<String>
        let normalizedTitle: String
    }

    private let guideService: GuideService
    private let indexedGuides: [IndexedGuide]
    private let rules: [Rule]

    init(policies: [AssistantPolicy], guideService: GuideService) {
        self.guideService = guideService
        indexedGuides = guideService.allGuides().map(Self.indexedGuide(for:))
        rules = policies.map(Rule.init)
    }

    convenience init(dataService: PreparednessDataService, guideService: GuideService) {
        self.init(policies: dataService.assistantPolicies(), guideService: guideService)
    }

    convenience init(bundle: Bundle = .main) {
        let dataService = PreparednessDataService(store: nil, bundle: bundle)
        let guideService = GuideService(dataService: dataService)
        self.init(dataService: dataService, guideService: guideService)
    }

    func classify(_ query: String) -> AssistantIntentClassification {
        let normalizedQuery = Self.normalize(query)
        let tokens = Set(Self.tokens(in: normalizedQuery)).subtracting(Self.stopWords)

        guard !normalizedQuery.isEmpty, !tokens.isEmpty else {
            return AssistantIntentClassification(
                policyID: nil,
                topic: .unknown,
                riskBand: .unknown,
                preferredMode: .guideFallback,
                modeWhenGenerationDisabled: .guideFallback,
                matchedGuideIDs: [],
                matchedTerms: [],
                trustLabel: nil,
                lastReviewed: nil,
                regionScope: nil,
                confidence: 0.0,
                escalationNote: nil
            )
        }

        let matches = rules.compactMap { $0.evaluate(normalizedQuery: normalizedQuery, tokens: tokens) }
            .sorted { lhs, rhs in
                if lhs.classification.confidence != rhs.classification.confidence {
                    return lhs.classification.confidence > rhs.classification.confidence
                }
                return Self.riskPriority(lhs.classification.riskBand) > Self.riskPriority(rhs.classification.riskBand)
            }

        if let bestMatch = matches.first,
           bestMatch.classification.confidence >= bestMatch.minimumConfidence {
            return bestMatch.classification
        }

        let fallbackGuides = closestGuideIDs(for: normalizedQuery, tokens: tokens, limit: 3)
        let confidence = fallbackGuides.isEmpty ? 0.18 : 0.38

        return AssistantIntentClassification(
            policyID: nil,
            topic: .unknown,
            riskBand: .unknown,
            preferredMode: .guideFallback,
            modeWhenGenerationDisabled: .guideFallback,
            matchedGuideIDs: fallbackGuides,
            matchedTerms: [],
            trustLabel: nil,
            lastReviewed: nil,
            regionScope: nil,
            confidence: confidence,
            escalationNote: nil
        )
    }

    func matchedGuides(for classification: AssistantIntentClassification) -> [Guide] {
        guideService.guides(ids: classification.matchedGuideIDs)
    }

    private func closestGuideIDs(for normalizedQuery: String, tokens: Set<String>, limit: Int) -> [String] {
        indexedGuides
            .map { entry in
                let titleOverlap = Double(tokens.intersection(entry.titleTokens).count)
                let bodyOverlap = Double(tokens.intersection(entry.bodyTokens).count)
                let titlePhraseBoost = normalizedQuery.contains(entry.normalizedTitle) ? 8.0 : 0.0
                let score = titleOverlap * 3.0 + bodyOverlap * 1.15 + titlePhraseBoost
                return (entry.guide.id, score)
            }
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }
                return lhs.0 < rhs.0
            }
            .prefix(limit)
            .map(\.0)
    }

    private static func indexedGuide(for guide: Guide) -> IndexedGuide {
        let normalizedTitle = normalize(guide.title)
        let titleTokens = Set(tokens(in: normalizedTitle)).subtracting(stopWords)
        let body = normalize(([guide.summary, guide.notes] + guide.steps).joined(separator: " "))
        let bodyTokens = Set(tokens(in: body)).subtracting(stopWords)

        return IndexedGuide(
            guide: guide,
            titleTokens: titleTokens,
            bodyTokens: bodyTokens.union(titleTokens),
            normalizedTitle: normalizedTitle
        )
    }

    static func normalize(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        let scalars = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : " "
        }

        return String(scalars)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokens(in normalizedValue: String) -> [String] {
        normalizedValue
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func riskPriority(_ riskBand: AssistantIntentRiskBand) -> Int {
        switch riskBand {
        case .critical:
            3
        case .advisory:
            2
        case .unknown:
            1
        }
    }

    private static let stopWords: Set<String> = [
        "a", "an", "and", "are", "at", "can", "do", "for", "from", "how", "i", "if", "in",
        "is", "it", "me", "my", "of", "on", "or", "should", "the", "to", "what", "when",
        "with", "you", "your"
    ]
}
