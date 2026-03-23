import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var appState: AppState
    @ObservedObject var router: NavigationRouter
    private let launchConfiguration: AppLaunchConfiguration
    @State private var loadedTabs: Set<AppTab>

    init(appState: AppState, router: NavigationRouter, launchConfiguration: AppLaunchConfiguration) {
        self.appState = appState
        self.router = router
        self.launchConfiguration = launchConfiguration
        _loadedTabs = State(initialValue: [router.selectedTab])
    }

    var body: some View {
        Group {
            if appState.isLowBatterySurvivalModeEnabled {
                SurvivalModeView(
                    appState: appState,
                    disable: { appState.disableLowBatterySurvivalMode() }
                )
            } else {
                mainTabView
            }
        }
        .alert("Enable Low Power Survival Mode?", isPresented: survivalPromptBinding) {
            Button("Enable") {
                appState.enableLowBatterySurvivalMode()
            }
            Button("Not Now", role: .cancel) {
                appState.dismissSurvivalModePrompt()
            }
        } message: {
            Text("Battery is at \(appState.batteryStatus.percentageText). RediM8 can switch to a simplified interface to preserve power.")
        }
        .onAppear {
            appState.startIfNeeded()
            QuickActionCoordinator.shared.bind(appState: appState)
            router.handlePendingQuickAction(from: appState)
            if !launchConfiguration.disablesAutomaticAlertRefresh {
                Task {
                    await appState.officialAlertService.refreshIfNeeded()
                }
            }
        }
        .onChange(of: appState.pendingQuickAction) { _, _ in
            router.handlePendingQuickAction(from: appState)
        }
        .onChange(of: appState.isShowingOnboarding) { _, isShowingOnboarding in
            guard !isShowingOnboarding, !appState.isEmergencyAccessActive else { return }

            let restoreHome = {
                router.requestedPlanFocus = nil
                router.selectedTab = .home
            }

            if shouldAnimateShellMotion {
                withAnimation(RediMotion.selection) {
                    restoreHome()
                }
            } else {
                restoreHome()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                router.restoreEmergencyAccessSessionIfNeeded(appState: appState)
                guard !launchConfiguration.disablesAutomaticAlertRefresh else {
                    return
                }
                Task {
                    await appState.officialAlertService.refreshIfNeeded()
                }
            case .background:
                appState.documentVaultService.lock()
                router.handleBackgroundTransition(appState: appState)
            default:
                break
            }
        }
        .overlay {
            if appState.isStealthModeEnabled {
                Color.black.opacity(0.14)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        // Emergency mode: subtle danger tint on top safe area
        .overlay(alignment: .top) {
            if router.isShowingEmergencyMode {
                ColorTheme.danger.opacity(0.06)
                    .frame(height: 1)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
            }
        }
        .transaction { transaction in
            if appState.isStealthModeEnabled {
                transaction.disablesAnimations = true
            }
        }
    }

    private var onboardingPresentationBinding: Binding<Bool> {
        Binding(
            get: {
                appState.isShowingOnboarding && !appState.isEmergencyAccessActive
            },
            set: { isPresented in
                if !isPresented {
                    appState.isShowingOnboarding = false
                }
            }
        )
    }

    private var mainTabView: some View {
        VStack(spacing: 0) {
            SituationHeader(
                appState: appState,
                isEmergencyActive: router.isShowingEmergencyMode
            )

            ZStack {
                tabLayer(.home) {
                    HomeView(
                        appState: appState,
                        router: router,
                        scrollToTopRequestID: router.scrollToTopRequestID(for: .home),
                        disablesAutomaticAlertRefresh: launchConfiguration.disablesAutomaticAlertRefresh
                    )
                }

                tabLayer(.ask) {
                    AskRediView(
                        appState: appState,
                        scrollToTopRequestID: router.scrollToTopRequestID(for: .ask),
                        router: router
                    )
                }

                tabLayer(.more) {
                    MoreView(
                        appState: appState,
                        router: router,
                        scrollToTopRequestID: router.scrollToTopRequestID(for: .more),
                        disablesAutomaticLocationPrompts: launchConfiguration.disablesAutomaticLocationPrompts
                    )
                }

                tabLayer(.map) {
                    MapView(
                        appState: appState,
                        scrollToTopRequestID: router.scrollToTopRequestID(for: .map),
                        openEvacuationRoutes: { router.openEvacuationRoutes() },
                        disablesAutomaticMapActivity: launchConfiguration.disablesAutomaticMapActivity
                    )
                }

                tabLayer(.signal) {
                    SignalView(
                        appState: appState,
                        scrollToTopRequestID: router.scrollToTopRequestID(for: .signal)
                    )
                }
            }
            .frame(maxHeight: .infinity)
        }
        .accessibilityHidden(router.isShowingEmergencyMode)
        .onAppear {
            loadedTabs.insert(router.selectedTab)
        }
        .onChange(of: router.selectedTab) { _, newTab in
            loadedTabs.insert(newTab)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            mainTabBar
        }
        .overlay {
            if router.isShowingEmergencyMode {
                EmergencyModeView(
                    appState: appState,
                    dismiss: { router.dismissEmergencyMode(appState: appState) },
                    openBlackout: { router.openBlackoutFromEmergency() },
                    openSignal: { router.openTabFromEmergency(.signal, appState: appState) },
                    openMap: { router.openTabFromEmergency(.map, appState: appState) },
                    openLeaveNow: { router.openLeaveNowFromEmergency() }
                )
                .transition(.identity)
                .zIndex(2)
            }
        }
        .fullScreenCover(isPresented: router.leaveNowModeBinding) {
            LeaveNowView(
                appState: appState,
                dismiss: { router.dismissLeaveNowMode(appState: appState) },
                openMap: { router.openTabFromLeaveNow(.map, appState: appState) },
                openSignal: { router.openTabFromLeaveNow(.signal, appState: appState) }
            )
            .interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: router.blackoutBinding) {
            BlackoutModeView(
                appState: appState,
                dismiss: { router.dismissBlackout(appState: appState) },
                switchToTab: { tab in
                    router.selectedTab = tab
                    router.dismissBlackout(appState: appState)
                }
            )
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: router.emergencyGuidesBinding, onDismiss: {
            router.didDismissEmergencyGuides(appState: appState)
        }) {
            NavigationStack {
                GuideLibraryView(appState: appState, highlightedCategory: router.highlightedGuideCategory)
            }
            .rediSheetPresentation()
        }
        .fullScreenCover(isPresented: onboardingPresentationBinding) {
            if appState.isElevatedThreat {
                EmergencyBootstrapView(
                    appState: appState,
                    completeBootstrap: {
                        appState.completeOnboarding(with: appState.profile.markedOnboarded())
                    },
                    openMap: { router.openMap() },
                    openSignal: { router.openSignalNearby() }
                )
            } else {
                OnboardingContainerView(appState: appState)
            }
        }
    }

    @ViewBuilder
    private func tabLayer<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        if loadedTabs.contains(tab) {
            NavigationStack {
                content()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(router.selectedTab == tab ? 1 : 0)
            .allowsHitTesting(router.selectedTab == tab)
            .accessibilityHidden(router.selectedTab != tab)
            .zIndex(router.selectedTab == tab ? 1 : 0)
        }
    }

    private var mainTabBar: some View {
        let items: [CommandDockItemModel<AppTab>] = [
            CommandDockItemModel(dockID: .home, title: "Home", systemImage: "house.fill", accent: ColorTheme.accent),
            CommandDockItemModel(dockID: .ask, title: "Ask Redi", systemImage: "sparkles", accent: ColorTheme.accent),
            CommandDockItemModel(dockID: .map, title: "Map", systemImage: "map.fill", accent: ColorTheme.accent),
            CommandDockItemModel(dockID: .signal, title: "Signal", systemImage: "antenna.radiowaves.left.and.right", accent: ColorTheme.accent),
            CommandDockItemModel(dockID: .more, title: "More", systemImage: "square.grid.2x2.fill", accent: ColorTheme.accent)
        ]

        return CommandDock(items: items, selectedID: router.selectedTab) { tab in
            router.requestScrollToTop(for: tab)

            guard router.selectedTab != tab else { return }

            let updateSelection = {
                router.selectedTab = tab
                if tab != .plan {
                    router.requestedPlanFocus = nil
                }
            }

            RediHaptics.selection(enabled: !appState.isStealthModeEnabled)

            if shouldAnimateShellMotion {
                withAnimation(RediMotion.selection) {
                    updateSelection()
                }
            } else {
                updateSelection()
            }
        }
    }

    private var shouldAnimateShellMotion: Bool {
        !reduceMotion && !appState.isStealthModeEnabled
    }

    private var survivalPromptBinding: Binding<Bool> {
        Binding(
            get: { appState.shouldPromptForSurvivalMode && !appState.isLowBatterySurvivalModeEnabled },
            set: { isPresented in
                if !isPresented {
                    appState.dismissSurvivalModePrompt()
                }
            }
        )
    }
}
