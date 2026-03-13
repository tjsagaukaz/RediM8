import Combine
import Foundation

struct LeaveNowActionDisplay: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let isComplete: Bool
}

@MainActor
final class LeaveNowViewModel: ObservableObject {
    @Published private(set) var actions: [LeaveNowActionDisplay] = []
    @Published private(set) var summaryLine = ""
    @Published private(set) var nextStepLine = ""
    @Published private(set) var mapStatusLine = ""
    @Published private(set) var signalStatusLine = ""
    @Published private(set) var statusItems: [OperationalStatusItem] = []

    private let appState: AppState
    private let decisionSupportService: DecisionSupportService
    private let goBagService: GoBagService
    private var completionIDs = Set<String>()
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        decisionSupportService = appState.decisionSupportService
        goBagService = appState.goBagService
        refresh()

        appState.$profile
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        appState.$settings
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        appState.$isStealthModeEnabled
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        goBagService.$completedItemIDs
            .sink { [weak self] _ in
                guard let self else { return }
                self.refresh()
            }
            .store(in: &cancellables)
    }

    func toggleAction(_ actionID: String) {
        if completionIDs.contains(actionID) {
            completionIDs.remove(actionID)
        } else {
            completionIDs.insert(actionID)
        }
        refresh(for: appState.profile)
    }

    private func refresh() {
        refresh(for: appState.profile)
    }

    private func refresh(for profile: UserProfile) {
        let goBagPlan = goBagService.plan(for: profile)
        let baseActions = decisionSupportService.leaveNowActions(for: profile, goBagPlan: goBagPlan)
        completionIDs = completionIDs.intersection(Set(baseActions.map(\.id)))
        actions = baseActions.map { action in
            LeaveNowActionDisplay(
                id: action.id,
                title: action.title,
                detail: action.detail,
                isComplete: completionIDs.contains(action.id)
            )
        }

        let routeCount = profile.evacuationRoutes.compactMap(\.nilIfBlank).count
        let installedPackIDs = appState.mapDataService.loadInstalledPackIDs()
        let installedPacks = appState.mapDataService.packs(withIDs: installedPackIDs)
        let packNames = installedPacks.prefix(2).map(\.name).joined(separator: ", ")
        let hasMorePacks = installedPacks.count > 2
        let packLabel = hasMorePacks ? "\(packNames) + \(installedPacks.count - 2) more" : packNames

        summaryLine = "Go Bag \(goBagPlan.readiness.percentage)% ready • \(routeCount) routes saved • \(profile.emergencyContacts.count) contacts stored"
        nextStepLine = "Grab the ready folder next, then open the offline map before you call or signal."
        mapStatusLine = installedPacks.isEmpty
            ? "No regional pack installed. The map falls back to the basemap, bundled resources, and saved markers."
            : "Offline coverage ready: \(packLabel). Outside those pack boundaries, layer detail can disappear."
        signalStatusLine = {
            if appState.isStealthModeEnabled {
                return "Signal is receive-only while Stealth Mode is active."
            }

            if appState.settings.privacy.isAnonymousModeEnabled {
                return "Signal is receive-only while Anonymous Mode is active."
            }

            return "Signal is short-range assistive only. Delivery is not guaranteed."
        }()
        statusItems = [
            OperationalStatusItem(
                iconName: "go_bag",
                label: "Go Bag",
                value: "\(goBagPlan.readiness.percentage)%",
                tone: goBagPlan.readiness.percentage >= 67 ? .ready : .caution
            ),
            OperationalStatusItem(
                iconName: "route",
                label: "Routes",
                value: routeCount == 0 ? "None saved" : "\(routeCount) ready",
                tone: routeCount == 0 ? .caution : .ready
            ),
            OperationalStatusItem(
                iconName: "map_marker",
                label: "Map",
                value: installedPacks.isEmpty ? "Fallback only" : "\(installedPacks.count) packs",
                tone: installedPacks.isEmpty ? .caution : .info
            ),
            OperationalStatusItem(
                iconName: "signal",
                label: "Signal",
                value: appState.isStealthModeEnabled || appState.settings.privacy.isAnonymousModeEnabled ? "Receive-only" : "Assistive",
                tone: appState.isStealthModeEnabled || appState.settings.privacy.isAnonymousModeEnabled ? .caution : .info
            )
        ]
    }
}
