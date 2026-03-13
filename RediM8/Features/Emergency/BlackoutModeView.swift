import SwiftUI

struct BlackoutModeView: View {
    @Environment(\.dismiss) private var dismissSheet
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: BlackoutViewModel

    let appState: AppState
    let dismiss: () -> Void
    let switchToTab: (AppTab) -> Void

    @State private var isShowingFirstAid = false
    @State private var isShowingContacts = false
    @State private var isShowingGoBag = false
    @State private var selectedGuide: Guide?

    init(appState: AppState, dismiss: @escaping () -> Void, switchToTab: @escaping (AppTab) -> Void) {
        self.appState = appState
        self.dismiss = dismiss
        self.switchToTab = switchToTab
        _viewModel = StateObject(wrappedValue: BlackoutViewModel(appState: appState))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var isBushfireModeEnabled: Bool {
        appState.profile.isBushfireModeEnabled
    }

    private var bushfireSteps: [String] {
        [
            "Leave early if advised.",
            "Wear protective clothing.",
            "Close windows and doors.",
            "Turn off gas supply.",
            "Follow emergency instructions."
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    if appState.isStealthModeEnabled {
                        StealthModeIndicatorView()
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Blackout Mode")
                                .font(RediTypography.screenTitle)
                                .foregroundStyle(ColorTheme.text)
                            Text("\(viewModel.headingText) • \(viewModel.orientationSummary)")
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.textMuted)
                        }
                        Spacer()
                        Button("Close") {
                            dismiss()
                            dismissSheet()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .frame(width: 110)
                    }

                    Text(TrustLayer.blackoutSafetyReminder)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isBushfireModeEnabled {
                        PanelCard(title: "Bushfire Approaching", subtitle: "Quick reference actions that stay readable in blackout conditions") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(bushfireSteps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(index + 1).")
                                            .font(RediTypography.bodyStrong)
                                            .foregroundStyle(ColorTheme.warning)
                                        Text(step)
                                            .font(RediTypography.body)
                                            .foregroundStyle(ColorTheme.textMuted)
                                    }
                                }
                            }
                        }
                    }

                    PanelCard(title: "Emergency Cards", subtitle: "Short action lists for quick reference in the dark") {
                        EmergencyCardDeckView(
                            cards: appState.guideService.emergencyCards(for: appState.profile.selectedScenarios, limit: 4),
                            selectedGuide: $selectedGuide
                        )
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.quickContacts) { contact in
                            emergencyActionButton(contact)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        blackoutButton(title: viewModel.isTorchOn ? "Flashlight On" : "Flashlight", systemImage: "flashlight") {
                            viewModel.toggleTorch()
                        }
                        blackoutButton(title: "Compass", subtitle: viewModel.headingText, systemImage: "compass") {}
                        blackoutButton(title: "First Aid", systemImage: "first_aid") {
                            isShowingFirstAid = true
                        }
                        blackoutButton(title: "Signal", systemImage: "signal") {
                            switchToTab(.signal)
                        }
                        blackoutButton(title: "Map", systemImage: "map_marker") {
                            switchToTab(.map)
                        }
                        blackoutButton(title: "Go Bag", systemImage: "go_bag") {
                            isShowingGoBag = true
                        }
                        blackoutButton(title: "Emergency Contacts", systemImage: "family") {
                            isShowingContacts = true
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .background(ColorTheme.background)
        }
        .ignoresSafeArea()
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $isShowingFirstAid) {
            NavigationStack {
                GuideLibraryView(appState: appState, highlightedCategory: .firstAid)
            }
            .rediSheetPresentation(style: .library, accent: ColorTheme.info)
        }
        .sheet(isPresented: $isShowingContacts) {
            NavigationStack {
                EmergencyContactsView(contacts: viewModel.emergencyContacts)
            }
            .rediSheetPresentation(style: .neutral, accent: ColorTheme.premium)
        }
        .sheet(item: $selectedGuide) { guide in
            NavigationStack {
                GuideDetailView(guide: guide)
            }
            .rediSheetPresentation(style: .library, accent: ColorTheme.info)
        }
        .fullScreenCover(isPresented: $isShowingGoBag) {
            GoBagEvacuationView(
                plan: appState.goBagService.plan(for: appState.profile),
                isBlackoutMode: true
            )
        }
    }

    private func blackoutButton(title: String, subtitle: String? = nil, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                RediIcon(systemImage)
                    .foregroundStyle(ColorTheme.accent)
                    .frame(width: 30, height: 30)
                Spacer()
                Text(title)
                    .font(RediTypography.sectionTitle)
                    .foregroundStyle(ColorTheme.text)
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textMuted)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 164, alignment: .leading)
            .background(ColorTheme.panelRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(ColorTheme.accent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func emergencyActionButton(_ contact: EmergencyQuickContact) -> some View {
        Button {
            guard let url = contact.dialURL else {
                return
            }
            openURL(url)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                RediIcon(contact.systemImage)
                    .foregroundStyle(contact.isAvailable ? ColorTheme.warning : ColorTheme.divider)
                    .frame(width: 28, height: 28)
                Spacer()
                Text(contact.displayNumber ?? "Not saved")
                    .font(RediTypography.emergencyValue)
                    .foregroundStyle(ColorTheme.text)
                Text(contact.title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                    .multilineTextAlignment(.leading)
                Text(contact.subtitle)
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textMuted)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
            .background(ColorTheme.panelRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(contact.isAvailable ? ColorTheme.warning.opacity(0.4) : ColorTheme.divider, lineWidth: 1)
            )
            .opacity(contact.isAvailable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!contact.isAvailable)
    }
}

struct EmergencyContactsView: View {
    let contacts: [EmergencyContact]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PanelCard(title: "Emergency Contacts", subtitle: "Stored locally for offline access") {
                    if contacts.isEmpty {
                        Text("No contacts saved yet. Add them from the Plan tab.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(contacts) { contact in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.name)
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)
                                Text(contact.phone)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle("Contacts")
    }
}
