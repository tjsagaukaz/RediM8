import SwiftUI

struct AssistantResponseCard: View {
    let response: AssistantResponse
    @ObservedObject var viewModel: AssistantViewModel
    @State private var isShowingSecondaryContent: Bool

    init(response: AssistantResponse, viewModel: AssistantViewModel) {
        self.response = response
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _isShowingSecondaryContent = State(initialValue: !response.shouldCollapseSecondaryContentByDefault)
    }

    var body: some View {
        PanelCard(
            title: response.title,
            subtitle: response.panelSubtitle
        ) {
            VStack(alignment: .leading, spacing: contentSpacing) {
                let hazardSections = response.contextSections.filter(\.isHazardWarning)
                let standardSections = response.contextSections.filter { !$0.isHazardWarning }
                let visibleSafetyNotes = response.visibleSafetyNotes
                let showsSecondaryContent = !response.shouldCollapseSecondaryContentByDefault || isShowingSecondaryContent
                let primaryAction = preferredPrimaryAction
                let hasSecondaryBlocks =
                    response.fallbackExplanation != nil
                    || response.usedOfflineModel
                    || response.interpretationNote != nil
                    || !hazardSections.isEmpty
                    || !standardSections.isEmpty
                    || !visibleSafetyNotes.isEmpty
                    || !response.relatedGuides.isEmpty
                    || !response.sourceSummary.isEmpty

                if response.shouldShowTrustStrip {
                    TrustStripView(status: response.advisorContextStatus)
                }

                if showsSecondaryContent, let fallbackExplanation = response.fallbackExplanation {
                    callout(title: "Closest Match", detail: fallbackExplanation, tint: ColorTheme.warning)
                }

                if showsSecondaryContent, let interpretationNote = response.interpretationNote {
                    callout(title: "Interpreted For Routing", detail: interpretationNote, tint: ColorTheme.accent)
                }

                if showsSecondaryContent, response.usedOfflineModel {
                    callout(
                        title: "On-Device Language Pass",
                        detail: "RediM8 used the local model only to tighten wording. Steps and safety notes still come from bundled guides.",
                        tint: ColorTheme.ready
                    )
                }

                if showsSecondaryContent, !hazardSections.isEmpty {
                    VStack(alignment: .leading, spacing: RediSpacing.compact) {
                        ForEach(hazardSections) { section in
                            contextSection(section)
                        }
                    }
                }

                callout(title: response.situationHeading, detail: response.summary, tint: responseTint)

                if let primaryAction,
                   response.shouldPrioritizePrimaryActionRow {
                    primaryActionSection(primaryAction)
                }

                if showsSecondaryContent, !standardSections.isEmpty {
                    VStack(alignment: .leading, spacing: RediSpacing.compact) {
                        Text(response.contextHeading.uppercased())
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)

                        ForEach(standardSections) { section in
                            contextSection(section)
                        }
                    }
                }

                if !response.steps.isEmpty {
                    VStack(alignment: .leading, spacing: RediSpacing.compact) {
                        Text(response.actionsHeading.uppercased())
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)

                        ForEach(Array(response.visibleSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: RediSpacing.compact) {
                                Text("\(index + 1)")
                                    .font(stepIndexFont(for: index))
                                    .foregroundStyle(ColorTheme.accent)
                                    .frame(width: 20)

                                Text(step)
                                    .font(stepFont(for: index))
                                    .foregroundStyle(ColorTheme.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.bottom, stepBottomPadding(after: index))
                        }
                    }
                }

                if let escalationNote = response.escalationNote {
                    callout(title: "Escalate Now", detail: escalationNote, tint: ColorTheme.danger)
                }

                if showsSecondaryContent, !visibleSafetyNotes.isEmpty {
                    VStack(alignment: .leading, spacing: RediSpacing.compact) {
                        Text(response.avoidHeading.uppercased())
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)

                        ForEach(visibleSafetyNotes, id: \.self) { note in
                            callout(title: "Avoid", detail: note, tint: ColorTheme.warning)
                        }
                    }
                }

                if let primaryGuide = response.primaryGuide,
                   response.shouldPrioritizePrimaryActionRow,
                   shouldShowSecondaryGuideAction {
                    secondaryGuideActionRow(for: primaryGuide)
                }

                if let clarifyingQuestion = response.clarifyingQuestion {
                    VStack(alignment: .leading, spacing: RediSpacing.compact) {
                        Text(response.questionHeading.uppercased())
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)

                        callout(title: "One Quick Check", detail: clarifyingQuestion.prompt, tint: ColorTheme.accent)

                        HStack(spacing: RediSpacing.compact) {
                            ForEach(clarifyingQuestion.options, id: \.self) { option in
                                actionButton(title: option, systemImage: "arrow.turn.down.right") {
                                    viewModel.submitClarifyingOption(option)
                                }
                            }
                        }
                    }
                }

                if response.shouldCollapseSecondaryContentByDefault, hasSecondaryBlocks {
                    collapsedSecondaryToggle
                }

                if showsSecondaryContent, response.shouldShowOperationalMetadata {
                    VStack(alignment: .leading, spacing: RediSpacing.compact) {
                        Text(response.sourceHeading.uppercased())
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)

                        metadataGrid
                    }

                    if !standardSections.isEmpty {
                        VStack(alignment: .leading, spacing: RediSpacing.compact) {
                            Text(response.contextHeading.uppercased())
                                .font(RediTypography.label)
                                .tracking(1.2)
                                .foregroundStyle(ColorTheme.textTertiary)

                            ForEach(standardSections) { section in
                                contextSection(section)
                            }
                        }
                    }

                    if !response.relatedGuides.isEmpty {
                        VStack(alignment: .leading, spacing: RediSpacing.compact) {
                            Text(response.guidesHeading.uppercased())
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
                }

                if let primaryGuide = response.primaryGuide,
                   !response.shouldPrioritizePrimaryActionRow {
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
            metadataTile(title: "Mode", value: response.deliveryModeTitle)
        }
    }

    private var contentSpacing: CGFloat {
        if response.isCrisisPresentation {
            return RediSpacing.section
        }

        if response.isElevatedPresentation {
            return RediSpacing.content
        }

        return RediSpacing.section
    }

    private var collapsedSecondaryToggle: some View {
        Button {
            isShowingSecondaryContent.toggle()
        } label: {
            HStack(spacing: RediSpacing.tight) {
                Image(systemName: isShowingSecondaryContent ? "chevron.up" : "ellipsis")
                    .font(.system(size: 10, weight: .bold))

                Text(isShowingSecondaryContent ? "HIDE EXTRA DETAIL" : "SHOW MORE")
                    .font(RediTypography.label)
                    .tracking(1.2)

                Spacer(minLength: 0)
            }
            .foregroundStyle(ColorTheme.textSecondary)
            .padding(.horizontal, RediSpacing.content)
            .padding(.vertical, RediSpacing.compact)
            .background(
                ColorTheme.graphite,
                in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .stroke(ColorTheme.divider, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func primaryActionSection(_ action: PrioritizedAssistantAction) -> some View {
        VStack(alignment: .leading, spacing: RediSpacing.tight) {
            Text("PRIMARY ACTION")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)

            Button {
                performPrioritizedAction(action)
            } label: {
                HStack(spacing: RediSpacing.compact) {
                    Image(systemName: prioritizedActionSystemImage(for: action))
                        .font(.system(size: 12, weight: .bold))

                    Text(prioritizedActionTitle(for: action).uppercased())
                        .font(RediTypography.button)
                        .tracking(1.2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(ColorTheme.accent)
                .padding(.horizontal, RediSpacing.content)
                .padding(.vertical, response.isCrisisPresentation ? RediSpacing.section : RediSpacing.content)
                .frame(maxWidth: .infinity)
                .background(ColorTheme.gunmetal, in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .stroke(ColorTheme.dividerStrong, lineWidth: 0.75)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func actionRow(for guide: Guide) -> some View {
        HStack(spacing: RediSpacing.compact) {
            actionButton(title: "Open Full Guide", systemImage: "book.fill") {
                viewModel.openGuide(guide)
            }

            if !response.shouldPrioritizePrimaryActionRow {
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
    }

    private func secondaryGuideActionRow(for guide: Guide) -> some View {
        HStack(spacing: RediSpacing.compact) {
            actionButton(title: "Open Full Guide", systemImage: "book.fill") {
                viewModel.openGuide(guide)
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
                    .fixedSize(horizontal: false, vertical: true)
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

}

private enum PrioritizedAssistantAction {
    case context(AssistantContextAction)
    case guide(Guide)
}

struct TrustStripView: View {
    let status: AdvisorContextStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: RediSpacing.tight) {
                Image(systemName: status.iconName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ColorTheme.textTertiary)

                Text(status.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            if let detail = status.detail {
                Text(detail)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(ColorTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RediSpacing.content)
        .padding(.vertical, RediSpacing.compact)
        .background(ColorTheme.graphite, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
    }
}

extension AssistantResponseCard {
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

    private var preferredPrimaryAction: PrioritizedAssistantAction? {
        guard response.shouldPrioritizePrimaryActionRow else {
            return nil
        }

        if let contextAction = prioritizedContextActions.first {
            return .context(contextAction)
        }

        if let primaryGuide = response.primaryGuide {
            return .guide(primaryGuide)
        }

        return nil
    }

    private var shouldShowSecondaryGuideAction: Bool {
        guard let preferredPrimaryAction else {
            return false
        }

        if case .context = preferredPrimaryAction {
            return true
        }

        return false
    }

    private var prioritizedContextActions: [AssistantContextAction] {
        var orderedActions: [AssistantContextAction] = []

        let sections = response.contextSections.sorted { lhs, rhs in
            if lhs.isHazardWarning == rhs.isHazardWarning {
                return false
            }

            return lhs.isHazardWarning && !rhs.isHazardWarning
        }

        for section in sections {
            for item in section.items {
                for action in item.actions where !orderedActions.contains(action) {
                    orderedActions.append(action)
                }
            }
        }

        return orderedActions.sorted { prioritizedContextActionRank($0) < prioritizedContextActionRank($1) }
    }

    private func prioritizedContextActionRank(_ action: AssistantContextAction) -> Int {
        let hasRouteRisk = response.situationSnapshot?.routeStatus == .atRisk || response.situationSnapshot?.routeStatus == .blocked

        switch action {
        case .callNumber:
            return 0
        case .navigateToCoordinate:
            return 1
        case .openMap:
            return hasRouteRisk ? 2 : 3
        case let .openTab(tab):
            return tab.lowercased() == "map" ? (hasRouteRisk ? 2 : 4) : 7
        case .openPlanFocus:
            return 6
        case .openGuide:
            return 8
        }
    }

    private func prioritizedActionTitle(for action: PrioritizedAssistantAction) -> String {
        switch action {
        case let .context(contextAction):
            switch contextAction {
            case let .callNumber(_, label):
                return label
            case .openMap, .navigateToCoordinate:
                switch response.situationSnapshot?.routeStatus {
                case .blocked:
                    return "View Alternative Route"
                case .atRisk:
                    return "View Safe Route"
                default:
                    return response.isCrisisPresentation ? "Open Map" : "Review Map"
                }
            case let .openTab(tab):
                if tab.lowercased() == "map" {
                    switch response.situationSnapshot?.routeStatus {
                    case .blocked:
                        return "View Alternative Route"
                    case .atRisk:
                        return "View Safe Route"
                    default:
                        return "Open Map"
                    }
                }
                return "Open \(tab.capitalized)"
            case .openPlanFocus:
                return "Review Plan"
            case .openGuide:
                return response.isCrisisPresentation ? "Review Next Steps" : "Open Full Guide"
            }
        case .guide:
            return response.isCrisisPresentation ? "Review Next Steps" : "Open Full Guide"
        }
    }

    private func prioritizedActionSystemImage(for action: PrioritizedAssistantAction) -> String {
        switch action {
        case let .context(contextAction):
            return contextActionIcon(for: contextAction)
        case .guide:
            return "book.fill"
        }
    }

    private func performPrioritizedAction(_ action: PrioritizedAssistantAction) {
        switch action {
        case let .context(contextAction):
            viewModel.handleContextAction(contextAction)
        case let .guide(guide):
            viewModel.openGuide(guide)
        }
    }

    private func stepFont(for index: Int) -> Font {
        if response.isCrisisPresentation, index == 0 {
            return RediTypography.screenSubtitle
        }

        if response.isElevatedPresentation, index == 0 {
            return RediTypography.bodyStrong
        }

        return RediTypography.body
    }

    private func stepIndexFont(for index: Int) -> Font {
        if response.isCrisisPresentation, index == 0 {
            return RediTypography.bodyStrong
        }

        return RediTypography.data
    }

    private func stepBottomPadding(after index: Int) -> CGFloat {
        if response.isCrisisPresentation, index == 0 {
            return RediSpacing.compact
        }

        return 0
    }

    private func contextActionIcon(for action: AssistantContextAction) -> String {
        switch action {
        case .callNumber:
            "phone.fill"
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
        case .callNumber:
            "Call"
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
