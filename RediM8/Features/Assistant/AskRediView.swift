import SwiftUI

struct AskRediView: View {
    @StateObject private var viewModel: AssistantViewModel
    @ObservedObject private var appState: AppState
    @State private var scrollTarget = UUID()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let scrollToTopRequestID: Int
    let router: NavigationRouter

    private var topicColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible(), spacing: RediSpacing.compact)]
        } else {
            [GridItem(.adaptive(minimum: 136, maximum: 220), spacing: RediSpacing.compact)]
        }
    }

    init(appState: AppState, scrollToTopRequestID: Int, router: NavigationRouter) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: AssistantViewModel(appState: appState, sourceLabel: "Ask Redi"))
        self.scrollToTopRequestID = scrollToTopRequestID
        self.router = router
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: RediSpacing.section) {
                        advisorBriefingCard
                            .padding(.top, RediSpacing.content)
                            .id("ask-redi-top")

                        if viewModel.hasConversation {
                            conversationList
                        } else {
                            readyState
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(scrollTarget)
                    }
                    .padding(.horizontal, RediSpacing.screen)
                    .padding(.bottom, 80 + RediLayout.commandDockContentInset)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear {
                    viewModel.onAppear()
                }
                .onChange(of: viewModel.conversation.count) { _, _ in
                    scrollTarget = UUID()
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(scrollTarget, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: scrollToTopRequestID) { _, _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("ask-redi-top", anchor: .top)
                    }
                }
            }

            commandInput
        }
        .background(consoleBackground)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("REDI ADVISOR")
                        .font(RediTypography.data)
                        .foregroundStyle(ColorTheme.text)
                    Text("FIELD ADVISOR (OFFLINE CAPABLE)")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: viewModel.pendingMapAction?.id) { _, _ in
            guard let action = viewModel.pendingMapAction else { return }
            viewModel.pendingMapAction = nil

            if let lat = action.latitude, let lon = action.longitude {
                let label = action.label ?? "Location"
                let encodedLabel = label.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? label
                if let url = URL(string: "maps://?ll=\(lat),\(lon)&q=\(encodedLabel)") {
                    UIApplication.shared.open(url)
                }
            }
        }
        .onChange(of: viewModel.pendingTabAction?.id) { _, _ in
            guard let action = viewModel.pendingTabAction else { return }
            viewModel.pendingTabAction = nil

            switch action.tab {
            case "map":
                router.openMap()
            case "plan":
                if let focus = action.planFocus {
                    switch focus {
                    case "waterRuntime":
                        router.openWaterRuntime()
                    case "vehicleKit":
                        router.openVehicleReadiness()
                    case "evacuationRoutes":
                        router.openEvacuationRoutes()
                    default:
                        router.openPlan()
                    }
                } else {
                    router.openPlan()
                }
            case "signal":
                router.openSignalNearby()
            case "library":
                router.openLibrary()
            case "vault":
                router.openVault()
            default:
                break
            }
        }
        .sheet(item: $viewModel.selectedGuide) { guide in
            NavigationStack {
                GuideDetailView(
                    guide: guide,
                    isSaved: viewModel.isGuideSaved(guide.id),
                    onToggleSaved: { viewModel.toggleSavedGuide(guide.id) }
                )
            }
            .rediSheetPresentation()
        }
        .sheet(item: $viewModel.sharePayload) { payload in
            AssistantActivityView(activityItems: payload.items)
        }
    }

    // MARK: - Console Background

    private var consoleBackground: some View {
        ZStack {
            ColorTheme.background.ignoresSafeArea()

            Canvas { context, size in
                let spacing: CGFloat = 24
                let color = ColorTheme.dividerSubtle
                for x in stride(from: 0, through: size.width, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(color), lineWidth: 0.5)
                }
                for y in stride(from: 0, through: size.height, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(color), lineWidth: 0.5)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Ready State

    private var readyState: some View {
        VStack(alignment: .leading, spacing: RediSpacing.section) {
            commonTasksCard
            commonQuestionsCard
        }
    }

    private var advisorBriefingCard: some View {
        CommandPanel(eyebrow: "Field Advisor") {
            VStack(alignment: .leading, spacing: RediSpacing.content) {
                Text("Operational guidance when signal is limited")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(ColorTheme.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Responses prioritise speed and clarity for real-world conditions.")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                statusStrip
            }
        }
    }

    private var commonTasksCard: some View {
        PanelCard(
            title: "Common Tasks",
            subtitle: "Start with direct actions when time or signal is limited."
        ) {
            LazyVGrid(columns: topicColumns, spacing: RediSpacing.compact) {
                ForEach(taskShortcuts) { shortcut in
                    topicTile(shortcut)
                }
            }
        }
    }

    private var commonQuestionsCard: some View {
        PanelCard(
            title: "Common Questions in Emergencies",
            subtitle: "Short, situational prompts you can use immediately."
        ) {
            VStack(spacing: RediSpacing.tight) {
                ForEach(viewModel.suggestions.prefix(4), id: \.self) { suggestion in
                    Button {
                        viewModel.applySuggestion(suggestion)
                    } label: {
                        HStack(alignment: .top, spacing: RediSpacing.compact) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ColorTheme.textTertiary)
                                .padding(.top, 2)

                            Text(suggestion)
                                .font(RediTypography.caption)
                                .foregroundStyle(ColorTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, RediSpacing.card)
                        .padding(.vertical, RediSpacing.content)
                        .background(
                            ColorTheme.graphite,
                            in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                                .stroke(ColorTheme.dividerStrong, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())
                }
            }
        }
    }

    // MARK: - Status Strip

    private var statusStrip: some View {
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RediSpacing.compact) {
                ForEach(statusPillModels) { item in
                    statusPill(label: item.label, color: item.color)
                }
            }
        }
    }

    private func statusPill(label: String, color: Color) -> some View {
        HStack(spacing: RediSpacing.micro) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.text)
        }
        .padding(.horizontal, RediSpacing.compact)
        .padding(.vertical, RediSpacing.tight)
        .background(
            ColorTheme.graphite,
            in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                .stroke(ColorTheme.dividerStrong, lineWidth: 0.5)
        )
    }

    // MARK: - Topic Tiles

    private func topicTile(_ shortcut: AskRediTaskShortcut) -> some View {
        Button {
            viewModel.applySuggestion(shortcut.query)
        } label: {
            VStack(alignment: .leading, spacing: RediSpacing.tight) {
                HStack(alignment: .top, spacing: RediSpacing.tight) {
                    Image(systemName: shortcut.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(shortcut.tint)

                    Spacer(minLength: 0)

                    Text("TASK")
                        .font(RediTypography.label)
                        .tracking(1.1)
                        .foregroundStyle(ColorTheme.textTertiary)
                }

                Text(shortcut.title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(shortcut.detail)
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 104, alignment: .leading)
            .padding(.horizontal, RediSpacing.content)
            .padding(.vertical, RediSpacing.content)
            .background(
                ColorTheme.gunmetal,
                in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .stroke(shortcut.tint.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    // MARK: - Conversation

    private var conversationList: some View {
        VStack(alignment: .leading, spacing: RediSpacing.section) {
            ForEach(viewModel.conversation) { turn in
                VStack(alignment: .leading, spacing: RediSpacing.content) {
                    UserQueryBubble(query: turn.query)
                    AssistantResponseCard(
                        response: turn.response,
                        viewModel: viewModel
                    )
                }
            }
        }
    }

    // MARK: - Command Input

    private var commandInput: some View {
        VStack(alignment: .leading, spacing: RediSpacing.compact) {
            guidanceContextStrip

            HStack(alignment: .bottom, spacing: RediSpacing.compact) {
                TextField("What do you need help with?", text: $viewModel.draftQuery, axis: .vertical)
                    .lineLimit(1...4)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.text)
                    .tint(ColorTheme.accent)
                    .padding(.horizontal, RediSpacing.card)
                    .padding(.vertical, RediSpacing.card)
                    .background(
                        ColorTheme.fieldBackground,
                        in: RoundedRectangle(cornerRadius: RediRadius.field, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RediRadius.field, style: .continuous)
                            .stroke(ColorTheme.dividerStrong, lineWidth: 0.5)
                    )

                Button {
                    viewModel.submitCurrentDraft()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isDraftEmpty ? ColorTheme.textTertiary : ColorTheme.chalk)
                        .frame(width: 40, height: 40)
                        .background(
                            isDraftEmpty ? ColorTheme.gunmetal : ColorTheme.accent,
                            in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isDraftEmpty)
            }
        }
        .padding(.horizontal, RediSpacing.screen)
        .padding(.top, RediSpacing.compact)
        .padding(.bottom, max(RediSpacing.content, RediLayout.commandDockContentInset))
        .background(
            ColorTheme.charcoal
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(ColorTheme.divider)
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(.container, edges: .bottom)
        )
    }

    private var isDraftEmpty: Bool {
        viewModel.draftQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var statusPillModels: [AskRediStatusPill] {
        let meshCount = appState.meshService.connectedPeers.count
        let alertCount = appState.officialAlertService.library.alerts.count

        return [
            AskRediStatusPill(label: "OFFLINE READY", color: ColorTheme.ready),
            AskRediStatusPill(
                label: meshCount == 0
                    ? "NO MESH CONNECTION"
                    : meshCount == 1
                        ? "1 MESH CONNECTION"
                        : "\(meshCount) MESH CONNECTIONS",
                color: meshCount > 0 ? ColorTheme.ready : ColorTheme.textTertiary
            ),
            AskRediStatusPill(
                label: alertCount == 0
                    ? "NO ALERTS CACHED"
                    : alertCount == 1
                        ? "1 ALERT CACHED"
                        : "\(alertCount) ALERTS CACHED",
                color: alertCount == 0 ? ColorTheme.textTertiary : ColorTheme.warning
            )
        ]
    }

    private var taskShortcuts: [AskRediTaskShortcut] {
        [
            AskRediTaskShortcut(
                title: "First Aid",
                detail: "Immediate injury, bite, and bleeding response.",
                icon: "cross.case.fill",
                query: "Snake bite — what do I do immediately?",
                tint: ColorTheme.danger
            ),
            AskRediTaskShortcut(
                title: "Water & Hydration",
                detail: "Supply, purification, and rationing guidance.",
                icon: "drop.fill",
                query: "Water needed for 3 days (per person)",
                tint: ColorTheme.info
            ),
            AskRediTaskShortcut(
                title: "Fire / Bushfire",
                detail: "Movement, shelter, smoke, and evacuation advice.",
                icon: "flame.fill",
                query: "Bushfire nearby — what do I do immediately?",
                tint: ColorTheme.warning
            ),
            AskRediTaskShortcut(
                title: "Signal & Comms",
                detail: "Rescue signals, contacts, and fallback comms.",
                icon: "antenna.radiowaves.left.and.right",
                query: "How do I signal for rescue?",
                tint: ColorTheme.accent
            ),
            AskRediTaskShortcut(
                title: "Shelter",
                detail: "Temporary cover and exposure reduction.",
                icon: "house.fill",
                query: "How do I build a survival shelter?",
                tint: ColorTheme.textTertiary
            ),
            AskRediTaskShortcut(
                title: "Food",
                detail: "Safe sourcing, storage, and rationing steps.",
                icon: "leaf.fill",
                query: "How do I find safe food when stranded?",
                tint: ColorTheme.textTertiary
            ),
            AskRediTaskShortcut(
                title: "Navigation",
                detail: "Direction finding when GPS is unavailable.",
                icon: "safari.fill",
                query: "How do I navigate without GPS?",
                tint: ColorTheme.accent
            ),
            AskRediTaskShortcut(
                title: "Vehicle",
                detail: "Stay, leave, recover, or wait for extraction.",
                icon: "car.fill",
                query: "Vehicle breakdown — stay or leave?",
                tint: ColorTheme.textSecondary
            )
        ]
    }

    private var guidanceContextStrip: some View {
        let context = guidanceContext

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: context.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(context.tint)
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.title.uppercased())
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(context.tint)

                Text(context.detail)
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, RediSpacing.card)
        .padding(.vertical, RediSpacing.content)
        .background(
            ColorTheme.graphite,
            in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                .stroke(context.tint.opacity(0.2), lineWidth: 0.8)
        )
    }

    private var guidanceContext: AskRediGuidanceContext {
        if let activePrioritySituation = appState.activePrioritySituation {
            return context(for: activePrioritySituation)
        }

        let selectedSpecificScenarios = appState.profile.selectedScenarios.filter { $0 != .generalEmergencies }
        guard let primaryScenario = selectedSpecificScenarios.first else {
            return AskRediGuidanceContext(
                title: "No active scenario selected",
                detail: "Guidance will remain general until you select a scenario or activate a live situation.",
                icon: "circle.slash",
                tint: ColorTheme.textTertiary
            )
        }

        return baselineContext(for: primaryScenario, additionalScenarioCount: max(0, selectedSpecificScenarios.count - 1))
    }

    private func context(for situation: PrioritySituation) -> AskRediGuidanceContext {
        switch situation {
        case .bushfire:
            return AskRediGuidanceContext(
                title: "Current context: Bushfire",
                detail: "Guidance will prioritise evacuation, route checks, and fire conditions.",
                icon: "flame.fill",
                tint: ColorTheme.warning
            )
        case .flood:
            return AskRediGuidanceContext(
                title: "Current context: Flood",
                detail: "Guidance will prioritise movement away from water, flood hazards, and shelter access.",
                icon: "drop.triangle.fill",
                tint: ColorTheme.info
            )
        case .blackout:
            return AskRediGuidanceContext(
                title: "Current context: Blackout",
                detail: "Guidance will prioritise power continuity, communication, and household fallback actions.",
                icon: "bolt.slash.fill",
                tint: ColorTheme.warning
            )
        case .remoteTravel:
            return AskRediGuidanceContext(
                title: "Current context: Remote Travel",
                detail: "Guidance will prioritise vehicle movement, water, navigation, and extraction options.",
                icon: "car.fill",
                tint: ColorTheme.ready
            )
        }
    }

    private func baselineContext(for scenario: ScenarioKind, additionalScenarioCount: Int) -> AskRediGuidanceContext {
        let title: String
        if additionalScenarioCount > 0 {
            title = "Baseline context: \(scenario.title) + \(additionalScenarioCount) more"
        } else {
            title = "Baseline context: \(scenario.title)"
        }

        let detail: String
        switch scenario {
        case .bushfires:
            detail = "Guidance will lean toward bushfire movement, fire conditions, and evacuation planning."
        case .floods, .cyclones, .severeStorm:
            detail = "Guidance will lean toward storm movement, water hazards, and shelter access."
        case .powerOutages, .extendedInfrastructureDisruption, .extremeHeat, .fuelShortages:
            detail = "Guidance will lean toward power, communication, and continuity planning."
        case .remoteTravel, .campingOffGrid:
            detail = "Guidance will lean toward vehicle, water, navigation, and extraction planning."
        case .earthquake:
            detail = "Guidance will lean toward immediate safety checks, movement, and fallback planning."
        case .generalEmergencies:
            detail = "Guidance will remain general until a more specific scenario is active."
        }

        return AskRediGuidanceContext(
            title: title,
            detail: detail,
            icon: "scope",
            tint: ColorTheme.accent
        )
    }
}

private struct AskRediStatusPill: Identifiable {
    let id = UUID()
    let label: String
    let color: Color
}

private struct AskRediTaskShortcut: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let query: String
    let tint: Color
}

private struct AskRediGuidanceContext {
    let title: String
    let detail: String
    let icon: String
    let tint: Color
}
