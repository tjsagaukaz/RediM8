import SwiftUI

private enum SignalWorkspace: String, CaseIterable, Identifiable {
    case communicate
    case network
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .communicate: "Signal"
        case .network: "Network"
        case .system: "System"
        }
    }

    var subtitle: String {
        switch self {
        case .communicate: "Broadcasts, direct signals, and field reports"
        case .network: "Nearby devices, roll call, and relayed reports"
        case .system: "Scanner, limits, and session activity"
        }
    }
}

struct SignalView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: SignalViewModel
    private let appState: AppState
    private let scrollToTopRequestID: Int
    @State private var isShowingSessionFeed = false
    @State private var isSignalPulseActive = false
    @State private var selectedWorkspace: SignalWorkspace = .communicate
    @State private var assistantContext: AssistantLaunchContext?
    private let quickMessageTemplates = ["NEED WATER", "SAFE LOCATION", "FIRE NEARBY", "NEED PICKUP"]

    init(appState: AppState, scrollToTopRequestID: Int = 0) {
        self.appState = appState
        self.scrollToTopRequestID = scrollToTopRequestID
        _viewModel = StateObject(wrappedValue: SignalViewModel(appState: appState))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear
                        .frame(height: 0)
                        .id(SignalScrollAnchor.top)

                    if viewModel.isStealthModeEnabled {
                        StealthModeIndicatorView()
                    }

                    if viewModel.isAnonymousModeEnabled {
                        HiddenModeIndicatorView(actionTitle: "Turn Off") {
                            viewModel.disableHiddenMode()
                        }
                    }

                    CinematicBanner("signal_vehicle_link", height: 160)

                    meshStatusBanner

                    signalCommandCenterCard
                    signalWorkspaceDeck
                    activeWorkspaceContent
                }
                .padding(20)
            }
            .onChange(of: scrollToTopRequestID) { _, _ in
                DispatchQueue.main.async {
                    withAnimation(RediMotion.selection) {
                        proxy.scrollTo(SignalScrollAnchor.top, anchor: .top)
                    }
                }
            }
        }
        .navigationTitle("Signal")
        .safeAreaInset(edge: .top, spacing: 0) {
            OperationalStatusRail(items: viewModel.statusItems, accent: signalStatusColor)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            signalCommandDock
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, 6)
                .padding(.bottom, 80)
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

    private enum SignalScrollAnchor {
        static let top = "signal-scroll-top"
    }

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

    private var broadcastDockButton: some View {
        signalDockButton(
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
        signalDockButton(
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
        signalDockButton(
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

    private var signalCommandColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 108, maximum: 170), spacing: 10)
        ]
    }

    private var signalCommandStatusGrid: some View {
        LazyVGrid(columns: signalCommandColumns, spacing: 10) {
            commandStatusTile(
                title: "Broadcast Alert",
                value: broadcastDockStatus,
                detail: "Emergency message to nearby devices",
                iconName: "exclamationmark.triangle.fill",
                tint: canTriggerBroadcast ? ColorTheme.danger : ColorTheme.warning
            )
            commandStatusTile(
                title: "Share Location",
                value: shareDockStatus,
                detail: canShareCurrentLocation ? "Current position ready" : shareDockDetail,
                iconName: "location.fill",
                tint: canShareCurrentLocation ? ColorTheme.accent : ColorTheme.warning
            )
            commandStatusTile(
                title: "Send Report",
                value: reportDockStatus,
                detail: viewModel.activeBeacon == nil ? (canManageReport ? "Short local report" : "Enable reports + GPS") : "Live report broadcasting",
                iconName: "dot.radiowaves.left.and.right",
                tint: reportDockTint
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

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
                signalHeroMetrics
            }
        }
    }

    private var analogSignalLaunchButton: some View {
        Button {
            viewModel.openAnalogSignalMode()
        } label: {
            RediCommandCard(
                title: viewModel.analogSignalButtonTitle,
                detail: viewModel.analogSignalButtonDetail,
                systemImage: "flashlight.on.fill",
                tint: ColorTheme.textTertiary,
                badge: viewModel.analogSignalStatus,
                prominence: .accented,
                layout: .rail
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

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

    @ViewBuilder
    private var activeWorkspaceContent: some View {
        switch selectedWorkspace {
        case .communicate:
            sendWorkspaceContent
            reportsWorkspaceContent
        case .network:
            accountabilityWorkspaceContent
            nearbyWorkspaceContent
        case .system:
            scannerWorkspaceContent
            diagnosticsWorkspaceContent
        }
    }

    private var sendWorkspaceSummary: String {
        if let composeAvailabilityMessage = viewModel.composeAvailabilityMessage, !viewModel.canBroadcastOutboundSignals {
            return composeAvailabilityMessage
        }

        return "Alerts, direct messages, and location sharing are staged in the command dock."
    }

    private var reportsWorkspaceSummary: String {
        if let activeBeacon = viewModel.activeBeacon {
            return "\(activeBeacon.type.title) is active and can relay while fresh."
        }

        if let beaconAvailabilityMessage = viewModel.beaconAvailabilityMessage {
            return beaconAvailabilityMessage
        }

        return "Broadcast one clear local situation report if nearby users need it."
    }

    private var accountabilityWorkspaceSummary: String {
        viewModel.accountabilitySummary
    }

    private var nearbyWorkspaceSummary: String {
        if !viewModel.connectedPeers.isEmpty {
            return "\(viewModel.connectedPeerSummary) with \(viewModel.relayStatusSummary.lowercased())."
        }

        if !viewModel.displayedBeacons.isEmpty {
            let noun = viewModel.displayedBeacons.count == 1 ? "report" : "reports"
            return "\(viewModel.displayedBeacons.count) nearby \(noun) visible right now."
        }

        return "No nearby users or relayed reports are visible yet."
    }

    private var scannerWorkspaceSummary: String {
        viewModel.scannerSummary
    }

    private var diagnosticsWorkspaceSummary: String {
        if signalFailureRows.isEmpty {
            return "Mesh limits, range, and session feed are available for reference."
        }

        return signalFailureRows.first?.title ?? "Diagnostics available"
    }

    private var sendWorkspaceContent: some View {
        VStack(spacing: 16) {
            sendUpdatePanel
        }
    }

    private var reportsWorkspaceContent: some View {
        VStack(spacing: 16) {
            communitySituationReportsPanel
        }
    }

    private var nearbyWorkspaceContent: some View {
        VStack(spacing: 16) {
            nearbySituationReportsPanel
            nearbyUsersPanel
        }
    }

    private var accountabilityWorkspaceContent: some View {
        VStack(spacing: 16) {
            accountabilityModePanel
        }
    }

    private var scannerWorkspaceContent: some View {
        VStack(spacing: 16) {
            localSituationalScannerPanel
        }
    }

    private var diagnosticsWorkspaceContent: some View {
        VStack(spacing: 16) {
            if !signalFailureRows.isEmpty {
                failureModesPanel
            }
            signalLimitsPanel
            meshDetailsPanel
            sessionFeedPanel
        }
    }

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
            return beaconAccentColor(for: activeBeacon.type)
        }

        if canManageReport {
            return beaconAccentColor(for: viewModel.selectedBeaconType)
        }

        return ColorTheme.warning
    }

    private var signalAssistantQuery: String? {
        if let activeBeacon = viewModel.activeBeacon {
            return "What should I do about \(activeBeacon.type.title.lowercased()) nearby?"
        }

        if !trimmedDraftMessage.isEmpty {
            return trimmedDraftMessage
        }

        return "What should I do about \(viewModel.selectedBeaconType.title.lowercased()) nearby?"
    }

    private var signalAssistantDetail: String {
        if let activeBeacon = viewModel.activeBeacon {
            return "Get next steps using the live \(activeBeacon.type.title.lowercased()) context before you transmit."
        }

        if !trimmedDraftMessage.isEmpty {
            return "Turn this draft into clear next steps before you send it."
        }

        return "Get next steps based on your current signal and report context."
    }

    private var urgentSituationReportTypes: [BeaconType] {
        let urgentOrder: [BeaconType] = [.fireSpotted, .medicalHelp, .floodedRoad]
        return urgentOrder.filter(viewModel.situationReportTypes.contains)
    }

    private var importantSituationReportTypes: [BeaconType] {
        viewModel.situationReportTypes.filter { !urgentSituationReportTypes.contains($0) }
    }

    private var sendUpdatePanel: some View {
        PanelCard(title: "Send Signal", subtitle: "Short transmission only. Optimised for low signal.") {
            VStack(alignment: .leading, spacing: 14) {
                signalCommandStatusGrid

                Button {
                    assistantContext = AssistantLaunchContext(
                        initialQuery: signalAssistantQuery,
                        sourceLabel: "Signal context"
                    )
                } label: {
                    RediCommandCard(
                        title: "Ask RediM8",
                        detail: signalAssistantDetail,
                        systemImage: "bubble.left.and.text.bubble.right.fill",
                        tint: signalStatusColor,
                        badge: "Context",
                        prominence: .accented,
                        layout: .rail
                    )
                }
                .buttonStyle(CardPressButtonStyle())

                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Starts")
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(quickMessageTemplates, id: \.self) { template in
                                messageTemplateButton(template)
                            }
                        }
                    }
                }

                TextField("What do others need to know?", text: $viewModel.draftMessage, axis: .vertical)
                    .lineLimit(4...8)
                    .textFieldStyle(TacticalTextFieldStyle())
                    .frame(minHeight: 108, alignment: .topLeading)
                    .disabled(!viewModel.canBroadcastOutboundSignals)

                Text("Use short text such as NEED WATER or FIRE NEARBY.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let composeAvailabilityMessage = viewModel.composeAvailabilityMessage {
                    Text(composeAvailabilityMessage)
                        .font(.caption)
                        .foregroundStyle(viewModel.canBroadcastOutboundSignals ? .secondary : ColorTheme.warning)
                }

                signalInsetCard(tint: ColorTheme.danger) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WHEN TO USE BROADCAST")
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.danger)

                        signalGuidanceLine("No signal or network")
                        signalGuidanceLine("Urgent situation nearby")
                        signalGuidanceLine("Need help or need to warn others")
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(ColorTheme.accent)
                    Text("Session activity stays in memory only on this phone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var communitySituationReportsPanel: some View {
        PanelCard(title: "Community Reports", subtitle: "Broadcast short local reports that can carry while they stay fresh") {
            VStack(alignment: .leading, spacing: 16) {
                Text(TrustLayer.beaconVerificationReminder)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TrustPillGroup(items: viewModel.draftBeaconTrustItems)

                if let activeBeacon = viewModel.activeBeacon {
                    signalInsetCard(tint: beaconAccentColor(for: activeBeacon.type)) {
                        HStack(alignment: .top) {
                            BeaconTypeBadge(type: activeBeacon.type)
                            Spacer()
                            Text("Broadcasting")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ColorTheme.ready)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(ColorTheme.ready.opacity(0.14), in: Capsule())
                        }

                        Text(activeBeacon.type.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(ColorTheme.text)

                        TrustPillGroup(items: viewModel.activeBeaconTrustItems(for: activeBeacon))

                        Text(activeBeacon.displayLabel)
                            .font(RediTypography.body)
                            .foregroundStyle(.secondary)

                        if let message = activeBeacon.message.nilIfBlank {
                            Text(message)
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.text)
                        }

                        if !activeBeacon.signalHighlights.isEmpty {
                            signalHighlightsBlock(activeBeacon.signalHighlights, accent: beaconAccentColor(for: activeBeacon.type))
                        }

                        if let sharedEmergencyMedicalSummary = activeBeacon.sharedEmergencyMedicalSummary {
                            sharedMedicalInfoBlock(sharedEmergencyMedicalSummary)
                        }

                        Text(activeBeacon.locationName)
                            .font(RediTypography.bodyStrong)
                            .foregroundStyle(ColorTheme.accent)

                        if !activeBeacon.resources.isEmpty {
                            BeaconResourceWrap(resources: activeBeacon.resources) { resource in
                                BeaconResourcePill(resource: resource, isSelected: true, action: {})
                            }
                        }

                        Text("Expires \(activeBeacon.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let staleWarning = viewModel.beaconStaleWarning(for: activeBeacon) {
                            Text(staleWarning)
                                .font(.caption)
                                .foregroundStyle(ColorTheme.warning)
                        }

                        HStack(spacing: 12) {
                            Button {
                                viewModel.refreshBeacon()
                            } label: {
                                Label("Refresh Broadcast", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(PrimaryActionButtonStyle())

                            Button {
                                viewModel.deactivateBeacon()
                            } label: {
                                Label("Stop Broadcast", systemImage: "xmark.circle")
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                }

                if !urgentSituationReportTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Urgent")
                            .font(RediTypography.heading)
                            .foregroundStyle(ColorTheme.text)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(urgentSituationReportTypes) { type in
                                situationReportButton(type)
                            }
                        }
                    }
                }

                if !importantSituationReportTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Important")
                            .font(RediTypography.heading)
                            .foregroundStyle(ColorTheme.text)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(importantSituationReportTypes) { type in
                                situationReportButton(type)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Starts")
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(quickMessageTemplates, id: \.self) { template in
                                reportQuickTemplateButton(template)
                            }
                        }
                    }
                }

                if !viewModel.secondaryBeaconTypes.isEmpty {
                    Picker("Other report types", selection: $viewModel.selectedBeaconType) {
                        ForEach(viewModel.secondaryBeaconTypes) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Text(viewModel.selectedReportLifetimeSummary)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textSecondary)

                TextField(viewModel.selectedReportLocationPrompt, text: $viewModel.beaconLocationName)
                    .textFieldStyle(TacticalTextFieldStyle())

                TextField(viewModel.selectedReportMessagePrompt, text: $viewModel.beaconMessage, axis: .vertical)
                    .textFieldStyle(TacticalTextFieldStyle())

                signalIntelligenceEditor

                if viewModel.selectedBeaconType.supportsEmergencyMedicalDisclosure {
                    signalInsetCard(tint: viewModel.includesEmergencyMedicalInfo ? ColorTheme.danger : ColorTheme.accent) {
                        Toggle("Include emergency medical info", isOn: $viewModel.includesEmergencyMedicalInfo)
                            .toggleStyle(.switch)
                            .foregroundStyle(ColorTheme.text)
                            .disabled(!viewModel.canAttachEmergencyMedicalInfo)

                        if let emergencyMedicalInfoStatusMessage = viewModel.emergencyMedicalInfoStatusMessage {
                            Text(emergencyMedicalInfoStatusMessage)
                                .font(.caption)
                                .foregroundStyle(viewModel.hasEmergencyMedicalInfo ? ColorTheme.textSecondary : ColorTheme.warning)
                        }

                        if let emergencyMedicalBroadcastPreview = viewModel.emergencyMedicalBroadcastPreview {
                            sharedMedicalInfoBlock(emergencyMedicalBroadcastPreview)
                        }
                    }
                }

                Toggle("Show optional display name", isOn: $viewModel.showsName)
                    .toggleStyle(.switch)
                    .foregroundStyle(ColorTheme.text)
                    .disabled(!viewModel.isDisplayNameControlEnabled)

                if !viewModel.isDisplayNameControlEnabled {
                    Text("Show Device Name is off in Settings, so nearby users will only see your node ID.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if viewModel.showsName {
                    TextField("Display name", text: $viewModel.displayName)
                        .textFieldStyle(TacticalTextFieldStyle())
                }

                if !orderedSelectedResources.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Linked tags")
                            .font(RediTypography.heading)
                            .foregroundStyle(ColorTheme.text)
                        BeaconResourceWrap(resources: orderedSelectedResources) { resource in
                            BeaconResourcePill(resource: resource, isSelected: true, action: {})
                        }
                    }
                }

                if let beaconAvailabilityMessage = viewModel.beaconAvailabilityMessage {
                    Text(beaconAvailabilityMessage)
                        .font(.caption)
                        .foregroundStyle(viewModel.canUseBeaconMode ? ColorTheme.danger : ColorTheme.warning)
                }

                Button {
                    viewModel.activateBeacon()
                } label: {
                    Label(viewModel.beaconActionTitle, systemImage: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(viewModel.beaconAvailabilityMessage != nil && viewModel.activeBeacon == nil)
            }
        }
    }

    private var nearbySituationReportsPanel: some View {
        PanelCard(title: "Nearby Reports", subtitle: "Temporary local reports discovered directly or relayed over the mesh") {
            if viewModel.displayedBeacons.isEmpty {
                Text("No nearby reports yet. No nearby devices or relayed report markers are visible in this session.")
                    .font(RediTypography.body)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    Text(TrustLayer.beaconVerificationReminder)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(viewModel.displayedBeacons) { beacon in
                        signalInsetCard(tint: beaconAccentColor(for: beacon.type)) {
                            beaconTypeStrip(for: beacon.type)

                            HStack(alignment: .top) {
                                BeaconTypeBadge(type: beacon.type)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(beacon.type.title)
                                        .font(RediTypography.heading)
                                        .foregroundStyle(ColorTheme.text)
                                    Text("\(beacon.displayLabel) • \(viewModel.beaconDistanceText(for: beacon))")
                                        .font(RediTypography.body)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if beacon.type.isPriorityReport {
                                    Text("Priority")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(ColorTheme.danger)
                                }
                            }

                            Text(beacon.statusText)
                                .font(RediTypography.bodyStrong)
                                .foregroundStyle(ColorTheme.text)

                            TrustPillGroup(items: viewModel.beaconTrustItems(for: beacon))

                            if !beacon.signalHighlights.isEmpty {
                                signalHighlightsBlock(beacon.signalHighlights, accent: beaconAccentColor(for: beacon.type))
                            }

                            if let message = beacon.message.nilIfBlank {
                                Text(message)
                                    .font(RediTypography.body)
                                    .foregroundStyle(.secondary)
                            }

                            if let sharedEmergencyMedicalSummary = beacon.sharedEmergencyMedicalSummary {
                                sharedMedicalInfoBlock(sharedEmergencyMedicalSummary)
                            }

                            Text(beacon.locationName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ColorTheme.accent)

                            Text("Expires \(beacon.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !beacon.resources.isEmpty {
                                BeaconResourceWrap(resources: beacon.resources) { resource in
                                    BeaconResourcePill(resource: resource, isSelected: true, action: {})
                                }
                            }

                            if let staleWarning = viewModel.beaconStaleWarning(for: beacon) {
                                Text(staleWarning)
                                    .font(.caption)
                                    .foregroundStyle(ColorTheme.warning)
                            } else if let relayDelayNotice = beacon.relayDelayNotice {
                                Text(relayDelayNotice)
                                    .font(.caption)
                                    .foregroundStyle(ColorTheme.warning)
                            }
                        }
                    }
                }
            }
        }
    }

    private var nearbyUsersPanel: some View {
        PanelCard(title: "Nearby Devices", subtitle: "Discovered over short-range local mesh only") {
            if viewModel.nearbyPeers.isEmpty {
                Text("No nearby devices detected. Keep Bluetooth and Wi-Fi enabled, then move within likely short range.")
                    .font(RediTypography.body)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.nearbyPeers) { peer in
                        signalInsetCard(tint: viewModel.connectedPeers.contains(peer) ? ColorTheme.accent : ColorTheme.warning) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(peer.displayName)
                                        .font(RediTypography.heading)
                                        .foregroundStyle(ColorTheme.text)
                                    Text(viewModel.connectedPeers.contains(peer) ? "Connected" : "Discovered")
                                        .font(RediTypography.body)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if viewModel.connectedPeers.contains(peer) {
                                    Button("Send Signal") {
                                        viewModel.sendDirect(to: peer)
                                    }
                                    .buttonStyle(SecondaryActionButtonStyle())
                                    .frame(width: 100)
                                    .disabled(!canTriggerBroadcast)
                                } else {
                                    Button("Connect") {
                                        viewModel.connect(to: peer)
                                    }
                                    .buttonStyle(SecondaryActionButtonStyle())
                                    .frame(width: 110)
                                    .disabled(!viewModel.canInitiateConnections)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var failureModesPanel: some View {
        PanelCard(title: "Failure Modes", subtitle: "What still works right now") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(signalFailureRows) { row in
                    signalFailureRow(row)
                }
            }
        }
    }

    private var signalLimitsPanel: some View {
        PanelCard(title: "Signal Limits", subtitle: "Fast reminder before you rely on mesh") {
            VStack(alignment: .leading, spacing: 12) {
                rangeIndicatorCard
                signalLimitLine(iconName: "antenna.radiowaves.left.and.right", text: "Short-range assistive messaging only")
                signalLimitLine(iconName: "iphone.slash", text: "Not a replacement for cellular or satellite")
                signalLimitLine(iconName: "exclamationmark.triangle.fill", text: "Delivery not guaranteed")
                signalLimitLine(iconName: "bolt.horizontal.circle", text: "Bluetooth + Wi-Fi must stay available")
            }
        }
    }

    private var meshDetailsPanel: some View {
        PanelCard(title: "Mesh Details", subtitle: "Plain-language local status") {
            VStack(alignment: .leading, spacing: 12) {
                meshDetailRow(label: "Your device ID", value: viewModel.userFacingDeviceID)
                if let visibleDeviceName = viewModel.visibleDeviceName {
                    meshDetailRow(label: "Visible name", value: visibleDeviceName)
                }
                meshDetailRow(label: "Nearby users", value: viewModel.nearbyPeerSummary)
                meshDetailRow(label: "Messages", value: viewModel.messageAvailabilitySummary)
                meshDetailRow(label: "Relay reports", value: viewModel.relayStatusSummary)
                meshDetailRow(label: "Last activity", value: viewModel.lastSignalLabel)
                meshDetailRow(label: "Sharing mode", value: viewModel.sharingModeSummary)
                meshDetailRow(label: "Constraints", value: viewModel.workingConstraintSummary)

                if viewModel.isStealthModeEnabled {
                    Text("Stealth Mode keeps this device hidden and receive-only.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                } else if viewModel.isAnonymousModeEnabled {
                    Text("Hidden Mode listens nearby without sending new broadcasts.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.accent)
                }
            }
        }
    }

    private var sessionFeedPanel: some View {
        CollapsiblePanelCard(
            title: "Session Feed",
            subtitle: "In-memory only. Clears when you choose.",
            accent: ColorTheme.textTertiary,
            isExpanded: $isShowingSessionFeed
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Button("Clear Session") {
                    viewModel.clearSession()
                }
                .buttonStyle(SecondaryActionButtonStyle())

                if viewModel.sessionMessages.isEmpty {
                    Text("No session messages yet.")
                        .font(RediTypography.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.sessionMessages) { message in
                        signalInsetCard(tint: message.kindLabel == "Alert" ? ColorTheme.danger : ColorTheme.accent) {
                            HStack {
                                Text(message.sender)
                                    .font(RediTypography.heading)
                                    .foregroundStyle(ColorTheme.text)
                                Spacer()
                                Text(message.kindLabel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(message.body)
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.text)
                            if let location = message.location {
                                Text("\(location.latitude.formatted(.number.precision(.fractionLength(4)))), \(location.longitude.formatted(.number.precision(.fractionLength(4))))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var localSituationalScannerPanel: some View {
        PanelCard(title: "Local Situational Scanner", subtitle: "Phone-only situational awareness that still works when no other RediM8 users are nearby") {
            VStack(alignment: .leading, spacing: 16) {
                signalInsetCard(tint: scannerAccentColor) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                                .fill(scannerAccentColor.opacity(0.16))
                                .frame(width: 42, height: 42)

                            Image(systemName: "wave.3.forward.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(scannerAccentColor)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text("LOCAL STATUS")
                                    .font(RediTypography.label)
                                    .tracking(1.2)
                                    .foregroundStyle(scannerAccentColor)

                                Text(viewModel.scannerStatusLabel.uppercased())
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(scannerAccentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(scannerAccentColor.opacity(0.14), in: Capsule())
                            }

                            Text(viewModel.scannerHeadline)
                                .font(RediTypography.heading)
                                .foregroundStyle(ColorTheme.text)

                            Text(viewModel.scannerSummary)
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.textSecondary)

                            Text("Updated just now from on-device radios and sensors.")
                                .font(.caption)
                                .foregroundStyle(ColorTheme.textTertiary)
                        }
                    }
                }

                LazyVGrid(columns: signalCommandColumns, spacing: 10) {
                    signalMetricTile(
                        title: "GPS",
                        value: viewModel.scannerSnapshot.gpsState.title,
                        detail: viewModel.scannerSnapshot.gpsState.detail,
                        iconName: "location.fill",
                        tint: color(for: viewModel.scannerSnapshot.gpsState.tone)
                    )
                    signalMetricTile(
                        title: "Network",
                        value: viewModel.scannerSnapshot.networkState.title,
                        detail: viewModel.scannerSnapshot.networkState.detail,
                        iconName: "antenna.radiowaves.left.and.right",
                        tint: color(for: viewModel.scannerSnapshot.networkState.tone)
                    )
                    signalMetricTile(
                        title: "Nearby Radio",
                        value: viewModel.scannerSnapshot.radioState.title,
                        detail: viewModel.scannerSnapshot.radioState.detail,
                        iconName: "dot.radiowaves.left.and.right",
                        tint: color(for: viewModel.scannerSnapshot.radioState.tone)
                    )
                    signalMetricTile(
                        title: "Power",
                        value: viewModel.scannerSnapshot.batteryPercentageText,
                        detail: viewModel.scannerSnapshot.powerState.detail,
                        iconName: "battery.100",
                        tint: color(for: viewModel.scannerSnapshot.powerState.tone)
                    )
                    signalMetricTile(
                        title: "Pressure",
                        value: viewModel.scannerSnapshot.pressureTrend.title,
                        detail: viewModel.scannerSnapshot.pressureTrend.detail,
                        iconName: "barometer",
                        tint: color(for: viewModel.scannerSnapshot.pressureTrend.tone)
                    )
                }

                if !viewModel.scannerAlerts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scanner cues")
                            .font(RediTypography.heading)
                            .foregroundStyle(ColorTheme.text)

                        ForEach(viewModel.scannerAlerts) { alert in
                            scannerAlertRow(alert)
                        }
                    }
                }

                Text("Scanner cues are local hints only. They help when the mesh is empty, but they do not confirm what other people are doing until reports arrive.")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
            }
        }
    }

    private var accountabilityModePanel: some View {
        PanelCard(title: "Accountability Mode", subtitle: "Offline roll call for household, street, camp, or team. Your own status can still broadcast when nearby mesh links appear.") {
            VStack(alignment: .leading, spacing: 16) {
                signalInsetCard(tint: accountabilityAccentColor) {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField(
                            "Circle name",
                            text: Binding(
                                get: { viewModel.accountabilityHeadline },
                                set: viewModel.setAccountabilityCircleTitle
                            )
                        )
                        .textFieldStyle(TacticalTextFieldStyle())

                        Text(viewModel.accountabilityCoverageSummary)
                            .font(RediTypography.bodyStrong)
                            .foregroundStyle(ColorTheme.text)

                        HStack(spacing: 8) {
                            accountabilitySummaryPill(.safe)
                            accountabilitySummaryPill(.checkingIn)
                            accountabilitySummaryPill(.needHelp)
                            accountabilitySummaryPill(.unknown)
                        }
                    }
                }

                signalInsetCard(tint: accountabilitySelfStatusTint) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("My Status")
                                    .font(RediTypography.heading)
                                    .foregroundStyle(ColorTheme.text)

                                Text(viewModel.accountabilitySelfMember?.name ?? "This device")
                                    .font(RediTypography.body)
                                    .foregroundStyle(ColorTheme.textSecondary)
                            }

                            Spacer(minLength: 0)

                            Text((viewModel.accountabilitySelfMember?.status.summaryLabel ?? AccountabilityStatus.unknown.summaryLabel))
                                .font(RediTypography.caption)
                                .foregroundStyle(accountabilitySelfStatusTint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(accountabilitySelfStatusTint.opacity(0.14), in: Capsule())
                        }

                        HStack(spacing: 8) {
                            ForEach(viewModel.accountabilityStatusButtons, id: \.self) { status in
                                accountabilityStatusButton(status)
                            }
                        }

                        Text(viewModel.canBroadcastAccountabilityStatus
                             ? "Self check-ins will also relay over nearby mesh links."
                             : "Self check-ins save locally first. They will relay once nearby mesh links open.")
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }

                signalInsetCard(tint: ColorTheme.accent) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            TextField("Add family, neighbor, or team member", text: $viewModel.newAccountabilityMemberName)
                                .textFieldStyle(TacticalTextFieldStyle())

                            Button("Add") {
                                viewModel.addAccountabilityMember()
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                            .disabled(viewModel.newAccountabilityMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        Button("Sync from Plan & Contacts") {
                            viewModel.syncAccountabilityRosterFromProfile()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Roster")
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)

                    ForEach(viewModel.accountabilityMembers) { member in
                        accountabilityMemberRow(member)
                    }
                }
            }
        }
    }

    private func accountabilitySummaryPill(_ status: AccountabilityStatus) -> some View {
        let tint = accountabilityTint(for: status)
        let count = viewModel.accountabilityCircle.members.filter { $0.status == status }.count

        return HStack(spacing: 6) {
            Image(systemName: status.systemImage)
                .font(.system(size: 11, weight: .bold))

            Text("\(count)")
                .font(RediTypography.label)
                .tracking(1.2)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private func accountabilityStatusButton(_ status: AccountabilityStatus) -> some View {
        let tint = accountabilityTint(for: status)

        return Button {
            viewModel.markSelfAccountabilityStatus(status)
        } label: {
            VStack(alignment: .center, spacing: 4) {
                Image(systemName: status.systemImage)
                    .font(.system(size: 14, weight: .bold))
                Text(status.buttonTitle.replacingOccurrences(of: "I Am ", with: ""))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .stroke(tint.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func accountabilityMemberRow(_ member: AccountabilityMember) -> some View {
        let tint = accountabilityTint(for: member.status)

        return signalInsetCard(tint: tint) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 38, height: 38)

                    Image(systemName: member.status.systemImage)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(member.name)
                            .font(RediTypography.heading)
                            .foregroundStyle(ColorTheme.text)

                        if member.source == .selfUser {
                            Text("YOU")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(tint)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(tint.opacity(0.14), in: Capsule())
                        }
                    }

                    Text(accountabilityMemberDetail(member))
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textSecondary)

                    if let note = member.note.nilIfBlank {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(ColorTheme.text)
                    }
                }

                Spacer(minLength: 0)

                Menu {
                    ForEach(AccountabilityStatus.allCases) { status in
                        Button(status.title) {
                            viewModel.setAccountabilityStatus(
                                status,
                                for: member.id,
                                source: member.source == .selfUser ? .local : .manual,
                                broadcast: member.source == .selfUser
                            )
                        }
                    }

                    if member.source != .selfUser {
                        Divider()

                        Button("Remove", role: .destructive) {
                            viewModel.removeAccountabilityMember(member.id)
                        }
                    }
                } label: {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(member.status.summaryLabel)
                            .font(RediTypography.caption)
                            .foregroundStyle(tint)

                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                    .padding(.leading, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func accountabilityMemberDetail(_ member: AccountabilityMember) -> String {
        var parts = [member.source.label]

        if let role = member.role.nilIfBlank, role != "This device" {
            parts.append(role)
        }

        if let updatedAt = member.updatedAt {
            parts.append(RelativeDateTimeFormatter.rediM8Short.localizedString(for: updatedAt, relativeTo: .now))
        } else {
            parts.append("No check-in yet")
        }

        return parts.joined(separator: " • ")
    }

    private func signalWorkspaceButton(_ workspace: SignalWorkspace) -> some View {
        let isSelected = selectedWorkspace == workspace
        let accent = workspaceAccent(for: workspace)

        return Button {
            withAnimation(RediMotion.reveal) {
                selectedWorkspace = workspace
                if workspace == .system {
                    isShowingSessionFeed = true
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.title)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                    Text(workspace.subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? ColorTheme.textSecondary : ColorTheme.textTertiary)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Text("OPEN")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(accent.opacity(0.14), in: Capsule())
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(isSelected ? 0.26 : 0.14), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .stroke((isSelected ? accent : ColorTheme.dividerStrong).opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func workspaceAccent(for workspace: SignalWorkspace) -> Color {
        switch workspace {
        case .communicate:
            viewModel.canBroadcastOutboundSignals ? ColorTheme.danger : ColorTheme.warning
        case .network:
            accountabilityAccentColor
        case .system:
            !signalFailureRows.isEmpty ? ColorTheme.warning : ColorTheme.accent
        }
    }

    private func signalStatusLine(label: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)
                .frame(width: 84, alignment: .leading)

            Text(detail)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var signalHeroMetrics: some View {
        LazyVGrid(columns: signalHeroMetricColumns, spacing: 12) {
            signalMetricTile(
                title: "Nearby",
                value: viewModel.nearbyPeerSummary,
                detail: viewModel.connectedPeerSummary,
                iconName: "family",
                tint: viewModel.nearbyPeers.isEmpty ? ColorTheme.textTertiary : signalStatusColor
            )
            signalMetricTile(
                title: "Broadcast",
                value: viewModel.canBroadcastOutboundSignals ? "Ready" : "Receive-only",
                detail: "Emergency alert to nearby devices",
                iconName: "exclamationmark.triangle.fill",
                tint: viewModel.canBroadcastOutboundSignals ? ColorTheme.danger : ColorTheme.warning
            )
            signalMetricTile(
                title: "Location",
                value: viewModel.workingLocationSummary,
                detail: viewModel.currentLocation == nil ? "Awaiting GPS" : "Share state ready",
                iconName: "location.fill",
                tint: viewModel.canShareLocation ? ColorTheme.accent : ColorTheme.warning
            )
            signalMetricTile(
                title: "Last Activity",
                value: viewModel.lastSignalLabel,
                detail: viewModel.sessionMessages.isEmpty ? "No messages received" : "Latest local signal event",
                iconName: "clock",
                tint: viewModel.sessionMessages.isEmpty ? ColorTheme.textTertiary : signalStatusColor
            )
        }
    }

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
            meshBannerStat(title: "Connections", value: viewModel.connectedPeerSummary, tint: signalStatusColor)
            meshBannerStat(title: "Relay", value: viewModel.relayStatusSummary, tint: beaconRelayTint)
            meshBannerStat(title: "Last Activity", value: viewModel.lastSignalLabel, tint: signalStatusColor)
        }
    }

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

    private var scannerAccentColor: Color {
        color(for: viewModel.scannerTone)
    }

    private var accountabilityAccentColor: Color {
        if viewModel.accountabilityMembers.contains(where: { $0.status == .needHelp || $0.status == .injured }) {
            return ColorTheme.danger
        }
        if viewModel.accountabilityMembers.contains(where: { $0.status == .unknown }) {
            return ColorTheme.warning
        }
        if viewModel.accountabilityMembers.contains(where: { $0.status == .checkingIn }) {
            return ColorTheme.accent
        }
        return ColorTheme.ready
    }

    private var accountabilitySelfStatusTint: Color {
        accountabilityTint(for: viewModel.accountabilitySelfMember?.status ?? .unknown)
    }

    private func accountabilityTint(for status: AccountabilityStatus) -> Color {
        switch status {
        case .safe:
            ColorTheme.ready
        case .checkingIn:
            ColorTheme.accent
        case .needHelp, .injured:
            ColorTheme.danger
        case .unknown:
            ColorTheme.warning
        }
    }

    private func color(for tone: OperationalStatusTone) -> Color {
        switch tone {
        case .ready:
            ColorTheme.ready
        case .info:
            ColorTheme.accent
        case .caution:
            ColorTheme.warning
        case .danger:
            ColorTheme.danger
        case .neutral:
            ColorTheme.textTertiary
        }
    }

    private func scannerAlertRow(_ alert: SituationalScannerAlert) -> some View {
        let tint = color(for: alert.tone)

        return signalInsetCard(tint: tint) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 34, height: 34)

                    Image(systemName: alert.iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)

                    Text(alert.detail)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var signalHeroMetricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var rangeIndicatorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Range")
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textTertiary)
                Spacer()
                Text("\(viewModel.rangeLevelTitle) • \(viewModel.workingRangeSummary)")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
            }

            HStack(spacing: 6) {
                ForEach(0..<viewModel.rangeMeterSegmentCount, id: \.self) { index in
                    let isActive = index < viewModel.rangeMeterFillCount

                    Capsule()
                        .fill(isActive ? ColorTheme.accent : ColorTheme.divider)
                        .frame(maxWidth: .infinity, minHeight: 8, maxHeight: 8)
                        .overlay {
                            if isActive {
                                Capsule()
                                    .fill(ColorTheme.accent.opacity(isSignalPulseActive ? 0.22 : 0.08))
                                    .scaleEffect(y: isSignalPulseActive ? 1.22 : 1)
                            }
                        }
                        .opacity(isActive && !reduceMotion ? (isSignalPulseActive ? 1 : 0.82) : 1)
                }
            }
        }
        .padding(14)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.card,

                atmosphere: ColorTheme.accent.opacity(0.1)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.card, edgeColor: ColorTheme.accent.opacity(0.12), shadowColor: ColorTheme.accent.opacity(0.04)))
    }

    private func startSignalPulse() {
        guard !reduceMotion else {
            isSignalPulseActive = false
            return
        }

        withAnimation(RediMotion.reveal) {
            isSignalPulseActive = true
        }
    }

    private func signalLimitLine(iconName: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RediIcon(iconName)
                .foregroundStyle(ColorTheme.textTertiary)
                .frame(width: 16, height: 16)
                .padding(.top, 2)

            Text(text)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func signalGuidanceLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(ColorTheme.danger)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func meshDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)
                .frame(width: 92, alignment: .leading)

            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func messageTemplateButton(_ template: String) -> some View {
        let tint = quickTemplateTint(for: template)

        return Button(template) {
            viewModel.draftMessage = template
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.26), lineWidth: 1)
        )
        .buttonStyle(CardPressButtonStyle())
    }

    private func reportQuickTemplateButton(_ template: String) -> some View {
        let tint = quickTemplateTint(for: template)

        return Button(template) {
            viewModel.applyStructuredQuickSignal(template)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.26), lineWidth: 1)
        )
        .buttonStyle(CardPressButtonStyle())
    }

    private func quickTemplateTint(for template: String) -> Color {
        if template.contains("FIRE") {
            return ColorTheme.danger
        }
        if template.contains("SAFE") {
            return ColorTheme.ready
        }
        if template.contains("WATER") {
            return ColorTheme.accent
        }
        return ColorTheme.warning
    }

    private var orderedSelectedResources: [BeaconResource] {
        viewModel.selectedResources.sorted { $0.title < $1.title }
    }

    private var signalIntelligenceEditor: some View {
        signalInsetCard(tint: beaconAccentColor(for: viewModel.selectedBeaconType)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Report Details")
                    .font(RediTypography.heading)
                    .foregroundStyle(ColorTheme.text)

                HStack(spacing: 10) {
                    signalMetadataPicker(
                        title: "Severity",
                        selectionText: viewModel.selectedSeverity.title
                    ) {
                        Picker("Severity", selection: $viewModel.selectedSeverity) {
                            ForEach(BeaconSeverity.allCases) { severity in
                                Text(severity.title).tag(severity)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    signalMetadataPicker(
                        title: "Confidence",
                        selectionText: viewModel.selectedConfidence.title
                    ) {
                        Picker("Confidence", selection: $viewModel.selectedConfidence) {
                            ForEach(BeaconConfidence.allCases) { confidence in
                                Text(confidence.title).tag(confidence)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if viewModel.selectedBeaconType.supportsDirectionHint,
                   let detailPrompt = viewModel.selectedBeaconType.detailPrompt {
                    TextField(detailPrompt, text: $viewModel.directionHint)
                        .textFieldStyle(TacticalTextFieldStyle())
                }

                if viewModel.selectedBeaconType.supportsRouteCondition {
                    signalMetadataPicker(
                        title: "Route",
                        selectionText: viewModel.selectedRouteCondition.title
                    ) {
                        Picker("Route", selection: $viewModel.selectedRouteCondition) {
                            ForEach(BeaconRouteCondition.allCases) { routeCondition in
                                Text(routeCondition.title).tag(routeCondition)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if viewModel.selectedBeaconType.supportsWaterSafety {
                    signalMetadataPicker(
                        title: "Water Safety",
                        selectionText: viewModel.selectedWaterSafety.title
                    ) {
                        Picker("Water Safety", selection: $viewModel.selectedWaterSafety) {
                            ForEach(BeaconWaterSafety.allCases) { waterSafety in
                                Text(waterSafety.title).tag(waterSafety)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if viewModel.selectedBeaconType.supportsShelterStatus {
                    signalMetadataPicker(
                        title: "Shelter Status",
                        selectionText: viewModel.selectedShelterStatus.title
                    ) {
                        Picker("Shelter Status", selection: $viewModel.selectedShelterStatus) {
                            ForEach(BeaconShelterStatus.allCases) { shelterStatus in
                                Text(shelterStatus.title).tag(shelterStatus)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if viewModel.selectedBeaconType.supportsShelterCapacityNote {
                    TextField("Capacity or access note", text: $viewModel.shelterCapacityNote)
                        .textFieldStyle(TacticalTextFieldStyle())
                }

                if viewModel.selectedBeaconType.supportsBatteryLevel {
                    TextField("Battery % (optional)", text: $viewModel.batteryLevelText)
                        .textFieldStyle(TacticalTextFieldStyle())
                        .keyboardType(.numberPad)
                }

                signalHighlightsBlock(viewModel.selectedSignalHighlights, accent: beaconAccentColor(for: viewModel.selectedBeaconType))
            }
        }
    }

    private func signalMetadataPicker<Content: View>(
        title: String,
        selectionText: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            Menu {
                content()
            } label: {
                HStack(spacing: 8) {
                    Text(selectionText)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ColorTheme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .stroke(ColorTheme.dividerStrong.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func signalHighlightsBlock(_ highlights: [(label: String, value: String)], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signal Details")
                .font(RediTypography.caption)
                .foregroundStyle(accent)

            ForEach(Array(highlights.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 10) {
                    Text(item.label.uppercased())
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
                        .frame(width: 76, alignment: .leading)

                    Text(item.value)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        )
    }

    private func situationReportButton(_ type: BeaconType) -> some View {
        let isSelected = viewModel.selectedBeaconType == type
        let tint = beaconAccentColor(for: type)

        return Button {
            viewModel.selectSituationReport(type)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    BeaconTypeBadge(type: type)
                    Spacer(minLength: 0)
                }

                Text(type.buttonTitle.uppercased())
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)

                Text(type.expiryBadgeTitle)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PremiumSurfaceBackground(
                    cornerRadius: RediRadius.card,

                    atmosphere: (isSelected ? tint : ColorTheme.textSecondary).opacity(isSelected ? 0.14 : 0.05)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.card, edgeColor: (isSelected ? tint : ColorTheme.dividerStrong).opacity(0.18), shadowColor: tint.opacity(0.04)))
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func beaconAccentColor(for _: BeaconType) -> Color {
        ColorTheme.textTertiary
    }

    private func sharedMedicalInfoBlock(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MEDICAL NOTE SHARED")
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.danger)
            Text(summary)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.button,

                atmosphere: ColorTheme.danger.opacity(0.12)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.button, edgeColor: ColorTheme.danger.opacity(0.16), shadowColor: ColorTheme.danger.opacity(0.04)))
    }

    private var signalFailureRows: [SignalFailureRowModel] {
        var rows: [SignalFailureRowModel] = []

        if viewModel.nearbyPeers.isEmpty && viewModel.connectedPeers.isEmpty {
            rows.append(
                SignalFailureRowModel(
                    title: "No mesh connection",
                    detail: "RediM8 is still listening, but no nearby devices are discoverable right now. Keep Bluetooth and Wi-Fi enabled, move closer to others, or use broadcast.",
                    iconName: "antenna.radiowaves.left.and.right.slash",
                    tint: ColorTheme.warning
                )
            )
        }

        if let composeAvailabilityMessage = viewModel.composeAvailabilityMessage, !viewModel.canBroadcastOutboundSignals {
            rows.append(
                SignalFailureRowModel(
                    title: "Outgoing signal unavailable",
                    detail: composeAvailabilityMessage,
                    iconName: "paperplane.circle.fill",
                    tint: ColorTheme.danger
                )
            )
        }

        if viewModel.currentLocation == nil {
            rows.append(
                SignalFailureRowModel(
                    title: "Location unavailable",
                    detail: "Location sharing and distance labels are limited until GPS returns. You can still send short text alerts if broadcasting is available.",
                    iconName: "location.slash.fill",
                    tint: ColorTheme.warning
                )
            )
        }

        if viewModel.sessionMessages.isEmpty {
            rows.append(
                SignalFailureRowModel(
                    title: "No recent signal activity",
                    detail: "No alerts, direct messages, or connection events have been seen in this session yet.",
                    iconName: "clock.badge.xmark.fill",
                    tint: ColorTheme.textTertiary
                )
            )
        }

        return rows
    }

    private func signalMetricTile(
        title: String,
        value: String,
        detail: String,
        iconName: String,
        tint: Color
    ) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 34, height: 34)

                    RediIcon(iconName)
                        .foregroundStyle(tint)
                        .frame(width: 16, height: 16)
                }

                Spacer(minLength: 0)
            }

            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(14)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.card,

                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.card, edgeColor: tint.opacity(0.12), shadowColor: tint.opacity(0.04)))
    }

    private func commandStatusTile(
        title: String,
        value: String,
        detail: String,
        iconName: String,
        tint: Color
    ) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)

                RediIcon(iconName)
                    .foregroundStyle(tint)
                    .frame(width: 16, height: 16)
            }

            Text(title)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)

            Text(value.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(tint)

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .padding(12)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.card,

                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.card, edgeColor: tint.opacity(0.14), shadowColor: tint.opacity(0.04)))
    }

    private func meshBannerStat(title: String, value: String, tint: Color) -> some View {
        return VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.button,

                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.button, edgeColor: tint.opacity(0.1), shadowColor: tint.opacity(0.03)))
    }

    private func signalFailureRow(_ row: SignalFailureRowModel) -> some View {
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .fill(row.tint.opacity(0.14))
                    .frame(width: 38, height: 38)

                RediIcon(row.iconName)
                    .foregroundStyle(row.tint)
                    .frame(width: 16, height: 16)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                Text(row.detail)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.card,

                atmosphere: row.tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.card, edgeColor: row.tint.opacity(0.12), shadowColor: row.tint.opacity(0.04)))
    }

    private func beaconTypeStrip(for type: BeaconType) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(beaconAccentColor(for: type))
            .frame(height: 3)
            .frame(maxWidth: .infinity)
    }

    private func signalInsetCard<Content: View>(
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        return VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.card,

                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.card, edgeColor: tint.opacity(0.12), shadowColor: tint.opacity(0.04)))
    }

    private func signalDockButton(
        title: String,
        detail: String,
        status: String,
        systemImage: String,
        tint: Color,
        prominence: SignalDockButtonProminence,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RediCommandCard(
                title: title,
                detail: detail,
                systemImage: systemImage,
                tint: tint,
                badge: status,
                prominence: commandProminence(for: prominence),
                layout: .rail,
                isEnabled: isEnabled,
                minHeight: 66
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("\(title), \(status). \(detail)")
    }

    private func commandProminence(for prominence: SignalDockButtonProminence) -> RediCommandCardProminence {
        switch prominence {
        case .critical:
            .critical
        case .accented:
            .accented
        case .standard:
            .neutral
        }
    }
}

private struct SignalFailureRowModel: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let iconName: String
    let tint: Color
}

private enum SignalDockButtonProminence {
    case critical
    case accented
    case standard
}

private struct BeaconTypeBadge: View {
    let type: BeaconType

    var body: some View {
        RediIcon(type.symbolName)
            .foregroundStyle(foreground)
            .frame(width: 18, height: 18)
            .padding(10)
            .background(background, in: Circle())
    }

    private var foreground: Color {
        ColorTheme.textTertiary
    }

    private var background: Color {
        foreground.opacity(0.16)
    }
}

private struct BeaconResourceWrap<Content: View>: View {
    let resources: [BeaconResource]
    @ViewBuilder let content: (BeaconResource) -> Content

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(resources) { resource in
                content(resource)
            }
        }
    }
}

private struct BeaconResourcePill: View {
    let resource: BeaconResource
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(RediTypography.label)
                Text(resource.title)
                    .font(RediTypography.bodyStrong)
            }
            .foregroundStyle(isSelected ? ColorTheme.text : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PremiumSurfaceBackground(
                    cornerRadius: RediRadius.button,

                    atmosphere: (isSelected ? ColorTheme.accent : ColorTheme.textSecondary).opacity(isSelected ? 0.14 : 0.04)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
            .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.button, edgeColor: (isSelected ? ColorTheme.accent : ColorTheme.dividerStrong).opacity(0.16), shadowColor: ColorTheme.accent.opacity(0.03)))
        }
        .buttonStyle(CardPressButtonStyle())
    }
}

private struct AnalogSignalModeView: View {
    @ObservedObject var viewModel: SignalViewModel

    private var snapshot: AnalogRescueSnapshot {
        viewModel.analogRescueSnapshot
    }

    private var torchBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isAnalogTorchPatternEnabled },
            set: { viewModel.setAnalogTorchPatternEnabled($0) }
        )
    }

    private var soundBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isAnalogAudiblePingEnabled },
            set: { viewModel.setAnalogAudiblePingEnabled($0) }
        )
    }

    private var vibrationBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isAnalogVibrationPingEnabled },
            set: { viewModel.setAnalogVibrationPingEnabled($0) }
        )
    }

    private var pulseIntervalBinding: Binding<AnalogSignalPulseInterval> {
        Binding(
            get: { viewModel.analogSignalPulseInterval },
            set: { viewModel.setAnalogSignalPulseInterval($0) }
        )
    }

    var body: some View {
        ZStack {
            ColorTheme.panel
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                Spacer(minLength: 18)

                signalHero
                    .padding(.horizontal, 20)

                Spacer(minLength: 18)

                ScrollView {
                    VStack(spacing: 16) {
                        controlsCard
                        rescueCard
                        analogCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Offline Hardware Beacon")
                                    .font(RediTypography.heading)
                                    .foregroundStyle(ColorTheme.text)

                                Text("This mode uses the screen, flashlight, speaker, vibration motor, and saved emergency profile on this phone only. It does not require internet, servers, or nearby RediM8 users.")
                                    .font(RediTypography.body)
                                    .foregroundStyle(ColorTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .interactiveDismissDisabled()
        .onDisappear {
            if viewModel.isAnalogSignalActive {
                viewModel.closeAnalogSignalMode()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Analog Survival Mode")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.white)

                Text("Battery + hardware only")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent.opacity(0.92))
            }

            Spacer(minLength: 12)

            Button {
                viewModel.closeAnalogSignalMode()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Stop")
                        .font(RediTypography.bodyStrong)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var signalHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(viewModel.analogSignalPattern.screenLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(RediTypography.display)
                        .foregroundStyle(Color.white)
                        .tracking(1.2)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 10) {
                Text(viewModel.analogSignalPattern.subtitle.uppercased())
                    .font(RediTypography.caption)
                    .foregroundStyle(accent)

                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)

                Text("SCREEN SIGNAL ACTIVE")
                    .font(RediTypography.caption)
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            if let coordinatesText = snapshot.coordinatesText {
                Text("GPS \(coordinatesText)")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(Color.white.opacity(0.82))
            } else {
                Text("GPS location still resolving")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: accent.opacity(0.18), radius: 18, y: 10)
    }

    private var controlsCard: some View {
        analogCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Signal Controls")
                            .font(RediTypography.heading)
                            .foregroundStyle(ColorTheme.text)

                        Text("Change the beacon type, then decide whether flashlight, sound, and vibration should run with it.")
                            .font(RediTypography.body)
                            .foregroundStyle(ColorTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    Button {
                        viewModel.triggerAnalogManualPing()
                    } label: {
                        Label("Manual Ping", systemImage: "dot.radiowaves.left.and.right")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(AnalogSignalPattern.allCases) { pattern in
                        Button {
                            viewModel.setAnalogSignalPattern(pattern)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(pattern.title.uppercased())
                                    .font(RediTypography.label)
                                    .tracking(1.2)
                                    .foregroundStyle(viewModel.analogSignalPattern == pattern ? accent : ColorTheme.textSecondary)
                                Text(pattern.subtitle)
                                    .font(RediTypography.bodyStrong)
                                    .foregroundStyle(ColorTheme.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                                    .fill(ColorTheme.panelElevated.opacity(0.86))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                                            .stroke(
                                                (viewModel.analogSignalPattern == pattern ? accent : ColorTheme.dividerStrong).opacity(viewModel.analogSignalPattern == pattern ? 0.46 : 0.18),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle("Flashlight beacon", isOn: torchBinding)
                    .toggleStyle(.switch)
                    .foregroundStyle(viewModel.isAnalogTorchAvailable ? ColorTheme.text : ColorTheme.textTertiary)
                    .disabled(!viewModel.isAnalogTorchAvailable)

                if !viewModel.isAnalogTorchAvailable {
                    Text("This device does not expose a usable torch, so the screen, sound, vibration, and rescue card remain active instead.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                }

                Toggle("Audible ping", isOn: soundBinding)
                    .toggleStyle(.switch)
                    .foregroundStyle(ColorTheme.text)

                Toggle("Vibration ping", isOn: vibrationBinding)
                    .toggleStyle(.switch)
                    .foregroundStyle(ColorTheme.text)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pulse interval")
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)

                    Picker("Pulse interval", selection: pulseIntervalBinding) {
                        ForEach(AnalogSignalPulseInterval.allCases) { interval in
                            Text(interval.title).tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let analogSignalLastErrorMessage = viewModel.analogSignalLastErrorMessage {
                    Text(analogSignalLastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                }
            }
        }
    }

    private var rescueCard: some View {
        analogCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Rescue Card")
                    .font(RediTypography.heading)
                    .foregroundStyle(ColorTheme.text)

                rescueRow(label: "Owner", value: snapshot.ownerName)
                rescueRow(label: "GPS", value: snapshot.coordinatesText ?? "Waiting for current location")

                if let bloodType = snapshot.bloodType {
                    rescueRow(label: "Blood Type", value: bloodType)
                }

                if let allergies = snapshot.allergies {
                    rescueRow(label: "Allergies", value: allergies)
                }

                if let medication = snapshot.medication {
                    rescueRow(label: "Medication", value: medication)
                }

                if let conditionSummary = snapshot.conditionSummary {
                    rescueRow(label: "Condition", value: conditionSummary)
                }

                if !snapshot.contacts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emergency Contacts")
                            .font(RediTypography.bodyStrong)
                            .foregroundStyle(ColorTheme.text)

                        ForEach(snapshot.contacts.prefix(3), id: \.id) { contact in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "person.crop.circle.badge.phone")
                                    .foregroundStyle(accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.name)
                                        .font(RediTypography.bodyStrong)
                                        .foregroundStyle(ColorTheme.text)
                                    Text(contact.phone)
                                        .font(RediTypography.body)
                                        .foregroundStyle(ColorTheme.textSecondary)
                                }
                            }
                        }
                    }
                } else {
                    Text("No emergency contacts saved yet. Add them in Settings or Plan so rescuers have someone to call.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                }
            }
        }
    }

    private func analogCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                .fill(ColorTheme.panelRaised.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func rescueRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(accent)
            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accent: Color {
        switch viewModel.analogSignalPattern {
        case .sos:
            ColorTheme.warning
        case .help:
            ColorTheme.danger
        case .stayAway:
            Color(red: 0.97, green: 0.38, blue: 0.34)
        case .safe:
            ColorTheme.ready
        }
    }

    private var backgroundTop: Color {
        switch viewModel.analogSignalPattern {
        case .sos:
            Color(red: 0.25, green: 0.14, blue: 0.02)
        case .help:
            Color(red: 0.26, green: 0.05, blue: 0.05)
        case .stayAway:
            Color(red: 0.22, green: 0.03, blue: 0.04)
        case .safe:
            Color(red: 0.06, green: 0.19, blue: 0.12)
        }
    }

    private var backgroundBottom: Color {
        switch viewModel.analogSignalPattern {
        case .sos:
            Color.black
        case .help:
            Color(red: 0.08, green: 0.01, blue: 0.01)
        case .stayAway:
            Color.black
        case .safe:
            Color.black
        }
    }
}

private extension MeshMessage {
    var kindLabel: String {
        switch kind {
        case .direct:
            "Direct"
        case .broadcastAlert:
            "Alert"
        case .locationShare:
            "Location"
        case .accountabilityStatus:
            "Roll Call"
        case .routeShare:
            "Route"
        case .hazardReport:
            "Hazard"
        }
    }
}
