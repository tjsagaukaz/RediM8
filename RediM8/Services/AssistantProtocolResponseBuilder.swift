import Foundation

final class AssistantProtocolResponseBuilder {
    private let guideService: GuideService

    init(guideService: GuideService) {
        self.guideService = guideService
    }

    func build(
        query: String,
        match: AssistantProtocolMatch,
        situationSnapshot: AssistantSituationSnapshot?,
        advisorContextStatus: AdvisorContextStatus,
        contextSections: [AssistantContextSection],
        recentActionHint: AssistantRecentActionHint? = nil
    ) -> AssistantProtocolResponseBuild {
        let definition = match.definition
        let effectiveSnapshot = mergedSnapshot(
            base: situationSnapshot,
            definition: definition,
            queryContext: match.queryContext,
            advisorContextStatus: advisorContextStatus
        )
        let relatedGuides = resolvedGuides(for: definition)
        let usesOperationalTrustContext = shouldUseOperationalTrustContext(
            definition: definition,
            snapshot: effectiveSnapshot,
            advisorContextStatus: advisorContextStatus
        )

        let responseContextSections = combinedContextSections(
            definition: definition,
            queryContext: match.queryContext,
            relatedGuides: relatedGuides,
            contextSections: contextSections,
            snapshot: effectiveSnapshot,
            recentActionHint: recentActionHint
        )

        let summary = effectiveSummary(
            for: definition,
            queryContext: match.queryContext,
            snapshot: effectiveSnapshot,
            advisorContextStatus: advisorContextStatus,
            recentActionHint: recentActionHint
        )
        let steps = adaptedSteps(
            for: definition,
            queryContext: match.queryContext,
            snapshot: effectiveSnapshot
        )
        let safetyNotes = adaptedAvoidance(
            for: definition,
            queryContext: match.queryContext,
            snapshot: effectiveSnapshot
        )
        let classification = AssistantIntentClassification(
            policyID: definition.id,
            topic: definition.topic,
            riskBand: definition.urgency.riskBand,
            preferredMode: .deterministicStepCard,
            modeWhenGenerationDisabled: .deterministicStepCard,
            matchedGuideIDs: relatedGuides.map(\.id),
            matchedTerms: match.matchedTerms,
            trustLabel: definition.verificationStatus.trustLabel,
            lastReviewed: nil,
            regionScope: definition.regionScope,
            confidence: normalizedConfidence(for: match.score, definition: definition),
            escalationNote: definition.emergencyEscalation
        )

        let response = AssistantResponse(
            query: query,
            title: responseTitle(
                for: definition,
                snapshot: effectiveSnapshot
            ),
            topic: definition.topic,
            confidence: classification.confidence,
            riskBand: definition.urgency.riskBand,
            trustLabel: definition.verificationStatus.trustLabel,
            answerMode: .deterministicStepCard,
            sourceMode: .deterministic,
            summary: summary,
            steps: steps,
            safetyNotes: safetyNotes,
            escalationNote: definition.emergencyEscalation,
            relatedGuides: relatedGuides,
            sourceSummary: sourceSummary(for: definition, relatedGuides: relatedGuides),
            lastReviewedSummary: definition.verificationStatus.reviewLabel,
            regionSummary: definition.regionScope.title,
            interpretationNote: nil,
            contextSections: responseContextSections,
            situationSnapshot: effectiveSnapshot,
            advisorContextStatus: usesOperationalTrustContext ? advisorContextStatus : AssistantContextPayload.empty.status,
            usesOperationalTrustContext: usesOperationalTrustContext,
            clarifyingQuestion: nil
        )

        return AssistantProtocolResponseBuild(
            response: response,
            classification: classification,
            relatedGuideIDs: relatedGuides.map(\.id)
        )
    }

    private func mergedSnapshot(
        base: AssistantSituationSnapshot?,
        definition: AssistantProtocolDefinition,
        queryContext: AssistantProtocolQueryContext,
        advisorContextStatus: AdvisorContextStatus
    ) -> AssistantSituationSnapshot {
        let baseMode = maxMode(base?.mode, definition.modeBias)
        let routeStatus = base?.routeStatus
            ?? advisorContextStatus.routeStatus
            ?? routeStatus(from: queryContext)

        return AssistantSituationSnapshot(
            hazard: base?.hazard ?? advisorContextStatus.hazard,
            severity: base?.severity,
            proximity: base?.proximity ?? .unknown,
            mode: baseMode,
            routeStatus: routeStatus,
            lastSyncMinutes: base?.lastSyncMinutes ?? advisorContextStatus.freshnessMinutes,
            hasDependents: base?.hasDependents == true || queryContext.flags.contains(.dependents) || queryContext.flags.contains(.child),
            operationalIntent: base?.operationalIntent
        )
    }

    private func resolvedGuides(for definition: AssistantProtocolDefinition) -> [Guide] {
        var ids = definition.relatedGuideIDs

        if let groundingGuideID = definition.groundingGuideID,
           !ids.contains(groundingGuideID) {
            ids.insert(groundingGuideID, at: 0)
        }

        return guideService.guides(ids: ids)
    }

    private func shouldUseOperationalTrustContext(
        definition: AssistantProtocolDefinition,
        snapshot: AssistantSituationSnapshot,
        advisorContextStatus: AdvisorContextStatus
    ) -> Bool {
        guard definition.domain == .survival else {
            return false
        }

        guard advisorContextStatus.source != .generalGuidance else {
            return false
        }

        return snapshot.hazard != nil || snapshot.routeStatus != nil
    }

    private func responseTitle(
        for definition: AssistantProtocolDefinition,
        snapshot: AssistantSituationSnapshot
    ) -> String {
        if snapshot.routeStatus == .blocked,
           definition.primaryAction == .reviewRouteIfAvailable {
            return "Route may be blocked"
        }

        if snapshot.routeStatus == .atRisk,
           definition.primaryAction == .reviewRouteIfAvailable {
            return "Route may be affected"
        }

        return definition.displayName
    }

    private func sourceSummary(
        for definition: AssistantProtocolDefinition,
        relatedGuides: [Guide]
    ) -> String {
        if definition.verificationStatus == .guideGrounded,
           let guide = relatedGuides.first {
            return "Deterministic offline protocol grounded in \(guide.title)"
        }

        return "Deterministic offline protocol"
    }

    private func normalizedConfidence(
        for score: Double,
        definition: AssistantProtocolDefinition
    ) -> Double {
        let base: Double = switch definition.urgency {
        case .emergency:
            0.84
        case .urgent:
            0.74
        case .planning:
            0.66
        }

        return min(0.98, base + min(score, 4.0) * 0.04)
    }

    private func effectiveSummary(
        for definition: AssistantProtocolDefinition,
        queryContext: AssistantProtocolQueryContext,
        snapshot: AssistantSituationSnapshot,
        advisorContextStatus: AdvisorContextStatus,
        recentActionHint: AssistantRecentActionHint?
    ) -> String {
        if recentActionHint == .reviewedRoute,
           definition.primaryAction == .reviewRouteIfAvailable {
            switch snapshot.routeStatus {
            case .blocked:
                return "Use the alternative route you just reviewed and avoid blocked approaches."
            case .atRisk:
                return "Use the safest route you just reviewed and avoid the higher-risk approach."
            default:
                return "Use the route you just reviewed and keep movement deliberate and early."
            }
        }

        if snapshot.routeStatus == .blocked,
           definition.contextInjectors.contains(.routeBlocked) || definition.primaryAction == .reviewRouteIfAvailable {
            return "Your primary route may be blocked. \(definition.whatMatters)"
        }

        if snapshot.routeStatus == .atRisk,
           definition.contextInjectors.contains(.routeRisk) || definition.primaryAction == .reviewRouteIfAvailable {
            let leading = advisorContextStatus.source == .lastSyncedAlerts
                ? "Your usual route may be affected based on the last synced alert."
                : "Your usual route may be affected."
            return "\(leading) \(definition.whatMatters)"
        }

        if definition.domain == .survival,
           advisorContextStatus.source != .generalGuidance,
           let hazard = snapshot.hazard {
            let freshnessLead = advisorContextStatus.source == .lastSyncedAlerts
                ? "Based on the last synced \(hazard.title.lowercased()) context,"
                : "A recent \(hazard.title.lowercased()) alert may affect your area."
            return "\(freshnessLead) \(definition.whatMatters)"
        }

        if queryContext.flags.contains(.child),
           let childNote = definition.childNote {
            return "\(childNote) \(definition.whatMatters)"
        }

        return definition.whatMatters
    }

    private func adaptedSteps(
        for definition: AssistantProtocolDefinition,
        queryContext: AssistantProtocolQueryContext,
        snapshot: AssistantSituationSnapshot
    ) -> [String] {
        var steps = definition.steps

        guard definition.domain == .survival else {
            return steps
        }

        if snapshot.routeStatus == .blocked,
           (definition.contextInjectors.contains(.routeBlocked) || definition.primaryAction == .reviewRouteIfAvailable),
           !steps.contains(where: { $0.localizedCaseInsensitiveContains("route") || $0.localizedCaseInsensitiveContains("alternative") }) {
            steps.insert("Check an alternative route before you leave.", at: 0)
        } else if snapshot.routeStatus == .atRisk,
                  (definition.contextInjectors.contains(.routeRisk) || definition.primaryAction == .reviewRouteIfAvailable),
                  !steps.contains(where: { $0.localizedCaseInsensitiveContains("route") || $0.localizedCaseInsensitiveContains("safe") }) {
            steps.insert("Check the safest available route before you move.", at: 0)
        }

        if snapshot.hasDependents,
           definition.contextInjectors.contains(.dependents),
           !steps.contains(where: containsDependentLanguage) {
            let insertionIndex = min(1, steps.count)
            steps.insert("Move children, pets, medicines, and anyone needing support into the first move.", at: insertionIndex)
        }

        if queryContext.flags.contains(.pets),
           definition.contextInjectors.contains(.pets),
           !steps.contains(where: { $0.localizedCaseInsensitiveContains("pet") || $0.localizedCaseInsensitiveContains("carrier") || $0.localizedCaseInsensitiveContains("lead") }) {
            let insertionIndex = min(1, steps.count)
            steps.insert("Move pets early with leads, carriers, food, and water ready.", at: insertionIndex)
        }

        return steps
    }

    private func adaptedAvoidance(
        for definition: AssistantProtocolDefinition,
        queryContext _: AssistantProtocolQueryContext,
        snapshot _: AssistantSituationSnapshot
    ) -> [String] {
        definition.avoid
    }

    private func combinedContextSections(
        definition: AssistantProtocolDefinition,
        queryContext: AssistantProtocolQueryContext,
        relatedGuides: [Guide],
        contextSections: [AssistantContextSection],
        snapshot: AssistantSituationSnapshot,
        recentActionHint _: AssistantRecentActionHint?
    ) -> [AssistantContextSection] {
        var sections: [AssistantContextSection] = []

        if definition.domain == .survival,
           (snapshot.hazard != nil || snapshot.routeStatus != nil) {
            sections.append(contentsOf: contextSections)
        }

        if let actionSection = protocolActionSection(
            for: definition,
            queryContext: queryContext,
            existingSections: sections
        ) {
            sections.append(actionSection)
        }

        if let equipmentSection = equipmentSection(for: definition, queryContext: queryContext) {
            sections.append(equipmentSection)
        }

        if let boundarySection = boundarySection(
            for: definition,
            queryContext: queryContext,
            relatedGuides: relatedGuides
        ) {
            sections.append(boundarySection)
        }

        return sections
    }

    private func protocolActionSection(
        for definition: AssistantProtocolDefinition,
        queryContext _: AssistantProtocolQueryContext,
        existingSections: [AssistantContextSection]
    ) -> AssistantContextSection? {
        switch definition.primaryAction {
        case .none:
            return nil
        case .callEmergency:
            return AssistantContextSection(
                id: "protocol-action-\(definition.id)",
                title: "Emergency Action",
                detail: "Call emergency services if available and follow the first steps while help is coming.",
                tone: .danger,
                items: [
                    AssistantContextItem(
                        title: "Emergency services",
                        detail: "Call 000 if you have service and immediate help is needed.",
                        actions: [.callNumber(number: "000", label: "Call 000")]
                    )
                ]
            )
        case .callPoisonsInformation:
            return AssistantContextSection(
                id: "protocol-action-\(definition.id)",
                title: "Poisons Advice",
                detail: "Use the Poisons Information Centre if a swallowed substance or exposure needs urgent specialist advice.",
                tone: .warning,
                items: [
                    AssistantContextItem(
                        title: "Poisons Information Centre",
                        detail: "Call 13 11 26 in Australia if this involves poisoning or a swallowed substance.",
                        actions: [.callNumber(number: "131126", label: "Call Poisons")]
                    )
                ]
            )
        case .reviewRouteIfAvailable:
            if existingSections.contains(where: sectionHasRouteAction) {
                return nil
            }

            return AssistantContextSection(
                id: "protocol-action-\(definition.id)",
                title: "Route Action",
                detail: "Check the safest available route before you commit to movement.",
                tone: .info,
                items: [
                    AssistantContextItem(
                        title: "Route review",
                        detail: "Open the map to confirm the safest route or a safer alternative.",
                        actions: [.openTab("map")]
                    )
                ]
            )
        }
    }

    private func equipmentSection(
        for definition: AssistantProtocolDefinition,
        queryContext: AssistantProtocolQueryContext
    ) -> AssistantContextSection? {
        var items: [AssistantContextItem] = definition.equipmentReferences.map { reference in
            AssistantContextItem(
                title: reference.label,
                detail: reference.note
            )
        }

        if queryContext.flags.contains(.child),
           let childNote = definition.childNote {
            items.append(
                AssistantContextItem(
                    title: "Child note",
                    detail: childNote
                )
            )
        }

        guard !items.isEmpty else {
            return nil
        }

        return AssistantContextSection(
            id: "protocol-equipment-\(definition.id)",
            title: "Equipment & Notes",
            detail: "Use these only if they are already available and you know what they are.",
            tone: .neutral,
            items: items
        )
    }

    private func boundarySection(
        for definition: AssistantProtocolDefinition,
        queryContext _: AssistantProtocolQueryContext,
        relatedGuides: [Guide]
    ) -> AssistantContextSection? {
        var items = definition.disclaimers.map { disclaimer in
            AssistantContextItem(
                title: "Important",
                detail: disclaimer
            )
        }

        if let guide = relatedGuides.first {
            items.append(
                AssistantContextItem(
                    title: "Offline reference",
                    detail: guide.title,
                    caption: guide.lastReviewed
                )
            )
        }

        return AssistantContextSection(
            id: "protocol-boundary-\(definition.id)",
            title: "Protocol Boundary",
            detail: definition.confidenceBoundary,
            tone: .neutral,
            items: items
        )
    }

    private func routeStatus(from queryContext: AssistantProtocolQueryContext) -> AssistantRouteStatus? {
        if queryContext.flags.contains(.routeBlocked) {
            return .blocked
        }

        if queryContext.flags.contains(.routeRisk) {
            return .atRisk
        }

        return nil
    }

    private func maxMode(_ lhs: AssistantSituationMode?, _ rhs: AssistantSituationMode) -> AssistantSituationMode {
        guard let lhs else {
            return rhs
        }

        let lhsRank = modeRank(lhs)
        let rhsRank = modeRank(rhs)
        return lhsRank >= rhsRank ? lhs : rhs
    }

    private func modeRank(_ mode: AssistantSituationMode) -> Int {
        switch mode {
        case .crisis:
            4
        case .elevated:
            3
        case .prep:
            2
        case .normal:
            1
        }
    }

    private func containsDependentLanguage(_ step: String) -> Bool {
        let normalized = step.lowercased()
        return normalized.contains("child")
            || normalized.contains("children")
            || normalized.contains("pet")
            || normalized.contains("medic")
            || normalized.contains("dependent")
            || normalized.contains("support")
    }

    private func sectionHasRouteAction(_ section: AssistantContextSection) -> Bool {
        section.items.contains { item in
            item.actions.contains { action in
                switch action {
                case .openMap, .navigateToCoordinate:
                    return true
                case let .openTab(tab):
                    return tab.lowercased() == "map"
                case .openGuide, .openPlanFocus, .callNumber:
                    return false
                }
            }
        }
    }
}
