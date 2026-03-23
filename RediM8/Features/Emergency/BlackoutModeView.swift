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
    @State private var isShowingBushfireReference = false
    @State private var isShowingEmergencyCards = false
    @State private var isShowingAdditionalContacts = false
    @AccessibilityFocusState private var isTitleFocused: Bool

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
                                .accessibilityFocused($isTitleFocused)
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

                    blackoutModeStatusCard

                    LazyVGrid(columns: columns, spacing: 16) {
                        blackoutPrimaryActionButton(
                            title: viewModel.isTorchOn ? "Flashlight On" : "Flashlight",
                            detail: viewModel.isTorchOn ? "Tap to conserve battery when you no longer need light." : "Fastest light source in the dark.",
                            systemImage: "flashlight",
                            tint: ColorTheme.textTertiary
                        ) {
                            viewModel.toggleTorch()
                        }

                        blackoutPrimaryActionButton(
                            title: primaryEmergencyContact?.displayNumber ?? TrustLayer.emergencyCallNumber,
                            detail: primaryEmergencyContact?.title ?? "Emergency call",
                            systemImage: primaryEmergencyContact?.systemImage ?? "emergency",
                            tint: ColorTheme.danger
                        ) {
                            callPrimaryEmergencyContact()
                        }

                        blackoutPrimaryActionButton(
                            title: "First Aid",
                            detail: "Offline medical guidance with large readable steps.",
                            systemImage: "first_aid",
                            tint: ColorTheme.textTertiary
                        ) {
                            isShowingFirstAid = true
                        }

                        blackoutPrimaryActionButton(
                            title: "Offline Map",
                            detail: "Keep the route and nearest fallbacks visible.",
                            systemImage: "map_marker",
                            tint: ColorTheme.textTertiary
                        ) {
                            switchToTab(.map)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        blackoutToolButton(title: "Signal", subtitle: "Nearby mesh", systemImage: "signal") {
                            switchToTab(.signal)
                        }

                        blackoutToolButton(title: "Go Bag", subtitle: "Evacuation checklist", systemImage: "go_bag") {
                            isShowingGoBag = true
                        }

                        blackoutToolButton(title: "Contacts", subtitle: "Stored offline", systemImage: "family") {
                            isShowingContacts = true
                        }

                        blackoutToolButton(title: "Compass", subtitle: viewModel.headingText, systemImage: "compass") {}
                    }

                    if isBushfireModeEnabled {
                        CollapsiblePanelCard(
                            title: "Bushfire Reference",
                            subtitle: "Quick steps that stay readable in blackout conditions.",
                            accent: ColorTheme.textTertiary,
                            isExpanded: $isShowingBushfireReference
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(bushfireSteps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(index + 1).")
                                            .font(RediTypography.bodyStrong)
                                            .foregroundStyle(ColorTheme.textTertiary)
                                        Text(step)
                                            .font(RediTypography.body)
                                            .foregroundStyle(ColorTheme.textMuted)
                                    }
                                }
                            }
                        }
                    }

                    CollapsiblePanelCard(
                        title: "Emergency Cards",
                        subtitle: "Short action lists for quick reference in the dark.",
                        accent: ColorTheme.textTertiary,
                        isExpanded: $isShowingEmergencyCards
                    ) {
                        EmergencyCardDeckView(
                            cards: appState.guideService.emergencyCards(for: appState.profile.selectedScenarios, limit: 4),
                            selectedGuide: $selectedGuide
                        )
                    }

                    CollapsiblePanelCard(
                        title: "Emergency Contacts",
                        subtitle: "Additional saved numbers kept offline.",
                        accent: ColorTheme.textTertiary,
                        isExpanded: $isShowingAdditionalContacts
                    ) {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.quickContacts) { contact in
                                emergencyActionButton(contact)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .background(Color.black)
        }
        .ignoresSafeArea()
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
        .accessibilityAction(named: "Toggle Flashlight") { viewModel.toggleTorch() }
        .accessibilityAction(named: "Call Emergency") { callPrimaryEmergencyContact() }
        .accessibilityAction(named: "First Aid Guides") { isShowingFirstAid = true }
        .accessibilityAction(named: "Open Offline Map") { switchToTab(.map) }
        .accessibilityAction(named: "Signal Nearby") { switchToTab(.signal) }
        .accessibilityAction(named: "Emergency Contacts") { isShowingContacts = true }
        .onAppear {
            viewModel.onAppear()
            isTitleFocused = true
        }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $isShowingFirstAid) {
            NavigationStack {
                GuideLibraryView(appState: appState, highlightedCategory: .firstAid)
            }
            .rediSheetPresentation()
        }
        .sheet(isPresented: $isShowingContacts) {
            NavigationStack {
                EmergencyContactsView(contacts: viewModel.emergencyContacts)
            }
            .rediSheetPresentation()
        }
        .sheet(item: $selectedGuide) { guide in
            NavigationStack {
                GuideDetailView(guide: guide)
            }
            .rediSheetPresentation()
        }
        .fullScreenCover(isPresented: $isShowingGoBag) {
            GoBagEvacuationView(
                plan: appState.goBagService.plan(for: appState.profile),
                isBlackoutMode: true
            )
        }
    }

    private var primaryEmergencyContact: EmergencyQuickContact? {
        viewModel.quickContacts.first { $0.id == "emergency_services" && $0.isAvailable }
            ?? viewModel.quickContacts.first { $0.isAvailable }
    }

    private func callPrimaryEmergencyContact() {
        guard let url = primaryEmergencyContact?.dialURL ?? URL(string: "tel://\(TrustLayer.emergencyCallNumber)") else {
            return
        }
        openURL(url)
    }

    private var blackoutModeStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(TrustLayer.blackoutSafetyReminder)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.warning)

            HStack(spacing: 12) {
                blackoutStatusBadge(title: "Heading", value: viewModel.headingText, tint: ColorTheme.text)
                blackoutStatusBadge(title: "Phone", value: viewModel.orientationSummary, tint: ColorTheme.text)
                blackoutStatusBadge(title: "Mode", value: "Readability first", tint: ColorTheme.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ColorTheme.panelRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
        )
    }

    private func blackoutStatusBadge(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(RediTypography.metadata)
                .foregroundStyle(ColorTheme.textFaint)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func blackoutPrimaryActionButton(
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
                    .frame(width: 32, height: 32)
                Spacer()
                Text(title)
                    .font(RediTypography.emergencyValue)
                    .foregroundStyle(ColorTheme.text)
                    .multilineTextAlignment(.leading)
                Text(detail)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textMuted)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 196, alignment: .leading)
            .background(ColorTheme.panelRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func blackoutToolButton(title: String, subtitle: String? = nil, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                RediIcon(systemImage)
                    .foregroundStyle(ColorTheme.accent)
                    .frame(width: 28, height: 28)
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
            .frame(maxWidth: .infinity, minHeight: 154, alignment: .leading)
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
                    .foregroundStyle(contact.isAvailable ? ColorTheme.accent : ColorTheme.divider)
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
                    .stroke(contact.isAvailable ? ColorTheme.accent.opacity(0.18) : ColorTheme.divider, lineWidth: 0.5)
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
