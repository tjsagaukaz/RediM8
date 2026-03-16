import Foundation

enum AssistantContextTone: Equatable {
    case danger
    case warning
    case info
    case ready
    case neutral
}

enum AssistantContextAction: Equatable {
    case openMap
    case navigateToCoordinate(latitude: Double, longitude: Double, label: String)
    case openGuide(guideID: String)
    case openTab(String)
    case openPlanFocus(String)
}

struct AssistantContextItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let caption: String?
    let actions: [AssistantContextAction]

    init(id: String = UUID().uuidString, title: String, detail: String, caption: String? = nil, actions: [AssistantContextAction] = []) {
        self.id = id
        self.title = title
        self.detail = detail
        self.caption = caption
        self.actions = actions
    }
}

struct AssistantContextSection: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let tone: AssistantContextTone
    let items: [AssistantContextItem]
    let isHazardWarning: Bool

    init(id: String, title: String, detail: String, tone: AssistantContextTone, items: [AssistantContextItem], isHazardWarning: Bool = false) {
        self.id = id
        self.title = title
        self.detail = detail
        self.tone = tone
        self.items = items
        self.isHazardWarning = isHazardWarning
    }
}

struct AssistantResponse: Identifiable, Equatable {
    enum SourceMode: String, Equatable {
        case deterministic
        case summarized
        case retrievalOnly
        case fallback
    }

    let id: UUID
    let query: String
    let title: String
    let topic: AssistantIntentTopic
    let confidence: Double
    let riskBand: AssistantIntentRiskBand
    let trustLabel: AssistantTrustLabel?
    let answerMode: AssistantAnswerMode
    let sourceMode: SourceMode
    let summary: String
    let steps: [String]
    let safetyNotes: [String]
    let escalationNote: String?
    let relatedGuides: [Guide]
    let sourceSummary: String
    let lastReviewedSummary: String
    let regionSummary: String
    let fallbackExplanation: String?
    let interpretationNote: String?
    let usedOfflineModel: Bool
    let contextSections: [AssistantContextSection]

    init(
        id: UUID = UUID(),
        query: String,
        title: String,
        topic: AssistantIntentTopic,
        confidence: Double,
        riskBand: AssistantIntentRiskBand,
        trustLabel: AssistantTrustLabel?,
        answerMode: AssistantAnswerMode,
        sourceMode: SourceMode,
        summary: String,
        steps: [String],
        safetyNotes: [String] = [],
        escalationNote: String?,
        relatedGuides: [Guide],
        sourceSummary: String,
        lastReviewedSummary: String,
        regionSummary: String,
        fallbackExplanation: String? = nil,
        interpretationNote: String? = nil,
        usedOfflineModel: Bool = false,
        contextSections: [AssistantContextSection] = []
    ) {
        self.id = id
        self.query = query
        self.title = title
        self.topic = topic
        self.confidence = confidence
        self.riskBand = riskBand
        self.trustLabel = trustLabel
        self.answerMode = answerMode
        self.sourceMode = sourceMode
        self.summary = summary
        self.steps = steps
        self.safetyNotes = safetyNotes
        self.escalationNote = escalationNote
        self.relatedGuides = relatedGuides
        self.sourceSummary = sourceSummary
        self.lastReviewedSummary = lastReviewedSummary
        self.regionSummary = regionSummary
        self.fallbackExplanation = fallbackExplanation
        self.interpretationNote = interpretationNote
        self.usedOfflineModel = usedOfflineModel
        self.contextSections = contextSections
    }

    var primaryGuide: Guide? {
        relatedGuides.first
    }

    var confidenceTitle: String {
        switch confidence {
        case 0.75...:
            "High"
        case 0.5..<0.75:
            "Medium"
        default:
            "Low"
        }
    }

    var answerModeTitle: String {
        switch sourceMode {
        case .deterministic:
            "Deterministic guide card"
        case .summarized:
            "Safe summarized retrieval"
        case .retrievalOnly:
            "Guide retrieval"
        case .fallback:
            "Fallback guide routing"
        }
    }

    var trustLabelTitle: String {
        trustLabel?.title ?? "Guide-linked"
    }
}

struct AssistantConversationTurn: Identifiable, Equatable {
    let id: UUID
    let query: String
    let response: AssistantResponse
    let createdAt: Date

    init(id: UUID = UUID(), query: String, response: AssistantResponse, createdAt: Date = .now) {
        self.id = id
        self.query = query
        self.response = response
        self.createdAt = createdAt
    }
}
