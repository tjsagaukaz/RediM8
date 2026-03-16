import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            RediM8Wordmark(
                iconSize: 48,
                titleFont: .system(size: 26, weight: .black),
                subtitle: "Offline-first emergency readiness",
                subtitleColor: ColorTheme.info
            )

            ModeHeroCard(
                eyebrow: "Fast Setup",
                title: "Be ready in a few quick steps.",
                subtitle: "We only ask for the basics: your risks, your household, your current supplies, and safer defaults.",
                iconName: "emergency",
                accent: ColorTheme.info,
                backgroundAssetName: "onboarding_family",
                backgroundImageOffset: CGSize(width: 18, height: 0)
            ) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "2-minute setup", tone: .verified),
                    TrustPillItem(title: "Edit later anytime", tone: .neutral),
                    TrustPillItem(title: "Offline first", tone: .info)
                ])
            }

            PanelCard(title: "We’ll Save", subtitle: "Just the essentials for a usable first launch.") {
                VStack(alignment: .leading, spacing: 12) {
                    setupLine("Risks RediM8 should prioritize.")
                    setupLine("A simple household count, route, meeting point, and contact.")
                    setupLine("A rough supply snapshot so the gaps are real.")
                    setupLine("Privacy, battery, and grab-and-go defaults.")
                }
            }

            PanelCard(title: "Keep It Simple", subtitle: "You do not need perfect answers right now.") {
                VStack(alignment: .leading, spacing: 10) {
                    setupLine("Official alerts always come first.")
                    setupLine("Signal and community reports are assistive only.")
                    setupLine("You can refine everything later from Home, Plan, or Settings.")
                }
            }
        }
    }

    private func setupLine(_ line: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(ColorTheme.info.opacity(0.8))
                .frame(width: 7, height: 7)
                .padding(.top, 7)

            Text(line)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
