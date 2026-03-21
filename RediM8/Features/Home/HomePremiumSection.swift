import SwiftUI

extension HomeView {
    var compactProBanner: some View {
        Button {
            activeSheet = .pro
        } label: {
            HStack(spacing: RediSpacing.card) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ColorTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(ColorTheme.textSecondary.opacity(0.14), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("home.pro.banner.title", "RediM8 Pro"))
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                    Text(appState.emergencyUnlockState.isActive
                        ? L10n.tr("home.pro.banner.active_subtitle", "Emergency access active")
                        : L10n.tr("home.pro.banner.default_subtitle", "Offline AI, survival maps, advanced tools"))
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textSecondary.opacity(0.6))
            }
            .padding(RediSpacing.card)
            .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .stroke(ColorTheme.divider, lineWidth: 0.5)
            )
        }
        .buttonStyle(CardPressButtonStyle())
        .accessibilityHint(L10n.tr("home.pro.banner.hint", "Opens RediM8 Pro plans and features."))
    }
}
