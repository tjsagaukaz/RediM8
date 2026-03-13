import SwiftUI

struct EmergencyModeView: View {
    @Environment(\.openURL) private var openURL

    let appState: AppState
    let dismiss: () -> Void
    let openBlackout: () -> Void
    let openSignal: () -> Void
    let openMap: () -> Void
    let openLeaveNow: () -> Void

    @State private var isShowingEmergencyDocuments = false
    @State private var isShowingContacts = false
    @State private var isShowingFirstAidLibrary = false
    @State private var isShowingSecondaryTools = false

    private let survivalDeckColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var isBushfireModeEnabled: Bool {
        appState.profile.isBushfireModeEnabled
    }

    private var primaryRoleTask: FamilyRoleTask? {
        appState.preparednessInsightsService.primaryRoleTask(for: appState.profile)
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
        GeometryReader { _ in
            VStack(spacing: 16) {
                if appState.isStealthModeEnabled {
                    StealthModeIndicatorView()
                }

                HStack {
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .frame(width: 110)
                }

                ModeHeroCard(
                    eyebrow: "Immediate Actions",
                    title: "Emergency Mode",
                    subtitle: "Emergency session is active. RediM8 lifts brightness, keeps the screen awake, and stages map, contacts, guides, and signal in one place.",
                    iconName: "emergency",
                    accent: ColorTheme.danger,
                    backgroundAssetName: "emergency_mode_phone"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        TrustPillGroup(
                            items: [
                                TrustPillItem(title: "Screen stays awake", tone: .verified),
                                TrustPillItem(title: "High visibility", tone: .info),
                                TrustPillItem(title: "One-tap tools", tone: .info)
                            ]
                        )

                        emergencySequenceLine(number: 1, title: "Leave Now", detail: "Open the no-scroll evacuation checklist.")
                        emergencySequenceLine(number: 2, title: "Grab Folder", detail: "Take IDs, medications, contacts, chargers, and keys together.")
                        emergencySequenceLine(number: 3, title: "Open Map", detail: "Confirm saved routes, shelter coverage, and water before you move.")
                        emergencySequenceLine(number: 4, title: "Call or Signal", detail: "Use the fastest channel still working on this device.")
                    }
                }

                survivalDeck

                VStack(spacing: 12) {
                    primaryEmergencyActionButton(
                        title: "1. LEAVE NOW",
                        detail: "Large-button evacuation flow with Grab Folder, Map, and Call or Signal already staged.",
                        iconName: "route",
                        tint: ColorTheme.danger,
                        action: openLeaveNow
                    )

                    primaryEmergencyActionButton(
                        title: "2. OPEN OFFLINE MAP",
                        detail: "\(appState.mapDataService.loadInstalledPackIDs().count) pack(s) available. Check route coverage before you move.",
                        iconName: "map_marker",
                        tint: ColorTheme.info,
                        action: openMap
                    )

                    primaryEmergencyActionButton(
                        title: "3. CALL \(TrustLayer.emergencyCallNumber)",
                        detail: "Fastest option if mobile coverage is still available.",
                        iconName: "emergency",
                        tint: ColorTheme.danger,
                        action: callEmergencyServices
                    )

                    primaryEmergencyActionButton(
                        title: "4. SIGNAL NEARBY",
                        detail: appState.isStealthModeEnabled || appState.settings.privacy.isAnonymousModeEnabled
                            ? "Currently receive-only. Check Signal for the current device limits."
                            : "Assistive short-range messaging only. Delivery is not guaranteed.",
                        iconName: "signal",
                        tint: ColorTheme.warning,
                        action: openSignal
                    )
                }

                secondaryEmergencyActionButton(
                    title: "Contacts & Documents",
                    systemImage: "documents",
                    detail: "Open emergency contacts plus local ID, insurance, medical, and document records."
                ) {
                    isShowingEmergencyDocuments = true
                }

                Spacer(minLength: 0)

                CollapsiblePanelCard(
                    title: "Secondary Support",
                    subtitle: "Use only after the main flow is moving.",
                    accent: ColorTheme.warning,
                    isExpanded: $isShowingSecondaryTools
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        secondaryEmergencyActionButton(title: "Blackout Mode", systemImage: "flashlight", detail: "Torch, contacts, and battery-preserving actions.") {
                            openBlackout()
                        }

                        secondaryEmergencyActionButton(title: "First Aid Guides", systemImage: "first_aid", detail: "Offline treatment and triage reference.") {
                            isShowingFirstAidLibrary = true
                        }

                        if let primaryRoleTask {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Your role: \(primaryRoleTask.memberName) - \(primaryRoleTask.role)")
                                    .font(RediTypography.bodyStrong)
                                    .foregroundStyle(ColorTheme.text)
                                Text(primaryRoleTask.taskTitle)
                                    .font(RediTypography.body)
                                    .foregroundStyle(ColorTheme.textMuted)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        if isBushfireModeEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bushfire reminders")
                                    .font(RediTypography.bodyStrong)
                                    .foregroundStyle(ColorTheme.text)

                                ForEach(Array(bushfireSteps.prefix(3).enumerated()), id: \.offset) { index, step in
                                    Text("\(index + 1). \(step)")
                                        .font(.subheadline)
                                        .foregroundStyle(ColorTheme.textMuted)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
            }
            .padding(24)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            OperationalStatusRail(items: emergencyStatusItems, accent: ColorTheme.danger)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.18, green: 0.05, blue: 0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .sheet(isPresented: $isShowingFirstAidLibrary) {
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
        .sheet(isPresented: $isShowingEmergencyDocuments) {
            EmergencyDocumentsQuickView(service: appState.documentVaultService)
                .rediSheetPresentation(style: .vault, accent: ColorTheme.secure)
        }
    }

    private var emergencyStatusItems: [OperationalStatusItem] {
        let routeCount = appState.profile.evacuationRoutes.compactMap(\.nilIfBlank).count
        let signalMode = appState.isStealthModeEnabled || appState.settings.privacy.isAnonymousModeEnabled ? "Receive-only" : "Assistive"

        return [
            OperationalStatusItem(
                iconName: "battery",
                label: "Battery",
                value: appState.batteryStatus.percentageText,
                tone: appState.batteryStatus.isBelowSurvivalThreshold ? .danger : .ready
            ),
            OperationalStatusItem(
                iconName: "route",
                label: "Routes",
                value: routeCount == 0 ? "None saved" : "\(routeCount) ready",
                tone: routeCount == 0 ? .caution : .ready
            ),
            OperationalStatusItem(
                iconName: "map_marker",
                label: "Offline Map",
                value: "\(appState.mapDataService.loadInstalledPackIDs().count) packs",
                tone: appState.mapDataService.loadInstalledPackIDs().isEmpty ? .caution : .info
            ),
            OperationalStatusItem(
                iconName: "signal",
                label: "Signal",
                value: signalMode,
                tone: signalMode == "Assistive" ? .info : .caution
            )
        ]
    }

    private func callEmergencyServices() {
        guard let url = URL(string: "tel://\(TrustLayer.emergencyCallNumber)") else {
            return
        }
        openURL(url)
    }

    private var survivalDeck: some View {
        PanelCard(title: "Survival Deck", subtitle: "The fastest tools stay one tap away while Emergency Mode is active.") {
            LazyVGrid(columns: survivalDeckColumns, spacing: 10) {
                compactSurvivalDeckButton(title: "Offline Map", iconName: "map_marker", tint: ColorTheme.info, action: openMap)
                compactSurvivalDeckButton(title: "Contacts", iconName: "family", tint: ColorTheme.warning) {
                    isShowingContacts = true
                }
                compactSurvivalDeckButton(title: "Guides", iconName: "first_aid", tint: ColorTheme.ready) {
                    isShowingFirstAidLibrary = true
                }
                compactSurvivalDeckButton(title: "Signal Mesh", iconName: "signal", tint: ColorTheme.warning, action: openSignal)
            }
        }
    }

    private func emergencySequenceLine(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number).")
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.danger)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textMuted)
            }
        }
    }

    private func compactSurvivalDeckButton(
        title: String,
        iconName: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RediIcon(iconName)
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ColorTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func primaryEmergencyActionButton(
        title: String,
        detail: String,
        iconName: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.16))
                        .frame(width: 52, height: 52)

                    RediIcon(iconName)
                        .foregroundStyle(tint)
                        .frame(width: 24, height: 24)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(RediTypography.button)
                        .foregroundStyle(ColorTheme.text)
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [ColorTheme.panelRaised, tint.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func secondaryEmergencyActionButton(
        title: String,
        systemImage: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                RediIcon(systemImage)
                    .foregroundStyle(ColorTheme.warning)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textMuted)
                }

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ColorTheme.warning.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
