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
        activeOverlay = .blackout
    }

    func presentEmergencyMode(appState: AppState) {
        appState.beginEmergencyAccessSession()
        highlightedGuideCategory = nil
        activeOverlay = .emergencyMode
    }

    func presentLeaveNowMode(appState: AppState) {
        appState.beginEmergencyAccessSession()
        highlightedGuideCategory = nil
        activeOverlay = .leaveNow
    }

    // MARK: - Overlay Dismissal

    func dismissEmergencyMode(appState: AppState) {
        activeOverlay = nil
        endSessionIfNoOverlayActive(appState: appState)
    }

    func dismissBlackout(appState: AppState) {
        activeOverlay = nil
        endSessionIfNoOverlayActive(appState: appState)
    }

    func didDismissEmergencyGuides(appState: AppState) {
        highlightedGuideCategory = nil
        activeOverlay = nil
        endSessionIfNoOverlayActive(appState: appState)
    }

    func dismissLeaveNowMode(appState: AppState) {
        activeOverlay = nil
        endSessionIfNoOverlayActive(appState: appState)
    }

    // MARK: - Overlay Transitions

    func openBlackoutFromEmergency() {
        activeOverlay = nil
        DispatchQueue.main.async {
            self.activeOverlay = .blackout
        }
    }

    func openLeaveNowFromEmergency() {
        activeOverlay = nil
        DispatchQueue.main.async {
            self.activeOverlay = .leaveNow
        }
    }

    func openTabFromEmergency(_ tab: AppTab, appState _: AppState) {
        activeOverlay = nil
        selectedTab = tab
        if tab != .plan {
            requestedPlanFocus = nil
        }
    }

    func openTabFromLeaveNow(_ tab: AppTab, appState _: AppState) {
        activeOverlay = nil
        selectedTab = tab
        if tab != .plan {
            requestedPlanFocus = nil
        }
    }

    // MARK: - Scroll

    func requestScrollToTop(for tab: AppTab) {
        tabScrollToTopRequests[tab, default: 0] += 1
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
