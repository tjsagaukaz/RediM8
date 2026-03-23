import SwiftUI

extension SettingsView {

    // MARK: - Preparedness Workspace

    var preparednessWorkspace: some View {
        VStack(spacing: 18) {
            preparednessSection
        }
    }

    // MARK: - Device Workspace

    var deviceWorkspace: some View {
        VStack(spacing: 18) {
            batterySection
            dataSection
            diagnosticsSection
            aboutSection
        }
    }

    // MARK: - Preparedness Section

    private var preparednessSection: some View {
        PanelCard(
            title: L10n.tr("settings.preparedness.title", "Preparedness"),
            subtitle: L10n.tr(
                "settings.preparedness.subtitle",
                "Controls your readiness targets and reminders."
            )
        ) {
            SettingsCallout(
                title: L10n.tr("settings.preparedness.callout.title", "Affects"),
                detail: L10n.tr(
                    "settings.preparedness.callout.detail",
                    "Water, food, evacuation planning, and readiness reminders."
                ),
                tone: .info,
                iconName: "list.bullet.rectangle.portrait"
            )

            SettingsDivider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SettingsRowLabel(
                        title: L10n.tr("settings.preparedness.household_size.title", "Household Size"),
                        subtitle: L10n.tr(
                            "settings.preparedness.household_size.subtitle",
                            "Used for water, food, and evacuation planning."
                        )
                    )
                    Spacer()
                    Text("\(appState.profile.household.totalPeople)")
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.textTertiary)
                }

                Stepper(value: householdSizeBinding, in: 1...12) {
                    Text(L10n.tr("settings.preparedness.household_size.adjust", "Adjust household size"))
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.text)
                }
                .tint(ColorTheme.accent)
            }

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.preparedness.prep_notifications.title", "Prep Score Notifications"),
                subtitle: L10n.tr(
                    "settings.preparedness.prep_notifications.subtitle",
                    "Keep readiness score review prompts enabled"
                ),
                isOn: binding(\.preparedness.prepScoreNotificationsEnabled)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.preparedness.plan_alerts.title", "72-Hour Plan Alerts"),
                subtitle: L10n.tr(
                    "settings.preparedness.plan_alerts.subtitle",
                    "Keep household emergency plan review reminders active"
                ),
                isOn: binding(\.preparedness.seventyTwoHourPlanAlertsEnabled)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.preparedness.go_bag.title", "Go Bag Reminders"),
                subtitle: L10n.tr(
                    "settings.preparedness.go_bag.subtitle",
                    "Monthly prompts to review evacuation bag essentials"
                ),
                isOn: binding(\.preparedness.goBagRemindersEnabled)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.preparedness.official_alert_notifications.title", "Official Alert Notifications"),
                subtitle: L10n.tr(
                    "settings.preparedness.official_alert_notifications.subtitle",
                    "Get notification banners when new official alerts match your chosen scope"
                ),
                footnote: L10n.tr(
                    "settings.preparedness.official_alert_notifications.footnote",
                    "Use Local for your area, State for family context, or Australia for a wider watch."
                ),
                isOn: officialAlertNotificationsBinding
            )

            if appState.settings.preparedness.officialAlertNotificationsEnabled {
                SettingsDivider()

                VStack(alignment: .leading, spacing: 12) {
                    SettingsRowLabel(
                        title: L10n.tr("settings.preparedness.official_alert_notifications.scope_title", "Notification Scope"),
                        subtitle: L10n.tr(
                            "settings.preparedness.official_alert_notifications.scope_subtitle",
                            "Choose which official warning view can trigger notifications"
                        )
                    )

                    PremiumSegmentedControl(
                        items: officialAlertNotificationScopeOptions,
                        selection: officialAlertNotificationScopeBinding
                    )

                    if appState.settings.preparedness.officialAlertNotificationScope == .state {
                        officialAlertNotificationJurisdictionPicker
                    }
                }
            }

            Text(L10n.tr(
                "settings.preparedness.go_bag.note",
                "Recommended monthly for households that may need to leave quickly."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Battery Section

    private var batterySection: some View {
        PanelCard(
            title: L10n.tr("settings.battery.title", "Battery"),
            subtitle: L10n.tr("settings.battery.subtitle", "Preserve power during long outages and evacuations")
        ) {
            SettingsToggleRow(
                title: L10n.tr("settings.battery.survival_mode.title", "Enable Survival Mode at 15%"),
                subtitle: L10n.tr(
                    "settings.battery.survival_mode.subtitle",
                    "Prompt for a simplified low-power interface when battery is low"
                ),
                isOn: binding(\.battery.enablesSurvivalModeAtFifteenPercent)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.battery.disable_background.title", "Disable Background Scanning"),
                subtitle: L10n.tr(
                    "settings.battery.disable_background.subtitle",
                    "Prefer less background activity when the app is not in use"
                ),
                isOn: binding(\.battery.disablesBackgroundScanning)
            )

            SettingsDivider()

            SettingsToggleRow(
                title: L10n.tr("settings.battery.reduce_animations.title", "Reduce Map Animations"),
                subtitle: L10n.tr(
                    "settings.battery.reduce_animations.subtitle",
                    "Use less animated map movement to conserve power"
                ),
                isOn: binding(\.battery.reducesMapAnimations)
            )

            Text(L10n.format(
                "settings.battery.current",
                "Current battery: %@",
                appState.batteryStatus.percentageText
            ))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        PanelCard(
            title: L10n.tr("settings.data.title", "Data"),
            subtitle: L10n.tr("settings.data.subtitle", "Offline storage, downloads, and local exports")
        ) {
            NavigationLink {
                OfflineDataManagementView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.data.manage.title", "Manage Offline Data"),
                    subtitle: L10n.tr("settings.data.manage.subtitle", "Review map packs stored on this device"),
                    value: viewModel.installedPackSummary
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            NavigationLink {
                OfflineDataManagementView(appState: appState)
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.data.download.title", "Download Map Packs"),
                    subtitle: L10n.tr("settings.data.download.subtitle", "Install regional coverage for offline emergencies"),
                    value: L10n.tr("common.open", "Open")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Button {
                viewModel.isShowingClearCacheAlert = true
            } label: {
                SettingsActionRow(
                    title: L10n.tr("settings.data.clear_cache.title", "Clear Cached Data"),
                    subtitle: L10n.tr(
                        "settings.data.clear_cache.subtitle",
                        "Remove cached reports and local signal session history"
                    ),
                    value: L10n.tr("common.clear", "Clear"),
                    tint: ColorTheme.textTertiary
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Button {
                viewModel.exportPreparednessReport()
            } label: {
                SettingsActionRow(
                    title: L10n.tr("settings.data.export_report.title", "Export Preparedness Report"),
                    subtitle: L10n.tr(
                        "settings.data.export_report.subtitle",
                        "Create a PDF version of your current readiness report"
                    ),
                    value: L10n.tr("settings.data.export_report.value", "Export"),
                    tint: ColorTheme.textTertiary
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Diagnostics Section

    private var diagnosticsSection: some View {
        PanelCard(
            title: "Advanced",
            subtitle: "Local-only system diagnostics and device health"
        ) {
            NavigationLink {
                DiagnosticsView()
            } label: {
                SettingsNavigationRow(
                    title: "Diagnostics",
                    subtitle: "View local system events, errors, and crash detection logs",
                    value: "\(DiagnosticStore.shared.eventCount) events"
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        PanelCard(
            title: L10n.tr("settings.about.title", "About"),
            subtitle: L10n.tr("settings.about.subtitle", "App information, notices, and support status")
        ) {
            SettingsInfoRow(
                title: L10n.tr("settings.about.app_version.title", "App Version"),
                subtitle: L10n.tr("settings.about.app_version.subtitle", "Current build installed on this device"),
                value: viewModel.appVersionText
            )

            SettingsDivider()

            NavigationLink {
                PrivacyPolicyView()
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.about.privacy_policy.title", "Privacy Policy"),
                    subtitle: L10n.tr(
                        "settings.about.privacy_policy.subtitle",
                        "How RediM8 stores data and uses permissions"
                    ),
                    value: L10n.tr("common.open", "Open")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Link(destination: TrustLayer.termsOfUseURL) {
                SettingsNavigationRow(
                    title: L10n.tr("settings.about.terms.title", "Terms of Use"),
                    subtitle: L10n.tr("settings.about.terms.subtitle", "Subscription terms and service conditions"),
                    value: L10n.tr("common.open", "Open")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            NavigationLink {
                SettingsReferenceSectionsView(
                    title: L10n.tr("settings.about.attributions.title", "Attributions & Licenses"),
                    subtitle: L10n.tr(
                        "settings.about.attributions.detail_subtitle",
                        "Map data, public warning feeds, and bundled software used in RediM8"
                    ),
                    sections: TrustLayer.attributionSections
                )
            } label: {
                SettingsNavigationRow(
                    title: L10n.tr("settings.about.attributions.title", "Attributions & Licenses"),
                    subtitle: L10n.tr(
                        "settings.about.attributions.subtitle",
                        "Third-party software, open data, and source notices"
                    ),
                    value: L10n.tr("common.open", "Open")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Link(destination: TrustLayer.supportURL) {
                SettingsNavigationRow(
                    title: L10n.tr("settings.about.support.title", "Contact Support"),
                    subtitle: "support@redim8.com.au",
                    value: L10n.tr("settings.about.support.value", "Email")
                )
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Text(L10n.tr(
                "settings.about.disclaimer",
                "RediM8 provides preparedness information. Always follow instructions from emergency authorities."
            ))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Jurisdiction Picker

    var officialAlertNotificationJurisdictionPicker: some View {
        Menu {
            ForEach(viewModel.availableOfficialAlertNotificationJurisdictions) { jurisdiction in
                Button {
                    appState.mutateSettings { settings in
                        settings.preparedness.officialAlertNotificationJurisdiction = jurisdiction
                    }
                } label: {
                    if jurisdiction == effectiveOfficialAlertNotificationJurisdiction {
                        Label(jurisdiction.title, systemImage: "checkmark")
                    } else {
                        Text(jurisdiction.title)
                    }
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("settings.preparedness.official_alert_notifications.state_picker.label", "STATE FEED"))
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text(
                        effectiveOfficialAlertNotificationJurisdiction?.title
                            ?? L10n.tr(
                                "settings.preparedness.official_alert_notifications.state_picker.placeholder",
                                "Select a state or territory"
                            )
                    )
                    .font(RediTypography.data)
                    .foregroundStyle(ColorTheme.text)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.textTertiary)
            }
            .padding(RediSpacing.content)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
