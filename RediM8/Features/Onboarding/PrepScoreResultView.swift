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
                eyebrow: "Launch Summary",
                title: "You’re launching with a calmer, more honest default setup.",
                subtitle: "RediM8 now knows your likely risks, has a route and meeting point to work with, and is configured with clearer trust and privacy defaults.",
                iconName: "checklist",
                accent: ColorTheme.accent
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

                    VStack(alignment: .trailing, spacing: 8) {
                        StatusBadge(tier: viewModel.livePreviewScore.tier)
                        if let highlighted = viewModel.highlightedPrioritySituation {
                            Text("\(highlighted.title) prioritized")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ColorTheme.info)
                        }
                    }
                }
            }

            PanelCard(title: "What Works Right Now", subtitle: "The fast-read summary after setup") {
                LazyVGrid(columns: columns, spacing: 12) {
                    launchCard(
                        title: "Emergency Flow",
                        value: "Ready",
                        detail: "Emergency Mode, Leave Now, Map, and Call/Signal are staged.",
                        tint: ColorTheme.danger
                    )
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
                }
            }

            PanelCard(title: "First Moves After Setup", subtitle: "Highest-value follow-through items") {
                VStack(alignment: .leading, spacing: 12) {
                    nextMove(
                        title: "Add emergency documents to Secure Vault",
                        detail: "Store ID, insurance, prescriptions, and medical records locally in the Vault tab."
                    )
                    nextMove(
                        title: "Review offline map coverage",
                        detail: "Confirm your area has pack coverage and that shelters, water, and routes are visible where you’ll need them."
                    )

                    if viewModel.launchSuggestions.isEmpty {
                        nextMove(
                            title: "Keep refining when calm",
                            detail: "You’re in a solid place. Revisit supplies, routes, and contacts as seasons or travel plans change."
                        )
                    } else {
                        ForEach(viewModel.launchSuggestions) { suggestion in
                            nextMove(title: suggestion.title, detail: suggestion.detail)
                        }
                    }
                }
            }

            PanelCard(title: "Trust Defaults", subtitle: "The stance RediM8 will now take by default") {
                VStack(alignment: .leading, spacing: 10) {
                    trustLine("Location sharing: \(viewModel.locationShareMode.title) - \(viewModel.locationShareMode.subtitle)")
                    trustLine(viewModel.isAnonymousModeEnabled ? "Signal identity: anonymous by default." : "Signal identity: device identity can be more visible.")
                    trustLine(viewModel.enablesSurvivalModeAtFifteenPercent ? "Low-battery survival mode prompt is enabled." : "Low-battery survival mode prompt is disabled.")
                    trustLine(TrustLayer.signalConstraintNotice)
                }
            }
        }
    }

    private var routeValue: String {
        viewModel.primaryEvacuationRoute.nilIfBlank == nil ? "Missing" : "Saved"
    }

    private var routeDetail: String {
        viewModel.primaryEvacuationRoute.nilIfBlank ?? "Add one route in Plan so Leave Now and Map have something concrete to use."
    }

    private var contactValue: String {
        viewModel.emergencyContactPhone.nilIfBlank == nil ? "Missing" : "Saved"
    }

    private var contactDetail: String {
        if let name = viewModel.emergencyContactName.nilIfBlank, let phone = viewModel.emergencyContactPhone.nilIfBlank {
            return "\(name) • \(phone)"
        }
        return "Add one reachable local contact for faster call decisions."
    }

    private var locationValue: String {
        switch locationPermissionState {
        case .authorized:
            "Enabled"
        case .notDetermined:
            "Not Asked"
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
            return "Offline maps still work, but your position will not auto-center until permission is granted."
        case .denied:
            return "Offline maps still work, but your position will not auto-center on this device."
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
