import Foundation

enum AdvisorContextSource: String, Equatable {
    case officialAlerts
    case lastSyncedAlerts
    case generalGuidance
}

struct AdvisorContextStatus: Equatable {
    let source: AdvisorContextSource
    let freshnessMinutes: Int?
    let isOffline: Bool
    let hazard: OfficialAlertKind?
    let routeStatus: AssistantRouteStatus?

    var iconName: String {
        switch source {
        case .officialAlerts:
            return "dot.radiowaves.left.and.right"
        case .lastSyncedAlerts:
            return "clock.arrow.circlepath"
        case .generalGuidance:
            return "shield.lefthalf.filled"
        }
    }

    var title: String {
        let freshnessTitle = freshnessMinutes.map { "Updated \(freshnessLabel(for: $0))" }
        let contextTitle = contextualTitle

        switch source {
        case .officialAlerts:
            return ["Using official alerts", contextTitle, freshnessTitle]
                .compactMap { $0 }
                .joined(separator: " • ")
        case .lastSyncedAlerts:
            let prefix = isOffline ? "Offline mode" : nil
            return [prefix, "Using last synced alerts", contextTitle, freshnessTitle]
                .compactMap { $0 }
                .joined(separator: " • ")
        case .generalGuidance:
            if isOffline {
                return "Offline mode • Using general safety guidance"
            }
            return "Using general safety guidance"
        }
    }

    var detail: String? {
        switch source {
        case .officialAlerts, .lastSyncedAlerts:
            if source == .lastSyncedAlerts, freshnessMinutes != nil {
                return "Conditions may have changed since the last update."
            }

            return nil
        case .generalGuidance:
            return nil
        }
    }

    private var contextualTitle: String? {
        if routeStatus == .blocked {
            return "Route blocked"
        }

        if routeStatus == .atRisk {
            return "Route risk detected"
        }

        if let hazard {
            return "\(hazard.title) nearby"
        }

        return nil
    }

    private func freshnessLabel(for freshnessMinutes: Int) -> String {
        if freshnessMinutes < 15 {
            return "just now"
        }

        if freshnessMinutes < 60 {
            return "\(freshnessMinutes) min ago"
        }

        let hours = freshnessMinutes / 60
        if hours <= 1 {
            return "over 1 hour ago"
        }

        return "over \(hours) hr\(hours == 1 ? "" : "s") ago"
    }
}

enum AssistantSituationMode: String, Equatable {
    case normal
    case prep
    case elevated
    case crisis
}

enum AssistantSituationProximity: String, Equatable {
    case inside
    case near
    case far
    case unknown
}

enum AssistantRouteStatus: String, Equatable {
    case clear
    case atRisk
    case blocked
}

enum AssistantRecentActionHint: String, Equatable {
    case reviewedRoute
}

enum AssistantOperationalIntent: String, Equatable {
    case planningAhead
    case stayingPut
    case leavingNow

    var lead: String {
        switch self {
        case .planningAhead:
            "You are planning ahead, so use this to prepare before conditions tighten."
        case .stayingPut:
            "You are staying put for the moment, so stabilise your position before doing anything optional."
        case .leavingNow:
            "You are leaving now, so focus on movement, essentials, and the safest available route."
        }
    }
}

enum AssistantClarifyingQuestionKind: String, Equatable {
    case entryDirection
    case currentSituation
    case movementIntent
}

struct AssistantClarifyingQuestion: Equatable {
    let kind: AssistantClarifyingQuestionKind
    let prompt: String
    let options: [String]
}

struct AssistantSituationSnapshot: Equatable {
    let hazard: OfficialAlertKind?
    let severity: OfficialAlertSeverity?
    let proximity: AssistantSituationProximity
    let mode: AssistantSituationMode
    let routeStatus: AssistantRouteStatus?
    let lastSyncMinutes: Int?
    let hasDependents: Bool
    let operationalIntent: AssistantOperationalIntent?

    init(
        hazard: OfficialAlertKind?,
        severity: OfficialAlertSeverity?,
        proximity: AssistantSituationProximity,
        mode: AssistantSituationMode,
        routeStatus: AssistantRouteStatus?,
        lastSyncMinutes: Int?,
        hasDependents: Bool,
        operationalIntent: AssistantOperationalIntent? = nil
    ) {
        self.hazard = hazard
        self.severity = severity
        self.proximity = proximity
        self.mode = mode
        self.routeStatus = routeStatus
        self.lastSyncMinutes = lastSyncMinutes
        self.hasDependents = hasDependents
        self.operationalIntent = operationalIntent
    }

    var hazardTitle: String? {
        hazard?.title
    }

    var hasEnvironmentalHazard: Bool {
        hazard != nil && severity != nil
    }

    func with(operationalIntent: AssistantOperationalIntent?) -> AssistantSituationSnapshot {
        AssistantSituationSnapshot(
            hazard: hazard,
            severity: severity,
            proximity: proximity,
            mode: mode,
            routeStatus: routeStatus,
            lastSyncMinutes: lastSyncMinutes,
            hasDependents: hasDependents,
            operationalIntent: operationalIntent ?? self.operationalIntent
        )
    }
}

struct AssistantContextPayload: Equatable {
    let sections: [AssistantContextSection]
    let snapshot: AssistantSituationSnapshot?
    let status: AdvisorContextStatus

    static let empty = AssistantContextPayload(
        sections: [],
        snapshot: nil,
        status: AdvisorContextStatus(
            source: .generalGuidance,
            freshnessMinutes: nil,
            isOffline: false,
            hazard: nil,
            routeStatus: nil
        )
    )
}
