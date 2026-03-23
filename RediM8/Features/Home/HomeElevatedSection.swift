import SwiftUI

extension HomeView {
    /// True when official alerts indicate a real, area-scoped threat that demands
    /// immediate action — not planning, not readiness scores, not upsells.
    /// Uses the ViewModel's safe mode summary (which requires both the alert AND
    /// resolved shelter/water/route data) rather than the raw AppState signal alone.
    var isElevatedMode: Bool {
        viewModel.safeModeSummary != nil
    }

    /// Stripped decision surface shown when `isElevatedMode` is true.
    /// Hero threat → primary actions → alerts → collapsed tools. Nothing else.
    @ViewBuilder
    var elevatedModeContent: some View {
        if appState.isStealthModeEnabled {
            StealthModeIndicatorView()
        }

        elevatedStateAnchor

        if let summary = viewModel.safeModeSummary {
            // Emergency Warning alerts surface above the hero — user reads
            // "THIS IS HAPPENING" before "DO THIS".
            if summary.alert.severity == .emergencyWarning {
                officialAlertsPanel
                elevatedHeroCard(summary: summary)
            } else {
                elevatedHeroCard(summary: summary)
                officialAlertsPanel
            }
        }

        elevatedPrimaryActions

        elevatedSecondaryAccess
    }

    // MARK: - State Anchor

    /// Persistent emergency-active indicator. Reinforces context without
    /// consuming significant space.
    private var elevatedStateAnchor: some View {
        HStack(spacing: RediSpacing.compact) {
            Circle()
                .fill(ColorTheme.danger)
                .frame(width: 8, height: 8)

            Text("EMERGENCY ACTIVE")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.danger)

            Spacer(minLength: 0)

            Text(Date.now, style: .time)
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.textTertiary)
        }
        .padding(.horizontal, RediSpacing.card)
        .padding(.vertical, RediSpacing.compact)
        .background(ColorTheme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Emergency active")
    }

    // MARK: - Hero Card

    private func elevatedHeroCard(summary: SafeModeHomeSummary) -> some View {
        VStack(alignment: .leading, spacing: RediSpacing.content) {
            HStack(alignment: .top, spacing: RediSpacing.content) {
                RediIcon(summary.alert.kind.systemImage)
                    .foregroundStyle(ColorTheme.danger)
                    .frame(width: 22, height: 22)
                    .padding(12)
                    .background(ColorTheme.danger.opacity(0.16), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text(summary.alert.severity.title.uppercased())
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.danger)

                    Text(summary.alert.title)
                        .font(RediTypography.display)
                        .foregroundStyle(ColorTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            TrustPillGroup(items: viewModel.officialAlertTrustItems)

            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                elevatedInfoLine(label: "Shelter", detail: summary.nearestShelterLine)
                elevatedInfoLine(label: "Water", detail: summary.nearestWaterLine)
                elevatedInfoLine(label: "Route", detail: summary.routeLine)
            }

            Text(summary.note)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RediSpacing.screen)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTheme.panelRaised, in: RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                .stroke(ColorTheme.danger.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active threat: \(summary.alert.title)")
    }

    private func elevatedInfoLine(label: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: RediSpacing.compact) {
            Text(label.uppercased())
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
                .frame(width: 58, alignment: .leading)

            Text(detail)
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Primary Actions

    private var elevatedPrimaryActions: some View {
        VStack(spacing: RediSpacing.content) {
            Button {
                RediHaptics.emergency(enabled: !appState.isStealthModeEnabled)
                router.presentEmergencyMode(appState: appState)
            } label: {
                HStack(spacing: RediSpacing.content) {
                    RediIcon("warning")
                        .foregroundStyle(Color.white)
                        .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: RediSpacing.micro) {
                        Text("START EMERGENCY ACTIONS")
                            .font(RediTypography.button)
                            .foregroundStyle(Color.white)
                        Text("Evacuation flow, emergency call, signal, and offline tools.")
                            .font(RediTypography.caption)
                            .foregroundStyle(Color.white.opacity(0.82))
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(RediSpacing.screen)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [ColorTheme.danger, ColorTheme.danger.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.elevated.emergencyMode")

            elevatedSecondaryButton(
                title: "LEAVE NOW",
                detail: "Evacuation checklist and departure.",
                iconName: "route",
                tint: ColorTheme.warning
            ) {
                RediHaptics.emergency(enabled: !appState.isStealthModeEnabled)
                router.presentLeaveNowMode(appState: appState)
            }

            elevatedSecondaryButton(
                title: "VIEW MAP",
                detail: "Routes and offline coverage.",
                iconName: "map_marker",
                tint: ColorTheme.accent
            ) {
                router.openMap()
            }
        }
    }

    private func elevatedSecondaryButton(
        title: String,
        detail: String,
        iconName: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: RediSpacing.content) {
                RediIcon(iconName)
                    .foregroundStyle(tint)
                    .frame(width: 18, height: 18)
                    .padding(10)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text(title)
                        .font(RediTypography.button)
                        .foregroundStyle(ColorTheme.text)
                    Text(detail)
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(RediSpacing.card)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(ColorTheme.panelRaised, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    // MARK: - Secondary Access (Collapsed)

    private var elevatedSecondaryAccess: some View {
        CollapsiblePanelCard(
            title: "If Needed",
            subtitle: "Signal, blackout mode, contacts, and guides.",
            accent: ColorTheme.textTertiary,
            isExpanded: $isShowingQuickAccess
        ) {
            VStack(spacing: RediSpacing.content) {
                elevatedToolRow(title: "Signal Nearby", systemImage: "signal") {
                    router.openSignalNearby()
                }
                elevatedToolRow(title: "Blackout Mode", systemImage: "flashlight") {
                    router.presentBlackout(appState: appState)
                }
                elevatedToolRow(title: "Emergency Guides", systemImage: "first_aid") {
                    router.presentEmergencyGuides(appState: appState)
                }
                elevatedToolRow(title: "Emergency Contacts", systemImage: "family") {
                    router.openPlan()
                }
            }
        }
    }

    private func elevatedToolRow(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: RediSpacing.content) {
                RediIcon(systemImage)
                    .foregroundStyle(ColorTheme.textTertiary)
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.textTertiary)
            }
            .padding(RediSpacing.card)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .stroke(ColorTheme.divider, lineWidth: 0.5)
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }
}
