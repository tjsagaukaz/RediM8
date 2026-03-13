import CoreLocation
import SwiftUI
import UIKit

struct GearChecklistView: View {
    @Environment(\.openURL) private var openURL

    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject var locationService: LocationService

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModeHeroCard(
                eyebrow: "Trust + Defaults",
                title: "Choose safer defaults before you need them.",
                subtitle: "RediM8 should feel honest on day one: approximate by default, battery-aware, and very clear that nearby signalling helps but does not guarantee delivery.",
                iconName: "signal",
                accent: ColorTheme.warning
            ) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Assistive signal only", tone: .caution),
                    TrustPillItem(title: "Approximate by default", tone: .verified),
                    TrustPillItem(title: "Large-button emergency", tone: .info)
                ])
            }

            PanelCard(title: "Communication + Privacy", subtitle: "Honest defaults for mesh, maps, and nearby signals") {
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Anonymous signal mode")
                                .font(RediTypography.bodyStrong)
                                .foregroundStyle(ColorTheme.text)
                            Text("Hide personal identity and keep nearby discovery more conservative by default.")
                                .font(.caption)
                                .foregroundStyle(ColorTheme.textMuted)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(ColorTheme.accent)

                    locationPermissionCard

                    Text(TrustLayer.signalAssistiveReminder)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(TrustLayer.signalDeliveryNotice)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            PanelCard(title: "Battery Behaviour", subtitle: "What RediM8 should do when the phone is under pressure") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $viewModel.enablesSurvivalModeAtFifteenPercent) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-offer Survival Mode at 15%")
                                .font(RediTypography.bodyStrong)
                                .foregroundStyle(ColorTheme.text)
                            Text("Reduce interface weight when the phone is close to running flat.")
                                .font(.caption)
                                .foregroundStyle(ColorTheme.textMuted)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(ColorTheme.warning)

                    Toggle(isOn: $viewModel.reducesMapAnimations) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reduce motion in maps and critical flows")
                                .font(RediTypography.bodyStrong)
                                .foregroundStyle(ColorTheme.text)
                            Text("Helps with glare, stress, and low battery without removing core information.")
                                .font(.caption)
                                .foregroundStyle(ColorTheme.textMuted)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(ColorTheme.info)
                }
            }

            PanelCard(title: "Core Grab-And-Go Gear", subtitle: "Mark what you already have so RediM8 can stop guessing") {
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
                        .tint(ColorTheme.ready)
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
                Text("Location Permission")
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
            "Location is enabled. Maps can center faster and RediM8 can use the share mode you choose."
        case .notDetermined:
            "Allow location if you want map centering and optional nearby sharing. RediM8 will still work offline without it."
        case .denied:
            "Location is currently denied. Map data still works offline, but your position will not auto-center."
        case .restricted:
            "Location access is restricted on this device."
        case .unavailable:
            "Location access is unavailable on this device."
        }
    }

    private func gearHint(for kind: ChecklistItemKind) -> String {
        switch kind {
        case .firstAidKit:
            "Medical basics for injury, burns, and rapid departure."
        case .batteryRadio:
            "Warnings and updates when power or mobile coverage drops."
        case .torch:
            "Large win for blackout movement and night evacuation."
        case .powerBank:
            "Keeps maps, calls, and vault access available longer."
        case .fireBlanket:
            "Useful for bushfire, kitchen flare-ups, and fast suppression."
        }
    }
}
