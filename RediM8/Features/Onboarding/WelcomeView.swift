import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            RediM8Wordmark(
                iconSize: 50,
                titleFont: .system(size: 26, weight: .black),
                subtitle: "Offline-first emergency readiness",
                subtitleColor: ColorTheme.info
            )

            ModeHeroCard(
                eyebrow: "Emergency Setup",
                title: "Set RediM8 up once. Trust it under pressure.",
                subtitle: "This setup focuses RediM8 around the few things that matter most in a real event: leaving early, navigating offline, seeing uncertainty clearly, and protecting your essential records.",
                iconName: "emergency",
                accent: ColorTheme.info,
                backgroundAssetName: "onboarding_family",
                backgroundImageOffset: CGSize(width: 18, height: 0)
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    emergencySequenceLine(number: 1, title: "Emergency Mode", detail: "Open one fast path instead of hunting across multiple apps.")
                    emergencySequenceLine(number: 2, title: "Leave Now", detail: "Use large-button actions with the grab-folder reminder built in.")
                    emergencySequenceLine(number: 3, title: "Map", detail: "Keep route, shelter, and water context available offline.")
                    emergencySequenceLine(number: 4, title: "Call or Signal", detail: "Use the fastest real channel still working on this device.")
                }
            }

            PanelCard(title: "What RediM8 Is Optimizing For", subtitle: "Mission reliability, not feature overload") {
                VStack(alignment: .leading, spacing: 12) {
                    pillarRow(
                        title: "Emergency Mode",
                        detail: "A calm panic tool for Leave Now, Map, Call, Signal, and Emergency Documents.",
                        iconName: "route",
                        tint: ColorTheme.danger
                    )
                    pillarRow(
                        title: "Preparedness Planning",
                        detail: "Household targets, supply gaps, water runtime, and route planning that stay local.",
                        iconName: "checklist",
                        tint: ColorTheme.ready
                    )
                    pillarRow(
                        title: "Offline Map",
                        detail: "Reference navigation and trusted route context that stay available without coverage.",
                        iconName: "map",
                        tint: ColorTheme.info
                    )
                    pillarRow(
                        title: "Secure Vault",
                        detail: "A dedicated Vault tab for encrypted local access to ID, insurance, and medical records.",
                        iconName: "documents",
                        tint: ColorTheme.info
                    )
                }
            }

            PanelCard(title: "Trust First", subtitle: "What RediM8 will and will not claim") {
                VStack(alignment: .leading, spacing: 10) {
                    trustLine("Offline-first, so core decisions still work without internet.")
                    trustLine("Signal and Community Reports are assistive only. Delivery is not guaranteed.")
                    trustLine("Secure Vault documents stay encrypted locally on your device.")
                    trustLine("Map data and community reports can be stale, approximate, or incomplete, and RediM8 says so clearly.")
                }
            }

            PanelCard(title: "What You’ll Finish In This Setup", subtitle: "Fast but high-value") {
                VStack(alignment: .leading, spacing: 10) {
                    trustLine("Choose the scenarios RediM8 should prioritize.")
                    trustLine("Save a household count, meeting point, route, and emergency contact.")
                    trustLine("Snapshot current supplies and core gear.")
                    trustLine("Choose safer privacy and battery defaults before you need them.")
                }
            }
        }
    }

    private func emergencySequenceLine(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(ColorTheme.background)
                .frame(width: 30, height: 30)
                .background(ColorTheme.info, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textMuted)
            }
        }
    }

    private func pillarRow(title: String, detail: String, iconName: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 42, height: 42)

                RediIcon(iconName)
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func trustLine(_ line: String) -> some View {
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
