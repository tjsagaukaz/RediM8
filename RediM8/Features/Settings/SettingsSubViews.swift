import SwiftUI

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ModeHeroCard(
                    eyebrow: L10n.tr("settings.privacy_policy.hero.eyebrow", "Privacy Policy"),
                    title: L10n.tr("settings.privacy_policy.hero.title", "Privacy at a glance"),
                    subtitle: L10n.tr(
                        "settings.privacy_policy.hero.subtitle",
                        "We built RediM8 so you can rely on it without worrying about your data."
                    ),
                    iconName: "lock.shield",
                    accent: ColorTheme.ready
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        TrustPillGroup(items: [
                            TrustPillItem(title: L10n.tr("settings.privacy_policy.trust.local_only", "On-device data"), tone: .verified),
                            TrustPillItem(title: L10n.tr("settings.privacy_policy.trust.no_analytics", "No analytics"), tone: .info),
                            TrustPillItem(title: L10n.tr("settings.privacy_policy.trust.offline_first", "Offline first"), tone: .caution)
                        ])

                        Text(L10n.tr("settings.about.privacy_policy.effective", "Effective 18 March 2026"))
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.privacy_policy.glance.title", "Privacy at a glance"),
                    subtitle: L10n.tr(
                        "settings.privacy_policy.glance.subtitle",
                        "Quick summary of how RediM8 handles your data."
                    )
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(TrustLayer.privacyAtAGlanceLines.enumerated()), id: \.offset) { _, line in
                            PolicyBulletRow(systemImage: "checkmark.shield", text: line, tint: ColorTheme.ready)
                        }
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.privacy_policy.why.title", "Why RediM8 is different"),
                    subtitle: L10n.tr(
                        "settings.privacy_policy.why.subtitle",
                        "Privacy by default is part of the product, not hidden legal fine print."
                    )
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(TrustLayer.privacyWhyDifferentLines.enumerated()), id: \.offset) { _, line in
                            PolicyBulletRow(systemImage: "shield.lefthalf.filled", text: line, tint: ColorTheme.accent)
                        }
                    }
                }

                ForEach(TrustLayer.privacyPolicySections) { section in
                    PanelCard(title: section.title, subtitle: section.subtitle) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                                PolicyBulletRow(systemImage: section.systemImage, text: line, tint: ColorTheme.textTertiary)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("settings.about.privacy_policy.title", "Privacy Policy"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Policy Bullet Row

struct PolicyBulletRow: View {
    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            Text(text)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Settings Reference Sections View

struct SettingsReferenceSectionsView: View {
    let title: String
    let subtitle: String
    let sections: [TrustReferenceSection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PanelCard(title: title, subtitle: subtitle) {
                    Text(L10n.tr(
                        "settings.references.intro",
                        "Review third-party software, public data sources, and attribution notices used throughout RediM8."
                    ))
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.text)
                }

                ForEach(sections) { section in
                    PanelCard(title: section.title, subtitle: section.subtitle) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(RediTypography.body)
                                    .foregroundStyle(ColorTheme.text)
                            }

                            if let linkTitle = section.linkTitle,
                               let linkURL = section.linkURL {
                                Link(linkTitle, destination: linkURL)
                                    .font(RediTypography.bodyStrong)
                                    .foregroundStyle(ColorTheme.accent)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Emergency Profile View

struct EmergencyProfileView: View {
    let appState: AppState

    @State private var draft: UserProfile

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 10)
    ]

    init(appState: AppState) {
        self.appState = appState
        _draft = State(initialValue: appState.profile)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ModeHeroCard(
                    eyebrow: L10n.tr("settings.emergency_profile.hero.eyebrow", "Emergency Profile"),
                    title: L10n.tr("settings.emergency_profile.hero.title", "Critical health information only."),
                    subtitle: L10n.tr(
                        "settings.emergency_profile.hero.subtitle",
                        "Keep this lightweight and local. Save only the details someone may need if you ask for urgent help nearby."
                    ),
                    iconName: "first_aid",
                    accent: ColorTheme.danger
                ) {
                    TrustPillGroup(items: [
                        TrustPillItem(title: L10n.tr("settings.emergency_profile.trust.local_only", "Local only"), tone: .verified),
                        TrustPillItem(title: L10n.tr("settings.emergency_profile.trust.optional", "Optional"), tone: .neutral),
                        TrustPillItem(title: L10n.tr("settings.emergency_profile.trust.shared_by_choice", "Shared only by choice"), tone: .info)
                    ])
                }

                PanelCard(
                    title: L10n.tr("settings.emergency_profile.health.title", "Critical Health Information"),
                    subtitle: L10n.tr("settings.emergency_profile.health.subtitle", "Do not use this as a full medical history")
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(TrustLayer.emergencyMedicalInfoScopeNotice)
                            .font(RediTypography.body)
                            .foregroundStyle(ColorTheme.textSecondary)

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                            ForEach(CriticalMedicalCondition.allCases) { condition in
                                Button {
                                    draft.emergencyMedicalInfo.toggle(condition)
                                } label: {
                                    Text(condition.title)
                                        .font(RediTypography.bodyStrong)
                                        .foregroundStyle(ColorTheme.text)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            draft.emergencyMedicalInfo.criticalConditions.contains(condition)
                                                ? ColorTheme.danger.opacity(0.18)
                                                : Color.black.opacity(0.2),
                                            in: Capsule()
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    (draft.emergencyMedicalInfo.criticalConditions.contains(condition) ? ColorTheme.danger : ColorTheme.divider).opacity(0.28),
                                                    lineWidth: 1
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        TextField(
                            L10n.tr("settings.emergency_profile.placeholder.allergies", "Severe allergies"),
                            text: $draft.emergencyMedicalInfo.severeAllergies,
                            axis: .vertical
                        )
                            .textFieldStyle(TacticalTextFieldStyle())

                        TextField(
                            L10n.tr("settings.emergency_profile.placeholder.blood_type", "Blood type (optional)"),
                            text: $draft.emergencyMedicalInfo.bloodType
                        )
                            .textFieldStyle(TacticalTextFieldStyle())

                        TextField(
                            L10n.tr("settings.emergency_profile.placeholder.medication", "Emergency medication or location"),
                            text: $draft.emergencyMedicalInfo.emergencyMedication,
                            axis: .vertical
                        )
                            .textFieldStyle(TacticalTextFieldStyle())

                        TextField(
                            L10n.tr("settings.emergency_profile.placeholder.other_condition", "Other critical condition"),
                            text: $draft.emergencyMedicalInfo.otherCriticalCondition,
                            axis: .vertical
                        )
                            .textFieldStyle(TacticalTextFieldStyle())

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(ColorTheme.textTertiary)
                            Text(TrustLayer.emergencyMedicalInfoPrivacyNotice)
                                .font(.caption)
                                .foregroundStyle(ColorTheme.textSecondary)
                        }

                        Text(L10n.tr(
                            "settings.emergency_profile.vault_note",
                            "Store prescriptions, records, and longer medical details in Secure Vault instead."
                        ))
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.emergency_profile.contacts.title", "Emergency Contacts"),
                    subtitle: L10n.tr("settings.emergency_profile.contacts.subtitle", "Contacts stay local and remain available offline")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        if draft.emergencyContacts.isEmpty {
                            Text(L10n.tr("settings.emergency_profile.contacts.empty", "No emergency contacts saved yet."))
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.textSecondary)
                        } else {
                            ForEach($draft.emergencyContacts) { $contact in
                                VStack(alignment: .leading, spacing: 10) {
                                    TextField(
                                        L10n.tr("settings.emergency_profile.contacts.name_placeholder", "Contact name"),
                                        text: $contact.name
                                    )
                                        .textFieldStyle(TacticalTextFieldStyle())
                                    TextField(
                                        L10n.tr("settings.emergency_profile.contacts.phone_placeholder", "Phone"),
                                        text: $contact.phone
                                    )
                                        .textFieldStyle(TacticalTextFieldStyle())
                                        .keyboardType(.phonePad)

                                    Button(L10n.tr("settings.emergency_profile.contacts.remove", "Remove Contact")) {
                                        draft.emergencyContacts.removeAll { $0.id == contact.id }
                                    }
                                    .font(RediTypography.bodyStrong)
                                    .foregroundStyle(ColorTheme.danger)
                                }
                                .padding(14)
                                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
                            }
                        }

                        Button(L10n.tr("settings.emergency_profile.contacts.add", "Add Emergency Contact")) {
                            draft.emergencyContacts.append(.empty)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.emergency_profile.share.title", "If You Choose To Share"),
                    subtitle: L10n.tr(
                        "settings.emergency_profile.share.subtitle",
                        "This preview only attaches to Need Help or Medical Emergency reports when you enable it"
                    )
                ) {
                    if let broadcastSummary = draft.emergencyMedicalInfo.broadcastSummary {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.tr("settings.emergency_profile.share.preview_label", "MEDICAL NOTE PREVIEW"))
                                .font(RediTypography.caption)
                                .foregroundStyle(ColorTheme.danger)
                            Text(broadcastSummary)
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.text)
                        }
                    } else {
                        Text(L10n.tr(
                            "settings.emergency_profile.share.empty",
                            "No emergency medical info will be attached until you add some here and explicitly choose to include it from Signal."
                        ))
                            .font(RediTypography.body)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("settings.emergency_profile.navigation_title", "Emergency Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: draft) { _, newValue in
            if appState.profile != newValue {
                appState.applyProfile(newValue)
            }
        }
    }
}

// MARK: - Safety Transparency Row

struct SafetyTransparencyRow: View {
    let title: String
    let detail: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SettingsRowLabel(title: title, subtitle: detail)
            Spacer()
            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.textTertiary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Safety Limitations View

struct SafetyLimitationsView: View {
    let appState: AppState

    private var installedPackCount: Int {
        appState.mapDataService.loadInstalledPackIDs().count
    }

    private var officialCoverageValue: String {
        let coverage = appState.officialAlertService.coverageSummary
        if appState.officialAlertService.hasCachedData {
            return coverage
        }
        return L10n.tr("settings.safety.data_sources.government_alerts.sync_once", "Sync once")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ModeHeroCard(
                    eyebrow: L10n.tr("settings.safety.hero.eyebrow", "Safety & Limitations"),
                    title: L10n.tr("settings.safety.hero.title", "Assistive, Not Authoritative"),
                    subtitle: L10n.tr(
                        "settings.safety.hero.subtitle",
                        "RediM8 supports preparedness, navigation, community awareness, and emergency reference access. It does not replace official services or professional care."
                    ),
                    iconName: "shield",
                    accent: ColorTheme.textTertiary
                ) {
                    TrustPillGroup(items: [
                        TrustPillItem(title: L10n.tr("settings.safety.trust.official_first", "Official alerts first"), tone: .verified),
                        TrustPillItem(title: L10n.tr("settings.safety.trust.community_unverified", "Community reports unverified"), tone: .info),
                        TrustPillItem(title: L10n.tr("settings.safety.trust.delivery_not_guaranteed", "Delivery not guaranteed"), tone: .caution)
                    ])
                }

                PanelCard(
                    title: L10n.tr("settings.safety.core_notice.title", "Core Safety Notice"),
                    subtitle: L10n.tr("settings.safety.core_notice.subtitle", "Plain-language scope and limitations")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(TrustLayer.safetyLimitationsLines.enumerated()), id: \.offset) { _, line in
                            safetyBullet(line)
                        }
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.safety.communication.title", "Communication Limits"),
                    subtitle: L10n.tr(
                        "settings.safety.communication.subtitle",
                        "Nearby tools help, but they are not dependable replacement comms"
                    )
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        safetyBullet(TrustLayer.signalAssistiveReminder)
                        safetyBullet(TrustLayer.signalDeliveryNotice)
                        safetyBullet(TrustLayer.signalConstraintNotice)
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.safety.data_sources.title", "Data Sources"),
                    subtitle: L10n.tr("settings.safety.data_sources.subtitle", "What RediM8 uses and how to interpret it")
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        SafetyTransparencyRow(
                            title: L10n.tr("settings.safety.data_sources.map_packs.title", "Offline map packs"),
                            detail: L10n.tr(
                                "settings.safety.data_sources.map_packs.detail",
                                "Bundled regional data packs plus a curated basemap catalog for downloadable local map packages covering shelters, water points, routes, overlays, and offline cartography."
                            ),
                            value: L10n.format(
                                "settings.safety.data_sources.map_packs.value",
                                "%d installed",
                                installedPackCount
                            )
                        )

                        SettingsDivider()

                        SafetyTransparencyRow(
                            title: L10n.tr("settings.safety.data_sources.community_reports.title", "Community reports"),
                            detail: L10n.tr(
                                "settings.safety.data_sources.community_reports.detail",
                                "Nearby user-shared situational reports passed over local mesh. Confirm when possible."
                            ),
                            value: L10n.tr("settings.safety.data_sources.community_reports.value", "Community")
                        )

                        SettingsDivider()

                        SafetyTransparencyRow(
                            title: L10n.tr("settings.safety.data_sources.government_alerts.title", "Government alerts"),
                            detail: L10n.tr(
                                "settings.safety.data_sources.government_alerts.detail",
                                "Mirrored Australian public warning feeds cached for offline access when available."
                            ),
                            value: officialCoverageValue
                        )

                        SettingsDivider()

                        SafetyTransparencyRow(
                            title: L10n.tr("settings.safety.data_sources.vault.title", "Secure Vault"),
                            detail: L10n.tr(
                                "settings.safety.data_sources.vault.detail",
                                "Emergency documents and info card stored locally on this device with local encryption."
                            ),
                            value: L10n.tr("settings.safety.data_sources.vault.value", "Local only")
                        )
                    }
                }

                PanelCard(
                    title: L10n.tr("settings.safety.trust_labels.title", "Trust Labels"),
                    subtitle: L10n.tr("settings.safety.trust_labels.subtitle", "What the badges in RediM8 mean at a glance")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(TrustLayer.trustLabelLegendLines.enumerated()), id: \.offset) { _, line in
                            safetyBullet(line)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("settings.safety.navigation_title", "Safety"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func safetyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ColorTheme.warning)
                .padding(.top, 2)
            Text(text)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
