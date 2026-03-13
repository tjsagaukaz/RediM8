import SwiftUI

struct LeaveNowView: View {
    @Environment(\.openURL) private var openURL
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
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .frame(width: 110)
                }

                ModeHeroCard(
                    eyebrow: "Evacuation Flow",
                    title: "LEAVE NOW",
                    subtitle: "Large actions only. No scrolling. Do the essentials first, then jump straight to map, call, or signal.",
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
                    }
                }

                VStack(spacing: 12) {
                    ForEach(viewModel.actions) { action in
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
                            .frame(maxWidth: .infinity, minHeight: max(64, (proxy.size.height - 380) / CGFloat(max(viewModel.actions.count, 1))), alignment: .leading)
                            .background(
                                action.title == "Evacuate"
                                    ? ColorTheme.danger
                                    : ColorTheme.panelRaised.opacity(action.isComplete ? 0.94 : 1),
                                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(
                                        action.title == "Evacuate"
                                            ? Color.white.opacity(0.08)
                                            : ColorTheme.accent.opacity(action.isComplete ? 0.30 : 0.14),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
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
                        tint: ColorTheme.info,
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
                            tint: ColorTheme.warning,
                            action: openSignal
                        )
                    }
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.16, green: 0.03, blue: 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func callEmergencyServices() {
        guard let url = URL(string: "tel://\(TrustLayer.emergencyCallNumber)") else {
            return
        }
        openURL(url)
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
}
