import SwiftUI

struct AssistantResponseCard: View {
    let response: AssistantResponse
    @ObservedObject var viewModel: AssistantViewModel

    var body: some View {
        PanelCard(
            title: response.title,
            subtitle: response.answerModeTitle
        ) {
            VStack(alignment: .leading, spacing: RediSpacing.section) {
                Text(response.summary)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.text)

                metadataGrid

                if let fallbackExplanation = response.fallbackExplanation {
                    callout(title: "Fallback Mode", detail: fallbackExplanation, tint: ColorTheme.warning)
                }

                if let interpretationNote = response.interpretationNote {
                    callout(title: "Interpreted Safely", detail: interpretationNote, tint: ColorTheme.accent)
                }

                if response.usedOfflineModel {
                    callout(
                        title: "On-Device AI Summary",
                        detail: "RediM8 used the local model to clarify the guide summary. Steps and safety notes still come directly from bundled guides.",
                        tint: ColorTheme.ready
                    )
                }

                if !response.contextSections.isEmpty {
                    let hazardSections = response.contextSections.filter(\.isHazardWarning)
                    let standardSections = response.contextSections.filter { !$0.isHazardWarning }

                    if !hazardSections.isEmpty {
                        VStack(alignment: .leading, spacing: RediSpacing.compact) {
                            ForEach(hazardSections) { section in
                                contextSection(section)
                            }
                        }
                    }

                    if !standardSections.isEmpty {
                        VStack(alignment: .leading, spacing: RediSpacing.compact) {
                            Text("LOCAL CONTEXT")
                                .font(RediTypography.label)
                                .tracking(1.2)
                                .foregroundStyle(ColorTheme.textTertiary)

                            ForEach(standardSections) { section in
                                contextSection(section)
                            }
                        }
                    }
                }

                if !response.steps.isEmpty {
                    VStack(alignment: .leading, spacing: RediSpacing.compact) {
                        Text("STEPS")
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)

                        ForEach(Array(response.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: RediSpacing.compact) {
                                Text("\(index + 1)")
                                    .font(RediTypography.data)
                                    .foregroundStyle(ColorTheme.accent)
                                    .frame(width: 20)

                                Text(step)
                                    .font(RediTypography.body)
                                    .foregroundStyle(ColorTheme.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }

                if !response.safetyNotes.isEmpty {
                    VStack(alignment: .leading, spacing: RediSpacing.compact) {
                        Text("SAFETY NOTES")
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)

                        ForEach(response.safetyNotes, id: \.self) { note in
                            callout(title: "Important", detail: note, tint: ColorTheme.warning)
                        }
                    }
                }

                if let escalationNote = response.escalationNote {
                    callout(title: "Escalation", detail: escalationNote, tint: ColorTheme.danger)
                }

                if !response.relatedGuides.isEmpty {
                    VStack(alignment: .leading, spacing: RediSpacing.compact) {
                        Text("RELATED GUIDES")
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)

                        ForEach(Array(response.relatedGuides.prefix(3))) { guide in
                            Button {
                                viewModel.openGuide(guide)
                            } label: {
                                HStack(alignment: .top, spacing: RediSpacing.compact) {
                                    Image(systemName: guide.heroIconName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(ColorTheme.textTertiary)
                                        .frame(width: 28, height: 28)
                                        .background(ColorTheme.gunmetal, in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(guide.title)
                                            .font(RediTypography.bodyStrong)
                                            .foregroundStyle(ColorTheme.text)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Text(guide.summary)
                                            .font(RediTypography.caption)
                                            .foregroundStyle(ColorTheme.textSecondary)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(RediSpacing.content)
                                .background(ColorTheme.panelRaised, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                                        .stroke(ColorTheme.divider, lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let primaryGuide = response.primaryGuide {
                    actionRow(for: primaryGuide)
                }
            }
        }
    }

    // MARK: - Subviews

    private var metadataGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: RediSpacing.compact), GridItem(.flexible(), spacing: RediSpacing.compact)], spacing: RediSpacing.compact) {
            metadataTile(title: "Confidence", value: response.confidenceTitle)
            metadataTile(title: "Trust", value: response.trustLabelTitle)
            metadataTile(title: "Last Reviewed", value: response.lastReviewedSummary)
            metadataTile(title: "Source", value: response.sourceSummary)
            metadataTile(title: "Region", value: response.regionSummary)
            metadataTile(title: "Risk", value: response.riskBand.rawValue.capitalized)
        }
    }

    private func actionRow(for guide: Guide) -> some View {
        HStack(spacing: RediSpacing.compact) {
            actionButton(title: "Open Guide", systemImage: "book.fill") {
                viewModel.openGuide(guide)
            }

            actionButton(
                title: viewModel.isGuideSaved(guide.id) ? "Saved" : "Save",
                systemImage: viewModel.isGuideSaved(guide.id) ? "bookmark.fill" : "bookmark"
            ) {
                _ = viewModel.toggleSavedGuide(guide.id)
            }

            actionButton(title: "Share", systemImage: "square.and.arrow.up.fill") {
                viewModel.shareGuide(guide)
            }
        }
    }

    private func contextSection(_ section: AssistantContextSection) -> some View {
        let sectionTint = tint(for: section.tone)

        return VStack(alignment: .leading, spacing: RediSpacing.compact) {
            HStack(spacing: RediSpacing.tight) {
                if section.isHazardWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(sectionTint)
                }

                Text(section.title.uppercased())
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(sectionTint)
            }

            Text(section.detail)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textSecondary)

            if section.items.isEmpty {
                Text("No nearby offline context is available right now.")
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textTertiary)
            } else {
                ForEach(section.items) { item in
                    VStack(alignment: .leading, spacing: RediSpacing.tight) {
                        Text(item.title)
                            .font(RediTypography.bodyStrong)
                            .foregroundStyle(ColorTheme.text)

                        Text(item.detail)
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.textSecondary)

                        if let caption = item.caption {
                            Text(caption)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(ColorTheme.textTertiary)
                        }

                        if !item.actions.isEmpty {
                            HStack(spacing: RediSpacing.tight) {
                                ForEach(Array(item.actions.enumerated()), id: \.offset) { _, action in
                                    contextActionButton(action: action, tint: sectionTint)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(RediSpacing.compact)
                    .background(ColorTheme.panelRaised, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                            .stroke(ColorTheme.divider, lineWidth: 0.5)
                    )
                }
            }
        }
        .padding(RediSpacing.content)
        .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                .stroke(
                    section.isHazardWarning ? sectionTint.opacity(0.3) : ColorTheme.divider,
                    lineWidth: section.isHazardWarning ? 1 : 0.5
                )
        )
    }

    // MARK: - Primitives

    private func contextActionButton(action: AssistantContextAction, tint: Color) -> some View {
        Button {
            viewModel.handleContextAction(action)
        } label: {
            HStack(spacing: RediSpacing.micro) {
                Image(systemName: contextActionIcon(for: action))
                    .font(.system(size: 10, weight: .bold))
                Text(contextActionLabel(for: action).uppercased())
                    .font(RediTypography.label)
                    .tracking(1.2)
            }
            .foregroundStyle(ColorTheme.accent)
            .padding(.horizontal, RediSpacing.compact)
            .padding(.vertical, RediSpacing.tight)
            .background(ColorTheme.gunmetal, in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                    .stroke(ColorTheme.dividerStrong, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func actionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: RediSpacing.tight) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                Text(title.uppercased())
                    .font(RediTypography.label)
                    .tracking(1.2)
            }
            .foregroundStyle(ColorTheme.accent)
            .padding(.horizontal, RediSpacing.content)
            .padding(.vertical, RediSpacing.compact)
            .frame(maxWidth: .infinity)
            .background(ColorTheme.gunmetal, in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .stroke(ColorTheme.dividerStrong, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func callout(title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: RediSpacing.compact) {
            Rectangle()
                .fill(tint)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(tint)
                Text(detail)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.text)
            }
        }
        .padding(RediSpacing.content)
        .background(ColorTheme.graphite, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
        )
    }

    private func metadataTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: RediSpacing.micro) {
            Text(title.uppercased())
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
            Text(value)
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RediSpacing.content)
        .background(ColorTheme.graphite, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private var responseTint: Color {
        switch response.riskBand {
        case .critical:
            ColorTheme.danger
        case .advisory:
            ColorTheme.accent
        case .unknown:
            ColorTheme.warning
        }
    }

    private func tint(for tone: AssistantContextTone) -> Color {
        switch tone {
        case .danger:
            ColorTheme.danger
        case .warning:
            ColorTheme.warning
        case .info:
            ColorTheme.accent
        case .ready:
            ColorTheme.ready
        case .neutral:
            ColorTheme.textSecondary
        }
    }

    private func guideAccent(for guide: Guide) -> Color {
        switch guide.category {
        case .firstAid, .medical:
            ColorTheme.danger
        case .disasterResponse, .fireSafety, .heatSafety, .stormSafety, .floodSafety:
            ColorTheme.warning
        case .bushcraft, .foodCooking, .foodGrowing:
            ColorTheme.accent
        case .navigation, .waterSafety:
            ColorTheme.accent
        case .wildlife, .trapping, .toolcraft, .fieldComms, .sanitation,
             .psychology, .security, .vehicleSurvival, .waterSourcing,
             .shelterBuilding, .firecraft, .navigationAdvanced:
            ColorTheme.accent
        }
    }

    private func contextActionIcon(for action: AssistantContextAction) -> String {
        switch action {
        case .openMap:
            "map.fill"
        case .navigateToCoordinate:
            "location.fill"
        case .openGuide:
            "book.fill"
        case .openTab:
            "square.grid.2x2.fill"
        case .openPlanFocus:
            "checklist"
        }
    }

    private func contextActionLabel(for action: AssistantContextAction) -> String {
        switch action {
        case .openMap:
            "Map"
        case .navigateToCoordinate:
            "Navigate"
        case .openGuide:
            "Open Steps"
        case .openTab:
            "Open"
        case .openPlanFocus:
            "Review"
        }
    }
}
