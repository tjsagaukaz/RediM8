import SwiftUI

struct MeshPeerTrustManagementView: View {
    @ObservedObject var meshService: MeshService
    @State private var peers: [KnownMeshPeer] = []
    @State private var peerToForget: KnownMeshPeer?
    @State private var showForgetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                trustHero
                verifiedPeersSection
                unknownPeersSection
                blockedPeersSection
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle("Peer Trust")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshPeers() }
        .alert("Forget Device", isPresented: $showForgetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Forget", role: .destructive) {
                if let peer = peerToForget {
                    meshService.forgetPeer(peer.displayName)
                    refreshPeers()
                }
            }
        } message: {
            if let peer = peerToForget {
                Text("Remove \(peer.displayName) from your known devices? If they connect again, they will appear as a new unknown peer.")
            }
        }
    }

    // MARK: - Hero

    private var trustHero: some View {
        ModeHeroCard(
            eyebrow: "Mesh Security",
            title: "Peer Trust",
            subtitle: "Control which devices can contribute trusted data. Only verified peers' hazard reports affect routing.",
            iconName: "shield.checkered",
            accent: ColorTheme.accent
        ) {
            TrustPillGroup(items: [
                TrustPillItem(title: "\(verifiedCount) verified", tone: verifiedCount > 0 ? .verified : .info),
                TrustPillItem(title: "\(unknownCount) unverified", tone: unknownCount > 0 ? .caution : .info),
                TrustPillItem(title: "\(blockedCount) blocked", tone: blockedCount > 0 ? .caution : .info)
            ])
        }
    }

    // MARK: - Sections

    private var verifiedPeersSection: some View {
        let verified = peers.filter { $0.trustLevel == .verified }
        return Group {
            if !verified.isEmpty {
                PanelCard(
                    title: "Verified Devices",
                    subtitle: "These devices can contribute hazard data to routing"
                ) {
                    ForEach(verified) { peer in
                        peerRow(peer)
                        if peer.id != verified.last?.id {
                            SettingsDivider()
                        }
                    }
                }
            }
        }
    }

    private var unknownPeersSection: some View {
        let unknown = peers.filter { $0.trustLevel == .unknown }
        return Group {
            if !unknown.isEmpty {
                PanelCard(
                    title: "Unverified Devices",
                    subtitle: "Connected previously but not yet verified by you"
                ) {
                    ForEach(unknown) { peer in
                        peerRow(peer)
                        if peer.id != unknown.last?.id {
                            SettingsDivider()
                        }
                    }
                }
            }
        }
    }

    private var blockedPeersSection: some View {
        let blocked = peers.filter { $0.trustLevel == .blocked }
        return Group {
            if !blocked.isEmpty {
                PanelCard(
                    title: "Blocked Devices",
                    subtitle: "Connections and messages from these devices are rejected"
                ) {
                    ForEach(blocked) { peer in
                        peerRow(peer)
                        if peer.id != blocked.last?.id {
                            SettingsDivider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Peer Row

    private func peerRow(_ peer: KnownMeshPeer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(peer.displayName)
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)

                    if let fp = meshService.shortFingerprint(for: peer.displayName) {
                        Text("ID: \(fp)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(ColorTheme.textTertiary)
                    }

                    Text("First seen \(peer.firstSeenAt.formatted(.relative(presentation: .named)))")
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
                Spacer()
                trustLevelBadge(peer.trustLevel)
            }

            HStack(spacing: 8) {
                switch peer.trustLevel {
                case .unknown:
                    Button("Verify") {
                        meshService.verifyPeer(peer.displayName)
                        refreshPeers()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button("Block") {
                        meshService.blockPeer(peer.displayName)
                        refreshPeers()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                case .verified:
                    Button("Revoke") {
                        meshService.revokePeerTrust(peer.displayName)
                        refreshPeers()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button("Block") {
                        meshService.blockPeer(peer.displayName)
                        refreshPeers()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                case .blocked:
                    Button("Unblock") {
                        meshService.revokePeerTrust(peer.displayName)
                        refreshPeers()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                Spacer()

                Button {
                    peerToForget = peer
                    showForgetConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func trustLevelBadge(_ level: MeshPeerTrustLevel) -> some View {
        let (text, color): (String, Color) = {
            switch level {
            case .verified: return ("VERIFIED", ColorTheme.ready)
            case .unknown: return ("UNVERIFIED", ColorTheme.warning)
            case .blocked: return ("BLOCKED", ColorTheme.danger)
            }
        }()

        return Text(text)
            .font(RediTypography.label)
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func refreshPeers() {
        peers = meshService.knownPeers
    }

    private var verifiedCount: Int { peers.filter { $0.trustLevel == .verified }.count }
    private var unknownCount: Int { peers.filter { $0.trustLevel == .unknown }.count }
    private var blockedCount: Int { peers.filter { $0.trustLevel == .blocked }.count }
}
