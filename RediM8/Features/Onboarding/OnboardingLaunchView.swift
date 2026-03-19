import SwiftUI

struct OnboardingLaunchView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModeHeroCard(
                eyebrow: "Activation",
                title: "System configured.",
                subtitle: "RediM8 will now prioritise your selected contexts across Home, maps, guides, and emergency tools. Activate when ready.",
                iconName: "checklist",
                accent: ColorTheme.accent,
                backgroundAssetName: "marketing_command_table",
                backgroundImageOffset: CGSize(width: 14, height: 0)
            ) {
                if let highlighted = viewModel.highlightedPrioritySituation {
                    TrustPillGroup(items: [
                        TrustPillItem(title: highlighted.title, tone: .info),
                        TrustPillItem(title: "Baseline active", tone: .verified)
                    ])
                } else {
                    TrustPillGroup(items: [
                        TrustPillItem(title: "Baseline active", tone: .info),
                        TrustPillItem(title: "Refine from Home", tone: .neutral)
                    ])
                }
            }

            PanelCard(title: "First Actions", subtitle: "Use the system before you need it.") {
                VStack(alignment: .leading, spacing: 14) {
                    nextStep(
                        icon: "house.fill",
                        tint: ColorTheme.info,
                        title: "Complete Household Profile",
                        detail: "Home will walk you through household, supplies, medical, and defaults one block at a time."
                    )
                    nextStep(
                        icon: "map.fill",
                        tint: ColorTheme.ready,
                        title: "Verify Offline Maps",
                        detail: "Download your region so local map context remains available without signal."
                    )
                    nextStep(
                        icon: "doc.text.fill",
                        tint: ColorTheme.warning,
                        title: "Secure Critical Documents",
                        detail: "Store ID, insurance, and prescriptions in the Secure Vault."
                    )
                    nextStep(
                        icon: "antenna.radiowaves.left.and.right",
                        tint: ColorTheme.accent,
                        title: "Check Local Signal",
                        detail: "Signal lets nearby devices exchange short-range updates when normal connectivity fails."
                    )
                }
            }
        }
    }

    private func nextStep(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
