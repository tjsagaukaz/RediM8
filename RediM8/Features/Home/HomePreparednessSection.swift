import SwiftUI

extension HomeView {
    var operationalInsightsContent: some View {
        VStack(alignment: .leading, spacing: RediSpacing.section) {
            if !viewModel.forgottenItems.isEmpty {
                VStack(alignment: .leading, spacing: RediSpacing.compact) {
                    Text(L10n.tr("home.operational_insights.forgotten_title", "OFTEN FORGOTTEN"))
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)

                    ForEach(Array(viewModel.forgottenItems.prefix(3))) { item in
                        insightRow(
                            title: item.title,
                            detail: item.detail,
                            systemImage: item.systemImage,
                            tint: ColorTheme.warning
                        )
                    }
                }
            }

            if viewModel.shouldShowExpiryReminders {
                VStack(alignment: .leading, spacing: RediSpacing.compact) {
                    Text(L10n.tr("home.operational_insights.expiry_title", "SUPPLY EXPIRY"))
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)

                    ForEach(Array(viewModel.expiryReminders.prefix(3))) { reminder in
                        insightRow(
                            title: reminder.title,
                            detail: reminder.detail,
                            systemImage: reminder.status == .overdue ? "exclamationmark.triangle.fill" : "calendar.badge.exclamationmark",
                            tint: reminder.status == .overdue ? ColorTheme.danger : ColorTheme.warning
                        )
                    }
                }
            }

            if viewModel.shouldShowWaterSourceGuidance {
                VStack(alignment: .leading, spacing: RediSpacing.compact) {
                    Text(L10n.tr("home.operational_insights.water_sources_title", "NEAREST WATER SOURCES"))
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)

                    NearbyWaterSourcesSection(
                        sources: viewModel.nearbyWaterSources,
                        contextText: viewModel.waterSourceContext,
                        emptyMessage: viewModel.waterSourceStatusMessage
                    )
                }
            }
        }
    }

    var bushfireModeCard: some View {
        VStack(alignment: .leading, spacing: RediSpacing.section) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: RediSpacing.tight) {
                    Text(L10n.tr("home.bushfire.mode_active.display", "BUSHFIRE MODE ACTIVE"))
                        .accessibilityLabel(L10n.tr("home.bushfire.mode_active", "Bushfire mode active"))
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.warning)
                    Text("\(viewModel.bushfireReadinessPercentage)%")
                        .font(RediTypography.dataHero)
                        .foregroundStyle(ColorTheme.text)
                        .accessibilityLabel(L10n.tr("home.bushfire.readiness_score_label", "Overall bushfire readiness"))
                        .accessibilityValue(L10n.format("home.bushfire.readiness_score_value", "%d percent", viewModel.bushfireReadinessPercentage))
                    Text(L10n.tr("home.bushfire.readiness_subtitle", "Overall bushfire readiness"))
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                }

                Spacer()

                RediIcon("fire_trail")
                    .foregroundStyle(ColorTheme.warning)
                    .frame(width: 28, height: 28)
                    .padding(RediSpacing.card)
                    .background(ColorTheme.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            }

            VStack(spacing: RediSpacing.content) {
                ForEach(viewModel.bushfireStatusRows) { row in
                    HStack(spacing: RediSpacing.content) {
                        RediIcon(row.systemImage)
                            .foregroundStyle(bushfireToneColor(row.tone))
                            .frame(width: 22, height: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(RediTypography.bodyStrong)
                                .foregroundStyle(ColorTheme.text)
                            Text(row.detail)
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(RediSpacing.content)
                    .homeInsetSurface(cornerRadius: RediRadius.card)
                }
            }

            Rectangle()
                .fill(ColorTheme.divider)
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text(L10n.tr("home.bushfire.checklist_title", "BUSHFIRE CHECKLIST"))
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                ForEach(viewModel.bushfireChecklistItems) { item in
                    Button {
                        viewModel.toggleBushfireChecklist(item.kind)
                    } label: {
                        HStack(spacing: RediSpacing.content) {
                            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isChecked ? ColorTheme.ready : ColorTheme.warning)
                            Text(item.kind.title)
                                .font(RediTypography.bodyStrong)
                                .foregroundStyle(ColorTheme.text)
                            Spacer()
                        }
                        .padding(.vertical, RediSpacing.micro)
                    }
                    .buttonStyle(CardPressButtonStyle())
                }
            }

            Rectangle()
                .fill(ColorTheme.divider)
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text(L10n.tr("home.bushfire.approaching_label", "BUSHFIRE APPROACHING"))
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                ForEach(Array(viewModel.bushfireEmergencySteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: RediSpacing.content) {
                        Text("\(index + 1).")
                            .font(RediTypography.data)
                            .foregroundStyle(ColorTheme.warning)
                        Text(step)
                            .font(RediTypography.body)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }
            }

            HStack(alignment: .top, spacing: RediSpacing.content) {
                RediIcon("warning")
                    .foregroundStyle(ColorTheme.warning)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text(viewModel.bushfireReminderTitle)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                    Text(viewModel.bushfireReminderMessage)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                }
            }
            .padding(RediSpacing.card)
            .homeInsetSurface(cornerRadius: RediRadius.card)
        }
    }

    var priorityModeCard: some View {
        VStack(alignment: .leading, spacing: RediSpacing.card) {
            LazyVGrid(columns: priorityColumns, spacing: RediSpacing.compact) {
                ForEach(viewModel.prioritySituationOptions) { situation in
                    Button {
                        viewModel.togglePrioritySituation(situation)
                    } label: {
                        HStack(spacing: RediSpacing.compact) {
                            RediIcon(situation.systemImage)
                                .frame(width: 15, height: 15)
                            Text(situation.title)
                                .font(RediTypography.bodyStrong)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(appState.activePrioritySituation == situation ? ColorTheme.warning : ColorTheme.text)
                        .padding(.horizontal, RediSpacing.card)
                        .padding(.vertical, RediSpacing.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .homeInsetSurface(cornerRadius: RediRadius.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                                .fill(
                                    appState.activePrioritySituation == situation
                                        ? ColorTheme.warning.opacity(0.12)
                                        : Color.clear
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                                .stroke(
                                    appState.activePrioritySituation == situation
                                        ? ColorTheme.warning.opacity(0.4)
                                        : ColorTheme.dividerStrong,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())
                }
            }

            if let summary = viewModel.priorityModeSummary {
                VStack(alignment: .leading, spacing: RediSpacing.card) {
                    HStack {
                        Text(L10n.tr("home.priority.active_label", "PRIORITY MODE ACTIVE"))
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.warning)
                        Spacer()
                        Button(L10n.tr("common.clear", "Clear")) {
                            viewModel.clearPriorityMode()
                        }
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: RediSpacing.content) {
                        ForEach(summary.actions) { action in
                            HStack(alignment: .top, spacing: RediSpacing.content) {
                                RediIcon(action.systemImage)
                                    .foregroundStyle(ColorTheme.warning)
                                    .frame(width: 16, height: 16)
                                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                                    Text(action.title)
                                        .font(RediTypography.bodyStrong)
                                        .foregroundStyle(ColorTheme.text)
                                    Text(action.detail)
                                        .font(RediTypography.body)
                                        .foregroundStyle(ColorTheme.textSecondary)
                                }
                            }
                        }
                    }

                    if !summary.resources.isEmpty {
                        Rectangle()
                            .fill(ColorTheme.divider)
                            .frame(height: 0.5)

                        VStack(alignment: .leading, spacing: RediSpacing.compact) {
                            Text(L10n.tr("home.priority.resources_label", "NEAREST RESOURCES"))
                                .font(RediTypography.label)
                                .tracking(1.2)
                                .foregroundStyle(ColorTheme.textTertiary)

                            ForEach(summary.resources) { resource in
                                HStack(alignment: .top, spacing: RediSpacing.content) {
                                    RediIcon(resource.systemImage)
                                        .foregroundStyle(ColorTheme.accent)
                                        .frame(width: 16, height: 16)
                                    VStack(alignment: .leading, spacing: RediSpacing.micro) {
                                        Text(resource.title)
                                            .font(RediTypography.bodyStrong)
                                            .foregroundStyle(ColorTheme.text)
                                        Text(resource.detail)
                                            .font(RediTypography.body)
                                            .foregroundStyle(ColorTheme.textSecondary)
                                    }
                                }
                            }
                        }
                    }

                    if !summary.evacuationOptions.isEmpty {
                        Rectangle()
                            .fill(ColorTheme.divider)
                            .frame(height: 0.5)

                        VStack(alignment: .leading, spacing: RediSpacing.compact) {
                            Text(L10n.tr("home.priority.evacuation_options_label", "EVACUATION OPTIONS"))
                                .font(RediTypography.label)
                                .tracking(1.2)
                                .foregroundStyle(ColorTheme.textTertiary)

                            ForEach(summary.evacuationOptions, id: \.self) { option in
                                HStack(alignment: .top, spacing: RediSpacing.compact) {
                                    RediIcon("route", fallbackSystemName: "arrow.triangle.turn.up.right.diamond.fill")
                                        .foregroundStyle(ColorTheme.accent)
                                        .frame(width: 14, height: 14)
                                        .padding(.top, RediSpacing.micro)
                                    Text(option)
                                        .font(RediTypography.body)
                                        .foregroundStyle(ColorTheme.textSecondary)
                                }
                            }
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: RediSpacing.content) {
                            Button(L10n.tr("home.priority.leave_now", "LEAVE NOW")) {
                                router.presentLeaveNowMode(appState: appState)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())

                            Button(L10n.tr("home.priority.emergency_screen", "Emergency Screen")) {
                                router.presentEmergencyMode(appState: appState)
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }

                        VStack(spacing: RediSpacing.content) {
                            Button(L10n.tr("home.priority.leave_now", "LEAVE NOW")) {
                                router.presentLeaveNowMode(appState: appState)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())

                            Button(L10n.tr("home.priority.emergency_screen", "Emergency Screen")) {
                                router.presentEmergencyMode(appState: appState)
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                }
            } else {
                Text(L10n.tr(
                    "home.priority.empty_state",
                    "Bushfire, flood, blackout, and remote-travel incidents each get their own action order so the app tells the user what matters first."
                ))
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.textSecondary)
            }
        }
    }

    private func insightRow(title: String, detail: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: RediSpacing.content) {
            RediIcon(systemImage)
                .foregroundStyle(tint)
                .frame(width: 24, height: 24, alignment: .center)

            VStack(alignment: .leading, spacing: RediSpacing.micro) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)
            }
        }
    }
}
