import SwiftUI

extension HomeView {
    var quickAccessHubCard: some View {
        CollapsiblePanelCard(
            title: L10n.tr("home.quick_access.title", "Command Tools"),
            subtitle: L10n.tr(
                "home.quick_access.subtitle",
                "Emergency modes, signal, vault, guides, and vehicle tools."
            ),
            accent: ColorTheme.accent,
            accessibilityIdentifier: "home.commandTools.toggle",
            isExpanded: $isShowingQuickAccess
        ) {
            quickAccessContent
        }
    }

    private var quickAccessContent: some View {
        VStack(alignment: .leading, spacing: RediSpacing.section) {
            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text(L10n.tr("home.quick_access.group.emergency", "EMERGENCY"))
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                LazyVGrid(columns: decisionColumns, spacing: RediSpacing.content) {
                    Button {
                        RediHaptics.emergency(enabled: !appState.isStealthModeEnabled)
                        router.presentEmergencyMode(appState: appState)
                    } label: {
                        RediCommandCard(
                            title: L10n.tr("home.quick_access.emergency_mode.title", "Emergency Mode"),
                            detail: L10n.tr(
                                "home.quick_access.emergency_mode.detail",
                                "Official alerts, hazard actions, and command tools."
                            ),
                            systemImage: "exclamationmark.triangle.fill",
                            tint: ColorTheme.danger,
                            badge: L10n.tr("home.quick_access.emergency_mode.badge", "Critical"),
                            prominence: .critical
                        )
                    }
                    .accessibilityIdentifier("home.emergencyModeTrigger")
                    .buttonStyle(CardPressButtonStyle())

                    Button {
                        RediHaptics.emergency(enabled: !appState.isStealthModeEnabled)
                        router.presentLeaveNowMode(appState: appState)
                    } label: {
                        RediCommandCard(
                            title: L10n.tr("home.quick_access.leave_now.title", "Leave Now"),
                            detail: L10n.tr(
                                "home.quick_access.leave_now.detail",
                                "Evacuation steps, routes, and go-time checks."
                            ),
                            systemImage: "figure.run",
                            tint: ColorTheme.warning,
                            badge: L10n.tr("home.quick_access.leave_now.badge", "Evacuate"),
                            prominence: .critical
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())
                }
            }

            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text(L10n.tr("home.quick_access.group.tools", "TOOLS"))
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                LazyVGrid(columns: quickActionColumns, spacing: RediSpacing.content) {
                    quickActionButton(
                        title: L10n.tr("home.quick_access.blackout.title", "Blackout Mode"),
                        subtitle: L10n.tr("home.quick_access.blackout.subtitle", "Dim tools"),
                        systemImage: "lightbulb.slash.fill",
                        tint: ColorTheme.textTertiary
                    ) {
                        router.presentBlackout(appState: appState)
                    }

                    quickActionButton(
                        title: L10n.tr("home.quick_access.signal_nearby.title", "Signal Nearby"),
                        subtitle: L10n.tr("home.quick_access.signal_nearby.subtitle", "Open mesh"),
                        systemImage: "antenna.radiowaves.left.and.right",
                        tint: ColorTheme.accent
                    ) {
                        router.openSignalNearby()
                    }

                    quickActionButton(
                        title: L10n.tr("home.quick_access.guides.title", "Emergency Guides"),
                        subtitle: L10n.tr("home.quick_access.guides.subtitle", "Offline help"),
                        systemImage: "books.vertical.fill",
                        tint: ColorTheme.textTertiary
                    ) {
                        router.presentEmergencyGuides(appState: appState)
                    }

                    quickActionButton(
                        title: appState.isStealthModeEnabled
                            ? L10n.tr("home.quick_access.stealth.disable_title", "Disable Stealth")
                            : L10n.tr("home.quick_access.stealth.enable_title", "Stealth Mode"),
                        subtitle: appState.isStealthModeEnabled
                            ? L10n.tr("home.quick_access.stealth.disable_subtitle", "Receive-only on")
                            : L10n.tr("home.quick_access.stealth.enable_subtitle", "Hide & conserve"),
                        systemImage: "eye.slash.fill",
                        tint: ColorTheme.textSecondary
                    ) {
                        appState.toggleStealthMode()
                    }
                }
            }

            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text(L10n.tr("home.quick_access.group.readiness", "READINESS"))
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                LazyVGrid(columns: decisionColumns, spacing: RediSpacing.content) {
                    decisionToolButton(
                        title: L10n.tr("home.quick_access.vault.title", "Secure Vault"),
                        value: appState.documentVaultService.isUnlocked
                            ? L10n.tr("home.quick_access.vault.value_ready", "Ready")
                            : L10n.tr("home.quick_access.vault.value_locked", "Locked"),
                        subtitle: L10n.tr("home.quick_access.vault.subtitle", "ID, insurance, and medical docs"),
                        systemImage: "documents",
                        tint: appState.documentVaultService.isUnlocked ? ColorTheme.ready : ColorTheme.accent,
                        action: { router.openVault() }
                    )

                    decisionToolButton(
                        title: L10n.tr("home.quick_access.vehicle.title", "Vehicle Kit"),
                        value: viewModel.vehicleReadinessPlan.readiness.percentage.percentageText,
                        subtitle: L10n.format(
                            "home.quick_access.vehicle.subtitle",
                            "%1$d / %2$d essentials checked",
                            viewModel.vehicleReadinessPlan.readiness.completedCount,
                            viewModel.vehicleReadinessPlan.readiness.totalCount
                        ),
                        systemImage: "car.fill",
                        tint: readinessColor(for: viewModel.vehicleReadinessPlan.readiness.percentage),
                        action: { router.openVehicleReadiness() }
                    )
                }

                Button {
                    activeSheet = .readinessReport
                } label: {
                    RediCommandCard(
                        title: L10n.tr("home.quick_access.readiness_report.title", "Readiness Report"),
                        detail: L10n.tr(
                            "home.quick_access.readiness_report.detail",
                            "Generate a PDF summary to save, share, or send to family."
                        ),
                        systemImage: "doc.richtext.fill",
                        tint: ColorTheme.accent,
                        badge: L10n.tr("home.common.badge.pdf", "PDF"),
                        prominence: .neutral,
                        layout: .rail
                    )
                }
                .buttonStyle(CardPressButtonStyle())
            }
        }
    }

    private func decisionToolButton(
        title: String,
        value: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RediCommandCard(
                title: title,
                detail: subtitle,
                systemImage: systemImage,
                tint: tint,
                badge: value,
                prominence: .accented,
                minHeight: 126
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func quickActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RediCommandCard(
                title: title,
                detail: subtitle,
                systemImage: systemImage,
                tint: tint,
                prominence: .neutral,
                minHeight: 96
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }
}
