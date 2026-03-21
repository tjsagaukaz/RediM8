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
    case callNumber(number: String, label: String)
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
    enum PresentationStyle: Equatable {
        case operational
        case entryPrompt
    }

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
    let presentationStyle: PresentationStyle
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
    let situationSnapshot: AssistantSituationSnapshot?
    let advisorContextStatus: AdvisorContextStatus
    let usesOperationalTrustContext: Bool
    let clarifyingQuestion: AssistantClarifyingQuestion?

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
        presentationStyle: PresentationStyle = .operational,
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
        contextSections: [AssistantContextSection] = [],
        situationSnapshot: AssistantSituationSnapshot? = nil,
        advisorContextStatus: AdvisorContextStatus = .init(
            source: .generalGuidance,
            freshnessMinutes: nil,
            isOffline: false,
            hazard: nil,
            routeStatus: nil
        ),
        usesOperationalTrustContext: Bool = false,
        clarifyingQuestion: AssistantClarifyingQuestion? = nil
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
        self.presentationStyle = presentationStyle
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
        self.situationSnapshot = situationSnapshot
        self.advisorContextStatus = advisorContextStatus
        self.usesOperationalTrustContext = usesOperationalTrustContext
        self.clarifyingQuestion = clarifyingQuestion
    }

    var primaryGuide: Guide? {
        relatedGuides.first
    }

    var hasHazardWarning: Bool {
        contextSections.contains(where: \.isHazardWarning)
    }

    var panelSubtitle: String {
        if let clarifyingQuestion {
            return "\(panelSubtitleBase) One quick question can tighten the next steps: \(clarifyingQuestion.prompt)"
        }
        return panelSubtitleBase
    }

    private var panelSubtitleBase: String {
        if isEntryPromptPresentation {
            return "Ask about emergencies, planning, or navigation to get grounded offline guidance."
        }

        if advisorContextStatus.source != .generalGuidance {
            return "Guidance shaped from bundled offline references and current conditions."
        }

        switch sourceMode {
        case .deterministic:
            return "Immediate steps grounded in bundled offline guidance."
        case .summarized:
            return usedOfflineModel
                ? "Guide-grounded guidance with an on-device wording pass."
                : "Guide-grounded guidance shaped from bundled offline references."
        case .retrievalOnly:
            return "Direct offline guidance from bundled RediM8 references."
        case .fallback:
            return "Closest bundled offline guidance for this question."
        }
    }

    var situationHeading: String {
        isEntryPromptPresentation ? "Start Here" : "What Matters Right Now"
    }

    var actionsHeading: String {
        "Do This Next"
    }

    var avoidHeading: String {
        "Avoid This"
    }

    var contextHeading: String {
        hasHazardWarning ? "Supporting Context" : "Local Context"
    }

    var sourceHeading: String {
        "Source & Trust"
    }

    var guidesHeading: String {
        primaryGuide == nil ? "Related Guides" : "Open Full Guides"
    }

    var questionHeading: String {
        isEntryPromptPresentation ? "Choose A Direction" : "Refine This"
    }

    var presentationMode: AssistantSituationMode {
        situationSnapshot?.mode ?? .normal
    }

    var isEntryPromptPresentation: Bool {
        presentationStyle == .entryPrompt
    }

    var isCrisisPresentation: Bool {
        presentationMode == .crisis
    }

    var isElevatedPresentation: Bool {
        presentationMode == .elevated
    }

    var visibleSteps: [String] {
        switch presentationMode {
        case .crisis:
            return Array(steps.prefix(3))
        case .elevated:
            return Array(steps.prefix(5))
        case .prep, .normal:
            return steps
        }
    }

    var visibleSafetyNotes: [String] {
        switch presentationMode {
        case .crisis:
            return Array(safetyNotes.prefix(1))
        case .elevated:
            return Array(safetyNotes.prefix(2))
        case .prep, .normal:
            return safetyNotes
        }
    }

    var shouldCollapseSecondaryContentByDefault: Bool {
        !isEntryPromptPresentation
    }

    var shouldPrioritizePrimaryActionRow: Bool {
        if isEntryPromptPresentation {
            return false
        }
        return isCrisisPresentation || isElevatedPresentation
    }

    var shouldShowTrustStrip: Bool {
        !isEntryPromptPresentation && usesOperationalTrustContext
    }

    var shouldShowOperationalMetadata: Bool {
        !isEntryPromptPresentation
    }

    var trustStripTitle: String {
        advisorContextStatus.title
    }

    var trustStripDetail: String? {
        advisorContextStatus.detail
    }

    var deliveryModeTitle: String {
        if hasHazardWarning || riskBand == .critical {
            return "Immediate"
        }

        switch sourceMode {
        case .deterministic:
            return "Guide-linked"
        case .summarized:
            return "Contextual"
        case .retrievalOnly:
            return "Direct"
        case .fallback:
            return "Fallback"
        }
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
