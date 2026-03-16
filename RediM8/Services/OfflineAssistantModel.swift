import CoreML
import Foundation

protocol OfflineAssistantModeling {
    var isAvailable: Bool { get }

    func summarize(text: String) -> String?
    func interpret(query: String) -> String?
}

protocol OfflineAssistantModelRuntime {
    var isAvailable: Bool { get }

    func generate(task: OfflineAssistantModel.Task, input: String, maxOutputTokens: Int) -> String?
}

final class OfflineAssistantModel: OfflineAssistantModeling {
    enum Task: String {
        case summarize
        case interpret
    }

    private enum Limits {
        static let maximumSummaryCharacters = 320
        static let maximumInterpretationTokens = 6
    }

    private let runtime: any OfflineAssistantModelRuntime

    init(bundle: Bundle = .main) {
        runtime = CoreMLAssistantModelRuntime(bundle: bundle)
    }

    init(runtime: any OfflineAssistantModelRuntime) {
        self.runtime = runtime
    }

    var isAvailable: Bool {
        runtime.isAvailable
    }

    func summarize(text: String) -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        guard let candidate = runtime.generate(task: .summarize, input: trimmedText, maxOutputTokens: 160) else {
            return nil
        }

        return Self.cleanedSummary(candidate, maximumCharacters: Limits.maximumSummaryCharacters)
    }

    func interpret(query: String) -> String? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return nil
        }

        guard let candidate = runtime.generate(task: .interpret, input: trimmedQuery, maxOutputTokens: 24) else {
            return nil
        }

        return Self.cleanedInterpretation(candidate, maximumTokens: Limits.maximumInterpretationTokens)
    }

    private static func cleanedSummary(_ value: String, maximumCharacters: Int) -> String? {
        let normalized = value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let normalized = normalized.nilIfBlank else {
            return nil
        }

        guard normalized.count > maximumCharacters else {
            return normalized
        }

        let limitIndex = normalized.index(normalized.startIndex, offsetBy: maximumCharacters)
        let clipped = String(normalized[..<limitIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        if let sentenceBoundary = clipped.lastIndex(of: ".") {
            let sentence = clipped[...sentenceBoundary].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                return sentence
            }
        }
        return clipped + "..."
    }

    private static func cleanedInterpretation(_ value: String, maximumTokens: Int) -> String? {
        let normalized = AssistantIntentClassifier.normalize(value)
        guard let normalized = normalized.nilIfBlank else {
            return nil
        }

        let tokens = normalized.split(separator: " ").map(String.init)
        guard !tokens.isEmpty, tokens.count <= maximumTokens else {
            return nil
        }

        return tokens.joined(separator: " ")
    }
}

private final class CoreMLAssistantModelRuntime: OfflineAssistantModelRuntime {
    private enum ModelSchema {
        static let candidateInputKeys = [
            ["task", "input_text", "max_output_tokens"],
            ["task", "text", "max_tokens"],
            ["prompt", "max_output_tokens"],
            ["text"]
        ]
        static let candidateOutputKeys = [
            "text",
            "output",
            "generated_text",
            "generatedText",
            "result"
        ]
    }

    private let bundle: Bundle
    private let configuration: MLModelConfiguration
    private lazy var model: MLModel? = loadModel()

    init(bundle: Bundle) {
        self.bundle = bundle
        configuration = MLModelConfiguration()
        configuration.computeUnits = .all
    }

    var isAvailable: Bool {
        model != nil
    }

    func generate(task: OfflineAssistantModel.Task, input: String, maxOutputTokens: Int) -> String? {
        guard let model else {
            return nil
        }

        let prompt = prompt(for: task, input: input)
        let requestCandidates: [[String: Any]] = [
            [
                "task": task.rawValue,
                "input_text": prompt,
                "max_output_tokens": maxOutputTokens
            ],
            [
                "task": task.rawValue,
                "text": prompt,
                "max_tokens": maxOutputTokens
            ],
            [
                "prompt": prompt,
                "max_output_tokens": maxOutputTokens
            ],
            [
                "text": prompt
            ]
        ]

        for request in requestCandidates {
            guard let provider = featureProvider(from: request) else {
                continue
            }

            if let response = try? model.prediction(from: provider),
               let text = extractText(from: response) {
                return text
            }
        }

        return nil
    }

    private func loadModel() -> MLModel? {
        let candidateURLs = [
            bundle.url(forResource: "RediM8Assistant", withExtension: "mlmodelc"),
            bundle.url(forResource: "RediM8Assistant", withExtension: nil),
            bundle.bundleURL
                .appendingPathComponent("RediM8Assistant.mlmodelc", isDirectory: true)
        ]

        for url in candidateURLs.compactMap({ $0 }) {
            if let loadedModel = try? MLModel(contentsOf: url, configuration: configuration) {
                return loadedModel
            }
        }

        return nil
    }

    private func featureProvider(from dictionary: [String: Any]) -> MLFeatureProvider? {
        var featureValues: [String: MLFeatureValue] = [:]
        for (key, rawValue) in dictionary {
            if let stringValue = rawValue as? String {
                featureValues[key] = MLFeatureValue(string: stringValue)
            } else if let intValue = rawValue as? Int {
                featureValues[key] = MLFeatureValue(int64: Int64(intValue))
            }
        }

        guard !featureValues.isEmpty else {
            return nil
        }

        return try? MLDictionaryFeatureProvider(dictionary: featureValues)
    }

    private func extractText(from provider: MLFeatureProvider) -> String? {
        for key in ModelSchema.candidateOutputKeys {
            guard let value = provider.featureValue(for: key) else {
                continue
            }

            if value.type == .string {
                return value.stringValue.nilIfBlank
            }
        }

        return nil
    }

    private func prompt(for task: OfflineAssistantModel.Task, input: String) -> String {
        switch task {
        case .summarize:
            return """
            Summarize the explanation clearly in under 3 sentences.
            Do not add numbered steps.
            Do not invent new survival instructions.

            \(input)
            """
        case .interpret:
            return """
            Convert this survival question into a short routing topic phrase only.
            No explanation. No punctuation. 2 to 6 words maximum.

            \(input)
            """
        }
    }
}
