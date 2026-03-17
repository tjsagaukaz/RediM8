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
        ScrollView {
            VStack(spacing: 16) {
                CinematicBanner("emergency_mode_gear", height: 200)

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
                    .accessibilityLabel("Close emergency mode")
                }

                emergencyHeroCard
                primaryLaneCard
                secondarySupportCard
            }
            .padding(24)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            OperationalStatusRail(items: emergencyStatusItems, accent: ColorTheme.danger)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .sheet(isPresented: $isShowingFirstAidLibrary) {
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
        .sheet(isPresented: $isShowingEmergencyDocuments) {
            EmergencyDocumentsQuickView(service: appState.documentVaultService)
                .rediSheetPresentation()
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

    private var emergencyHeroCard: some View {
        ModeHeroCard(
            eyebrow: "Next Five Minutes",
            title: "Emergency Mode",
            subtitle: "Emergency session is active. Use one clear lane first, then open support tools only if the essentials are already moving.",
            iconName: "emergency",
            accent: ColorTheme.danger,
            backgroundAssetName: "emergency_mode_phone"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TrustPillGroup(
                    items: [
                        TrustPillItem(title: "Screen stays awake", tone: .verified),
                        TrustPillItem(title: "High visibility", tone: .info),
                        TrustPillItem(title: "Action order staged", tone: .info)
                    ]
                )

                emergencySequenceLine(number: 1, title: "Leave Now", detail: "Open the no-scroll evacuation checklist if you need fast movement.")
                emergencySequenceLine(number: 2, title: "Grab Folder", detail: "Take IDs, medications, chargers, keys, and the documents you cannot replace quickly.")
                emergencySequenceLine(number: 3, title: "Check Route", detail: "Confirm offline map coverage, evacuation notes, shelter, and water before moving.")
                emergencySequenceLine(number: 4, title: "Call or Signal", detail: "Use the fastest real channel still working on this device.")

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        heroSupportButton(
                            title: "Emergency Documents",
                            iconName: "documents",
                            tint: ColorTheme.secure
                        ) {
                            isShowingEmergencyDocuments = true
                        }

                        heroSupportButton(
                            title: "Emergency Contacts",
                            iconName: "family",
                            tint: ColorTheme.textTertiary
                        ) {
                            isShowingContacts = true
                        }
                    }

                    VStack(spacing: 12) {
                        heroSupportButton(
                            title: "Emergency Documents",
                            iconName: "documents",
                            tint: ColorTheme.secure
                        ) {
                            isShowingEmergencyDocuments = true
                        }

                        heroSupportButton(
                            title: "Emergency Contacts",
                            iconName: "family",
                            tint: ColorTheme.textTertiary
                        ) {
                            isShowingContacts = true
                        }
                    }
                }
            }
        }
    }

    private var primaryLaneCard: some View {
        PanelCard(title: "Primary Lane", subtitle: "Do these in order. The rest can wait until you are already moving.") {
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
                    tint: ColorTheme.textTertiary,
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
        }
    }

    private var secondarySupportCard: some View {
        CollapsiblePanelCard(
            title: "Support & References",
            subtitle: "Open only after the primary lane is underway.",
            accent: ColorTheme.textTertiary,
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

    private func heroSupportButton(
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
                    .foregroundStyle(ColorTheme.textTertiary)
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
            .padding(RediSpacing.card)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .stroke(ColorTheme.divider, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
