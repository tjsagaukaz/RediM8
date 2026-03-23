import SwiftUI

/// Shown on first launch when an elevated threat is detected.
/// Three actions. No onboarding. No profile. Instant utility.
struct EmergencyBootstrapView: View {
    @Environment(\.openURL) private var openURL

    let appState: AppState
    let completeBootstrap: () -> Void
    let openMap: () -> Void
    let openSignal: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: RediSpacing.section) {
                    VStack(alignment: .leading, spacing: RediSpacing.compact) {
                        Text("EMERGENCY ACTIVE")
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.danger)

                        Text("You can use this now.")
                            .font(RediTypography.display)
                            .foregroundStyle(ColorTheme.text)

                        Text("No setup needed. These tools work immediately.")
                            .font(RediTypography.body)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }

                    bootstrapActionButton(
                        title: "CALL \(TrustLayer.emergencyCallNumber)",
                        detail: "Direct call to emergency services.",
                        iconName: "emergency",
                        tint: ColorTheme.danger
                    ) {
                        guard let url = URL(string: "tel://\(TrustLayer.emergencyCallNumber)") else { return }
                        openURL(url)
                    }

                    bootstrapActionButton(
                        title: "OPEN MAP",
                        detail: "See your location, nearby shelters, and water sources.",
                        iconName: "map_marker",
                        tint: ColorTheme.accent
                    ) {
                        completeBootstrap()
                        openMap()
                    }

                    bootstrapActionButton(
                        title: "SIGNAL NEARBY",
                        detail: "Check if anyone within range can receive your message.",
                        iconName: "signal",
                        tint: ColorTheme.accent
                    ) {
                        completeBootstrap()
                        openSignal()
                    }

                    TrustPillGroup(items: [
                        TrustPillItem(title: "No account needed", tone: .verified),
                        TrustPillItem(title: "Works offline", tone: .verified),
                        TrustPillItem(title: "Official instructions first", tone: .caution)
                    ])
                }
                .padding(RediSpacing.screen)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: RediSpacing.compact) {
                Rectangle()
                    .fill(ColorTheme.divider)
                    .frame(height: 0.5)

                Button {
                    completeBootstrap()
                } label: {
                    Text("Continue to full setup")
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RediSpacing.content)
                }
                .buttonStyle(.plain)
            }
        }
        .background(ColorTheme.background.ignoresSafeArea())
    }

    private func bootstrapActionButton(
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
                    .frame(width: 24, height: 24)
                    .padding(14)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text(title)
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)
                    Text(detail)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ColorTheme.textTertiary)
            }
            .padding(RediSpacing.screen)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(ColorTheme.panelRaised, in: RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
