import SwiftUI

enum MoreWorkspace: String, CaseIterable, Identifiable {
    case plan
    case vault
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plan: "Plan"
        case .vault: "Vault"
        case .settings: "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .plan: "Household readiness, supplies, and scenarios"
        case .vault: "Secure identity and emergency documents"
        case .settings: "Privacy, signal, maps, and device options"
        }
    }

    var systemImage: String {
        switch self {
        case .plan: "checklist"
        case .vault: "lock.doc.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct MoreView: View {
    let appState: AppState
    @ObservedObject var router: NavigationRouter
    let scrollToTopRequestID: Int
    let disablesAutomaticLocationPrompts: Bool

    @State private var selectedWorkspace: MoreWorkspace = .plan
    @State private var forwardedPlanScrollToTopRequestID = 0
    @State private var forwardedVaultScrollToTopRequestID = 0

    var body: some View {
        VStack(spacing: RediSpacing.section) {
            workspacePicker
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.screen)

            activeWorkspaceContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.bottom, RediLayout.commandDockContentInset)
        .navigationTitle("Workspace")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            handlePendingNavigation()
        }
        .onChange(of: router.selectedTab) { _, newTab in
            switch newTab {
            case .more, .plan, .vault, .library:
                handlePendingNavigation()
            default:
                break
            }
        }
        .onChange(of: scrollToTopRequestID) { _, _ in
            forwardScrollToTopToActiveWorkspace()
        }
    }

    private func handlePendingNavigation() {
        if router.selectedTab == .plan {
            selectedWorkspace = .plan
            router.selectedTab = .more
        } else if router.selectedTab == .vault {
            selectedWorkspace = .vault
            router.selectedTab = .more
        } else if router.selectedTab == .library {
            // Library is no longer user-visible from the More workspace.
            // Keep legacy deep links safe by falling back to the default workspace.
            selectedWorkspace = .plan
            router.selectedTab = .more
        }
    }

    // MARK: - Workspace Picker

    private var workspacePicker: some View {
        CommandPanel(eyebrow: "Preparedness") {
            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                ForEach(MoreWorkspace.allCases) { workspace in
                    workspaceButton(workspace)
                }
            }
        }
    }

    private func workspaceButton(_ workspace: MoreWorkspace) -> some View {
        let isSelected = selectedWorkspace == workspace

        return Button {
            withAnimation(RediMotion.reveal) {
                selectedWorkspace = workspace
            }
        } label: {
            HStack(alignment: .center, spacing: RediSpacing.content) {
                Image(systemName: workspace.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTheme.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(ColorTheme.gunmetal, in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(workspace.title)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                    Text(workspace.subtitle)
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Text("OPEN")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.accent)
                        .padding(.horizontal, RediSpacing.compact)
                        .padding(.vertical, RediSpacing.tight)
                        .background(ColorTheme.gunmetal, in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous))
                }
            }
            .padding(RediSpacing.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? ColorTheme.panelElevated : ColorTheme.panelRaised,
                in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .stroke(
                        isSelected ? ColorTheme.dividerStrong : ColorTheme.divider,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(CardPressButtonStyle())
        .accessibilityIdentifier("more.workspace.\(workspace.rawValue)")
    }

    // MARK: - Active Content

    @ViewBuilder
    private var activeWorkspaceContent: some View {
        switch selectedWorkspace {
        case .plan:
            PlanView(
                appState: appState,
                requestedFocus: $router.requestedPlanFocus,
                scrollToTopRequestID: router.scrollToTopRequestID(for: .plan) + forwardedPlanScrollToTopRequestID,
                disablesAutomaticLocationPrompts: disablesAutomaticLocationPrompts
            )
        case .vault:
            SecureVaultView(
                service: appState.documentVaultService,
                isProUser: appState.isProUser,
                storeKitService: appState.storeKitService,
                scrollToTopRequestID: router.scrollToTopRequestID(for: .vault) + forwardedVaultScrollToTopRequestID
            )
        case .settings:
            SettingsView(appState: appState)
        }
    }

    private func forwardScrollToTopToActiveWorkspace() {
        switch selectedWorkspace {
        case .plan:
            forwardedPlanScrollToTopRequestID += 1
        case .vault:
            forwardedVaultScrollToTopRequestID += 1
        case .settings:
            break
        }
    }
}
