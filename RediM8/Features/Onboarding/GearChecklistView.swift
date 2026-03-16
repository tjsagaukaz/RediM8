import CoreLocation
import SwiftUI
import UIKit

struct GearChecklistView: View {
    @Environment(\.openURL) private var openURL

    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject var locationService: LocationService
    @State private var isShowingGearChecklist = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModeHeroCard(
                eyebrow: "Defaults",
                title: "Choose safer defaults before you need them.",
                subtitle: "Keep signal conservative, battery-aware, and simple on day one.",
                iconName: "signal",
                accent: ColorTheme.textTertiary,
                backgroundAssetName: "signal_vehicle_link",
                backgroundImageOffset: CGSize(width: 12, height: 0)
            ) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Approximate by default", tone: .verified),
                    TrustPillItem(title: "Battery-aware", tone: .info),
                    TrustPillItem(title: "Editable later", tone: .neutral)
                ])
            }

            PanelCard(title: "Privacy + Battery", subtitle: "These are the settings that matter most under stress.") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Location sharing")
                            .font(RediTypography.bodyStrong)
                            .foregroundStyle(ColorTheme.text)

                        Picker("Location sharing", selection: $viewModel.locationShareMode) {
                            ForEach(LocationShareMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(viewModel.locationShareMode.subtitle)
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textMuted)
                    }

                    Toggle(isOn: $viewModel.isAnonymousModeEnabled) {
                        toggleLabel(
                            title: "Anonymous signal mode",
                            detail: "Hide personal identity by default."
                        )
                    }
                    .toggleStyle(.switch)
                    .tint(ColorTheme.accent)

                    Toggle(isOn: $viewModel.enablesSurvivalModeAtFifteenPercent) {
                        toggleLabel(
                            title: "Offer Survival Mode at 15%",
                            detail: "Reduce interface weight when battery gets low."
                        )
                    }
                    .toggleStyle(.switch)
                    .tint(ColorTheme.accent)

                    Toggle(isOn: $viewModel.reducesMapAnimations) {
                        toggleLabel(
                            title: "Reduce map motion",
                            detail: "Make maps calmer and easier to read under stress."
                        )
                    }
                    .toggleStyle(.switch)
                    .tint(ColorTheme.info)

                    locationPermissionCard
                }
            }

            CollapsiblePanelCard(
                title: "Core Grab-And-Go Gear",
                subtitle: "Optional now. Mark what you already have so RediM8 stops guessing.",
                accent: ColorTheme.textTertiary,
                isExpanded: $isShowingGearChecklist
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach($viewModel.checklistItems) { $item in
                        Toggle(isOn: $item.isChecked) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.kind.title)
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)
                                Text(gearHint(for: item.kind))
                                    .font(.caption)
                                    .foregroundStyle(ColorTheme.textMuted)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(ColorTheme.accent)
                    }
                }
            }
        }
    }

    private var permissionState: AppPermissionState {
        switch locationService.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            .authorized
        case .notDetermined:
            .notDetermined
        case .restricted:
            .restricted
        case .denied:
            .denied
        @unknown default:
            .restricted
        }
    }

    private var locationPermissionCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(permissionTint.opacity(0.16))
                    .frame(width: 42, height: 42)

                Image(systemName: permissionIcon)
                    .foregroundStyle(permissionTint)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Location permission")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)

                Text(permissionDescription)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if permissionState == .notDetermined {
                    Button("Enable Location") {
                        locationService.requestAccess()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                } else if permissionState == .denied {
                    Button("Open Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }
                        openURL(url)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var permissionTint: Color {
        switch permissionState {
        case .authorized:
            ColorTheme.ready
        case .notDetermined:
            ColorTheme.info
        case .denied, .restricted:
            ColorTheme.warning
        case .unavailable:
            ColorTheme.textFaint
        }
    }

    private var permissionIcon: String {
        switch permissionState {
        case .authorized:
            "location.fill"
        case .notDetermined:
            "location.circle"
        case .denied, .restricted:
            "location.slash.fill"
        case .unavailable:
            "slash.circle"
        }
    }

    private var permissionDescription: String {
        switch permissionState {
        case .authorized:
            "Enabled. Maps can center faster and use the sharing mode you picked."
        case .notDetermined:
            "Optional. Offline maps still work even if you skip this."
        case .denied:
            "Denied. Maps still work offline, but your position will not auto-center."
        case .restricted:
            "Restricted on this device."
        case .unavailable:
            "Unavailable on this device."
        }
    }

    private func toggleLabel(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textMuted)
        }
    }

    private func gearHint(for kind: ChecklistItemKind) -> String {
        switch kind {
        case .firstAidKit:
            "Medical basics for injury and rapid departure."
        case .batteryRadio:
            "Useful when power or mobile coverage drops."
        case .torch:
            "Big win for blackout movement."
        case .powerBank:
            "Keeps maps, calls, and vault access alive longer."
        case .fireBlanket:
            "Useful for kitchen fires and fast suppression."
        }
    }
}
