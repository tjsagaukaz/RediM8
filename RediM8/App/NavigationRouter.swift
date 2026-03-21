import Foundation
import SwiftUI

enum AppTab: Hashable {
    case home
    case ask
    case map
    case signal
    case more
    case plan
    case vault
    case library
}

enum PlanFocus: Hashable {
    case householdOverview
    case waterRuntime
    case evacuationRoutes
    case vehicleKit
    case supplies
    case medicalProfile
    case gearChecklist
}

/// Mutually exclusive full-screen overlay states.
/// Replaces 4 independent booleans that could get into invalid states.
enum OverlayMode: Equatable {
    case emergencyMode
    case leaveNow
    case blackout
    case emergencyGuides
}

@MainActor
final class NavigationRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var requestedPlanFocus: PlanFocus?
    @Published var activeOverlay: OverlayMode?
    @Published var highlightedGuideCategory: GuideCategory?
    @Published private var tabScrollToTopRequests: [AppTab: Int] = [:]

    // MARK: - Computed Bindings for SwiftUI Presentation

    var isShowingEmergencyMode: Bool {
        activeOverlay == .emergencyMode
    }

    var isShowingLeaveNowMode: Bool {
        activeOverlay == .leaveNow
    }

    var isShowingBlackout: Bool {
        activeOverlay == .blackout
    }

    var isShowingEmergencyGuides: Bool {
        activeOverlay == .emergencyGuides
    }

    var emergencyModeBinding: Binding<Bool> {
        Binding(
            get: { self.activeOverlay == .emergencyMode },
            set: { if !$0 { self.activeOverlay = nil } }
        )
    }

    var leaveNowModeBinding: Binding<Bool> {
        Binding(
            get: { self.activeOverlay == .leaveNow },
            set: { if !$0 { self.activeOverlay = nil } }
        )
    }

    var blackoutBinding: Binding<Bool> {
        Binding(
            get: { self.activeOverlay == .blackout },
            set: { if !$0 { self.activeOverlay = nil } }
        )
    }

    var emergencyGuidesBinding: Binding<Bool> {
        Binding(
            get: { self.activeOverlay == .emergencyGuides },
            set: { if !$0 { self.activeOverlay = nil } }
        )
    }

    // MARK: - Quick Actions

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

    func restoreEmergencyAccessSessionIfNeeded(appState: AppState) {
        if activeOverlay != nil || appState.isLowBatterySurvivalModeEnabled {
            appState.beginEmergencyAccessSession()
        }
    }

    // MARK: - Tab Navigation

    func openAsk() {
        requestedPlanFocus = nil
        selectedTab = .ask
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
        // The full library is now hidden from primary user navigation.
        // Keep legacy calls stable by resolving them to More.
        selectedTab = .more
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

    func openProfileStep(_ step: ProfileCompletionStep) {
        switch step.id {
        case "household", "contact", "route":
            requestedPlanFocus = .householdOverview
        case "supplies":
            requestedPlanFocus = .supplies
        case "medical":
            requestedPlanFocus = .medicalProfile
        case "gear":
            requestedPlanFocus = .gearChecklist
        default:
            requestedPlanFocus = .householdOverview
        }
        selectedTab = .plan
    }

    func openSignalNearby() {
        activeOverlay = nil
        highlightedGuideCategory = nil
        selectedTab = .signal
    }

    // MARK: - Overlay Presentation

    func presentEmergencyGuides(appState: AppState) {
        appState.beginEmergencyAccessSession()
        selectedTab = .home
        highlightedGuideCategory = .firstAid
        activeOverlay = .emergencyGuides
    }

    func presentBlackout(appState: AppState) {
        appState.beginEmergencyAccessSession()
        selectedTab = .home
        highlightedGuideCategory = nil
        setOverlay(.blackout)
    }

    func presentEmergencyMode(appState: AppState) {
        let startTime = CFAbsoluteTimeGetCurrent()
        appState.beginEmergencyAccessSession()
        highlightedGuideCategory = nil
        setOverlay(.emergencyMode)
        let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        RediLogger.performance.debug("Emergency mode transition prepared in \(elapsed, privacy: .public) ms")
    }

    func presentLeaveNowMode(appState: AppState) {
        appState.beginEmergencyAccessSession()
        highlightedGuideCategory = nil
        setOverlay(.leaveNow)
    }

    // MARK: - Overlay Dismissal

    func dismissEmergencyMode(appState: AppState) {
        setOverlay(nil)
        endSessionIfNoOverlayActive(appState: appState)
    }

    func dismissBlackout(appState: AppState) {
        setOverlay(nil)
        endSessionIfNoOverlayActive(appState: appState)
    }

    func didDismissEmergencyGuides(appState: AppState) {
        highlightedGuideCategory = nil
        activeOverlay = nil
        endSessionIfNoOverlayActive(appState: appState)
    }

    func dismissLeaveNowMode(appState: AppState) {
        setOverlay(nil)
        endSessionIfNoOverlayActive(appState: appState)
    }

    // MARK: - Overlay Transitions

    func openBlackoutFromEmergency() {
        setOverlay(nil)
        DispatchQueue.main.async {
            self.setOverlay(.blackout)
        }
    }

    func openLeaveNowFromEmergency() {
        setOverlay(nil)
        DispatchQueue.main.async {
            self.setOverlay(.leaveNow)
        }
    }

    func openTabFromEmergency(_ tab: AppTab, appState _: AppState) {
        setOverlay(nil)
        selectedTab = tab
        if tab != .plan {
            requestedPlanFocus = nil
        }
    }

    func openTabFromLeaveNow(_ tab: AppTab, appState _: AppState) {
        setOverlay(nil)
        selectedTab = tab
        if tab != .plan {
            requestedPlanFocus = nil
        }
    }

    // MARK: - Scroll

    func requestScrollToTop(for tab: AppTab) {
        tabScrollToTopRequests[tab, default: 0] += 1
    }

    private func setOverlay(_ overlay: OverlayMode?) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeOverlay = overlay
        }
    }

    func scrollToTopRequestID(for tab: AppTab) -> Int {
        tabScrollToTopRequests[tab, default: 0]
    }

    // MARK: - Private

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
            activeOverlay = nil
            highlightedGuideCategory = nil
            appState.enableStealthMode()
        case .flashlight:
            presentBlackout(appState: appState)
        }
    }

    private func endSessionIfNoOverlayActive(appState: AppState) {
        if activeOverlay == nil && !appState.isLowBatterySurvivalModeEnabled {
            appState.endEmergencyAccessSession()
        }
    }

    func consumeRequestedPlanFocus() -> PlanFocus? {
        let focus = requestedPlanFocus
        requestedPlanFocus = nil
        return focus
    }
}
