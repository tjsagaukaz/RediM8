import SwiftUI

struct SurvivalModeView: View {
    @Environment(\.openURL) private var openURL

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
            VStack(alignment: .leading, spacing: 18) {
                if appState.isStealthModeEnabled {
                    StealthModeIndicatorView()
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Low Battery Survival Mode")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(ColorTheme.text)
                        Text("Battery \(appState.batteryStatus.percentageText) • simplified interface only")
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

                Text("Nonessential UI is hidden to preserve battery. Keep actions short and deliberate.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ColorTheme.warning)

                LazyVGrid(columns: columns, spacing: 16) {
                    survivalButton(
                        title: torchService.isTorchOn ? "Flashlight On" : "Flashlight",
                        systemImage: "flashlight"
                    ) {
                        torchService.toggleTorch()
                    }

                    survivalButton(title: "Signal Nearby", systemImage: "signal") {
                        isShowingSignal = true
                    }

                    survivalButton(title: "Emergency Guides", systemImage: "first_aid") {
                        isShowingGuides = true
                    }

                    survivalButton(title: "Emergency Contacts", systemImage: "family") {
                        isShowingContacts = true
                    }
                }

                if let emergencyContact = quickContacts.first(where: { $0.id == "emergency_services" }) {
                    Button {
                        guard let url = emergencyContact.dialURL else {
                            return
                        }
                        openURL(url)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Call Emergency")
                                    .font(.headline)
                                    .foregroundStyle(Color.white)
                                Text(emergencyContact.displayNumber ?? TrustLayer.emergencyCallNumber)
                                    .font(.title3.weight(.heavy))
                                    .foregroundStyle(Color.white)
                            }
                            Spacer()
                            RediIcon(emergencyContact.systemImage)
                                .foregroundStyle(Color.white)
                                .frame(width: 24, height: 24)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ColorTheme.danger, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .sheet(isPresented: $isShowingGuides) {
            NavigationStack {
                GuideLibraryView(appState: appState, highlightedCategory: .firstAid)
            }
            .rediSheetPresentation(style: .library, accent: ColorTheme.info)
        }
        .sheet(isPresented: $isShowingContacts) {
            NavigationStack {
                EmergencyContactsView(contacts: appState.profile.emergencyContacts)
            }
            .rediSheetPresentation(style: .neutral, accent: ColorTheme.premium)
        }
        .fullScreenCover(isPresented: $isShowingSignal) {
            NavigationStack {
                SignalView(appState: appState)
            }
        }
    }

    private func survivalButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                RediIcon(systemImage)
                    .foregroundStyle(ColorTheme.info)
                    .frame(width: 28, height: 28)
                Spacer()
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ColorTheme.text)
                    .multilineTextAlignment(.leading)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(ColorTheme.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
