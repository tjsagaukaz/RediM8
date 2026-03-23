import Foundation

struct SettingsNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var notice: SettingsNotice?
    @Published var isShowingResetNodeAlert = false
    @Published var isShowingClearCacheAlert = false
    @Published var isShowingEmergencySafeDefaultsAlert = false
    @Published private(set) var lastError: AppError?
    @Published private(set) var systemState: SystemState = .healthy

    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var appVersionText: String {
        let shortVersion = Bundle.main.infoDictionary?[AppConstants.AppInfo.shortVersionKey] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?[AppConstants.AppInfo.buildNumberKey] as? String ?? "?"
        return "Version \(shortVersion) (\(buildNumber))"
    }

    var installedPackSummary: String {
        let count = appState.mapDataService.loadInstalledPackIDs().count
        return count == 1 ? "1 pack installed" : "\(count) packs installed"
    }

    var defaultOfficialAlertNotificationJurisdiction: AustralianJurisdiction? {
        appState.officialAlertService.preferredJurisdiction(
            currentLocation: appState.locationService.currentLocation,
            installedPacks: appState.mapDataService.packs(withIDs: appState.mapDataService.loadInstalledPackIDs())
        )
    }

    var availableOfficialAlertNotificationJurisdictions: [AustralianJurisdiction] {
        var ordered: [AustralianJurisdiction] = []

        if let preferred = defaultOfficialAlertNotificationJurisdiction {
            ordered.append(preferred)
        }

        for jurisdiction in AustralianJurisdiction.allCases.sorted(by: { $0.title < $1.title }) where !ordered.contains(jurisdiction) {
            ordered.append(jurisdiction)
        }

        return ordered
    }

    func toggleStealthMode(_ isEnabled: Bool) {
        let wasEnabled = appState.isStealthModeEnabled
        if isEnabled {
            appState.enableStealthMode()
        } else {
            appState.disableStealthMode()
        }

        guard wasEnabled != isEnabled else { return }
        notice = SettingsNotice(
            title: isEnabled ? "Stealth Mode Enabled" : "Stealth Mode Disabled",
            message: isEnabled
                ? "Your device will remain hidden from nearby RediM8 users and switch to receive-only behavior."
                : "Your normal discovery, community report, and location settings are active again."
        )
    }

    func resetLocalNodeID() {
        let newNodeID = appState.resetLocalNodeID()
        notice = SettingsNotice(
            title: "Node ID Reset",
            message: "Nearby users will now see Node \(newNodeID) when name sharing is hidden."
        )
    }

    func clearCachedData() {
        appState.clearCachedData()
        notice = SettingsNotice(
            title: "Cache Cleared",
            message: "Nearby report cache and session messages were removed from this device."
        )
    }

    func resetToEmergencySafeDefaults() {
        appState.disableStealthMode()
        appState.mutateSettings { settings in
            settings = .emergencySafe
        }

        notice = SettingsNotice(
            title: "Emergency-Safe Defaults Restored",
            message: "This device now uses approximate location sharing, balanced signal behavior, critical map layers, and visible emergency-safe communication settings."
        )
    }

    func setOfficialAlertNotificationsEnabled(_ isEnabled: Bool) {
        guard isEnabled else {
            appState.mutateSettings { settings in
                settings.preparedness.officialAlertNotificationsEnabled = false
            }
            notice = SettingsNotice(
                title: "Official Alert Notifications Off",
                message: "RediM8 will stop sending notification banners for mirrored official alerts."
            )
            return
        }

        Task { @MainActor in
            let result = await appState.officialAlertNotificationService.requestAuthorizationIfNeeded()
            switch result {
            case .granted:
                appState.mutateSettings { settings in
                    settings.preparedness.officialAlertNotificationsEnabled = true
                    if settings.preparedness.officialAlertNotificationScope == .state,
                       settings.preparedness.officialAlertNotificationJurisdiction == nil {
                        settings.preparedness.officialAlertNotificationJurisdiction = self.defaultOfficialAlertNotificationJurisdiction
                    }
                }
                notice = SettingsNotice(
                    title: "Official Alert Notifications On",
                    message: "RediM8 will notify you when new official alerts match your selected scope."
                )
            case .denied:
                appState.mutateSettings { settings in
                    settings.preparedness.officialAlertNotificationsEnabled = false
                }
                notice = SettingsNotice(
                    title: "Notifications Not Allowed",
                    message: "Enable notifications for RediM8 in iPhone Settings if you want alert banners."
                )
            case .failed:
                appState.mutateSettings { settings in
                    settings.preparedness.officialAlertNotificationsEnabled = false
                }
                notice = SettingsNotice(
                    title: "Notification Setup Failed",
                    message: "RediM8 could not request notification access right now. Try again in a moment."
                )
                lastError = .permissionDenied(type: "Notification")
                systemState = .degraded(reason: "Notification permission could not be obtained")
            }
        }
    }

    func exportPreparednessReport() {
        do {
            let url = try appState.exportPreparednessReport()
            notice = SettingsNotice(
                title: "Preparedness Report Exported",
                message: "Saved \(url.lastPathComponent) to the app's Readiness Reports folder."
            )
        } catch {
            notice = SettingsNotice(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
    }
}
