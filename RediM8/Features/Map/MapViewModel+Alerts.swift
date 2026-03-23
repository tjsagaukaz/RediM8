import Foundation
import MapKit

// MARK: - Official Alerts

extension MapViewModel {
    var topOfficialAlert: OfficialAlert? {
        nearbyOfficialAlerts.first
    }

    var officialAlertHeadline: String {
        if let topOfficialAlert {
            return topOfficialAlert.title
        }
        if officialAlertService.hasCachedData {
            return "No nearby official warnings"
        }
        return "Official warnings not cached yet"
    }

    var officialAlertDetail: String {
        if let topOfficialAlert {
            let issued = DateFormatter.rediM8Short.string(from: topOfficialAlert.lastUpdated)
            if topOfficialAlert.isAreaScoped {
                return "\(topOfficialAlert.severity.title) issued by \(topOfficialAlert.issuer). Updated \(issued)."
            }
            return "\(topOfficialAlert.scopeTrustLabel) from \(topOfficialAlert.issuer) for \(topOfficialAlert.jurisdiction.title). Confirm affected areas in the official source. Updated \(issued)."
        }

        if let officialAlertUnavailableMessage {
            return officialAlertUnavailableMessage
        }

        if currentLocation == nil, installedPacks.isEmpty, officialAlertService.hasCachedData {
            return "Location or installed pack coverage is needed before RediM8 can scope cached official warnings to this map."
        }

        if officialAlertService.hasCachedData {
            return "Cached \(officialCoverageSummary) official warning feeds show no area-scoped or jurisdiction-matched alerts for this device or installed pack coverage."
        }

        return "Connect once so RediM8 can mirror current public warnings for offline use."
    }

    var officialAlertTone: OperationalStatusTone {
        guard let topOfficialAlert else {
            if currentLocation == nil, installedPacks.isEmpty, officialAlertService.hasCachedData {
                return .info
            }
            return officialAlertService.hasCachedData ? .ready : .caution
        }

        if !topOfficialAlert.isAreaScoped {
            return .info
        }

        switch topOfficialAlert.severity {
        case .advice:
            return .info
        case .watchAndAct:
            return .caution
        case .emergencyWarning:
            return .danger
        }
    }

    var officialAlertStatusValue: String {
        if let topOfficialAlert {
            return topOfficialAlert.isAreaScoped ? "\(topOfficialAlert.severity.title) nearby" : "Feed active"
        }
        if currentLocation == nil, installedPacks.isEmpty, officialAlertService.hasCachedData {
            return "Scope needed"
        }
        return officialAlertService.hasCachedData ? "No active warnings" : "Warnings unavailable"
    }

    var officialAlertUnavailableMessage: String? {
        if !officialAlertService.hasCachedData {
            return officialAlertService.lastRefreshError
        }
        return nil
    }

    var officialAlertOverviewTrustItems: [TrustPillItem] {
        var items = [
            TrustPillItem(title: "Official", tone: .verified),
            TrustPillItem(title: "Mirrored", tone: .info),
            TrustPillItem(title: officialCoverageTrustLabel, tone: .info)
        ]

        if let topOfficialAlert {
            items.append(TrustPillItem(title: topOfficialAlert.scopeTrustLabel, tone: topOfficialAlert.isAreaScoped ? .verified : .caution))
            items.append(TrustPillItem(title: TrustLayer.freshnessLabel(for: topOfficialAlert.lastUpdated), tone: .neutral))
        } else if officialAlertService.hasCachedData {
            items.append(TrustPillItem(title: TrustLayer.freshnessLabel(for: officialAlertService.library.lastUpdated), tone: .neutral))
        } else {
            items.append(TrustPillItem(title: "Offline cache empty", tone: .caution))
        }

        return items
    }

    var hasCachedOfficialAlerts: Bool {
        officialAlertService.hasCachedData
    }

    var defaultOfficialAlertJurisdiction: AustralianJurisdiction? {
        officialAlertService.preferredJurisdiction(
            currentLocation: currentLocation,
            installedPacks: installedPacks
        )
    }

    var availableOfficialAlertJurisdictions: [AustralianJurisdiction] {
        var ordered: [AustralianJurisdiction] = []

        if let preferred = defaultOfficialAlertJurisdiction {
            ordered.append(preferred)
        }

        for jurisdiction in AustralianJurisdiction.allCases.sorted(by: { $0.title < $1.title }) where !ordered.contains(jurisdiction) {
            ordered.append(jurisdiction)
        }

        return ordered
    }

    func officialAlerts(for scope: MapOfficialAlertScope, jurisdiction: AustralianJurisdiction?) -> [OfficialAlert] {
        switch scope {
        case .local:
            return nearbyOfficialAlerts
        case .state:
            guard let jurisdiction else {
                return []
            }
            return officialAlertService.alerts(for: jurisdiction)
        case .australia:
            return officialAlertService.australiaWideAlerts()
        }
    }

    func officialAlertSummary(for scope: MapOfficialAlertScope, jurisdiction: AustralianJurisdiction?) -> MapOfficialAlertSummary {
        switch scope {
        case .local:
            return MapOfficialAlertSummary(
                title: officialAlertHeadline,
                detail: officialAlertDetail,
                tone: officialAlertTone
            )
        case .state:
            return stateAlertSummary(for: jurisdiction)
        case .australia:
            return australiaAlertSummary()
        }
    }

    func scopedOfficialAlertTrustItems(for scope: MapOfficialAlertScope, jurisdiction: AustralianJurisdiction?) -> [TrustPillItem] {
        let alerts = officialAlerts(for: scope, jurisdiction: jurisdiction)
        var items = [
            TrustPillItem(title: "Official", tone: .verified),
            TrustPillItem(title: "Mirrored", tone: .info)
        ]

        switch scope {
        case .local:
            items.append(TrustPillItem(title: "Map-local", tone: .info))
        case .state:
            items.append(
                TrustPillItem(
                    title: jurisdiction.map { "\($0.shortTitle) scope" } ?? "State scope",
                    tone: .info
                )
            )
        case .australia:
            items.append(TrustPillItem(title: "Australia-wide", tone: .info))
        }

        if let alert = alerts.first {
            items.append(TrustPillItem(title: alert.scopeTrustLabel, tone: alert.isAreaScoped ? .verified : .caution))
            items.append(TrustPillItem(title: TrustLayer.freshnessLabel(for: alert.lastUpdated), tone: .neutral))
        } else if officialAlertService.hasCachedData {
            items.append(TrustPillItem(title: TrustLayer.freshnessLabel(for: officialAlertService.library.lastUpdated), tone: .neutral))
            if scope == .state,
               let jurisdiction,
               !officialAlertService.cachedJurisdictions.contains(jurisdiction) {
                items.append(TrustPillItem(title: "Not cached yet", tone: .caution))
            }
        } else {
            items.append(TrustPillItem(title: "Offline cache empty", tone: .caution))
        }

        return items
    }

    func officialAlertCountSummary(for scope: MapOfficialAlertScope, jurisdiction: AustralianJurisdiction?) -> String? {
        let alerts = officialAlerts(for: scope, jurisdiction: jurisdiction)
        guard !alerts.isEmpty else {
            return nil
        }

        switch scope {
        case .local:
            return alerts.count == 1
                ? "1 official alert matched this map area or installed coverage."
                : "\(alerts.count) official alerts matched this map area or installed coverage."
        case .state:
            guard let jurisdiction else {
                return nil
            }
            return alerts.count == 1
                ? "1 official alert is active in the \(jurisdiction.shortTitle) feed."
                : "\(alerts.count) official alerts are active in the \(jurisdiction.shortTitle) feed."
        case .australia:
            return alerts.count == 1
                ? "1 official alert is active across cached Australian feeds."
                : "\(alerts.count) official alerts are active across cached Australian feeds."
        }
    }

    func officialAlertScopeLine(for alert: OfficialAlert, scope: MapOfficialAlertScope) -> String {
        switch scope {
        case .local:
            return officialAlertDistanceText(for: alert)
        case .state:
            return alert.isAreaScoped ? "\(alert.regionScope) • \(alert.jurisdiction.shortTitle)" : "\(alert.jurisdiction.shortTitle) statewide feed"
        case .australia:
            return alert.isAreaScoped ? "\(alert.regionScope) • \(alert.jurisdiction.shortTitle)" : "\(alert.jurisdiction.title) statewide"
        }
    }

    func officialAlertUpdatedLine(for alert: OfficialAlert) -> String {
        "Updated \(DateFormatter.rediM8Short.string(from: alert.lastUpdated))"
    }

    func officialAlertDistanceText(for alert: OfficialAlert) -> String {
        guard alert.isAreaScoped else {
            return "\(alert.jurisdiction.shortTitle) statewide"
        }

        if let currentLocation {
            let metres = alert.distance(from: currentLocation)
            if metres >= 1_000 {
                return String(format: "%.1f km away", metres / 1_000)
            }
            return "\(Int(metres.rounded())) m away"
        }

        return "Pack-area match"
    }

    func officialAlertTrustItems(for alert: OfficialAlert) -> [TrustPillItem] {
        [
            TrustPillItem(title: "Official", tone: .verified),
            TrustPillItem(title: "Mirrored", tone: .info),
            TrustPillItem(title: alert.jurisdictionTrustLabel, tone: .info),
            TrustPillItem(title: alert.scopeTrustLabel, tone: alert.isAreaScoped ? .verified : .caution),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: alert.lastUpdated), tone: .neutral)
        ]
    }

    func officialAlertSafetyNote(for alert: OfficialAlert) -> String {
        if !alert.isAreaScoped {
            return "This is a jurisdiction-wide official feed summary. The affected area may be smaller than the whole state or territory, so confirm the exact warning area in the official source."
        }

        switch alert.severity {
        case .emergencyWarning:
            return "Follow the issuing authority immediately. RediM8 does not replace official emergency alert systems."
        case .watchAndAct:
            return "Conditions may escalate quickly. Prepare to leave and keep official channels in view."
        case .advice:
            return "Monitor official updates and confirm conditions before you move."
        }
    }

    var officialAlertBannerText: String? {
        guard let topOfficialAlert else {
            return nil
        }

        if topOfficialAlert.isAreaScoped {
            return "Official warning nearby: \(topOfficialAlert.severity.title)"
        }

        return "Official \(topOfficialAlert.jurisdiction.shortTitle) feed active"
    }

    var visibleOfficialAlerts: [OfficialAlert] {
        guard enabledLayers.contains(.officialAlerts) else {
            return []
        }
        return nearbyOfficialAlerts.filter(\.isAreaScoped)
    }

    // MARK: - Alert Helpers (internal for cross-file access)

    internal var officialCoverageTrustLabel: String {
        officialAlertService.cachedJurisdictions.count == AustralianJurisdiction.allCases.count
            ? "Australia-wide"
            : officialCoverageSummary
    }

    internal var officialCoverageSummary: String {
        let count = officialAlertService.cachedJurisdictions.count
        if count == AustralianJurisdiction.allCases.count {
            return "Australia-wide"
        }
        if count == 1, let jurisdiction = officialAlertService.cachedJurisdictions.first {
            return jurisdiction.title
        }
        return "\(count) jurisdictions"
    }

    internal func stateAlertSummary(for jurisdiction: AustralianJurisdiction?) -> MapOfficialAlertSummary {
        guard let jurisdiction else {
            return MapOfficialAlertSummary(
                title: "State scope unavailable",
                detail: "Choose a state or territory to review that mirrored official warning feed on the map.",
                tone: .info
            )
        }

        let alerts = officialAlertService.alerts(for: jurisdiction)
        if let alert = alerts.first {
            let updated = DateFormatter.rediM8Short.string(from: alert.lastUpdated)
            if alerts.count == 1 {
                let detail = alert.isAreaScoped
                    ? "\(alert.severity.title) in \(alert.regionScope). Updated \(updated)."
                    : "\(alert.severity.title) statewide feed from \(alert.issuer). Confirm exact areas in the official source. Updated \(updated)."
                return MapOfficialAlertSummary(
                    title: alert.title,
                    detail: detail,
                    tone: alertTone(for: alert)
                )
            }

            let areaScopedCount = alerts.filter(\.isAreaScoped).count
            let statewideCount = alerts.count - areaScopedCount
            return MapOfficialAlertSummary(
                title: "\(alerts.count) official alerts in \(jurisdiction.shortTitle)",
                detail: "Highest severity: \(alert.severity.title). \(areaScopedCount) area-scoped, \(statewideCount) statewide feed. Updated \(updated).",
                tone: alertTone(for: alert)
            )
        }

        if !officialAlertService.hasCachedData {
            return MapOfficialAlertSummary(
                title: "Official alerts syncing",
                detail: "Connect once so RediM8 can cache public warnings for offline map access.",
                tone: .info
            )
        }

        if !officialAlertService.cachedJurisdictions.contains(jurisdiction) {
            return MapOfficialAlertSummary(
                title: "\(jurisdiction.shortTitle) feed not cached",
                detail: "Connect once so RediM8 can mirror \(jurisdiction.title) official warnings for offline access.",
                tone: .info
            )
        }

        return MapOfficialAlertSummary(
            title: "No active \(jurisdiction.shortTitle) alerts",
            detail: "Monitoring cached \(jurisdiction.title) warning sources for this map view.",
            tone: .ready
        )
    }

    internal func australiaAlertSummary() -> MapOfficialAlertSummary {
        let alerts = officialAlertService.australiaWideAlerts()

        if let alert = alerts.first {
            let updated = DateFormatter.rediM8Short.string(from: alert.lastUpdated)
            if alerts.count == 1 {
                return MapOfficialAlertSummary(
                    title: alert.title,
                    detail: "\(alert.severity.title) in \(alert.jurisdiction.title). Updated \(updated).",
                    tone: alertTone(for: alert)
                )
            }

            return MapOfficialAlertSummary(
                title: "\(alerts.count) official alerts across Australia",
                detail: "Highest severity: \(alert.severity.title). Mirroring cached warning feeds across \(officialCoverageSummary). Updated \(updated).",
                tone: alertTone(for: alert)
            )
        }

        if !officialAlertService.hasCachedData {
            return MapOfficialAlertSummary(
                title: "Official alerts syncing",
                detail: "Connect once so RediM8 can cache public warnings for offline map access.",
                tone: .info
            )
        }

        return MapOfficialAlertSummary(
            title: "No active alerts across Australia",
            detail: "Monitoring cached warning feeds across \(officialCoverageSummary).",
            tone: .ready
        )
    }

    // Renamed from `tone(for:)` to avoid ambiguity across extensions
    internal func alertTone(for alert: OfficialAlert) -> OperationalStatusTone {
        switch alert.severity {
        case .advice:
            return .info
        case .watchAndAct:
            return .caution
        case .emergencyWarning:
            return .danger
        }
    }

    internal func reloadOfficialAlerts() {
        nearbyOfficialAlerts = officialAlertService.nearbyAlerts(
            currentLocation: currentLocation,
            installedPacks: installedPacks
        )
    }
}
