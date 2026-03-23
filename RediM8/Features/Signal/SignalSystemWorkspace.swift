import SwiftUI

// MARK: - System Workspace (Scanner + Diagnostics)

struct SignalSystemWorkspaceView: View {
    @ObservedObject var viewModel: SignalViewModel
    @Binding var isShowingSessionFeed: Bool
    let isSignalPulseActive: Bool
    let signalStatusColor: Color

    var body: some View {
        scannerWorkspaceContent
        diagnosticsWorkspaceContent
    }

    // MARK: - Scanner

    private var scannerWorkspaceContent: some View {
        VStack(spacing: 16) {
            localSituationalScannerPanel
        }
    }

    private var localSituationalScannerPanel: some View {
        PanelCard(title: "Local Situational Scanner", subtitle: "Phone-only situational awareness that still works when no other RediM8 users are nearby") {
            VStack(alignment: .leading, spacing: 16) {
                SignalViewHelpers.signalInsetCard(tint: scannerAccentColor) {
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
                    SignalViewHelpers.signalMetricTile(
                        title: "GPS",
                        value: viewModel.scannerSnapshot.gpsState.title,
                        detail: viewModel.scannerSnapshot.gpsState.detail,
                        iconName: "location.fill",
                        tint: SignalViewHelpers.color(for: viewModel.scannerSnapshot.gpsState.tone)
                    )
                    SignalViewHelpers.signalMetricTile(
                        title: "Network",
                        value: viewModel.scannerSnapshot.networkState.title,
                        detail: viewModel.scannerSnapshot.networkState.detail,
                        iconName: "antenna.radiowaves.left.and.right",
                        tint: SignalViewHelpers.color(for: viewModel.scannerSnapshot.networkState.tone)
                    )
                    SignalViewHelpers.signalMetricTile(
                        title: "Nearby Radio",
                        value: viewModel.scannerSnapshot.radioState.title,
                        detail: viewModel.scannerSnapshot.radioState.detail,
                        iconName: "dot.radiowaves.left.and.right",
                        tint: SignalViewHelpers.color(for: viewModel.scannerSnapshot.radioState.tone)
                    )
                    SignalViewHelpers.signalMetricTile(
                        title: "Power",
                        value: viewModel.scannerSnapshot.batteryPercentageText,
                        detail: viewModel.scannerSnapshot.powerState.detail,
                        iconName: "battery.100",
                        tint: SignalViewHelpers.color(for: viewModel.scannerSnapshot.powerState.tone)
                    )
                    SignalViewHelpers.signalMetricTile(
                        title: "Pressure",
                        value: viewModel.scannerSnapshot.pressureTrend.title,
                        detail: viewModel.scannerSnapshot.pressureTrend.detail,
                        iconName: "barometer",
                        tint: SignalViewHelpers.color(for: viewModel.scannerSnapshot.pressureTrend.tone)
                    )
                }

                if !viewModel.scannerAlerts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scanner cues")
                            .font(RediTypography.heading)
                            .foregroundStyle(ColorTheme.text)

                        ForEach(viewModel.scannerAlerts) { alert in
                            SignalViewHelpers.scannerAlertRow(alert)
                        }
                    }
                }

                Text("Scanner cues are local hints only. They help when the mesh is empty, but they do not confirm what other people are doing until reports arrive.")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
            }
        }
    }

    // MARK: - Diagnostics

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

    private var failureModesPanel: some View {
        PanelCard(title: "Failure Modes", subtitle: "What still works right now") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(signalFailureRows) { row in
                    SignalViewHelpers.signalFailureRow(row)
                }
            }
        }
    }

    private var signalLimitsPanel: some View {
        PanelCard(title: "Signal Limits", subtitle: "Fast reminder before you rely on mesh") {
            VStack(alignment: .leading, spacing: 12) {
                rangeIndicatorCard
                SignalViewHelpers.signalLimitLine(iconName: "antenna.radiowaves.left.and.right", text: "Short-range assistive messaging only")
                SignalViewHelpers.signalLimitLine(iconName: "iphone.slash", text: "Not a replacement for cellular or satellite")
                SignalViewHelpers.signalLimitLine(iconName: "exclamationmark.triangle.fill", text: "Delivery not guaranteed")
                SignalViewHelpers.signalLimitLine(iconName: "bolt.horizontal.circle", text: "Bluetooth + Wi-Fi must stay available")
            }
        }
    }

    private var meshDetailsPanel: some View {
        PanelCard(title: "Mesh Details", subtitle: "Plain-language local status") {
            VStack(alignment: .leading, spacing: 12) {
                SignalViewHelpers.meshDetailRow(label: "Your device ID", value: viewModel.userFacingDeviceID)
                if let visibleDeviceName = viewModel.visibleDeviceName {
                    SignalViewHelpers.meshDetailRow(label: "Visible name", value: visibleDeviceName)
                }
                SignalViewHelpers.meshDetailRow(label: "Nearby users", value: viewModel.nearbyPeerSummary)
                SignalViewHelpers.meshDetailRow(label: "Messages", value: viewModel.messageAvailabilitySummary)
                SignalViewHelpers.meshDetailRow(label: "Relay reports", value: viewModel.relayStatusSummary)
                SignalViewHelpers.meshDetailRow(label: "Last activity", value: viewModel.lastSignalLabel)
                SignalViewHelpers.meshDetailRow(label: "Sharing mode", value: viewModel.sharingModeSummary)
                SignalViewHelpers.meshDetailRow(label: "Constraints", value: viewModel.workingConstraintSummary)

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
                        SignalViewHelpers.signalInsetCard(tint: message.kindLabel == "Alert" ? ColorTheme.danger : ColorTheme.accent) {
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

    // MARK: - Range Indicator

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    // MARK: - Computed Helpers

    private var signalCommandColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 108, maximum: 170), spacing: 10)
        ]
    }

    private var scannerAccentColor: Color {
        SignalViewHelpers.color(for: viewModel.scannerTone)
    }

    var signalFailureRows: [SignalFailureRowModel] {
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
}
