import Foundation

enum AssistantProtocolDomain: String, CaseIterable, Equatable {
    case medical
    case survival
}

enum AssistantProtocolUrgency: String, CaseIterable, Equatable {
    case planning
    case urgent
    case emergency

    var riskBand: AssistantIntentRiskBand {
        switch self {
        case .planning:
            .advisory
        case .urgent, .emergency:
            .critical
        }
    }

    var preferredMode: AssistantSituationMode {
        switch self {
        case .planning:
            .prep
        case .urgent:
            .elevated
        case .emergency:
            .crisis
        }
    }
}

enum AssistantProtocolVerificationStatus: String, CaseIterable, Equatable {
    case guideGrounded
    case sourceReviewRequired

    var trustLabel: AssistantTrustLabel {
        switch self {
        case .guideGrounded:
            .verified
        case .sourceReviewRequired:
            .general
        }
    }

    var reviewLabel: String {
        switch self {
        case .guideGrounded:
            "Bundled offline protocol"
        case .sourceReviewRequired:
            "Pending ANZCOR / St John verification"
        }
    }
}

enum AssistantProtocolReviewSource: String, CaseIterable, Equatable {
    case anzcor
    case australianResuscitationCouncil
    case stJohnAustralia
    case healthdirectAustralia
    case poisonsInformationCentre
    case surfLifeSavingAustralia
}

enum AssistantProtocolPrimaryAction: Equatable {
    case none
    case callEmergency
    case callPoisonsInformation
    case reviewRouteIfAvailable
}

enum AssistantProtocolFallbackPolicy: Equatable {
    case entryPrompt
    case contextDriven
    case emergencyEscalationOnly
    case planningPolicy
}

enum AssistantProtocolContextInjector: String, CaseIterable, Equatable {
    case bystander
    case dependents
    case child
    case pets
    case multipleCasualties
    case routeRisk
    case routeBlocked
    case noSignal
    case noGPS
    case noPower
    case noWater
    case smoke
    case waterExposure
    case vehicle
    case heat
    case cold
    case night
    case noEquipment
    case beach
    case poisoning
    case swallowedSubstance
    case chemicalExposure
}

enum AssistantProtocolQueryFlag: String, CaseIterable, Hashable {
    case bystander
    case child
    case dependents
    case pets
    case loneUser
    case multipleCasualties
    case noSignal
    case noGPS
    case noPower
    case noEquipment
    case hasAED
    case hasInhaler
    case hasSpacer
    case hasEpiPen
    case hasNaloxone
    case routeRisk
    case routeBlocked
    case smoke
    case heat
    case cold
    case vehicle
    case waterExposure
    case beach
    case poisoning
    case swallowedSubstance
    case chemicalExposure
}

struct AssistantProtocolEquipmentReference: Equatable {
    let label: String
    let note: String
}

struct AssistantProtocolDefinition: Identifiable, Equatable {
    let id: String
    let displayName: String
    let domain: AssistantProtocolDomain
    let topic: AssistantIntentTopic
    let urgency: AssistantProtocolUrgency
    let modeBias: AssistantSituationMode
    let triggerTerms: [String]
    let alternateTriggerPhrases: [String]
    let triggerTokenGroups: [[String]]
    let summary: String
    let whatMatters: String
    let steps: [String]
    let avoid: [String]
    let emergencyEscalation: String?
    let confidenceBoundary: String
    let disclaimers: [String]
    let equipmentReferences: [AssistantProtocolEquipmentReference]
    let childNote: String?
    let suppressClarification: Bool
    let shouldPrioritizePrimaryAction: Bool
    let fastPathEligible: Bool
    let primaryAction: AssistantProtocolPrimaryAction
    let contextInjectors: [AssistantProtocolContextInjector]
    let safeFallbackPolicy: AssistantProtocolFallbackPolicy
    let relatedGuideIDs: [String]
    let groundingGuideID: String?
    let verificationStatus: AssistantProtocolVerificationStatus
    let reviewSources: [AssistantProtocolReviewSource]
    let regionScope: AssistantRegionScope

    init(
        id: String,
        displayName: String,
        domain: AssistantProtocolDomain,
        topic: AssistantIntentTopic,
        urgency: AssistantProtocolUrgency,
        modeBias: AssistantSituationMode? = nil,
        triggerTerms: [String],
        alternateTriggerPhrases: [String] = [],
        triggerTokenGroups: [[String]] = [],
        summary: String,
        whatMatters: String,
        steps: [String],
        avoid: [String],
        emergencyEscalation: String?,
        confidenceBoundary: String,
        disclaimers: [String] = [],
        equipmentReferences: [AssistantProtocolEquipmentReference] = [],
        childNote: String? = nil,
        suppressClarification: Bool = true,
        shouldPrioritizePrimaryAction: Bool = false,
        fastPathEligible: Bool = true,
        primaryAction: AssistantProtocolPrimaryAction = .none,
        contextInjectors: [AssistantProtocolContextInjector] = [],
        safeFallbackPolicy: AssistantProtocolFallbackPolicy = .contextDriven,
        relatedGuideIDs: [String] = [],
        groundingGuideID: String? = nil,
        verificationStatus: AssistantProtocolVerificationStatus = .sourceReviewRequired,
        reviewSources: [AssistantProtocolReviewSource] = [.anzcor, .stJohnAustralia],
        regionScope: AssistantRegionScope = .general
    ) {
        self.id = id
        self.displayName = displayName
        self.domain = domain
        self.topic = topic
        self.urgency = urgency
        self.modeBias = modeBias ?? urgency.preferredMode
        self.triggerTerms = triggerTerms
        self.alternateTriggerPhrases = alternateTriggerPhrases
        self.triggerTokenGroups = triggerTokenGroups
        self.summary = summary
        self.whatMatters = whatMatters
        self.steps = steps
        self.avoid = avoid
        self.emergencyEscalation = emergencyEscalation
        self.confidenceBoundary = confidenceBoundary
        self.disclaimers = disclaimers
        self.equipmentReferences = equipmentReferences
        self.childNote = childNote
        self.suppressClarification = suppressClarification
        self.shouldPrioritizePrimaryAction = shouldPrioritizePrimaryAction
        self.fastPathEligible = fastPathEligible
        self.primaryAction = primaryAction
        self.contextInjectors = contextInjectors
        self.safeFallbackPolicy = safeFallbackPolicy
        self.relatedGuideIDs = relatedGuideIDs
        self.groundingGuideID = groundingGuideID
        self.verificationStatus = verificationStatus
        self.reviewSources = reviewSources
        self.regionScope = regionScope
    }
}

struct AssistantProtocolQueryContext: Equatable {
    let normalizedQuery: String
    let tokens: [String]
    let tokenSet: Set<String>
    let flags: Set<AssistantProtocolQueryFlag>
}

struct AssistantProtocolMatch: Equatable {
    let definition: AssistantProtocolDefinition
    let score: Double
    let matchedTerms: [String]
    let queryContext: AssistantProtocolQueryContext
}

struct AssistantProtocolResponseBuild {
    let response: AssistantResponse
    let classification: AssistantIntentClassification
    let relatedGuideIDs: [String]
}
