import SwiftUI

struct PrepScoreResultView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let locationPermissionState: AppPermissionState

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModeHeroCard(
                eyebrow: "Ready",
                title: "You now have a usable baseline.",
                subtitle: "RediM8 knows your likely risks, has the basics of your household plan, and can show gaps more honestly.",
                iconName: "checklist",
                accent: ColorTheme.accent,
                backgroundAssetName: "marketing_command_table",
                backgroundImageOffset: CGSize(width: 14, height: 0)
            ) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(viewModel.livePreviewScore.overall)%")
                            .font(.system(size: 48, weight: .black))
                            .foregroundStyle(ColorTheme.text)
                        Text("Readiness snapshot")
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textMuted)
                    }

                    Spacer()

                    StatusBadge(tier: viewModel.livePreviewScore.tier)
                }
            }

            PanelCard(title: "Ready Now", subtitle: "The important pieces after setup.") {
                LazyVGrid(columns: columns, spacing: 12) {
                    launchCard(
                        title: "Route",
                        value: routeValue,
                        detail: routeDetail,
                        tint: viewModel.primaryEvacuationRoute.nilIfBlank == nil ? ColorTheme.warning : ColorTheme.ready
                    )
                    launchCard(
                        title: "Contact",
                        value: contactValue,
                        detail: contactDetail,
                        tint: viewModel.emergencyContactPhone.nilIfBlank == nil ? ColorTheme.warning : ColorTheme.info
                    )
                    launchCard(
                        title: "Location",
                        value: locationValue,
                        detail: locationDetail,
                        tint: locationPermissionState == .authorized ? ColorTheme.ready : ColorTheme.warning
                    )
                    launchCard(
                        title: "Priority",
                        value: viewModel.highlightedPrioritySituation?.title ?? "General",
                        detail: "Emergency shortcuts and planning targets now follow this bias first.",
                        tint: ColorTheme.accent
                    )
                }
            }

            PanelCard(title: "Next", subtitle: "Highest-value follow-through after launch.") {
                VStack(alignment: .leading, spacing: 12) {
                    nextMove(
                        title: "Add emergency documents to Secure Vault",
                        detail: "Store ID, insurance, prescriptions, and medical records locally."
                    )
                    nextMove(
                        title: "Check offline map coverage",
                        detail: "Make sure your area has the packs, shelters, and routes you expect."
                    )

                    ForEach(Array(viewModel.launchSuggestions.prefix(2))) { suggestion in
                        nextMove(title: suggestion.title, detail: suggestion.detail)
                    }
                }
            }
        }
    }

    private var routeValue: String {
        viewModel.primaryEvacuationRoute.nilIfBlank == nil ? "Missing" : "Saved"
    }

    private var routeDetail: String {
        viewModel.primaryEvacuationRoute.nilIfBlank ?? "Add one route in Plan if you want Leave Now to be more concrete."
    }

    private var contactValue: String {
        viewModel.emergencyContactPhone.nilIfBlank == nil ? "Missing" : "Saved"
    }

    private var contactDetail: String {
        if let name = viewModel.emergencyContactName.nilIfBlank, let phone = viewModel.emergencyContactPhone.nilIfBlank {
            return "\(name) • \(phone)"
        }
        return "Add one reachable contact later if you skipped it."
    }

    private var locationValue: String {
        switch locationPermissionState {
        case .authorized:
            "Enabled"
        case .notDetermined:
            "Not asked"
        case .denied:
            "Denied"
        case .restricted:
            "Restricted"
        case .unavailable:
            "Unavailable"
        }
    }

    private var locationDetail: String {
        switch locationPermissionState {
        case .authorized:
            return "\(viewModel.locationShareMode.title) sharing is ready if you use Signal or map centering."
        case .notDetermined:
            return "Offline maps still work even if you skip location permission."
        case .denied:
            return "Offline maps still work, but your position will not auto-center."
        case .restricted, .unavailable:
            return "Treat maps as reference navigation without live self-location."
        }
    }

    private func launchCard(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(ColorTheme.text)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(16)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private func nextMove(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.up.forward.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ColorTheme.ready)
                .padding(.top, 2)

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
