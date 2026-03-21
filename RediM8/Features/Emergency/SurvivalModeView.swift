import SwiftUI

struct SurvivalModeView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ObservedObject private var appState: AppState
    @ObservedObject private var torchService: TorchService

    let disable: () -> Void

    @State private var isShowingSignal = false
    @State private var isShowingGuides = false
    @State private var isShowingContacts = false

    init(appState: AppState, disable: @escaping () -> Void) {
        self.appState = appState
        self.disable = disable
        _torchService = ObservedObject(wrappedValue: appState.torchService)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var quickContacts: [EmergencyQuickContact] {
        TrustLayer.quickContacts(for: appState.profile)
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                if requiresScrollableLayout(in: proxy.size) {
                    ScrollView {
                        survivalContent(fixedHeightLayout: false)
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    survivalContent(fixedHeightLayout: true)
                        .padding(24)
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $isShowingGuides) {
            NavigationStack {
                GuideLibraryView(appState: appState, highlightedCategory: .firstAid)
            }
            .rediSheetPresentation()
        }
        .sheet(isPresented: $isShowingContacts) {
            NavigationStack {
                EmergencyContactsView(contacts: appState.profile.emergencyContacts)
            }
            .rediSheetPresentation()
        }
        .fullScreenCover(isPresented: $isShowingSignal) {
            NavigationStack {
                SignalView(appState: appState)
            }
        }
    }

    @ViewBuilder
    private func survivalContent(fixedHeightLayout: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if appState.isStealthModeEnabled {
                StealthModeIndicatorView()
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Low Battery Survival Mode")
                        .font(RediTypography.screenTitle)
                        .foregroundStyle(ColorTheme.text)
                    Text("Battery \(appState.batteryStatus.percentageText) • stripped to essentials only")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Exit") {
                    disable()
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .frame(width: 92)
            }

            survivalStatusCard

            if let primaryEmergencyContact {
                emergencyCallCard(primaryEmergencyContact)
            }

            LazyVGrid(columns: columns, spacing: 16) {
                survivalPrimaryButton(
                    title: torchService.isTorchOn ? "Flashlight On" : "Flashlight",
                    detail: torchService.isTorchOn ? "Turn off when you no longer need it." : "Fastest light with one tap.",
                    systemImage: "flashlight",
                    tint: ColorTheme.textTertiary
                ) {
                    torchService.toggleTorch()
                }

                survivalPrimaryButton(
                    title: "Signal Nearby",
                    detail: "Short mesh check without the full app shell.",
                    systemImage: "signal",
                    tint: ColorTheme.textTertiary
                ) {
                    isShowingSignal = true
                }

                survivalPrimaryButton(
                    title: "Emergency Guides",
                    detail: "Offline medical and emergency steps.",
                    systemImage: "first_aid",
                    tint: ColorTheme.textTertiary
                ) {
                    isShowingGuides = true
                }

                survivalPrimaryButton(
                    title: "Emergency Contacts",
                    detail: "Stored locally for offline access.",
                    systemImage: "family",
                    tint: ColorTheme.textTertiary
                ) {
                    isShowingContacts = true
                }
            }

            if fixedHeightLayout {
                Spacer(minLength: 0)
            }
        }
    }

    private func requiresScrollableLayout(in size: CGSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || size.height < 720
    }

    private var primaryEmergencyContact: EmergencyQuickContact? {
        quickContacts.first { $0.id == "emergency_services" && $0.isAvailable }
            ?? quickContacts.first { $0.isAvailable }
    }

    private var survivalStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOW")
                        .font(RediTypography.metadata)
                        .foregroundStyle(ColorTheme.textFaint)
                    Text(Date.now, style: .time)
                        .font(.system(size: 36, weight: .bold).monospaced())
                        .foregroundStyle(ColorTheme.text)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("BATTERY")
                        .font(RediTypography.metadata)
                        .foregroundStyle(ColorTheme.textFaint)
                    Text(appState.batteryStatus.percentageText)
                        .font(.system(size: 36, weight: .bold).monospaced())
                        .foregroundStyle(appState.batteryStatus.isBelowSurvivalThreshold ? ColorTheme.warning : ColorTheme.ready)
                }
            }

            Text("Nonessential UI is hidden to preserve battery. Keep actions short and deliberate.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ColorTheme.warning)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTheme.panelRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ColorTheme.warning.opacity(0.18), lineWidth: 1)
        )
    }

    private func emergencyCallCard(_ contact: EmergencyQuickContact) -> some View {
        Button {
            guard let url = contact.dialURL else {
                return
            }
            openURL(url)
        } label: {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Call Emergency")
                        .font(RediTypography.sectionTitle)
                        .foregroundStyle(Color.white)
                    Text(contact.displayNumber ?? TrustLayer.emergencyCallNumber)
                        .font(.system(size: 34, weight: .bold).monospaced())
                        .foregroundStyle(Color.white)
                    Text(contact.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.82))
                }
                Spacer()
                RediIcon(contact.systemImage)
                    .foregroundStyle(Color.white)
                    .frame(width: 28, height: 28)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
            .background(ColorTheme.danger, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func survivalPrimaryButton(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                RediIcon(systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                Spacer()
                Text(title)
                    .font(RediTypography.sectionTitle)
                    .foregroundStyle(ColorTheme.text)
                    .multilineTextAlignment(.leading)
                Text(detail)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textMuted)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
            .background(ColorTheme.panelRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
