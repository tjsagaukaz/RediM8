import Foundation

enum AssistantIntentTopic: String, CaseIterable, Codable, Equatable {
    case snakeBite = "snake_bite"
    case cpr
    case majorBleeding = "major_bleeding"
    case burns
    case heatIllness = "heat_illness"
    case bushfireEvacuation = "bushfire_evacuation"
    case floodSafety = "flood_safety"
    case asthmaAttack = "asthma_attack"
    case waterPurification = "water_purification"
    case waterPlanning = "water_planning"
    case routePlanning = "route_planning"
    case preparednessPlanning = "preparedness_planning"
    case unknown
}

enum AssistantIntentRiskBand: String, Codable, Equatable {
    case critical
    case advisory
    case unknown
}

enum AssistantAnswerMode: String, Codable, Equatable {
    case deterministicStepCard = "deterministic_step_card"
    case summarizedRetrieval = "summarized_retrieval"
    case retrievalOnlyCard = "retrieval_only_card"
    case guideFallback = "guide_fallback"
}

enum AssistantTrustLabel: String, Codable, Equatable {
    case verified
    case general
    case approximate

    var title: String {
        switch self {
        case .verified:
            "Verified"
        case .general:
            "General"
        case .approximate:
            "Approximate"
        }
    }
}

enum AssistantRegionScope: String, Codable, Equatable {
    case australia
    case general
    case regional

    var title: String {
        switch self {
        case .australia:
            "Australia-specific"
        case .general:
            "General guidance"
        case .regional:
            "Regional guidance"
        }
    }
}

enum AssistantConfidenceBand: String, Equatable {
    case high
    case medium
    case low
}

struct AssistantPolicy: Identifiable, Codable, Equatable {
    let id: String
    let intent: AssistantIntentTopic
    let riskBand: AssistantIntentRiskBand
    let answerMode: AssistantAnswerMode
    let fallbackMode: AssistantAnswerMode
    let guideIDs: [String]
    let trustLabel: AssistantTrustLabel
    let lastReviewed: Date
    let regionScope: AssistantRegionScope
    let escalationNote: String?
    let matchPhrases: [String]
    let tokenGroups: [[String]]
    let baseConfidence: Double
    let minimumConfidence: Double

    enum CodingKeys: String, CodingKey {
        case id
        case intent
        case riskBand = "risk_band"
        case answerMode = "answer_mode"
        case fallbackMode = "fallback_mode"
        case guideIDs = "guide_ids"
        case trustLabel = "trust_label"
        case lastReviewed = "last_reviewed"
        case regionScope = "region_scope"
        case escalationNote = "escalation_note"
        case matchPhrases = "match_phrases"
        case tokenGroups = "token_groups"
        case baseConfidence = "base_confidence"
        case minimumConfidence = "minimum_confidence"
    }
}

struct AssistantPolicyLibrary: Codable, Equatable {
    let lastUpdated: Date
    let policies: [AssistantPolicy]

    enum CodingKeys: String, CodingKey {
        case lastUpdated = "last_updated"
        case policies
    }
}

struct AssistantIntentClassification: Equatable {
    let policyID: String?
    let topic: AssistantIntentTopic
    let riskBand: AssistantIntentRiskBand
    let preferredMode: AssistantAnswerMode
    let modeWhenGenerationDisabled: AssistantAnswerMode
    let matchedGuideIDs: [String]
    let matchedTerms: [String]
    let trustLabel: AssistantTrustLabel?
    let lastReviewed: Date?
    let regionScope: AssistantRegionScope?
    let confidence: Double
    let escalationNote: String?

    var confidenceBand: AssistantConfidenceBand {
        switch confidence {
        case 0.75...:
            .high
        case 0.5..<0.75:
            .medium
        default:
            .low
        }
    }

    var bypassesGeneration: Bool {
        preferredMode == .deterministicStepCard
    }
}
