import SwiftUI

struct LeaveNowView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel: LeaveNowViewModel
    let dismiss: () -> Void
    let openMap: () -> Void
    let openSignal: () -> Void

    init(
        appState: AppState,
        dismiss: @escaping () -> Void,
        openMap: @escaping () -> Void,
        openSignal: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: LeaveNowViewModel(appState: appState))
        self.dismiss = dismiss
        self.openMap = openMap
        self.openSignal = openSignal
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                if requiresScrollableLayout(in: proxy.size) {
                    ScrollView {
                        leaveNowContent(in: proxy.size, fixedHeightLayout: false)
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    leaveNowContent(in: proxy.size, fixedHeightLayout: true)
                        .padding(24)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            OperationalStatusRail(items: viewModel.statusItems, accent: ColorTheme.danger)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ThumbActionDock {
                VStack(spacing: 12) {
                    actionFooterButton(
                        title: "Open Offline Map",
                        detail: viewModel.mapStatusLine,
                        assetName: "route",
                        tint: ColorTheme.accent,
                        action: openMap
                    )

                    HStack(spacing: 12) {
                        actionFooterButton(
                            title: "Call 000",
                            detail: "Fastest option if mobile coverage is still available.",
                            assetName: "emergency",
                            tint: ColorTheme.danger,
                            action: callEmergencyServices
                        )

                        actionFooterButton(
                            title: "Signal Nearby",
                            detail: viewModel.signalStatusLine,
                            assetName: "signal",
                            tint: ColorTheme.accent,
                            action: openSignal
                        )
                    }
                }
            }
        }
        .background(ColorTheme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func leaveNowContent(in size: CGSize, fixedHeightLayout: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .frame(width: 110)
            }

            CinematicBanner("evacuation_staging", height: 180)

            ModeHeroCard(
                eyebrow: "Evacuation Flow",
                title: "LEAVE NOW",
                subtitle: fixedHeightLayout
                    ? "Large actions only. No scrolling. Do the essentials first, then jump straight to map, call, or signal."
                    : "Large actions first. Scroll only if needed to reach every departure step.",
                iconName: "route",
                accent: ColorTheme.danger,
                backgroundAssetName: "emergency_mode_gear"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.summaryLine)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                    Text(viewModel.nextStepLine)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textMuted)

                    ReadinessMeter(value: prepProgress, tint: departureStatusTint, height: 10)

                    HStack(spacing: 10) {
                        departureBadge(
                            title: "\(completedPrepCount) / \(prepActions.count) prep done",
                            tint: departureStatusTint
                        )
                        departureBadge(
                            title: departureStatusTitle,
                            tint: departureStatusTint
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Before You Move")
                    .font(RediTypography.sectionTitle)
                    .foregroundStyle(ColorTheme.text)
                Text("Finish the essentials you still can. If officials say leave, go even if this list is incomplete.")
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textMuted)

                VStack(spacing: 12) {
                    ForEach(prepActions) { action in
                        prepActionButton(
                            action: action,
                            minHeight: prepActionMinimumHeight(in: size, fixedHeightLayout: fixedHeightLayout)
                        )
                    }
                }
            }

            if let evacuationAction {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Final Departure")
                        .font(RediTypography.sectionTitle)
                        .foregroundStyle(ColorTheme.text)
                    Text(departureStatusDetail)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textMuted)

                    finalDepartureButton(action: evacuationAction)
                }
            }

            if fixedHeightLayout {
                Spacer(minLength: 6)
            }
        }
    }

    private func prepActionMinimumHeight(in size: CGSize, fixedHeightLayout: Bool) -> CGFloat {
        guard fixedHeightLayout else { return 68 }
        return max(68, (size.height - 470) / CGFloat(max(prepActions.count, 1)))
    }

    private func requiresScrollableLayout(in size: CGSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || size.height < 780
    }

    private func callEmergencyServices() {
        guard let url = URL(string: "tel://\(TrustLayer.emergencyCallNumber)") else {
            return
        }
        openURL(url)
    }

    private var prepActions: [LeaveNowActionDisplay] {
        viewModel.actions.filter { $0.id != "evacuate" }
    }

    private var evacuationAction: LeaveNowActionDisplay? {
        viewModel.actions.first { $0.id == "evacuate" }
    }

    private var completedPrepCount: Int {
        prepActions.filter { $0.isComplete }.count
    }

    private var remainingPrepCount: Int {
        max(prepActions.count - completedPrepCount, 0)
    }

    private var prepProgress: Double {
        guard !prepActions.isEmpty else { return 1 }
        return Double(completedPrepCount) / Double(prepActions.count)
    }

    private var departureStatusTitle: String {
        if evacuationAction?.isComplete == true {
            return "Departure marked"
        }

        if remainingPrepCount == 0 {
            return "Ready to depart"
        }

        return "Finish \(remainingPrepCount) more"
    }

    private var departureStatusDetail: String {
        if evacuationAction?.isComplete == true {
            return "Departure has been marked complete. Keep map, call, and signal tools available while moving."
        }

        if remainingPrepCount == 0 {
            return "Essentials are covered. Use the departure card when you are actually moving."
        }

        return "The route is already staged below. If official instructions say leave now, leave even if the checklist is not perfect."
    }

    private var departureStatusTint: Color {
        if evacuationAction?.isComplete == true {
            return ColorTheme.ready
        }

        return remainingPrepCount == 0 ? ColorTheme.ready : ColorTheme.warning
    }

    private func actionFooterButton(
        title: String,
        detail: String,
        assetName: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                RediIcon(assetName)
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)

                Spacer(minLength: 0)

                Text(title)
                    .font(RediTypography.button)
                    .foregroundStyle(Color.white)

                Text(detail)
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(ColorTheme.panelRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func prepActionButton(action: LeaveNowActionDisplay, minHeight: CGFloat) -> some View {
        Button {
            viewModel.toggleAction(action.id)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: action.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(action.isComplete ? ColorTheme.ready : Color.white.opacity(0.65))

                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(RediTypography.button)
                        .foregroundStyle(Color.white)
                    Text(action.detail)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textMuted)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(
                ColorTheme.panelRaised.opacity(action.isComplete ? 0.94 : 1),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(action.isComplete ? ColorTheme.ready.opacity(0.30) : ColorTheme.accent.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func finalDepartureButton(action: LeaveNowActionDisplay) -> some View {
        Button {
            viewModel.toggleAction(action.id)
        } label: {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: action.isComplete ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.white)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(action.title.uppercased())
                            .font(RediTypography.button)
                            .foregroundStyle(Color.white)
                        Text(action.isComplete ? "Marked" : (remainingPrepCount == 0 ? "Ready" : "When safe"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(action.isComplete ? ColorTheme.ready : Color.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                (action.isComplete ? ColorTheme.ready : Color.white.opacity(0.14)),
                                in: Capsule()
                            )
                    }

                    Text(action.detail)
                        .font(RediTypography.body)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .multilineTextAlignment(.leading)

                    Text(remainingPrepCount == 0
                         ? "Map, call, and signal stay ready in the dock below."
                         : "If conditions escalate, move with the essentials you have and use the dock below on the way.")
                        .font(RediTypography.caption)
                        .foregroundStyle(Color.white.opacity(0.78))
                }

                Spacer()
            }
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
            .background(
                LinearGradient(
                    colors: action.isComplete
                        ? [ColorTheme.ready, ColorTheme.ready.opacity(0.72)]
                        : [ColorTheme.danger, ColorTheme.danger.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func departureBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.14), in: Capsule())
    }
}
