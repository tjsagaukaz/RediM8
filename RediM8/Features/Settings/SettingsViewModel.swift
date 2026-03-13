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
