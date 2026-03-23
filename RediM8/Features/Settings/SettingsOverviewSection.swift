import SwiftUI

extension SettingsView {

    var overviewWorkspace: some View {
        VStack(spacing: 18) {
            systemDefaultsSection
            proSection
            safetySection
            emergencyProfileSection
            assistantSection
        }
    }

    // MARK: - System Defaults

    private var systemDefaultsSection: some View {
        PanelCard(
            title: L10n.tr("settings.defaults.title", "Emergency-Safe Defaults"),
            subtitle: L10n.tr(
                "settings.defaults.subtitle",
                "Reset this device to the recommended emergency behavior in one step."
            )
        ) {
            SettingsInfoRow(
                title: L10n.tr("settings.defaults.summary.title", "What This Resets"),
                subtitle: L10n.tr(
                    "settings.defaults.summary.subtitle",
                    "Approximate location sharing, balanced signal mode, critical map layers, and Stealth Mode off."
                ),
                value: L10n.tr("settings.defaults.summary.value", "Recommended")
            )

            SettingsDivider()

            Button {
                viewModel.isShowingEmergencySafeDefaultsAlert = true
            } label: {
                SettingsActionRow(
                    title: L10n.tr("settings.defaults.action.title", "Reset to Emergency-Safe Settings"),
                    subtitle: L10n.tr(
                        "settings.defaults.action.subtitle",
                        "Use this when you need fast, predictable system behavior under pressure."
                    ),
                    value: L10n.tr("common.reset", "Reset"),
                    tint: ColorTheme.warning
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Pro

    private var proSection: some View {
        PanelCard(
            title: L10n.tr("settings.overview.pro.title", "RediM8 Pro"),
            subtitle: L10n.tr(
                "settings.overview.pro.subtitle",
                "Core safety stays free. Pro funds premium planning, maps, vault upgrades, and the offline assistant."
            )
        ) {
            NavigationLink {
                RediM8ProView(storeKitService: appState.storeKitService, emergencyUnlockState: appState.emergencyUnlockState)
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.overview.pro.view_plans", "Unlock Advanced Planning Tools"),
                    subtitle: proSubtitle,
                    value: proValueLabel
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            SettingsInfoRow(
                title: L10n.tr("settings.overview.pro.always_free", "Always Free"),
                subtitle: monetizationCatalog.alwaysFreePromise,
                value: L10n.tr("paywall.matrix.value.included", "Included")
            )

            SettingsDivider()

            SettingsInfoRow(
                title: L10n.tr("settings.overview.pro.emergency_unlock", "Emergency Unlock"),
                subtitle: emergencyUnlockSubtitle,
                value: emergencyUnlockValue
            )

            SettingsDivider()

            Button {
                Task { await appState.storeKitService.restorePurchases() }
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.overview.pro.restore_purchases", "Restore Purchases"),
                    subtitle: L10n.tr(
                        "settings.overview.pro.restore_subtitle",
                        "Recover previous Pro purchases from your Apple ID"
                    ),
                    value: L10n.tr("common.restore", "Restore")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions") ?? URL(fileURLWithPath: "/")) {
                SettingsNavigationRow(
                    title: L10n.tr("settings.overview.pro.manage_subscription", "Manage Subscription"),
                    subtitle: L10n.tr(
                        "settings.overview.pro.manage_subtitle",
                        "Change or cancel your plan in App Store settings"
                    ),
                    value: L10n.tr("common.open", "Open")
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Safety

    private var safetySection: some View {
        PanelCard(
            title: L10n.tr("settings.overview.safety.title", "Safety"),
            subtitle: L10n.tr(
                "settings.overview.safety.subtitle",
                "Scope, limitations, and data transparency for emergency use."
            )
        ) {
            NavigationLink {
                SafetyLimitationsView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.overview.safety.link_title", "Safety & Limitations"),
                    subtitle: L10n.tr(
                        "settings.overview.safety.link_subtitle",
                        "Emergency scope, trust labels, communication limits, and data sources"
                    ),
                    value: appState.profile.hasAcknowledgedSafetyNotice
                        ? L10n.tr("settings.overview.safety.value.reviewed", "Reviewed")
                        : L10n.tr("common.open", "Open")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            SettingsInfoRow(
                title: L10n.tr("settings.overview.safety.acknowledged", "Acknowledged"),
                subtitle: L10n.tr(
                    "settings.overview.safety.acknowledged_subtitle",
                    "Recorded once during onboarding and always reviewable here"
                ),
                value: safetyAcknowledgementValue
            )
        }
    }

    private var safetyAcknowledgementValue: String {
        guard let acknowledgedAt = appState.profile.lastAcknowledgedSafetyNoticeAt else {
            return L10n.tr("settings.overview.safety.value.not_yet", "Not yet")
        }
        return DateFormatter.rediM8Short.string(from: acknowledgedAt)
    }

    // MARK: - Emergency Profile

    private var emergencyProfileSection: some View {
        PanelCard(
            title: L10n.tr("settings.overview.emergency_profile.title", "Emergency Profile"),
            subtitle: L10n.tr(
                "settings.overview.emergency_profile.subtitle",
                "Local-only contacts and critical health info for urgent help situations."
            )
        ) {
            NavigationLink {
                EmergencyProfileView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.overview.emergency_profile.link_title", "Emergency Profile"),
                    subtitle: L10n.tr(
                        "settings.overview.emergency_profile.link_subtitle",
                        "Critical health info, blood type, medication details, and emergency contacts"
                    ),
                    value: appState.profile.emergencyMedicalInfo.hasAnyContent
                        ? L10n.tr("settings.overview.emergency_profile.value.saved", "Saved")
                        : L10n.tr("settings.overview.emergency_profile.value.optional", "Optional")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            SettingsInfoRow(
                title: L10n.tr("settings.overview.emergency_profile.sharing_rule", "Sharing Rule"),
                subtitle: TrustLayer.emergencyMedicalInfoPrivacyNotice,
                value: L10n.tr("settings.overview.emergency_profile.value.local_only", "Local only")
            )
        }
    }

    // MARK: - Assistant

    private var assistantSection: some View {
        PanelCard(
            title: L10n.tr("settings.overview.assistant.title", "On-Device AI"),
            subtitle: L10n.tr(
                "settings.overview.assistant.subtitle",
                "On-device AI for low-risk guide summaries and question support, with no internet required."
            )
        ) {
            SettingsToggleRow(
                title: L10n.tr("settings.overview.assistant.toggle_title", "On-Device AI Summaries"),
                subtitle: appState.isProUser
                    ? L10n.tr(
                        "settings.overview.assistant.toggle_subtitle.pro",
                        "Use on-device AI to summarize guides and interpret questions. All processing stays on this device."
                    )
                    : L10n.tr(
                        "settings.overview.assistant.toggle_subtitle.free",
                        "Upgrade to RediM8 Pro to enable on-device AI with no internet required."
                    ),
                isOn: appState.isProUser ? binding(\.assistant.offlineAISummariesEnabled) : .constant(false)
            )
            .disabled(!appState.isProUser)

            SettingsDivider()

            SettingsInfoRow(
                title: L10n.tr("settings.overview.assistant.model_status", "Model Status"),
                subtitle: appState.assistantModel.isAvailable
                    ? L10n.tr(
                        "settings.overview.assistant.model_status.available",
                        "The local CoreML assistant model is available for advisory summaries."
                    )
                    : L10n.tr(
                        "settings.overview.assistant.model_status.unavailable",
                        "No local model bundle is loaded in this build, so RediM8 will stay guide-only until one is bundled."
                    ),
                value: appState.settings.assistant.offlineAISummariesEnabled
                    ? (appState.assistantModel.isAvailable
                        ? L10n.tr("settings.overview.assistant.value.ready", "Ready")
                        : L10n.tr("settings.overview.assistant.value.standby", "Standby"))
                    : L10n.tr("common.off", "Off")
            )
        }
    }

    // MARK: - Pro Computed Properties

    var proSubtitle: String {
        if appState.isProUser, case .pro = appState.proEntitlement {
            return L10n.tr(
                "settings.pro.subtitle.active",
                "RediM8 Pro is active. Thank you for supporting the project."
            )
        }
        if appState.emergencyUnlockState.isActive {
            return L10n.tr(
                "settings.pro.subtitle.unlocked",
                "Emergency Unlock active. Pro tools are temporarily available."
            )
        }
        if appState.emergencyUnlockState.isRecentlyEnded {
            return L10n.tr(
                "settings.pro.subtitle.ended",
                "Emergency access ended. Upgrade to keep Pro tools available anytime."
            )
        }
        return L10n.tr(
            "settings.pro.subtitle.default",
            "Unlock expanded maps, deeper planning tools, vault upgrades, and on-device AI."
        )
    }

    var proValueLabel: String {
        if case .pro = appState.proEntitlement {
            return L10n.tr("settings.pro.value.active", "Active")
        }
        if appState.emergencyUnlockState.isActive {
            return L10n.tr("settings.pro.value.unlocked", "Unlocked")
        }
        if appState.emergencyUnlockState.isRecentlyEnded {
            return L10n.tr("settings.pro.value.ended", "Ended")
        }
        return L10n.tr("settings.pro.value.upgrade", "Upgrade")
    }

    var emergencyUnlockSubtitle: String {
        if appState.emergencyUnlockState.isVisible {
            return appState.emergencyUnlockState.calloutDetail
        }
        return L10n.tr(
            "settings.emergency_unlock.subtitle.default",
            "Activates automatically during severe official events so payment is not the first decision."
        )
    }

    var emergencyUnlockValue: String {
        if appState.emergencyUnlockState.isActive {
            return L10n.tr("settings.emergency_unlock.value.active", "Active")
        }
        if appState.emergencyUnlockState.isRecentlyEnded {
            return L10n.tr("settings.emergency_unlock.value.ended", "Ended")
        }
        return L10n.tr("settings.emergency_unlock.value.standby", "Standby")
    }
}
