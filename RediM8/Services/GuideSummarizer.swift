import Foundation

struct GuideSummaryResult: Equatable {
    let summary: String
    let steps: [String]
    let safetyNotes: [String]
    let usedOfflineModel: Bool
}

final class GuideSummarizer {
    private enum Limits {
        static let maximumSummaryLength = 320
        static let maximumSteps = 4
        static let maximumSafetyNotes = 3
    }

    func summarize(
        guides: [Guide],
        classification: AssistantIntentClassification,
        offlineModel: (any OfflineAssistantModeling)? = nil,
        safetyFilter: AssistantSafetyFilter? = nil
    ) -> GuideSummaryResult {
        guard let primaryGuide = guides.first else {
            return GuideSummaryResult(
                summary: "RediM8 could not load a bundled guide for this question, so no summary was created.",
                steps: [],
                safetyNotes: [],
                usedOfflineModel: false
            )
        }

        let supportingGuides = Array(guides.dropFirst())
        let fallbackSummary = buildSummary(primaryGuide: primaryGuide, supportingGuides: supportingGuides)
        let steps = condensedSteps(from: primaryGuide)
        let safetyNotes = preservedSafetyNotes(from: guides)

        let modelSummaryInput = buildModelSummaryInput(primaryGuide: primaryGuide, supportingGuides: supportingGuides)
        let modelSummary = classification.riskBand == .critical ? nil : offlineModel?.summarize(text: modelSummaryInput)
        let acceptedModelSummary = modelSummary.flatMap { safetyFilter?.filteredSummary($0, sourceText: modelSummaryInput) }

        return GuideSummaryResult(
            summary: acceptedModelSummary ?? fallbackSummary,
            steps: steps,
            safetyNotes: safetyNotes,
            usedOfflineModel: acceptedModelSummary != nil
        )
    }

    private func buildSummary(primaryGuide: Guide, supportingGuides: [Guide]) -> String {
        var fragments = [primaryGuide.summary]

        if let supportingGuide = supportingGuides.first {
            fragments.append("Related offline guide: \(supportingGuide.title).")
        }

        if let shortNote = primaryGuide.notes.nilIfBlank {
            fragments.append(shortNote)
        }

        let combined = fragments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard combined.count > Limits.maximumSummaryLength else {
            return combined
        }

        let index = combined.index(combined.startIndex, offsetBy: Limits.maximumSummaryLength)
        return String(combined[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func buildModelSummaryInput(primaryGuide: Guide, supportingGuides: [Guide]) -> String {
        var fragments = [primaryGuide.summary]

        let sectionSummaries = primaryGuide.sections.compactMap(\.summary)
        fragments.append(contentsOf: sectionSummaries.prefix(2))

        if let nonWarningNote = primaryGuide.notes.nilIfBlank, !containsWarningLanguage(nonWarningNote) {
            fragments.append(nonWarningNote)
        }

        if let supportingGuide = supportingGuides.first {
            fragments.append("Related guide: \(supportingGuide.title). \(supportingGuide.summary)")
        }

        return fragments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func condensedSteps(from guide: Guide) -> [String] {
        Array(guide.steps.prefix(Limits.maximumSteps))
    }

    private func preservedSafetyNotes(from guides: [Guide]) -> [String] {
        var notes: [String] = []

        for guide in guides {
            if let note = guide.notes.nilIfBlank, containsWarningLanguage(note) {
                notes.append(note)
            }

            for step in guide.steps where containsWarningLanguage(step) {
                notes.append(step)
            }
        }

        var seen = Set<String>()
        return notes.filter { note in
            seen.insert(note).inserted
        }
        .prefix(Limits.maximumSafetyNotes)
        .map { $0 }
    }

    private func containsWarningLanguage(_ value: String) -> Bool {
        let normalized = value.lowercased()
        return normalized.contains("do not")
            || normalized.contains("don't")
            || normalized.contains("never")
            || normalized.contains("call emergency")
            || normalized.contains("urgent")
            || normalized.contains("seek medical")
            || normalized.contains("avoid")
    }
}
