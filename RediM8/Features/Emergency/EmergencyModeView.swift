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
    @State private var installedPackCount = 0
    @State private var didLoadInstalledPackCount = false

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
                    .accessibilityIdentifier("emergency.mode.close")
                }

                emergencyHeader
                primaryLaneCard
                secondarySupportCard
            }
            .padding(24)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .accessibilityIdentifier("emergency.mode.root")
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            OperationalStatusRail(items: emergencyStatusItems, accent: ColorTheme.danger)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .task {
            installedPackCount = appState.mapDataService.loadInstalledPackIDs().count
            didLoadInstalledPackCount = true
        }
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
                value: didLoadInstalledPackCount ? "\(installedPackCount) packs" : "Checking...",
                tone: installedPackCount == 0 ? .caution : .info
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

    private var emergencyHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Emergency Mode")
                .font(RediTypography.display)
                .foregroundStyle(ColorTheme.text)
                .accessibilityAddTraits(.isHeader)

            Text("Emergency session is active. Start the primary lane now. Support tools stay tucked away until movement is already underway.")
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TrustPillGroup(
                items: [
                    TrustPillItem(title: "Screen stays awake", tone: .verified),
                    TrustPillItem(title: "High visibility", tone: .info),
                    TrustPillItem(title: "Primary lane first", tone: .info)
                ]
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("emergency.mode.instructions")
    }

    private var primaryLaneCard: some View {
        PanelCard(title: "Primary Lane", subtitle: "Do these now. The rest can wait until you are already moving.") {
            VStack(spacing: 12) {
                emergencyActionRow(
                    leading: compactEmergencyActionButton(
                        title: "LEAVE NOW",
                        detail: "Open the no-scroll evacuation flow.",
                        iconName: "route",
                        tint: ColorTheme.danger,
                        accessibilityIdentifier: "emergency.mode.leaveNow",
                        action: openLeaveNow
                    ),
                    trailing: compactEmergencyActionButton(
                        title: "OFFLINE MAP",
                        detail: !didLoadInstalledPackCount
                            ? "Checking installed coverage."
                            : "\(installedPackCount) pack(s) ready.",
                        iconName: "map_marker",
                        tint: ColorTheme.textTertiary,
                        accessibilityIdentifier: "emergency.mode.map",
                        action: openMap
                    )
                )

                emergencyActionRow(
                    leading: compactEmergencyActionButton(
                        title: "CALL \(TrustLayer.emergencyCallNumber)",
                        detail: "Use if mobile coverage is available.",
                        iconName: "emergency",
                        tint: ColorTheme.danger,
                        accessibilityIdentifier: "emergency.mode.call",
                        action: callEmergencyServices
                    ),
                    trailing: compactEmergencyActionButton(
                        title: "SIGNAL NEARBY",
                        detail: appState.isStealthModeEnabled || appState.settings.privacy.isAnonymousModeEnabled
                            ? "Currently receive-only."
                            : "Assistive short-range messaging.",
                        iconName: "signal",
                        tint: ColorTheme.warning,
                        accessibilityIdentifier: "emergency.mode.signal",
                        action: openSignal
                    )
                )
            }
        }
        .accessibilityIdentifier("emergency.mode.primaryLane")
    }

    @ViewBuilder
    private func emergencyActionRow<Leading: View, Trailing: View>(
        leading: Leading,
        trailing: Trailing
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                leading
                trailing
            }

            VStack(spacing: 12) {
                leading
                trailing
            }
        }
    }

    private var secondarySupportCard: some View {
        CollapsiblePanelCard(
            title: "Support & References",
            subtitle: "Open only after the primary lane is underway.",
            accent: ColorTheme.textTertiary,
            accessibilityIdentifier: "emergency.mode.support.toggle",
            isExpanded: $isShowingSecondaryTools
        ) {
            VStack(alignment: .leading, spacing: 12) {
                secondaryEmergencyActionButton(
                    title: "Emergency Documents",
                    systemImage: "documents",
                    detail: "Passports, insurance, scripts, and other critical records.",
                    accessibilityIdentifier: "emergency.mode.support.documents"
                ) {
                    isShowingEmergencyDocuments = true
                }

                secondaryEmergencyActionButton(
                    title: "Emergency Contacts",
                    systemImage: "family",
                    detail: "Call lists and role assignments for the household.",
                    accessibilityIdentifier: "emergency.mode.support.contacts"
                ) {
                    isShowingContacts = true
                }

                secondaryEmergencyActionButton(
                    title: "Blackout Mode",
                    systemImage: "flashlight",
                    detail: "Torch, contacts, and battery-preserving actions.",
                    accessibilityIdentifier: "emergency.mode.support.blackout"
                ) {
                    openBlackout()
                }

                secondaryEmergencyActionButton(
                    title: "First Aid Guides",
                    systemImage: "first_aid",
                    detail: "Offline treatment and triage reference.",
                    accessibilityIdentifier: "emergency.mode.support.firstAid"
                ) {
                    isShowingFirstAidLibrary = true
                }

                if appState.profile.isBushfireModeEnabled {
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

                if let primaryRoleTask = appState.preparednessInsightsService.primaryRoleTask(for: appState.profile) {
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
            }
        }
    }

    private func compactEmergencyActionButton(
        title: String,
        detail: String,
        iconName: String,
        tint: Color,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.16))
                            .frame(width: 40, height: 40)

                        RediIcon(iconName)
                            .foregroundStyle(tint)
                            .frame(width: 18, height: 18)
                    }

                    Spacer(minLength: 0)
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
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(accessibilityIdentifier)
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
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func secondaryEmergencyActionButton(
        title: String,
        systemImage: String,
        detail: String,
        accessibilityIdentifier: String,
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
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(accessibilityIdentifier)
            .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .stroke(ColorTheme.divider, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
