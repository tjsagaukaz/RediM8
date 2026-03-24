import SwiftUI

// MARK: - Network Workspace (Accountability + Nearby)

struct SignalNetworkWorkspaceView: View {
    @ObservedObject var viewModel: SignalViewModel

    var body: some View {
        accountabilityWorkspaceContent
        nearbyWorkspaceContent
    }

    // MARK: - Accountability

    private var accountabilityWorkspaceContent: some View {
        VStack(spacing: 16) {
            accountabilityModePanel
        }
    }

    private var accountabilityModePanel: some View {
        PanelCard(title: "Accountability Mode", subtitle: "Offline roll call for household, street, camp, or team. Your own status can still broadcast when nearby mesh links appear.") {
            VStack(alignment: .leading, spacing: 16) {
                SignalViewHelpers.signalInsetCard(tint: accountabilityAccentColor) {
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

                SignalViewHelpers.signalInsetCard(tint: accountabilitySelfStatusTint) {
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

                SignalViewHelpers.signalInsetCard(tint: ColorTheme.accent) {
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

    // MARK: - Accountability Components

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

        return SignalViewHelpers.signalInsetCard(tint: tint) {
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

    // MARK: - Nearby Content

    private var nearbyWorkspaceContent: some View {
        VStack(spacing: 16) {
            nearbySituationReportsPanel
            nearbyUsersPanel
            peerTrustPanel
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
                        nearbyBeaconCard(beacon)
                    }
                }
            }
        }
    }

    private func nearbyBeaconCard(_ beacon: CommunityBeacon) -> some View {
        SignalViewHelpers.signalInsetCard(tint: SignalViewHelpers.beaconAccentColor(for: beacon.type)) {
            SignalViewHelpers.beaconTypeStrip(for: beacon.type)

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
                SignalViewHelpers.signalHighlightsBlock(beacon.signalHighlights, accent: SignalViewHelpers.beaconAccentColor(for: beacon.type))
            }

            if let message = beacon.message.nilIfBlank {
                Text(message)
                    .font(RediTypography.body)
                    .foregroundStyle(.secondary)
            }

            if let sharedEmergencyMedicalSummary = beacon.sharedEmergencyMedicalSummary {
                SignalViewHelpers.sharedMedicalInfoBlock(sharedEmergencyMedicalSummary)
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

    private var nearbyUsersPanel: some View {
        PanelCard(title: "Nearby Devices", subtitle: "Discovered over short-range local mesh only") {
            if viewModel.nearbyPeers.isEmpty {
                Text("No nearby devices detected. Keep Bluetooth and Wi-Fi enabled, then move within likely short range.")
                    .font(RediTypography.body)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.nearbyPeers) { peer in
                        let trust = viewModel.meshService.peerTrustLevel(for: peer.displayName)
                        let isConnected = viewModel.connectedPeers.contains(peer)
                        let tint = peerTintColor(trust: trust, isConnected: isConnected)

                        SignalViewHelpers.signalInsetCard(tint: tint) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(peer.displayName)
                                            .font(RediTypography.heading)
                                            .foregroundStyle(ColorTheme.text)
                                        peerTrustBadge(trust)
                                    }
                                    Text(isConnected ? "Connected" : "Discovered")
                                        .font(RediTypography.body)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if isConnected {
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

    private var peerTrustPanel: some View {
        let knownPeers = viewModel.meshService.knownPeers
        return PanelCard(
            title: "Peer Trust",
            subtitle: knownPeers.isEmpty ? "No known mesh peers" : "\(knownPeers.count) known device(s)"
        ) {
            if knownPeers.isEmpty {
                Text("Peers appear here after their first mesh connection. You can verify, block, or forget devices to control what data you trust.")
                    .font(RediTypography.body)
                    .foregroundStyle(.secondary)
            } else {
                NavigationLink {
                    MeshPeerTrustManagementView(meshService: viewModel.meshService)
                } label: {
                    SettingsNavigationRow(
                        title: "Manage Trusted Devices",
                        subtitle: trustSummaryText(knownPeers),
                        value: "Open"
                    )
                }
                .buttonStyle(.plain)
            }

            Text("Only verified peers can contribute hazard data to routing. Unknown peers' reports are visible but informational only.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func trustSummaryText(_ peers: [KnownMeshPeer]) -> String {
        let verified = peers.filter { $0.trustLevel == .verified }.count
        let blocked = peers.filter { $0.trustLevel == .blocked }.count
        var parts: [String] = []
        if verified > 0 { parts.append("\(verified) verified") }
        if blocked > 0 { parts.append("\(blocked) blocked") }
        let unknown = peers.count - verified - blocked
        if unknown > 0 { parts.append("\(unknown) unverified") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func peerTrustBadge(_ trust: MeshPeerTrustLevel) -> some View {
        switch trust {
        case .verified:
            Text("VERIFIED")
                .font(RediTypography.label)
                .tracking(1.0)
                .foregroundStyle(ColorTheme.ready)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(ColorTheme.ready.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        case .blocked:
            Text("BLOCKED")
                .font(RediTypography.label)
                .tracking(1.0)
                .foregroundStyle(ColorTheme.danger)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(ColorTheme.danger.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        case .unknown:
            EmptyView()
        }
    }

    private func peerTintColor(trust: MeshPeerTrustLevel, isConnected: Bool) -> Color {
        switch trust {
        case .blocked: return ColorTheme.danger
        case .verified: return isConnected ? ColorTheme.ready : ColorTheme.accent
        case .unknown: return isConnected ? ColorTheme.accent : ColorTheme.warning
        }
    }

    // MARK: - Color Helpers

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

    private var canTriggerBroadcast: Bool {
        viewModel.canBroadcastOutboundSignals && !viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
