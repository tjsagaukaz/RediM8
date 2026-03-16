import Foundation

final class AssistantSafetyFilter {
    private enum Limits {
        static let maximumSummaryCharacters = 320
        static let maximumNovelTokenRatio = 0.4
    }

    private static let stopWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "by", "do", "for", "from", "if", "in",
        "into", "is", "it", "of", "on", "or", "that", "the", "then", "to", "use", "with",
        "guide", "pick"
    ]

    private static let unsafeNovelTokens: Set<String> = [
        "antibiotic", "bleach", "cut", "dose", "inject", "medicine", "remove",
        "suck", "tablet", "tourniquet"
    ]

    func filteredSummary(_ candidate: String, sourceText: String) -> String? {
        let normalized = candidate
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let normalized = normalized.nilIfBlank else {
            return nil
        }

        guard !containsStructuredSteps(normalized) else {
            return nil
        }

        let sourceTokens = Set(tokens(in: sourceText))
        let candidateTokens = tokens(in: normalized).filter { !Self.stopWords.contains($0) }
        guard !candidateTokens.isEmpty else {
            return nil
        }

        let novelTokens = candidateTokens.filter { !sourceTokens.contains($0) }
        let novelRatio = Double(novelTokens.count) / Double(candidateTokens.count)
        guard novelRatio <= Limits.maximumNovelTokenRatio else {
            return nil
        }

        guard Set(novelTokens).isDisjoint(with: Self.unsafeNovelTokens) else {
            return nil
        }

        if normalized.count > Limits.maximumSummaryCharacters {
            let index = normalized.index(normalized.startIndex, offsetBy: Limits.maximumSummaryCharacters)
            return String(normalized[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }

        return normalized
    }

    func filteredInterpretation(_ candidate: String, classifier: AssistantIntentClassifier) -> String? {
        let normalized = AssistantIntentClassifier.normalize(candidate)
        guard let normalized = normalized.nilIfBlank else {
            return nil
        }

        let tokens = normalized.split(separator: " ").map(String.init)
        guard (1 ... 6).contains(tokens.count) else {
            return nil
        }

        let classification = classifier.classify(normalized)
        guard classification.topic != .unknown else {
            return nil
        }

        return normalized
    }

    private func containsStructuredSteps(_ value: String) -> Bool {
        let lowered = value.lowercased()
        return lowered.contains("step 1")
            || lowered.contains("1.")
            || lowered.contains("2.")
            || lowered.contains("•")
            || lowered.contains("- ")
    }

    private func tokens(in value: String) -> [String] {
        AssistantIntentClassifier.normalize(value)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
