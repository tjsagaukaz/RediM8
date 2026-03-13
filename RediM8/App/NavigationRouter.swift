import Foundation

enum AppTab: Hashable {
    case home
    case plan
    case vault
    case library
    case map
    case signal
}

enum PlanFocus: Hashable {
    case householdOverview
    case waterRuntime
    case evacuationRoutes
    case vehicleKit
}

@MainActor
final class NavigationRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var requestedPlanFocus: PlanFocus?
    @Published var isShowingBlackout = false
    @Published var isShowingEmergencyMode = false
    @Published var isShowingLeaveNowMode = false
    @Published var isShowingEmergencyGuides = false
    @Published var highlightedGuideCategory: GuideCategory?

    func handlePendingQuickAction(from appState: AppState) {
        guard let action = appState.consumePendingQuickAction() else {
            return
        }

        DispatchQueue.main.async {
            self.performQuickAction(action, appState: appState)
        }
    }

    func handleBackgroundTransition(appState: AppState) {
        appState.endEmergencyAccessSession()
    }

    func openPlan() {
        requestedPlanFocus = .householdOverview
        selectedTab = .plan
    }

    func openVault() {
        requestedPlanFocus = nil
        selectedTab = .vault
    }

    func openLibrary() {
        requestedPlanFocus = nil
        selectedTab = .library
    }

    func openMap() {
        requestedPlanFocus = nil
        selectedTab = .map
    }

    func openVehicleReadiness() {
        requestedPlanFocus = .vehicleKit
        selectedTab = .plan
    }

    func openWaterRuntime() {
        requestedPlanFocus = .waterRuntime
        selectedTab = .plan
    }

    func openEvacuationRoutes() {
        requestedPlanFocus = .evacuationRoutes
        selectedTab = .plan
    }

    func openSignalNearby() {
        isShowingEmergencyGuides = false
        highlightedGuideCategory = nil
        isShowingBlackout = false
        selectedTab = .signal
    }

    func presentEmergencyGuides(appState: AppState) {
        appState.beginEmergencyAccessSession()
        selectedTab = .home
        highlightedGuideCategory = .firstAid

        if isShowingBlackout {
            isShowingBlackout = false
            DispatchQueue.main.async {
                self.isShowingEmergencyGuides = true
            }
            return
        }

        isShowingEmergencyGuides = true
    }

    func presentBlackout(appState: AppState) {
        appState.beginEmergencyAccessSession()
        selectedTab = .home
        highlightedGuideCategory = nil

        if isShowingEmergencyGuides {
            isShowingEmergencyGuides = false
            DispatchQueue.main.async {
                self.isShowingBlackout = true
            }
            return
        }

        isShowingBlackout = true
    }

    func presentEmergencyMode(appState: AppState) {
        appState.beginEmergencyAccessSession()
        isShowingEmergencyGuides = false
        highlightedGuideCategory = nil
        isShowingBlackout = false
        isShowingLeaveNowMode = false
        isShowingEmergencyMode = true
    }

    func dismissEmergencyMode(appState: AppState) {
        isShowingEmergencyMode = false
        if !isShowingBlackout && !isShowingEmergencyGuides && !isShowingLeaveNowMode && !appState.isLowBatterySurvivalModeEnabled {
            appState.endEmergencyAccessSession()
        }
    }

    func dismissBlackout(appState: AppState) {
        isShowingBlackout = false
        if !isShowingEmergencyMode && !isShowingEmergencyGuides && !isShowingLeaveNowMode && !appState.isLowBatterySurvivalModeEnabled {
            appState.endEmergencyAccessSession()
        }
    }

    func didDismissEmergencyGuides(appState: AppState) {
        highlightedGuideCategory = nil
        if !isShowingBlackout && !isShowingEmergencyMode && !isShowingLeaveNowMode {
            appState.endEmergencyAccessSession()
        }
    }

    func presentLeaveNowMode(appState: AppState) {
        appState.beginEmergencyAccessSession()
        isShowingEmergencyGuides = false
        highlightedGuideCategory = nil
        isShowingBlackout = false
        isShowingEmergencyMode = false
        isShowingLeaveNowMode = true
    }

    func dismissLeaveNowMode(appState: AppState) {
        isShowingLeaveNowMode = false
        if !isShowingBlackout && !isShowingEmergencyMode && !isShowingEmergencyGuides && !appState.isLowBatterySurvivalModeEnabled {
            appState.endEmergencyAccessSession()
        }
    }

    func openBlackoutFromEmergency() {
        isShowingEmergencyMode = false
        DispatchQueue.main.async {
            self.isShowingBlackout = true
        }
    }

    func openLeaveNowFromEmergency() {
        isShowingEmergencyMode = false
        DispatchQueue.main.async {
            self.isShowingLeaveNowMode = true
        }
    }

    func openTabFromEmergency(_ tab: AppTab, appState _: AppState) {
        isShowingEmergencyMode = false
        selectedTab = tab
        if tab != .plan {
            requestedPlanFocus = nil
        }
    }

    func openTabFromLeaveNow(_ tab: AppTab, appState _: AppState) {
        isShowingLeaveNowMode = false
        selectedTab = tab
        if tab != .plan {
            requestedPlanFocus = nil
        }
    }

    private func performQuickAction(_ action: EmergencyQuickAction, appState: AppState) {
        switch action {
        case .blackoutMode:
            presentBlackout(appState: appState)
        case .signalNearby:
            openSignalNearby()
        case .emergencyGuides:
            presentEmergencyGuides(appState: appState)
        case .stealthMode:
            selectedTab = .home
            isShowingEmergencyGuides = false
            highlightedGuideCategory = nil
            isShowingBlackout = false
            isShowingEmergencyMode = false
            isShowingLeaveNowMode = false
            appState.enableStealthMode()
        case .flashlight:
            presentBlackout(appState: appState)
        }
    }

    func consumeRequestedPlanFocus() -> PlanFocus? {
        let focus = requestedPlanFocus
        requestedPlanFocus = nil
        return focus
    }
}
