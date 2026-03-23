import CoreLocation
import Foundation
import MapKit
import SwiftUI

// MARK: - Layer Management, Surface Mode & Map Status

extension MapViewModel {
    var isBushfireModeEnabled: Bool {
        selectedScenarios.contains(.bushfires)
    }

    var installedPacks: [OfflineMapPack] {
        mapDataService.packs(withIDs: installedPackIDs)
    }

    var hasNearbyNetworkResourceData: Bool {
        waterPoints.contains(where: \.isNetworkNearby) || shelters.contains(where: \.isNetworkNearby)
    }

    var isTacticalSurfaceActive: Bool {
        !surfaceMode.usesAppleTiles
    }

    var surfaceBadgeTitle: String {
        switch surfaceMode {
        case .liveTiles:
            "Live Tiles"
        case .hybrid:
            "Hybrid Tiles"
        case .tactical:
            isPremiumBasemapActive ? "Local Basemap" : "Tactical Fallback"
        }
    }

    var surfaceTint: Color {
        switch surfaceMode {
        case .liveTiles:
            ColorTheme.info
        case .hybrid:
            ColorTheme.water
        case .tactical:
            isPremiumBasemapActive ? ColorTheme.ready : ColorTheme.warning
        }
    }

    var basemapStatusMessage: String {
        switch surfaceMode {
        case .liveTiles:
            "Apple road tiles are active. Keep Tactical ready for true offline fallback."
        case .hybrid:
            "Apple hybrid tiles are active. Satellite detail helps with terrain and landmarks while tile data is available."
        case .tactical:
            offlineBasemapStatusMessage
        }
    }

    var surfaceAvailabilityNote: String? {
        guard surfaceMode.usesAppleTiles else {
            return nil
        }

        if isPremiumBasemapActive {
            return "Local offline basemap remains ready if service drops or tiles fail."
        }

        return "Switch to Offline Tactical if live tiles stop loading or coverage drops away."
    }

    // MARK: - Map Confidence

    var mapConfidenceValue: String {
        switch mapConfidenceTone {
        case .ready:
            "High"
        case .info:
            "Medium"
        case .caution, .danger, .neutral:
            "Low"
        }
    }

    var mapConfidenceDetail: String {
        let coverageDetail: String
        if !installedPacks.isEmpty {
            coverageDetail = "\(installedPacks.count) offline pack\(installedPacks.count == 1 ? "" : "s") ready"
        } else if isPremiumBasemapActive {
            coverageDetail = "local offline basemap ready"
        } else if surfaceMode.usesAppleTiles {
            coverageDetail = "live tiles only"
        } else {
            coverageDetail = "fallback overlays only"
        }

        if let accuracyText = locationAccuracySummary {
            return "\(accuracyText) • \(coverageDetail)"
        }

        return "Waiting for live GPS • \(coverageDetail)"
    }

    var mapConfidenceOverlayDetail: String {
        if let locationAccuracySummary {
            return locationAccuracySummary
        }

        if currentLocation == nil {
            return "Waiting for GPS"
        }

        return mapModeOverlayDetail
    }

    var mapConfidenceTone: OperationalStatusTone {
        guard let currentLocation else {
            return installedPacks.isEmpty && !isPremiumBasemapActive ? .danger : .caution
        }

        let accuracy = max(currentLocation.horizontalAccuracy, 0)
        let hasOfflineCoverage = !installedPacks.isEmpty || isPremiumBasemapActive

        if accuracy > 0, accuracy > 120 {
            return hasOfflineCoverage ? .caution : .danger
        }

        if hasOfflineCoverage {
            return accuracy > 40 ? .info : .ready
        }

        return accuracy > 40 ? .caution : .info
    }

    // MARK: - Map Trust Items

    var mapTrustItems: [TrustPillItem] {
        var items: [TrustPillItem] = [
            TrustPillItem(
                title: surfaceBadgeTitle,
                tone: surfaceMode == .tactical
                    ? (isPremiumBasemapActive ? .verified : .caution)
                    : .info
            ),
            TrustPillItem(title: surfaceMode.usesAppleTiles ? "Network-assisted" : "Offline only", tone: surfaceMode.usesAppleTiles ? .caution : .info),
            TrustPillItem(title: "Confidence \(mapConfidenceValue)", tone: confidenceTrustTone),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: max(resourceDatasetLastUpdated, offlineLayerLastUpdated)), tone: .neutral)
        ]

        if surfaceMode.usesAppleTiles {
            items.append(
                TrustPillItem(
                    title: isPremiumBasemapActive ? "Offline basemap ready" : "Offline tactical ready",
                    tone: isPremiumBasemapActive ? .verified : .caution
                )
            )
        }

        if installedPacks.isEmpty {
            items.append(TrustPillItem(title: "Coverage limited", tone: .caution))
        }

        if hasNearbyNetworkResourceData {
            items.append(TrustPillItem(title: "Live nearby data", tone: .caution))
        }

        if hazardFeedLastSuccessfulFetch != nil {
            items.append(
                TrustPillItem(
                    title: "Hazard feeds \(hazardFeedService.feedFreshnessText)",
                    tone: hazardFeedTone == .ready ? .verified : .caution
                )
            )
        } else if hazardFeedIsFetching {
            items.append(TrustPillItem(title: "Hazard feeds syncing", tone: .info))
        } else {
            items.append(
                TrustPillItem(
                    title: hazardFeedLastRefreshError == nil ? "Hazard feeds pending" : "Hazard feeds unavailable",
                    tone: hazardFeedLastRefreshError == nil ? .neutral : .caution
                )
            )
        }

        if let topOfficialAlert {
            items.append(
                TrustPillItem(
                    title: topOfficialAlert.isAreaScoped
                        ? (topOfficialAlert.severity == .advice ? "Official alert nearby" : "Official warning nearby")
                        : "Official feed active",
                    tone: topOfficialAlert.isAreaScoped
                        ? (topOfficialAlert.severity == .advice ? .info : .danger)
                        : .info
                )
            )
        }

        return items
    }

    // MARK: - Map Mode Overlay

    var mapModeOverlayTitle: String {
        switch surfaceMode {
        case .liveTiles:
            return installedPacks.isEmpty ? "LIVE MAP (NETWORK)" : "LIVE + OFFLINE FALLBACK"
        case .hybrid:
            return installedPacks.isEmpty ? "HYBRID MAP (NETWORK)" : "HYBRID + OFFLINE FALLBACK"
        case .tactical:
            return isPremiumBasemapActive ? "OFFLINE MAP ACTIVE" : "OFFLINE FALLBACK"
        }
    }

    var mapModeOverlayDetail: String {
        if !installedPacks.isEmpty {
            return "\(installedPacks.count) offline pack\(installedPacks.count == 1 ? "" : "s") installed"
        }

        if isPremiumBasemapActive {
            return "Local offline basemap ready"
        }

        if surfaceMode.usesAppleTiles {
            return "Using live tiles + bundled references"
        }

        return "Using overlays + saved references"
    }

    // MARK: - Map Status

    var mapStatusHeadline: String {
        switch surfaceMode {
        case .liveTiles:
            return "Live map active"
        case .hybrid:
            return "Hybrid map active"
        case .tactical:
            break
        }

        if isPremiumBasemapActive, !installedPacks.isEmpty {
            return "Offline map active"
        }

        if isPremiumBasemapActive {
            return "Offline basemap active"
        }

        return "Offline fallback active"
    }

    var mapStatusDetail: String {
        switch surfaceMode {
        case .liveTiles:
            if installedPacks.isEmpty {
                return "Offline fallback available"
            }
            return "\(installedPacks.count) offline pack\(installedPacks.count == 1 ? "" : "s") installed"
        case .hybrid:
            if installedPacks.isEmpty {
                return "Offline fallback available"
            }
            return "\(installedPacks.count) offline pack\(installedPacks.count == 1 ? "" : "s") installed"
        case .tactical:
            break
        }

        if isPremiumBasemapActive, !installedPacks.isEmpty {
            return "\(installedPacks.count) offline pack\(installedPacks.count == 1 ? "" : "s") installed"
        }

        if isPremiumBasemapActive {
            return "Offline fallback available"
        }

        return "Using pack overlays and saved references only"
    }

    var mapStatusTone: OperationalStatusTone {
        if surfaceMode.usesAppleTiles {
            return installedPacks.isEmpty ? .info : .ready
        }

        if isPremiumBasemapActive, !installedPacks.isEmpty {
            return .ready
        }

        if isPremiumBasemapActive || !installedPacks.isEmpty {
            return .info
        }

        return .caution
    }

    // MARK: - Basemap & Coverage

    var workingBasemapSummary: String {
        switch surfaceMode {
        case .liveTiles:
            return "Apple road tiles are active for live route and place context."
        case .hybrid:
            return "Apple hybrid tiles are active for satellite terrain and landmark context."
        case .tactical:
            return isPremiumBasemapActive
                ? "Local offline basemap is active."
                : "A tactical fallback surface is active. It shows offline packs, tracks, shelters, water, and markers, but not full road or topographic cartography."
        }
    }

    var basemapOperationalValue: String {
        switch surfaceMode {
        case .liveTiles:
            return installedPacks.isEmpty ? "Live map (network)" : "Live + offline fallback"
        case .hybrid:
            return installedPacks.isEmpty ? "Hybrid map (network)" : "Hybrid + offline fallback"
        case .tactical:
            return isPremiumBasemapActive ? "Offline map active" : "Offline fallback"
        }
    }

    var basemapOperationalTone: OperationalStatusTone {
        switch surfaceMode {
        case .liveTiles, .hybrid:
            return .info
        case .tactical:
            return isPremiumBasemapActive ? .ready : .caution
        }
    }

    var workingCoverageSummary: String {
        guard !installedPacks.isEmpty else {
            if hasNearbyNetworkResourceData {
                let basemapNoun = surfaceMode.usesAppleTiles ? "selected surface" : "basemap"
                return "No regional pack is installed. RediM8 is using live nearby data for current-position water and shelter context, while the \(basemapNoun) and saved markers remain available."
            }
            let basemapNoun = surfaceMode.usesAppleTiles ? "selected surface" : "basemap"
            return "No regional pack is installed. RediM8 can still show the \(basemapNoun), bundled resources, and any saved markers."
        }

        let packNames = installedPacks.map(\.name)
        if packNames.count == 1, let packName = packNames.first {
            return "\(packName) coverage is installed."
        }

        let preview = packNames.prefix(2).joined(separator: ", ")
        if packNames.count > 2 {
            return "\(packNames.count) regional packs are installed: \(preview), plus \(packNames.count - 2) more."
        }

        return "\(packNames.count) regional packs are installed: \(preview)."
    }

    var workingPositionSummary: String {
        if let locationAccuracySummary {
            return "Live position and heading are available. \(locationAccuracySummary) for recentering and nearby distance estimates."
        }

        return "No live position right now. Distances fall back to offline reference mode."
    }

    var workingMotionSummary: String {
        reducesMapAnimations
            ? "Reduced-motion map path is active for stress and battery protection."
            : "Standard map motion is active."
    }

    var offlineFallbackSummary: String {
        installedPacks.isEmpty
            ? "Offline map pack not installed. RediM8 falls back to the basemap, saved routes, and bundled reference points."
            : "Regional offline coverage is installed."
    }

    var coverageLimitSummary: String {
        guard !installedPacks.isEmpty else {
            if hasNearbyNetworkResourceData {
                return "No regional pack is installed. Live nearby search is helping fill current-position shelter and water context, but dependable offline coverage still starts with installed packs."
            }
            return "No regional pack is installed. If layer data is missing, RediM8 keeps the basemap and saved markers visible while map-pack layers stay empty."
        }

        let packNames = installedPacks.prefix(2).map(\.name).joined(separator: ", ")
        let remainder = installedPacks.count - min(installedPacks.count, 2)
        let label = remainder > 0 ? "\(packNames) + \(remainder) more" : packNames
        if hasNearbyNetworkResourceData {
            return "Installed coverage: \(label). Outside those pack boundaries, RediM8 keeps the basemap and saved markers visible. Live nearby search can add extra shelter and water candidates around your current position, but only installed packs remain dependable offline."
        }
        return "Installed coverage: \(label). Outside those pack boundaries, RediM8 keeps the basemap and saved markers visible, but water points, shelters, and track layers can disappear."
    }

    var coverageLimitHeadline: String {
        installedPacks.first?.name ?? "No offline pack installed"
    }

    var coverageLimitBullets: [String] {
        if installedPacks.isEmpty {
            var bullets = [
                "Only the basemap and saved markers stay consistently visible.",
                "Water, shelter, and track overlays may disappear without installed coverage."
            ]

            if hasNearbyNetworkResourceData {
                bullets[1] = "Live nearby search can add temporary water and shelter candidates, but installed packs remain the dependable offline source."
            }

            return bullets
        }

        return [
            "Outside this pack area, only the basemap and saved markers stay visible.",
            "Water, shelter, and track overlays may disappear beyond installed boundaries."
        ]
    }

    var bushfireMapSummary: String? {
        guard isBushfireModeEnabled else {
            return nil
        }
        return "Fire trails, water points, shelters, and evacuation points are surfaced first while Bushfire Mode is active."
    }

    var distanceRingLabels: [String] {
        ["1 km", "5 km", "10 km"]
    }

    // MARK: - Layer Actions

    func isLayerEnabled(_ layer: MapLayer) -> Bool {
        enabledLayers.contains(layer)
    }

    func setLayer(_ layer: MapLayer, isEnabled: Bool) {
        appState.setMapLayer(layer, isEnabled: isEnabled)
        if !isEnabled, layer == .evacuationPoints {
            selectedShelterID = nil
        }
        if layer == .communityBeacons {
            syncCommunityMonitoring()
        }
    }

    func setSurfaceMode(_ mode: MapSurfaceMode) {
        appState.mutateSettings { settings in
            settings.maps.surfaceMode = mode
        }
    }

    func toggleDistanceRings() {
        appState.mutateSettings { settings in
            settings.maps.showsDistanceRings.toggle()
        }
    }

    // MARK: - Offline Pack Actions

    func installPack(_ packID: String) {
        installedPackIDs = mapDataService.installPack(packID, into: installedPackIDs)
        reloadOfflineMapFeatures()
        reloadOfficialAlerts()
        focus(onPackID: packID)
    }

    func removePack(_ packID: String) {
        installedPackIDs = mapDataService.removePack(packID, from: installedPackIDs)
        reloadOfflineMapFeatures()
        reloadOfficialAlerts()
        recenter(requestAccessIfNeeded: false)
    }

    func focus(onPackID packID: String) {
        guard let pack = mapDataService.pack(withID: packID) else {
            return
        }

        viewportRegion = renderController.focusRegion(for: pack)
        viewportRevision += 1
    }

    func packTrustItems(for pack: OfflineMapPack, isInstalled: Bool) -> [TrustPillItem] {
        var items = [
            TrustPillItem(title: "Offline only", tone: .info),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: pack.lastUpdated), tone: .neutral)
        ]

        items.insert(
            TrustPillItem(title: isInstalled ? "Installed" : "Not installed", tone: isInstalled ? .verified : .caution),
            at: 0
        )

        return items
    }

    var locationFailureSummary: String {
        currentLocation == nil
            ? "Use saved routes, known landmarks,\nand offline references until GPS returns."
            : "Live location is available."
    }

    // MARK: - Internal Helpers

    internal var confidenceTrustTone: TrustPillTone {
        switch mapConfidenceTone {
        case .ready:
            .verified
        case .info:
            .info
        case .caution:
            .caution
        case .danger:
            .danger
        case .neutral:
            .neutral
        }
    }

    internal var locationAccuracySummary: String? {
        guard let currentLocation else {
            return nil
        }

        let accuracy = max(currentLocation.horizontalAccuracy, 0)
        guard accuracy > 0 else {
            return nil
        }

        if accuracy >= 1_000 {
            return String(format: "GPS accuracy %.1f km", accuracy / 1_000)
        }

        return "GPS accuracy \(Int(accuracy.rounded())) m"
    }

    internal static func orderedLayers(for scenarios: [ScenarioKind]) -> [MapLayer] {
        guard scenarios.contains(.bushfires) else {
            return MapLayer.allCases
        }

        let priority: [MapLayer] = [
            .officialAlerts,
            .fireTrails,
            .waterPoints,
            .evacuationPoints,
            .resources,
            .dirtRoads,
            .communityBeacons
        ]

        return priority + MapLayer.allCases.filter { !priority.contains($0) }
    }

    internal func reloadOfflineMapFeatures(useBackgroundQueue: Bool = false) {
        let installedPackIDs = self.installedPackIDs
        let currentCoordinate = currentLocation?.coordinate

        guard useBackgroundQueue else {
            applyOfflineDataSnapshot(
                offlineDataController.makeSnapshot(
                    installedPackIDs: installedPackIDs,
                    currentLocation: currentCoordinate
                )
            )
            return
        }

        offlineReloadGeneration += 1
        let generation = offlineReloadGeneration
        offlineDataController.loadSnapshot(
            installedPackIDs: installedPackIDs,
            currentLocation: currentCoordinate
        ) { [weak self] snapshot in
            guard let self, generation == self.offlineReloadGeneration else {
                return
            }
            self.applyOfflineDataSnapshot(snapshot)
        }
    }

    internal func applyOfflineDataSnapshot(_ snapshot: MapOfflineDataSnapshot) {
        availablePacks = snapshot.availablePacks
        offlineLayerLastUpdated = snapshot.lastUpdated
        dirtRoads = snapshot.dirtRoads
        fireTrails = snapshot.fireTrails
        waterPoints = snapshot.waterPoints
        shelters = snapshot.shelters
        resourceDataStatusMessage = snapshot.didLoadOfflineData ? nil : TrustLayer.mapDataUnavailableMessage
        refreshLastUpdatedText(didLoadOfflineData: snapshot.didLoadOfflineData)
        if let selectedShelterID, !snapshot.shelters.contains(where: { $0.id == selectedShelterID }) {
            self.selectedShelterID = nil
        }
    }

    internal func refreshLastUpdatedText(didLoadOfflineData: Bool) {
        let latestOfflineDate = max(resourceDatasetLastUpdated, offlineLayerLastUpdated)
        let hasAnyOfflineData = mapService.didLoadBundledResources || didLoadOfflineData
        lastUpdatedText = hasAnyOfflineData ? DateFormatter.rediM8MonthYear.string(from: latestOfflineDate) : "Unavailable"
    }

    internal func syncCommunityMonitoring() {
        guard isVisible else {
            beaconService.stopMonitoring()
            return
        }

        if enabledLayers.contains(.communityBeacons) {
            beaconService.startMonitoring()
        } else {
            beaconService.stopMonitoring()
        }
    }
}

extension CLAuthorizationStatus {
    var isAuthorizedForRediM8: Bool {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            true
        default:
            false
        }
    }
}
