import SwiftUI

struct SignalView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: SignalViewModel
    private let appState: AppState
    private let scrollToTopRequestID: Int
    @State private var isShowingSessionFeed = false
    @State private var isSignalPulseActive = false
    @State private var selectedWorkspace: SignalWorkspace = .communicate
    @State private var assistantContext: AssistantLaunchContext?
    @State private var signalScrollOffset: CGFloat = 0
    private let quickMessageTemplates = ["NEED WATER", "SAFE LOCATION", "FIRE NEARBY", "NEED PICKUP"]

    init(appState: AppState, scrollToTopRequestID: Int = 0) {
        self.appState = appState
        self.scrollToTopRequestID = scrollToTopRequestID
        _viewModel = StateObject(wrappedValue: SignalViewModel(appState: appState))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Color.clear
                            .frame(height: 0)
                            .id(SignalScrollAnchor.top)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: SignalScrollOffsetPreferenceKey.self,
                                        value: proxy.frame(in: .named(SignalScrollSpace.name)).minY
                                    )
                                }
                            )

                        if viewModel.isStealthModeEnabled {
                            StealthModeIndicatorView()
                        }

                        if viewModel.isAnonymousModeEnabled {
                            HiddenModeIndicatorView(actionTitle: "Turn Off") {
                                viewModel.disableHiddenMode()
                            }
                        }

                        if !appState.isElevatedThreat {
                            CinematicBanner("signal_vehicle_link", height: 160)
                        }

                        meshStatusBanner

                        if !appState.isElevatedThreat {
                            signalCommandCenterCard
                            signalWorkspaceDeck
                        }
                        activeWorkspaceContent
                    }
                    .padding(20)
                    .padding(.bottom, signalContentBottomInset)
                }
                .coordinateSpace(name: SignalScrollSpace.name)
                .onChange(of: scrollToTopRequestID) { _, _ in
                    DispatchQueue.main.async {
                        withAnimation(RediMotion.selection) {
                            proxy.scrollTo(SignalScrollAnchor.top, anchor: .top)
                        }
                    }
                }
                .onPreferenceChange(SignalScrollOffsetPreferenceKey.self) { offset in
                    signalScrollOffset = offset
                }
            }

            if shouldShowSignalCommandDock {
                signalCommandDock
                    .padding(.horizontal, RediSpacing.screen)
                    .padding(.bottom, max(RediSpacing.content, RediLayout.commandDockContentInset))
                    .scaleEffect(signalDockScale, anchor: .bottom)
                    .offset(y: signalDockVerticalOffset)
                    .opacity(signalDockOpacity)
                    .animation(reduceMotion ? nil : RediMotion.selection, value: signalDockCollapseProgress)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Signal")
        .safeAreaInset(edge: .top, spacing: 0) {
            OperationalStatusRail(items: viewModel.statusItems, accent: signalStatusColor)
        }
        .background(
            ColorTheme.panel
            .ignoresSafeArea()
        )
        .onAppear {
            viewModel.onAppear()
            startSignalPulse()
        }
        .onDisappear { viewModel.onDisappear() }
        .alert(item: $viewModel.beaconNotice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
        .fullScreenCover(isPresented: $viewModel.isShowingAnalogSignalMode) {
            AnalogSignalModeView(viewModel: viewModel)
        }
        .sheet(item: $assistantContext) { context in
            NavigationStack {
                AssistantView(
                    appState: appState,
                    initialQuery: context.initialQuery,
                    sourceLabel: context.sourceLabel
                )
            }
            .rediSheetPresentation()
        }
    }

    // MARK: - Scroll Anchor

    private enum SignalScrollAnchor {
        static let top = "signal-scroll-top"
    }

    // MARK: - Command Dock

    private var signalCommandDock: some View {
        ThumbActionDock {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    broadcastDockButton
                    shareGPSDockButton
                    reportDockButton
                }

                VStack(spacing: 8) {
                    broadcastDockButton

                    HStack(spacing: 8) {
                        shareGPSDockButton
                        reportDockButton
                    }
                }
            }
        }
    }

    private var shouldShowSignalCommandDock: Bool {
        selectedWorkspace == .communicate
    }

    private var signalContentBottomInset: CGFloat {
        if shouldShowSignalCommandDock {
            return 80 + RediLayout.commandDockContentInset
        }

        return RediLayout.commandDockContentInset
    }

    private var signalDockCollapseProgress: CGFloat {
        guard shouldShowSignalCommandDock else { return 0 }

        let downwardTravel = max(0, -signalScrollOffset)
        return min(1, downwardTravel / 72)
    }

    private var signalDockScale: CGFloat {
        1 - (signalDockCollapseProgress * 0.08)
    }

    private var signalDockVerticalOffset: CGFloat {
        signalDockCollapseProgress * 20
    }

    private var signalDockOpacity: Double {
        Double(1 - (signalDockCollapseProgress * 0.08))
    }

    // MARK: - Dock Buttons

    private var broadcastDockButton: some View {
        SignalViewHelpers.signalDockButton(
            title: "Broadcast Alert",
            detail: hasDraftMessage ? "Send urgent alert nearby" : "Add text first",
            status: broadcastDockStatus,
            systemImage: "exclamationmark.triangle.fill",
            tint: canTriggerBroadcast ? ColorTheme.danger : ColorTheme.warning,
            prominence: .critical,
            isEnabled: canTriggerBroadcast
        ) {
            viewModel.broadcastAlert()
        }
    }

    private var shareGPSDockButton: some View {
        SignalViewHelpers.signalDockButton(
            title: "Share Location",
            detail: canShareCurrentLocation ? "Send current position" : shareDockDetail,
            status: shareDockStatus,
            systemImage: "location.fill",
            tint: canShareCurrentLocation ? ColorTheme.accent : ColorTheme.warning,
            prominence: .standard,
            isEnabled: canShareCurrentLocation
        ) {
            viewModel.shareLocation()
        }
    }

    private var reportDockButton: some View {
        SignalViewHelpers.signalDockButton(
            title: viewModel.activeBeacon == nil ? "Send Report" : "Update Report",
            detail: viewModel.activeBeacon == nil ? "Broadcast local situation" : "Refresh live broadcast",
            status: reportDockStatus,
            systemImage: "dot.radiowaves.left.and.right",
            tint: reportDockTint,
            prominence: .accented,
            isEnabled: canManageReport
        ) {
            viewModel.activateBeacon()
        }
    }

    // MARK: - Hero Card

    private var signalCommandCenterCard: some View {
        ModeHeroCard(
            eyebrow: "Lifeline System",
            title: "Signal",
            subtitle: "Emergency communication when networks fail.",
            iconName: "signal",
            accent: signalStatusColor
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TrustPillGroup(items: viewModel.signalTrustItems)

                if isSignalEmpty {
                    signalOnboardingPrompt
                } else {
                    signalHeroMetrics
                }
            }
        }
    }

    /// True when the user has no peers and no activity — show guidance instead of empty metrics.
    private var isSignalEmpty: Bool {
        viewModel.nearbyPeers.isEmpty && viewModel.sessionMessages.isEmpty
    }

    private var signalOnboardingPrompt: some View {
        VStack(alignment: .leading, spacing: RediSpacing.compact) {
            Text("Signal connects you to nearby devices when networks fail. Open this tab when others are nearby to exchange messages, share locations, and broadcast alerts.")
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TrustPillGroup(items: [
                TrustPillItem(title: "No internet needed", tone: .verified),
                TrustPillItem(title: "Bluetooth range", tone: .info),
                TrustPillItem(title: "Auto-discovers peers", tone: .neutral)
            ])
        }
        .padding(RediSpacing.content)
        .background(ColorTheme.graphite, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
    }

    private var signalHeroMetrics: some View {
        LazyVGrid(columns: signalHeroMetricColumns, spacing: 12) {
            SignalViewHelpers.signalMetricTile(
                title: "Nearby",
                value: viewModel.nearbyPeerSummary,
                detail: viewModel.connectedPeerSummary,
                iconName: "family",
                tint: viewModel.nearbyPeers.isEmpty ? ColorTheme.textTertiary : signalStatusColor
            )
            SignalViewHelpers.signalMetricTile(
                title: "Broadcast",
                value: viewModel.canBroadcastOutboundSignals ? "Ready" : "Receive-only",
                detail: "Emergency alert to nearby devices",
                iconName: "exclamationmark.triangle.fill",
                tint: viewModel.canBroadcastOutboundSignals ? ColorTheme.danger : ColorTheme.warning
            )
            SignalViewHelpers.signalMetricTile(
                title: "Location",
                value: viewModel.workingLocationSummary,
                detail: viewModel.currentLocation == nil ? "Awaiting GPS" : "Share state ready",
                iconName: "location.fill",
                tint: viewModel.canShareLocation ? ColorTheme.accent : ColorTheme.warning
            )
            SignalViewHelpers.signalMetricTile(
                title: "Last Activity",
                value: viewModel.lastSignalLabel,
                detail: viewModel.sessionMessages.isEmpty ? "No messages received" : "Latest local signal event",
                iconName: "clock",
                tint: viewModel.sessionMessages.isEmpty ? ColorTheme.textTertiary : signalStatusColor
            )
        }
    }

    private var signalHeroMetricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    // MARK: - Mesh Status Banner

    private var meshStatusBanner: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(signalStatusColor.opacity(isSignalPulseActive ? 0.16 : 0.08))
                        .frame(width: 54, height: 54)
                        .scaleEffect(isSignalPulseActive ? 1.08 : 0.92)

                    RediIcon("signal")
                        .foregroundStyle(signalStatusColor)
                        .frame(width: 18, height: 18)
                        .padding(10)
                        .background(signalStatusColor.opacity(0.14), in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("LIFELINE STATUS")
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(signalStatusColor)

                        Text(viewModel.meshStatusLabel.uppercased())
                            .font(.caption2.weight(.black))
                            .foregroundStyle(signalStatusColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(signalStatusColor.opacity(0.14), in: Capsule())
                    }
                    Text(viewModel.meshStatusHeadline)
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)
                    Text(viewModel.meshStatusDetail)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            meshStatusSnapshot
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .fill(ColorTheme.panelElevated)

                Image("signal_beacon_node")
                    .resizable()
                    .scaledToFill()
                    .saturation(0.9)
                    .contrast(1.04)
                    .brightness(-0.05)
                    .overlay {
                        Color.black.opacity(0.58)
                    }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                .stroke(signalStatusColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var meshStatusSnapshot: some View {
        HStack(spacing: 10) {
            SignalViewHelpers.meshBannerStat(title: "Connections", value: viewModel.connectedPeerSummary, tint: signalStatusColor)
            SignalViewHelpers.meshBannerStat(title: "Relay", value: viewModel.relayStatusSummary, tint: beaconRelayTint)
            SignalViewHelpers.meshBannerStat(title: "Last Activity", value: viewModel.lastSignalLabel, tint: signalStatusColor)
        }
    }

    // MARK: - Workspace Selector

    private var signalWorkspaceDeck: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Workspace", selection: $selectedWorkspace) {
                ForEach(SignalWorkspace.allCases) { workspace in
                    Text(workspace.title).tag(workspace)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedWorkspace.subtitle)
                .font(.caption)
                .foregroundStyle(ColorTheme.textSecondary)
        }
    }

    // MARK: - Active Workspace Content

    @ViewBuilder
    private var activeWorkspaceContent: some View {
        switch selectedWorkspace {
        case .communicate:
            SignalCommunicateWorkspaceView(
                viewModel: viewModel,
                signalStatusColor: signalStatusColor,
                quickMessageTemplates: quickMessageTemplates,
                assistantContextAction: { context in
                    assistantContext = context
                }
            )
        case .network:
            SignalNetworkWorkspaceView(viewModel: viewModel)
        case .system:
            SignalSystemWorkspaceView(
                viewModel: viewModel,
                isShowingSessionFeed: $isShowingSessionFeed,
                isSignalPulseActive: isSignalPulseActive,
                signalStatusColor: signalStatusColor
            )
        }
    }

    // MARK: - Computed Helpers

    private var trimmedDraftMessage: String {
        viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasDraftMessage: Bool {
        !trimmedDraftMessage.isEmpty
    }

    private var canTriggerBroadcast: Bool {
        viewModel.canBroadcastOutboundSignals && hasDraftMessage
    }

    private var canShareCurrentLocation: Bool {
        viewModel.canShareLocation && viewModel.currentLocation != nil
    }

    private var canManageReport: Bool {
        viewModel.activeBeacon != nil || viewModel.beaconAvailabilityMessage == nil
    }

    private var broadcastDockStatus: String {
        if !viewModel.canBroadcastOutboundSignals {
            return "Receive-only"
        }
        return hasDraftMessage ? "Ready" : "Need Text"
    }

    private var shareDockStatus: String {
        if !viewModel.canShareLocation {
            return "Location Off"
        }
        return viewModel.currentLocation == nil ? "Need GPS" : "Ready"
    }

    private var reportDockStatus: String {
        if viewModel.activeBeacon != nil {
            return "Live"
        }
        return canManageReport ? "Ready" : "Need GPS"
    }

    private var shareDockDetail: String {
        if !viewModel.canShareLocation {
            return "Location sharing off"
        }
        return "GPS lock pending"
    }

    private var reportDockTint: Color {
        if let activeBeacon = viewModel.activeBeacon {
            return SignalViewHelpers.beaconAccentColor(for: activeBeacon.type)
        }

        if canManageReport {
            return SignalViewHelpers.beaconAccentColor(for: viewModel.selectedBeaconType)
        }

        return ColorTheme.warning
    }

    // MARK: - Status Colors

    private var signalStatusColor: Color {
        switch viewModel.meshStatusTone {
        case .ready:
            ColorTheme.ready
        case .info:
            ColorTheme.statusInfo
        case .caution:
            ColorTheme.statusWarning
        case .danger:
            ColorTheme.statusDanger
        case .neutral:
            ColorTheme.textTertiary
        }
    }

    private var beaconRelayTint: Color {
        viewModel.relayStatusSummary == "No relay queued" ? ColorTheme.textTertiary : ColorTheme.accent
    }

    // MARK: - Signal Pulse

    private func startSignalPulse() {
        guard !reduceMotion else {
            isSignalPulseActive = false
            return
        }

        withAnimation(RediMotion.reveal) {
            isSignalPulseActive = true
        }
    }
}
