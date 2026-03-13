import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var appState: AppState
    @ObservedObject var router: NavigationRouter

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
            QuickActionCoordinator.shared.bind(appState: appState)
            router.handlePendingQuickAction(from: appState)
            Task {
                await appState.officialAlertService.refreshIfNeeded()
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
            guard newPhase == .background else { return }
            appState.documentVaultService.lock()
            router.handleBackgroundTransition(appState: appState)
        }
        .overlay {
            if appState.isStealthModeEnabled {
                Color.black.opacity(0.14)
                    .ignoresSafeArea()
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
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                HomeView(
                    appState: appState,
                    openPlan: { router.openPlan() },
                    openVault: { router.openVault() },
                    openLibrary: { router.openLibrary() },
                    openMap: { router.openMap() },
                    openVehicleReadiness: { router.openVehicleReadiness() },
                    openWaterRuntime: { router.openWaterRuntime() },
                    openBlackout: { router.presentBlackout(appState: appState) },
                    openSignalNearby: { router.openSignalNearby() },
                    openEmergencyGuides: { router.presentEmergencyGuides(appState: appState) },
                    openEmergency: { router.presentEmergencyMode(appState: appState) },
                    openLeaveNow: { router.presentLeaveNowMode(appState: appState) }
                )
            }
            .tag(AppTab.home)
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                PlanView(appState: appState, requestedFocus: $router.requestedPlanFocus)
            }
            .tag(AppTab.plan)
            .tabItem { Label("Plan", systemImage: "checklist") }

            NavigationStack {
                SecureVaultView(service: appState.documentVaultService)
            }
            .tag(AppTab.vault)
            .tabItem { Label("Vault", systemImage: "lock.doc.fill") }

            NavigationStack {
                GuideLibraryView(appState: appState)
            }
            .tag(AppTab.library)
            .tabItem { Label("Library", systemImage: "books.vertical.fill") }

            NavigationStack {
                MapView(
                    appState: appState,
                    openEvacuationRoutes: { router.openEvacuationRoutes() }
                )
            }
            .tag(AppTab.map)
            .tabItem { Label("Map", systemImage: "map.fill") }

            NavigationStack {
                SignalView(appState: appState)
            }
            .tag(AppTab.signal)
            .tabItem { Label("Signal", systemImage: "antenna.radiowaves.left.and.right") }
        }
        .toolbar(.hidden, for: .tabBar)
        .background(AmbientBackground(style: ambientBackgroundStyle))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            mainTabBar
        }
        .fullScreenCover(isPresented: $router.isShowingEmergencyMode) {
            EmergencyModeView(
                appState: appState,
                dismiss: { router.dismissEmergencyMode(appState: appState) },
                openBlackout: { router.openBlackoutFromEmergency() },
                openSignal: { router.openTabFromEmergency(.signal, appState: appState) },
                openMap: { router.openTabFromEmergency(.map, appState: appState) },
                openLeaveNow: { router.openLeaveNowFromEmergency() }
            )
        }
        .fullScreenCover(isPresented: $router.isShowingLeaveNowMode) {
            LeaveNowView(
                appState: appState,
                dismiss: { router.dismissLeaveNowMode(appState: appState) },
                openMap: { router.openTabFromLeaveNow(.map, appState: appState) },
                openSignal: { router.openTabFromLeaveNow(.signal, appState: appState) }
            )
        }
        .fullScreenCover(isPresented: $router.isShowingBlackout) {
            BlackoutModeView(
                appState: appState,
                dismiss: { router.dismissBlackout(appState: appState) },
                switchToTab: { tab in
                    router.selectedTab = tab
                    router.dismissBlackout(appState: appState)
                }
            )
        }
        .sheet(isPresented: $router.isShowingEmergencyGuides, onDismiss: {
            router.didDismissEmergencyGuides(appState: appState)
        }) {
            NavigationStack {
                GuideLibraryView(appState: appState, highlightedCategory: router.highlightedGuideCategory)
            }
            .rediSheetPresentation(style: .library, accent: ColorTheme.archive)
        }
        .fullScreenCover(isPresented: onboardingPresentationBinding) {
            OnboardingContainerView(appState: appState)
        }
    }

    private var mainTabBar: some View {
        let items: [CommandDockItemModel<AppTab>] = [
            CommandDockItemModel(dockID: .home, title: "Home", systemImage: "house.fill", accent: ColorTheme.accent),
            CommandDockItemModel(dockID: .plan, title: "Plan", systemImage: "checklist", accent: ColorTheme.warning),
            CommandDockItemModel(dockID: .vault, title: "Vault", systemImage: "lock.doc.fill", accent: ColorTheme.secure),
            CommandDockItemModel(dockID: .library, title: "Library", systemImage: "books.vertical.fill", accent: ColorTheme.archive),
            CommandDockItemModel(dockID: .map, title: "Map", systemImage: "map.fill", accent: ColorTheme.terrain),
            CommandDockItemModel(dockID: .signal, title: "Signal", systemImage: "antenna.radiowaves.left.and.right", accent: ColorTheme.comms)
        ]

        return CommandDock(items: items, selectedID: router.selectedTab) { tab in
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

    private var ambientBackgroundStyle: AmbientBackgroundStyle {
        switch router.selectedTab {
        case .home:
            .home
        case .plan:
            .plan
        case .vault:
            .vault
        case .library:
            .library
        case .map:
            .map
        case .signal:
            .signal
        }
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
