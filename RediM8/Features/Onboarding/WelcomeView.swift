import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RediM8Wordmark(
                iconSize: 48,
                titleFont: .system(size: 26, weight: .black),
                subtitle: "Offline-first emergency operating system",
                subtitleColor: ColorTheme.info
            )

            ModeHeroCard(
                eyebrow: "System Setup",
                title: "Select the situations you need to be ready for.",
                subtitle: "RediM8 will configure your baseline accordingly. Household profile, supplies, medical details, and routes can be refined later from Home.",
                iconName: "emergency",
                accent: ColorTheme.info,
                backgroundAssetName: "onboarding_family",
                backgroundImageOffset: CGSize(width: 18, height: 0)
            ) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Under a minute", tone: .verified),
                    TrustPillItem(title: "Baseline only", tone: .neutral),
                    TrustPillItem(title: "Refine later", tone: .info)
                ])
            }

            PanelCard(title: "Minimum Required", subtitle: "Minimum required to activate your system.") {
                VStack(alignment: .leading, spacing: 12) {
                    setupLine("Review the operating limits.")
                    setupLine("Select the situations RediM8 should prioritize.")
                    setupLine("Activate the baseline.")
                }
            }

            PanelCard(title: "After Activation", subtitle: "Home will guide the next build-out.") {
                VStack(alignment: .leading, spacing: 10) {
                    setupLine("Record household details, routes, and meeting points.")
                    setupLine("Log supplies so RediM8 can identify the real gaps.")
                    setupLine("Store emergency contacts and critical medical details.")
                    setupLine("Set privacy, battery, and grab-and-go defaults.")
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
