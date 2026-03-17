import SwiftUI

struct AskRediView: View {
    @StateObject private var viewModel: AssistantViewModel
    @State private var scrollTarget = UUID()

    let scrollToTopRequestID: Int
    let router: NavigationRouter

    private let topicColumns = [
        GridItem(.adaptive(minimum: 100, maximum: 160), spacing: RediSpacing.compact)
    ]

    init(appState: AppState, scrollToTopRequestID: Int, router: NavigationRouter) {
        _viewModel = StateObject(wrappedValue: AssistantViewModel(appState: appState, sourceLabel: "Ask Redi"))
        self.scrollToTopRequestID = scrollToTopRequestID
        self.router = router
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if viewModel.hasConversation {
                            conversationList
                                .padding(.top, RediSpacing.compact)
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
                    Text("ASK REDI")
                        .font(RediTypography.data)
                        .foregroundStyle(ColorTheme.text)
                    Text("OFFLINE ADVISOR")
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
            statusStrip
                .padding(.top, RediSpacing.content)
                .id("ask-redi-top")

            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text("QUICK TOPICS")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                LazyVGrid(columns: topicColumns, spacing: RediSpacing.compact) {
                    topicTile(title: "First Aid", icon: "cross.case", query: "first aid emergency help")
                    topicTile(title: "Water", icon: "drop", query: "how do I find water from terrain")
                    topicTile(title: "Fire", icon: "flame", query: "how do I start a fire with nothing")
                    topicTile(title: "Shelter", icon: "house", query: "how do I build a survival shelter")
                    topicTile(title: "Food", icon: "leaf", query: "how do I trap food or forage safely")
                    topicTile(title: "Navigate", icon: "safari", query: "how do I navigate without GPS")
                    topicTile(title: "Signal", icon: "antenna.radiowaves.left.and.right", query: "how do I signal for rescue")
                    topicTile(title: "Vehicle", icon: "car", query: "should I stay with my vehicle or leave")
                }
            }

            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                Text("SUGGESTED")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                VStack(spacing: RediSpacing.tight) {
                    ForEach(viewModel.suggestions.prefix(4), id: \.self) { suggestion in
                        Button {
                            viewModel.applySuggestion(suggestion)
                        } label: {
                            HStack(spacing: RediSpacing.compact) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(ColorTheme.textTertiary)

                                Text(suggestion)
                                    .font(RediTypography.caption)
                                    .foregroundStyle(ColorTheme.textSecondary)
                                    .lineLimit(1)

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
                                    .stroke(ColorTheme.divider, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Status Strip

    private var statusStrip: some View {
        let meshCount = viewModel.appState.meshService.connectedPeers.count
        let alertCount = viewModel.appState.officialAlertService.library.alerts.count

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RediSpacing.compact) {
                statusPill(label: "OFFLINE", color: ColorTheme.ready)
                statusPill(
                    label: "MESH \(meshCount)",
                    color: meshCount > 0 ? ColorTheme.ready : ColorTheme.textTertiary
                )
                statusPill(
                    label: "ALERTS \(alertCount)",
                    color: alertCount == 0 ? ColorTheme.textTertiary : ColorTheme.warning
                )
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
                .foregroundStyle(ColorTheme.textSecondary)
        }
        .padding(.horizontal, RediSpacing.compact)
        .padding(.vertical, RediSpacing.tight)
        .background(
            ColorTheme.graphite,
            in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
        )
    }

    // MARK: - Topic Tiles

    private func topicTile(title: String, icon: String, query: String) -> some View {
        Button {
            viewModel.applySuggestion(query)
        } label: {
            HStack(spacing: RediSpacing.tight) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ColorTheme.textTertiary)

                Text(title.uppercased())
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.text)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, RediSpacing.content)
            .padding(.vertical, RediSpacing.content)
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
        HStack(alignment: .bottom, spacing: RediSpacing.compact) {
            TextField("Ask anything about survival", text: $viewModel.draftQuery, axis: .vertical)
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
}
