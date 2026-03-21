import Foundation
import SwiftUI
import UIKit

@MainActor
final class AssistantViewModel: ObservableObject {
    struct SharePayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    let appState: AppState
    let sourceLabel: String

    @Published var draftQuery: String
    @Published private(set) var conversation: [AssistantConversationTurn] = []
    @Published var selectedGuide: Guide?
    @Published var sharePayload: SharePayload?
    @Published var pendingMapAction: PendingMapAction?
    @Published var pendingTabAction: PendingTabAction?

    struct PendingMapAction: Identifiable {
        let id = UUID()
        let latitude: Double?
        let longitude: Double?
        let label: String?
    }

    struct PendingTabAction: Identifiable {
        let id = UUID()
        let tab: String
        let planFocus: String?
    }

    private var pendingInitialQuery: String?
    private var hasConsumedInitialQuery = false

    init(appState: AppState, initialQuery: String? = nil, sourceLabel: String = "Offline Assistant") {
        self.appState = appState
        self.sourceLabel = sourceLabel
        draftQuery = initialQuery ?? ""
        pendingInitialQuery = initialQuery?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
    }

    var suggestions: [String] {
        [
            "Snake bite — what do I do immediately?",
            "Water needed for 3 days (per person)",
            "How to purify water safely (no power)",
            "Bushfire evacuation — what do I do now?",
            "How do I stop bleeding quickly?",
            "Floodwater nearby — move or shelter?",
            "Vehicle breakdown — stay or leave?",
            "How do I signal for rescue?",
            "How do I navigate without GPS?",
            "What can I do during a blackout right now?",
            "What should go in a grab-and-go kit?",
            "How do I stay calm and make a plan?"
        ]
    }

    var hasConversation: Bool {
        !conversation.isEmpty
    }

    var statusItems: [OperationalStatusItem] {
        let aiValue: String
        let aiTone: OperationalStatusTone
        if !appState.settings.assistant.offlineAISummariesEnabled {
            aiValue = "Off"
            aiTone = .neutral
        } else if appState.assistantModel.isAvailable {
            aiValue = "Ready"
            aiTone = .info
        } else {
            aiValue = "Guide only"
            aiTone = .neutral
        }

        return [
            OperationalStatusItem(iconName: "wifi.slash", label: "Mode", value: "Offline", tone: .ready),
            OperationalStatusItem(iconName: "checkmark.shield.fill", label: "Safety", value: "Policy-driven", tone: .info),
            OperationalStatusItem(iconName: "sparkles", label: "AI", value: aiValue, tone: aiTone),
            OperationalStatusItem(iconName: "book.fill", label: "Source", value: "Bundled guides", tone: .neutral),
            OperationalStatusItem(iconName: "tray.full.fill", label: "Turns", value: "\(conversation.count)", tone: .neutral)
        ]
    }

    func onAppear() {
        guard !hasConsumedInitialQuery else { return }
        hasConsumedInitialQuery = true

        if let pendingInitialQuery {
            submit(query: pendingInitialQuery)
            draftQuery = ""
        }
    }

    func submitCurrentDraft() {
        let query = draftQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        submit(query: query)
        draftQuery = ""
    }

    func applySuggestion(_ suggestion: String) {
        draftQuery = suggestion
        submitCurrentDraft()
    }

    func submitClarifyingOption(_ option: String) {
        submit(query: option)
    }

    @discardableResult
    func toggleSavedGuide(_ guideID: String) -> Bool {
        var isSaved = false

        appState.mutateProfile { profile in
            if let existingIndex = profile.savedGuideIDs.firstIndex(of: guideID) {
                profile.savedGuideIDs.remove(at: existingIndex)
                isSaved = false
            } else {
                profile.savedGuideIDs.removeAll { $0 == guideID }
                profile.savedGuideIDs.insert(guideID, at: 0)
                profile.savedGuideIDs = Array(profile.savedGuideIDs.prefix(16))
                isSaved = true
            }
        }

        RediHaptics.selection(enabled: !appState.isStealthModeEnabled)
        return isSaved
    }

    func isGuideSaved(_ guideID: String) -> Bool {
        appState.profile.savedGuideIDs.contains(guideID)
    }

    func openGuide(_ guide: Guide) {
        appState.mutateProfile { profile in
            profile.recentGuideIDs.removeAll { $0 == guide.id }
            profile.recentGuideIDs.insert(guide.id, at: 0)
            profile.recentGuideIDs = Array(profile.recentGuideIDs.prefix(12))
        }
        selectedGuide = guide
    }

    func shareGuide(_ guide: Guide) {
        let text = buildShareText(for: guide)
        sharePayload = SharePayload(items: [text])
    }

    func handleContextAction(_ action: AssistantContextAction) {
        RediHaptics.selection(enabled: !appState.isStealthModeEnabled)
        appState.assistant.noteContextAction(action)

        switch action {
        case .openMap:
            pendingMapAction = PendingMapAction(latitude: nil, longitude: nil, label: nil)

        case let .navigateToCoordinate(latitude, longitude, label):
            pendingMapAction = PendingMapAction(latitude: latitude, longitude: longitude, label: label)

        case let .openGuide(guideID):
            if let guide = appState.guideService.guide(id: guideID) {
                openGuide(guide)
            }

        case let .openTab(tab):
            pendingTabAction = PendingTabAction(tab: tab, planFocus: nil)

        case let .openPlanFocus(focus):
            pendingTabAction = PendingTabAction(tab: "plan", planFocus: focus)

        case let .callNumber(number, _):
            guard let url = URL(string: "tel://\(number)") else {
                return
            }

            UIApplication.shared.open(url)
        }
    }

    private func submit(query: String) {
        let response = appState.assistant.ask(
            query,
            allowsSafeSummaries: appState.isProUser && appState.settings.assistant.offlineAISummariesEnabled
        )
        conversation.append(
            AssistantConversationTurn(
                query: query,
                response: response
            )
        )
        RediHaptics.selection(enabled: !appState.isStealthModeEnabled)
    }

    private func buildShareText(for guide: Guide) -> String {
        var lines = [String]()
        lines.append(guide.title)
        lines.append("")
        lines.append(guide.summary)

        if !guide.steps.isEmpty {
            lines.append("")
            lines.append("Steps:")
            lines.append(contentsOf: guide.steps.enumerated().map { "\($0.offset + 1). \($0.element)" })
        }

        if let note = guide.notes.nilIfBlank {
            lines.append("")
            lines.append("Important:")
            lines.append(note)
        }

        lines.append("")
        lines.append("Shared from RediM8 offline assistant.")

        return lines.joined(separator: "\n")
    }
}
