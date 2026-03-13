import MultipeerConnectivity
import SwiftUI

struct SignalView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: SignalViewModel
    @State private var isShowingSessionFeed = false
    @State private var isSignalPulseActive = false
    private let quickMessageTemplates = ["Need water", "Safe here", "Fire nearby", "Need pickup"]

    init(appState: AppState) {
        _viewModel = StateObject(wrappedValue: SignalViewModel(appState: appState))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if viewModel.isStealthModeEnabled {
                    StealthModeIndicatorView()
                }

                if viewModel.isAnonymousModeEnabled {
                    HiddenModeIndicatorView()
                }

                meshStatusBanner

                ModeHeroCard(
                    eyebrow: "Local Comms",
                    title: "Signal",
                    subtitle: "Short-range assistive messaging only. Check status first, then send the shortest update possible.",
                    iconName: "signal",
                    accent: signalStatusColor,
                    backgroundAssetName: "signal_vehicle_link",
                    backgroundImageOffset: CGSize(width: -18, height: 0)
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        TrustPillGroup(items: viewModel.signalTrustItems)
                        signalHeroMetrics
                        signalStatusLine(label: "Mode", detail: viewModel.workingBroadcastSummary)
                        signalStatusLine(label: "Location", detail: viewModel.workingLocationSummary)
                        rangeIndicatorCard
                        signalStatusLine(label: "Relay", detail: viewModel.relayStatusSummary)
                        signalStatusLine(label: "Constraints", detail: viewModel.workingConstraintSummary)
                    }
                }

                PanelCard(title: "Send Update", subtitle: "Short message only. The command dock below keeps Alert, Share, and Report ready.") {
                    VStack(alignment: .leading, spacing: 14) {
                        signalCommandStatusGrid

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick starts")
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(quickMessageTemplates, id: \.self) { template in
                                        messageTemplateButton(template)
                                    }
                                }
                            }
                        }

                        TextField("Send short update", text: $viewModel.draftMessage, axis: .vertical)
                            .lineLimit(4...8)
                            .textFieldStyle(TacticalTextFieldStyle())
                            .frame(minHeight: 108, alignment: .topLeading)
                            .disabled(!viewModel.canBroadcastOutboundSignals)

                        Text("Try: Need water, Safe here, Fire nearby")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let composeAvailabilityMessage = viewModel.composeAvailabilityMessage {
                            Text(composeAvailabilityMessage)
                                .font(.caption)
                                .foregroundStyle(viewModel.canBroadcastOutboundSignals ? .secondary : ColorTheme.warning)
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(ColorTheme.info)
                            Text("Session feed stays in memory only on this phone.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !signalFailureRows.isEmpty {
                    PanelCard(title: "Failure Modes", subtitle: "What still works right now") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(signalFailureRows) { row in
                                signalFailureRow(row)
                            }
                        }
                    }
                }

                PanelCard(title: "Signal Limits", subtitle: "Fast reminder before you rely on mesh") {
                    VStack(alignment: .leading, spacing: 8) {
                        signalLimitLine(iconName: "antenna.radiowaves.left.and.right", text: "Short-range assistive messaging only")
                        signalLimitLine(iconName: "iphone.slash", text: "Not a replacement for cellular or satellite")
                        signalLimitLine(iconName: "exclamationmark.triangle.fill", text: "Delivery not guaranteed")
                        signalLimitLine(iconName: "bolt.horizontal.circle", text: "Bluetooth + Wi-Fi must stay available")
                    }
                }

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

                        if viewModel.isStealthModeEnabled {
                            Text("Stealth Mode keeps this device hidden and receive-only.")
                                .font(.caption)
                                .foregroundStyle(ColorTheme.warning)
                        } else if viewModel.isAnonymousModeEnabled {
                            Text("Anonymous Mode listens nearby without sending new broadcasts.")
                                .font(.caption)
                                .foregroundStyle(ColorTheme.info)
                        }
                    }
                }

                PanelCard(title: "Community Situation Reports", subtitle: "Broadcast temporary local reports that can carry forward while still fresh") {
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
                                    Text("Active")
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
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let message = activeBeacon.message.nilIfBlank {
                                    Text(message)
                                        .font(.subheadline)
                                        .foregroundStyle(ColorTheme.text)
                                }

                                if let sharedEmergencyMedicalSummary = activeBeacon.sharedEmergencyMedicalSummary {
                                    sharedMedicalInfoBlock(sharedEmergencyMedicalSummary)
                                }

                                Text(activeBeacon.locationName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(ColorTheme.info)

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
                                    Button("Refresh Report") {
                                        viewModel.refreshBeacon()
                                    }
                                    .buttonStyle(PrimaryActionButtonStyle())

                                    Button("Stop Report") {
                                        viewModel.deactivateBeacon()
                                    }
                                    .buttonStyle(SecondaryActionButtonStyle())
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Report Situation")
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)

                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                ForEach(viewModel.situationReportTypes) { type in
                                    situationReportButton(type)
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
                            .foregroundStyle(ColorTheme.textMuted)

                        TextField(viewModel.selectedReportLocationPrompt, text: $viewModel.beaconLocationName)
                            .textFieldStyle(TacticalTextFieldStyle())

                        TextField(viewModel.selectedReportMessagePrompt, text: $viewModel.beaconMessage, axis: .vertical)
                            .textFieldStyle(TacticalTextFieldStyle())

                        if viewModel.selectedBeaconType.supportsEmergencyMedicalDisclosure {
                            signalInsetCard(tint: viewModel.includesEmergencyMedicalInfo ? ColorTheme.danger : ColorTheme.info) {
                                Toggle("Include emergency medical info", isOn: $viewModel.includesEmergencyMedicalInfo)
                                    .toggleStyle(.switch)
                                    .foregroundStyle(ColorTheme.text)
                                    .disabled(!viewModel.canAttachEmergencyMedicalInfo)

                                if let emergencyMedicalInfoStatusMessage = viewModel.emergencyMedicalInfoStatusMessage {
                                    Text(emergencyMedicalInfoStatusMessage)
                                        .font(.caption)
                                        .foregroundStyle(viewModel.hasEmergencyMedicalInfo ? ColorTheme.textMuted : ColorTheme.warning)
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
                                    .font(.headline)
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

                PanelCard(title: "Nearby Situation Reports", subtitle: "Temporary local reports discovered directly or relayed over the mesh") {
                    if viewModel.displayedBeacons.isEmpty {
                        Text("No nearby situation reports yet. No nearby RediM8 users or report markers are currently visible in this session.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 12) {
                            Text(TrustLayer.beaconVerificationReminder)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(viewModel.displayedBeacons) { beacon in
                                signalInsetCard(tint: beaconAccentColor(for: beacon.type)) {
                                    HStack(alignment: .top) {
                                        BeaconTypeBadge(type: beacon.type)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(beacon.type.title)
                                                .font(.headline)
                                                .foregroundStyle(ColorTheme.text)
                                            Text("\(beacon.displayLabel) • \(viewModel.beaconDistanceText(for: beacon))")
                                                .font(.subheadline)
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
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(ColorTheme.text)

                                    TrustPillGroup(items: viewModel.beaconTrustItems(for: beacon))

                                    if let message = beacon.message.nilIfBlank {
                                        Text(message)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    if let sharedEmergencyMedicalSummary = beacon.sharedEmergencyMedicalSummary {
                                        sharedMedicalInfoBlock(sharedEmergencyMedicalSummary)
                                    }

                                    Text(beacon.locationName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(ColorTheme.info)

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

                PanelCard(title: "Nearby Users", subtitle: "Discovered over short-range local mesh only") {
                    if viewModel.nearbyPeers.isEmpty {
                        Text("No nearby RediM8 users detected. Keep Bluetooth and Wi-Fi enabled, then move devices within likely short range.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(viewModel.nearbyPeers, id: \.displayName) { peer in
                                signalInsetCard(tint: viewModel.connectedPeers.contains(peer) ? ColorTheme.info : ColorTheme.warning) {
                                    HStack(alignment: .center, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(peer.displayName)
                                                .font(.headline)
                                                .foregroundStyle(ColorTheme.text)
                                            Text(viewModel.connectedPeers.contains(peer) ? "Connected" : "Discovered")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if viewModel.connectedPeers.contains(peer) {
                                            Button("Send") {
                                                viewModel.sendDirect(to: peer)
                                            }
                                            .buttonStyle(SecondaryActionButtonStyle())
                                            .frame(width: 100)
                                            .disabled(!viewModel.canBroadcastOutboundSignals || viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

                CollapsiblePanelCard(
                    title: "Session Feed",
                    subtitle: "In-memory only. Clears when you choose.",
                    accent: ColorTheme.info,
                    isExpanded: $isShowingSessionFeed
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Button("Clear Session") {
                            viewModel.clearSession()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())

                        if viewModel.sessionMessages.isEmpty {
                            Text("No session messages yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.sessionMessages) { message in
                                signalInsetCard(tint: message.kindLabel == "Alert" ? ColorTheme.danger : ColorTheme.info) {
                                    HStack {
                                        Text(message.sender)
                                            .font(.headline)
                                            .foregroundStyle(ColorTheme.text)
                                        Spacer()
                                        Text(message.kindLabel)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(message.body)
                                        .font(.subheadline)
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
            .padding(20)
        }
        .navigationTitle("Signal")
        .safeAreaInset(edge: .top, spacing: 0) {
            OperationalStatusRail(items: viewModel.statusItems, accent: signalStatusColor)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ThumbActionDock {
                HStack(spacing: 12) {
                    Button {
                        viewModel.broadcastAlert()
                    } label: {
                        Label("Alert", systemImage: "exclamationmark.triangle.fill")
                    }
                    .buttonStyle(EmergencyActionButtonStyle())
                    .disabled(!viewModel.canBroadcastOutboundSignals || viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        viewModel.shareLocation()
                    } label: {
                        Label("Share", systemImage: "location.fill")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(!viewModel.canShareLocation)

                    Button {
                        viewModel.activateBeacon()
                    } label: {
                        Label(viewModel.activeBeacon == nil ? "Report" : "Update", systemImage: "dot.radiowaves.left.and.right")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(viewModel.beaconAvailabilityMessage != nil && viewModel.activeBeacon == nil)
                }
            }
            .padding(.horizontal, RediSpacing.screen)
            .padding(.top, RediSpacing.screen)
            .padding(.bottom, RediLayout.commandDockContentInset)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.11, green: 0.08, blue: 0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
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
    }

    private func signalStatusLine(label: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textFaint)
                .frame(width: 84, alignment: .leading)

            Text(detail)
                .font(.subheadline)
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
                tint: viewModel.nearbyPeers.isEmpty ? ColorTheme.textFaint : signalStatusColor
            )
            signalMetricTile(
                title: "Broadcast",
                value: viewModel.canBroadcastOutboundSignals ? "Ready" : "Receive-only",
                detail: viewModel.sharingModeSummary,
                iconName: "exclamationmark.triangle.fill",
                tint: viewModel.canBroadcastOutboundSignals ? ColorTheme.danger : ColorTheme.warning
            )
            signalMetricTile(
                title: "Location",
                value: viewModel.workingLocationSummary,
                detail: viewModel.currentLocation == nil ? "Awaiting GPS" : "Share state ready",
                iconName: "location.fill",
                tint: viewModel.canShareLocation ? ColorTheme.info : ColorTheme.warning
            )
            signalMetricTile(
                title: "Relay",
                value: viewModel.relayStatusSummary,
                detail: viewModel.lastSignalLabel,
                iconName: "arrow.triangle.branch",
                tint: beaconRelayTint
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
                        .blur(radius: isSignalPulseActive ? 16 : 8)
                        .scaleEffect(isSignalPulseActive ? 1.08 : 0.92)

                    RediIcon("signal")
                        .foregroundStyle(signalStatusColor)
                        .frame(width: 18, height: 18)
                        .padding(10)
                        .background(signalStatusColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("MESH STATUS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(signalStatusColor)

                        Text(viewModel.meshStatusLabel.uppercased())
                            .font(.caption2.weight(.black))
                            .foregroundStyle(signalStatusColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(signalStatusColor.opacity(0.14), in: Capsule())
                    }
                    Text(viewModel.meshStatusHeadline)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text(viewModel.meshStatusDetail)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textMuted)
                }

                Spacer(minLength: 0)
            }

            meshStatusSnapshot
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ColorTheme.panelElevated)

                Image("signal_beacon_node")
                    .resizable()
                    .scaledToFill()
                    .saturation(0.9)
                    .contrast(1.04)
                    .brightness(-0.05)
                    .overlay {
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.42),
                                    Color.black.opacity(0.58),
                                    Color.black.opacity(0.76)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.54),
                                    Color.clear,
                                    Color.black.opacity(0.36)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(signalStatusColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var meshStatusSnapshot: some View {
        HStack(spacing: 10) {
            meshBannerStat(title: "Links", value: viewModel.connectedPeerSummary, tint: signalStatusColor)
            meshBannerStat(title: "Relay", value: viewModel.relayStatusSummary, tint: beaconRelayTint)
            meshBannerStat(title: "Last", value: viewModel.lastSignalLabel, tint: signalStatusColor)
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
            ColorTheme.textFaint
        }
    }

    private var beaconRelayTint: Color {
        viewModel.relayStatusSummary == "No relay queue" ? ColorTheme.textFaint : ColorTheme.info
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
                    .foregroundStyle(ColorTheme.textFaint)
                Spacer()
                Text("\(viewModel.rangeLevelTitle) • \(viewModel.workingRangeSummary)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTheme.text)
            }

            HStack(spacing: 6) {
                ForEach(0..<viewModel.rangeMeterSegmentCount, id: \.self) { index in
                    let isActive = index < viewModel.rangeMeterFillCount

                    Capsule()
                        .fill(isActive ? ColorTheme.info : ColorTheme.divider)
                        .frame(maxWidth: .infinity, minHeight: 8, maxHeight: 8)
                        .overlay {
                            if isActive {
                                Capsule()
                                    .fill(ColorTheme.info.opacity(isSignalPulseActive ? 0.22 : 0.08))
                                    .blur(radius: isSignalPulseActive ? 6 : 2)
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
                cornerRadius: 16,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: ColorTheme.info.opacity(0.1)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 16, edgeColor: ColorTheme.info.opacity(0.12), shadowColor: ColorTheme.info.opacity(0.04)))
    }

    private func startSignalPulse() {
        guard !reduceMotion else {
            isSignalPulseActive = false
            return
        }

        withAnimation(RediMotion.pulse) {
            isSignalPulseActive = true
        }
    }

    private func signalLimitLine(iconName: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RediIcon(iconName)
                .foregroundStyle(ColorTheme.warning)
                .frame(width: 16, height: 16)
                .padding(.top, 2)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func meshDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textFaint)
                .frame(width: 92, alignment: .leading)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var signalCommandStatusGrid: some View {
        LazyVGrid(columns: signalCommandColumns, spacing: 10) {
            commandStatusTile(
                title: "Alert",
                value: viewModel.canBroadcastOutboundSignals ? "Ready" : "Off",
                detail: "Emergency text broadcast",
                iconName: "exclamationmark.triangle.fill",
                tint: viewModel.canBroadcastOutboundSignals ? ColorTheme.danger : ColorTheme.warning
            )
            commandStatusTile(
                title: "Share",
                value: viewModel.canShareLocation ? "Ready" : "Blocked",
                detail: "Current position",
                iconName: "location.fill",
                tint: viewModel.canShareLocation ? ColorTheme.info : ColorTheme.warning
            )
            commandStatusTile(
                title: "Report",
                value: viewModel.activeBeacon == nil ? (viewModel.canUseBeaconMode ? "Standby" : "Blocked") : "Active",
                detail: viewModel.activeBeacon == nil ? "Broadcast situation" : "Update live report",
                iconName: "dot.radiowaves.left.and.right",
                tint: viewModel.activeBeacon == nil ? (viewModel.canUseBeaconMode ? ColorTheme.ready : ColorTheme.warning) : beaconAccentColor(for: viewModel.selectedBeaconType)
            )
        }
    }

    private var signalCommandColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
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

    private func quickTemplateTint(for template: String) -> Color {
        switch template {
        case "Need water":
            ColorTheme.water
        case "Safe here":
            ColorTheme.ready
        case "Fire nearby":
            ColorTheme.danger
        case "Need pickup":
            ColorTheme.warning
        default:
            ColorTheme.info
        }
    }

    private var orderedSelectedResources: [BeaconResource] {
        viewModel.selectedResources.sorted { $0.title < $1.title }
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

                Text(type.buttonTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTheme.text)

                Text(type.expiryBadgeTitle)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PremiumSurfaceBackground(
                    cornerRadius: 16,
                    backgroundAssetName: nil,
                    backgroundImageOffset: .zero,
                    atmosphere: (isSelected ? tint : ColorTheme.premium).opacity(isSelected ? 0.14 : 0.05)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .modifier(PremiumSurfaceChrome(cornerRadius: 16, edgeColor: (isSelected ? tint : ColorTheme.dividerStrong).opacity(0.18), shadowColor: tint.opacity(0.04)))
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func beaconAccentColor(for type: BeaconType) -> Color {
        switch type {
        case .safeLocation, .shelter:
            ColorTheme.ready
        case .waterAvailable:
            ColorTheme.water
        case .fuelAvailable, .fireSpotted, .floodedRoad, .roadBlocked:
            ColorTheme.warning
        case .medicalHelp, .needHelp:
            ColorTheme.danger
        }
    }

    private func sharedMedicalInfoBlock(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MEDICAL NOTE SHARED")
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.danger)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 14,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: ColorTheme.danger.opacity(0.12)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 14, edgeColor: ColorTheme.danger.opacity(0.16), shadowColor: ColorTheme.danger.opacity(0.04)))
    }

    private var signalFailureRows: [SignalFailureRowModel] {
        var rows: [SignalFailureRowModel] = []

        if viewModel.nearbyPeers.isEmpty && viewModel.connectedPeers.isEmpty {
            rows.append(
                SignalFailureRowModel(
                    title: "No nearby RediM8 users detected",
                    detail: "RediM8 is still listening, but nothing nearby is discoverable right now. Keep Bluetooth and Wi-Fi enabled and close distance before relying on Signal.",
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
                    title: "No recent mesh activity",
                    detail: "No alerts, direct messages, or connection events have been seen in this session yet.",
                    iconName: "clock.badge.xmark.fill",
                    tint: ColorTheme.textFaint
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 34, height: 34)

                    RediIcon(iconName)
                        .foregroundStyle(tint)
                        .frame(width: 16, height: 16)
                }

                Spacer(minLength: 0)
            }

            Text(title.uppercased())
                .font(RediTypography.metadata)
                .foregroundStyle(ColorTheme.textFaint)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(ColorTheme.text)

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(14)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 18,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 18, edgeColor: tint.opacity(0.12), shadowColor: tint.opacity(0.04)))
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)

                RediIcon(iconName)
                    .foregroundStyle(tint)
                    .frame(width: 16, height: 16)
            }

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(ColorTheme.text)

            Text(value.uppercased())
                .font(RediTypography.metadata)
                .foregroundStyle(tint)

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .padding(12)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 18,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 18, edgeColor: tint.opacity(0.14), shadowColor: tint.opacity(0.04)))
    }

    private func meshBannerStat(title: String, value: String, tint: Color) -> some View {
        return VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(RediTypography.metadata)
                .foregroundStyle(ColorTheme.textFaint)
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
                cornerRadius: 14,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 14, edgeColor: tint.opacity(0.1), shadowColor: tint.opacity(0.03)))
    }

    private func signalFailureRow(_ row: SignalFailureRowModel) -> some View {
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 18,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: row.tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 18, edgeColor: row.tint.opacity(0.12), shadowColor: row.tint.opacity(0.04)))
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
                cornerRadius: 18,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 18, edgeColor: tint.opacity(0.12), shadowColor: tint.opacity(0.04)))
    }
}

private struct SignalFailureRowModel: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let iconName: String
    let tint: Color
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
        switch type {
        case .safeLocation, .shelter:
            ColorTheme.ready
        case .waterAvailable:
            ColorTheme.water
        case .fuelAvailable, .fireSpotted, .floodedRoad, .roadBlocked:
            ColorTheme.warning
        case .medicalHelp, .needHelp:
            ColorTheme.danger
        }
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
                    .font(.caption.weight(.bold))
                Text(resource.title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(isSelected ? ColorTheme.text : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PremiumSurfaceBackground(
                    cornerRadius: 14,
                    backgroundAssetName: nil,
                    backgroundImageOffset: .zero,
                    atmosphere: (isSelected ? ColorTheme.info : ColorTheme.premium).opacity(isSelected ? 0.14 : 0.04)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .modifier(PremiumSurfaceChrome(cornerRadius: 14, edgeColor: (isSelected ? ColorTheme.info : ColorTheme.dividerStrong).opacity(0.16), shadowColor: ColorTheme.info.opacity(0.03)))
        }
        .buttonStyle(CardPressButtonStyle())
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
        }
    }
}
