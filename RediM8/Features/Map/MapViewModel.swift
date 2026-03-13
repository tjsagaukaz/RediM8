import Combine
import CoreLocation
import Foundation
import MapKit
import SwiftUI

@MainActor
final class MapViewModel: ObservableObject {
    @Published private(set) var bundledResources: [ResourceMarker]
    @Published var userMarkers: [ResourceMarker]
    @Published var selectedMarkerKind: MarkerKind = .shelter
    @Published var markerTitle = ""
    @Published private(set) var viewportRegion: MKCoordinateRegion
    @Published private(set) var viewportRevision = 0
    @Published private(set) var lastUpdatedText: String
    @Published private(set) var resourceDataStatusMessage: String?
    @Published private(set) var nearbyBeacons: [CommunityBeacon] = []
    @Published private(set) var activeBeacon: CommunityBeacon?
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var heading: CLLocationDirection = 0
    @Published private(set) var selectedScenarios: [ScenarioKind]
    @Published private(set) var savedRoutes: [String]
    @Published private(set) var enabledLayers: Set<MapLayer>
    @Published private(set) var surfaceMode: MapSurfaceMode
    @Published private(set) var reducesMapAnimations: Bool
    @Published private(set) var isStealthModeEnabled: Bool
    @Published private(set) var availableLayers: [MapLayer]
    @Published private(set) var availablePacks: [OfflineMapPack]
    @Published private(set) var installedPackIDs: Set<String>
    @Published private(set) var dirtRoads: [TrackSegment] = []
    @Published private(set) var fireTrails: [TrackSegment] = []
    @Published private(set) var waterPoints: [WaterPoint] = []
    @Published private(set) var shelters: [ShelterLocation] = []
    @Published private(set) var selectedShelterID: String?
    @Published private(set) var nearbyOfficialAlerts: [OfficialAlert] = []

    private let appState: AppState
    private let officialAlertService: OfficialAlertService
    private let mapService: MapService
    private let mapDataService: MapDataService
    private let waterPointService: WaterPointService
    private let shelterService: ShelterService
    private let beaconService: BeaconService
    private let locationService: LocationService
    private let resourceCategoryIndex: [String: ResourceCategoryDefinition]
    private let resourceDatasetLastUpdated: Date
    private var offlineLayerLastUpdated: Date
    let basemapStyleURL: URL
    private let offlineBasemapStatusMessage: String
    let isPremiumBasemapActive: Bool

    init(appState: AppState) {
        self.appState = appState
        officialAlertService = appState.officialAlertService
        mapService = appState.mapService
        mapDataService = appState.mapDataService
        waterPointService = appState.waterPointService
        shelterService = appState.shelterService
        beaconService = appState.beaconService
        locationService = appState.locationService
        resourceCategoryIndex = Dictionary(uniqueKeysWithValues: appState.mapService.resourceCategories.map { ($0.id, $0) })
        resourceDatasetLastUpdated = appState.mapService.lastUpdated
        offlineLayerLastUpdated = appState.mapDataService.lastUpdated
        let basemapConfiguration = appState.offlineBasemapService.configuration
        basemapStyleURL = basemapConfiguration.styleURL
        offlineBasemapStatusMessage = basemapConfiguration.statusMessage
        isPremiumBasemapActive = basemapConfiguration.isPremiumActive
        bundledResources = appState.mapService.bundledResources
        userMarkers = appState.mapService.loadUserMarkers()
        viewportRegion = appState.mapService.fallbackRegion()
        selectedScenarios = appState.profile.selectedScenarios
        savedRoutes = appState.profile.evacuationRoutes.compactMap(\.nilIfBlank)
        enabledLayers = appState.settings.maps.defaultLayers
        surfaceMode = appState.settings.maps.surfaceMode
        isStealthModeEnabled = appState.isStealthModeEnabled
        reducesMapAnimations = appState.settings.battery.reducesMapAnimations || appState.isStealthModeEnabled
        availableLayers = Self.orderedLayers(for: appState.profile.selectedScenarios)
        availablePacks = appState.mapDataService.availablePacks
        installedPackIDs = appState.mapDataService.loadInstalledPackIDs()

        let latestOfflineDate = max(resourceDatasetLastUpdated, offlineLayerLastUpdated)
        let hasAnyOfflineData = appState.mapService.didLoadBundledResources || appState.mapDataService.didLoadOfflineData
        lastUpdatedText = hasAnyOfflineData ? DateFormatter.rediM8MonthYear.string(from: latestOfflineDate) : "Unavailable"
        resourceDataStatusMessage = appState.mapDataService.didLoadOfflineData ? nil : TrustLayer.mapDataUnavailableMessage
        reloadOfflineMapFeatures()
        reloadOfficialAlerts()

        beaconService.$nearbyBeacons
            .assign(to: &$nearbyBeacons)

        beaconService.$activeBeacon
            .assign(to: &$activeBeacon)

        locationService.$currentLocation
            .sink { [weak self] location in
                guard let self else { return }
                self.currentLocation = location
                self.reloadOfflineMapFeatures()
                self.reloadOfficialAlerts()
                guard let coordinate = location?.coordinate else {
                    return
                }
                Task { [weak self] in
                    await self?.refreshNearbyNetworkResources(near: coordinate)
                }
            }
            .store(in: &cancellables)

        locationService.$heading
            .assign(to: &$heading)

        appState.$profile
            .sink { [weak self] profile in
                self?.selectedScenarios = profile.selectedScenarios
                self?.savedRoutes = profile.evacuationRoutes.compactMap(\.nilIfBlank)
                self?.availableLayers = Self.orderedLayers(for: profile.selectedScenarios)
            }
            .store(in: &cancellables)

        appState.$settings
            .sink { [weak self] settings in
                guard let self else { return }
                self.enabledLayers = settings.maps.defaultLayers
                self.surfaceMode = settings.maps.surfaceMode
                self.reducesMapAnimations = settings.battery.reducesMapAnimations || self.isStealthModeEnabled
                if !settings.maps.defaultLayers.contains(.evacuationPoints) {
                    self.selectedShelterID = nil
                }
            }
            .store(in: &cancellables)

        appState.$isStealthModeEnabled
            .sink { [weak self] isEnabled in
                guard let self else { return }
                self.isStealthModeEnabled = isEnabled
                self.reducesMapAnimations = self.appState.settings.battery.reducesMapAnimations || isEnabled
            }
            .store(in: &cancellables)

        officialAlertService.$library
            .sink { [weak self] _ in
                self?.reloadOfficialAlerts()
            }
            .store(in: &cancellables)

        officialAlertService.$lastRefreshError
            .sink { [weak self] _ in
                self?.reloadOfficialAlerts()
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    var allMarkers: [ResourceMarker] {
        bundledResources + userMarkers
    }

    var visibleResourceMarkers: [ResourceMarker] {
        enabledLayers.contains(.resources) ? allMarkers : []
    }

    var visibleDirtRoads: [TrackSegment] {
        enabledLayers.contains(.dirtRoads) ? dirtRoads : []
    }

    var visibleFireTrails: [TrackSegment] {
        enabledLayers.contains(.fireTrails) ? fireTrails : []
    }

    var visibleWaterPoints: [WaterPoint] {
        enabledLayers.contains(.waterPoints) ? waterPoints : []
    }

    var visibleShelters: [ShelterLocation] {
        enabledLayers.contains(.evacuationPoints) ? shelters : []
    }

    var visibleOfficialAlerts: [OfficialAlert] {
        guard enabledLayers.contains(.officialAlerts) else {
            return []
        }
        return nearbyOfficialAlerts.filter(\.isAreaScoped)
    }

    var visibleBeacons: [CommunityBeacon] {
        guard enabledLayers.contains(.communityBeacons) else {
            return []
        }

        var beacons = nearbyBeacons
        if let activeBeacon {
            beacons.removeAll { $0.id == activeBeacon.id }
            beacons.insert(activeBeacon, at: 0)
        }
        return beacons.sorted { lhs, rhs in
            if lhs.id == activeBeacon?.id { return true }
            if rhs.id == activeBeacon?.id { return false }
            if lhs.type.priority != rhs.type.priority {
                return lhs.type.priority < rhs.type.priority
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    var groupedBundledResources: [(MarkerKind, [ResourceMarker])] {
        Dictionary(grouping: bundledResources, by: \.kind)
            .sorted { $0.key.title < $1.key.title }
    }

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
            isPremiumBasemapActive ? "Verified Basemap" : "Tactical Fallback"
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
            return "Verified offline basemap remains ready if service drops or tiles fail."
        }

        return "Switch to Offline Tactical if live tiles stop loading or coverage drops away."
    }

    var mapTrustItems: [TrustPillItem] {
        var items: [TrustPillItem] = [
            TrustPillItem(
                title: surfaceBadgeTitle,
                tone: surfaceMode == .tactical
                    ? (isPremiumBasemapActive ? .verified : .caution)
                    : .info
            ),
            TrustPillItem(title: surfaceMode.usesAppleTiles ? "Network-assisted" : "Offline only", tone: surfaceMode.usesAppleTiles ? .caution : .info),
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

    var mapStatusHeadline: String {
        switch surfaceMode {
        case .liveTiles:
            return "Live tiled map active"
        case .hybrid:
            return "Hybrid tiled map active"
        case .tactical:
            break
        }

        if isPremiumBasemapActive, !installedPacks.isEmpty {
            return "Full offline map pack loaded"
        }

        if isPremiumBasemapActive {
            return "Offline basemap active"
        }

        return "Offline tactical fallback active"
    }

    var mapStatusDetail: String {
        switch surfaceMode {
        case .liveTiles:
            if installedPacks.isEmpty {
                return "Apple road tiles are active for map context. Offline shelters, water, and trails still depend on installed packs or the tactical fallback."
            }
            let packNoun = installedPacks.count == 1 ? "pack" : "packs"
            return "Apple road tiles are active, and \(installedPacks.count) offline \(packNoun) still power shelters, water, and trail overlays."
        case .hybrid:
            if installedPacks.isEmpty {
                return "Hybrid satellite tiles are active for terrain context. Offline shelters, water, and trails still depend on installed packs or the tactical fallback."
            }
            let packNoun = installedPacks.count == 1 ? "pack" : "packs"
            return "Hybrid satellite tiles are active, and \(installedPacks.count) offline \(packNoun) still power shelters, water, and trail overlays."
        case .tactical:
            break
        }

        if isPremiumBasemapActive, !installedPacks.isEmpty {
            let packNoun = installedPacks.count == 1 ? "pack" : "packs"
            return "\(installedPacks.count) regional \(packNoun) ready. Shelters, water, and saved-route references are available offline."
        }

        if isPremiumBasemapActive {
            return "Verified cartography is available, but local resource coverage still depends on installed packs."
        }

        return "Verified road maps unavailable. RediM8 is showing shelters, water, pack boundaries, and saved references only."
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

    var workingBasemapSummary: String {
        switch surfaceMode {
        case .liveTiles:
            return "Apple road tiles are active for live route and place context."
        case .hybrid:
            return "Apple hybrid tiles are active for satellite terrain and landmark context."
        case .tactical:
            return isPremiumBasemapActive
                ? "Premium offline basemap is active."
                : "A tactical fallback surface is active. It shows offline packs, tracks, shelters, water, and markers, but not full road or topographic cartography."
        }
    }

    var basemapOperationalValue: String {
        switch surfaceMode {
        case .liveTiles:
            return "Tiles"
        case .hybrid:
            return "Hybrid"
        case .tactical:
            return isPremiumBasemapActive ? "Verified" : "Fallback"
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
        currentLocation == nil
            ? "No live position right now. Distances fall back to offline reference mode."
            : "Live position and heading are available for recentering and distance estimates."
    }

    var workingMotionSummary: String {
        reducesMapAnimations
            ? "Reduced-motion map path is active for stress and battery protection."
            : "Standard map motion is active."
    }

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
            return topOfficialAlert.isAreaScoped ? topOfficialAlert.severity.title : "Jurisdiction feed"
        }
        if currentLocation == nil, installedPacks.isEmpty, officialAlertService.hasCachedData {
            return "Scope needed"
        }
        return officialAlertService.hasCachedData ? "Clear" : "Unavailable"
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

    var savedRouteSummary: String {
        guard let firstRoute = savedRoutes.first else {
            return "No saved evacuation route yet. RediM8 can still show shelters and water offline, but route choice becomes manual."
        }

        if savedRoutes.count == 1 {
            return "Primary saved route: \(firstRoute)"
        }

        return "Primary saved route: \(firstRoute) • \(savedRoutes.count - 1) backup route(s) also saved."
    }

    var savedRouteTrustItems: [TrustPillItem] {
        [
            TrustPillItem(title: "Saved in Plan", tone: .info),
            TrustPillItem(title: "Offline only", tone: .info),
            TrustPillItem(title: "Last updated unknown", tone: .caution)
        ]
    }

    var locationFailureSummary: String {
        currentLocation == nil
            ? "Location unavailable. Use saved routes, shelter names, and visible landmarks until GPS returns."
            : "Live location is available."
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

    var featuredDirtRoads: [TrackSegment] {
        visibleDirtRoads.sorted { lhs, rhs in
            distance(to: lhs.midpoint) < distance(to: rhs.midpoint)
        }
    }

    var featuredFireTrails: [TrackSegment] {
        visibleFireTrails.sorted { lhs, rhs in
            distance(to: lhs.midpoint) < distance(to: rhs.midpoint)
        }
    }

    var featuredWaterPoints: [WaterPoint] {
        visibleWaterPoints.sorted { lhs, rhs in
            distance(to: lhs.location) < distance(to: rhs.location)
        }
    }

    var featuredShelters: [ShelterLocation] {
        let scenarioSet = Set(selectedScenarios)

        return visibleShelters.sorted { lhs, rhs in
            let lhsPriority = shelterPriority(for: lhs.type, scenarios: scenarioSet)
            let rhsPriority = shelterPriority(for: rhs.type, scenarios: scenarioSet)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            let lhsDistance = distance(to: lhs.coordinate)
            let rhsDistance = distance(to: rhs.coordinate)
            if lhsDistance == rhsDistance {
                return lhs.name < rhs.name
            }
            return lhsDistance < rhsDistance
        }
    }

    var selectedShelter: ShelterLocation? {
        guard enabledLayers.contains(.evacuationPoints), let selectedShelterID else {
            return nil
        }
        return shelters.first { $0.id == selectedShelterID }
    }

    var shelterPrioritySummary: String? {
        let scenarios = Set(selectedScenarios)
        if scenarios.contains(.cyclones) {
            return "Cyclone shelters and community shelters are ranked first for your selected scenarios."
        }
        if scenarios.contains(.bushfires) {
            return "Bushfire Mode prioritises fire trails, water points, and evacuation points for rapid route review."
        }
        return nil
    }

    var bushfireMapSummary: String? {
        guard isBushfireModeEnabled else {
            return nil
        }
        return "Fire trails, water points, shelters, and evacuation points are surfaced first while Bushfire Mode is active."
    }

    var distanceRingLabels: [String] {
        ["10 km", "25 km", "50 km"]
    }

    func onAppear() {
        beaconService.startMonitoring()
        locationService.start()
        recenter()
        Task {
            await officialAlertService.refreshIfNeeded()
        }
    }

    func onDisappear() {
        beaconService.stopMonitoring()
        locationService.stop()
    }

    func recenter() {
        viewportRegion = preferredRegion()
        viewportRevision += 1
    }

    func addCurrentLocationMarker() {
        guard let coordinate = locationService.currentLocation?.coordinate else { return }
        let title = markerTitle.nilIfBlank ?? selectedMarkerKind.title
        let marker = ResourceMarker(
            title: title,
            subtitle: "Saved on device",
            kind: selectedMarkerKind,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            detail: "User-created marker for offline reference.",
            source: "Personal marker",
            isUserGenerated: true
        )
        userMarkers.insert(marker, at: 0)
        mapService.saveUserMarkers(userMarkers)
        markerTitle = ""
    }

    func deleteMarker(_ markerID: UUID) {
        userMarkers.removeAll { $0.id == markerID }
        mapService.saveUserMarkers(userMarkers)
    }

    func isLayerEnabled(_ layer: MapLayer) -> Bool {
        enabledLayers.contains(layer)
    }

    func setLayer(_ layer: MapLayer, isEnabled: Bool) {
        appState.setMapLayer(layer, isEnabled: isEnabled)
        if !isEnabled, layer == .evacuationPoints {
            selectedShelterID = nil
        }
    }

    func setSurfaceMode(_ mode: MapSurfaceMode) {
        appState.mutateSettings { settings in
            settings.maps.surfaceMode = mode
        }
    }

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
        recenter()
    }

    func focus(onPackID packID: String) {
        guard let pack = mapDataService.pack(withID: packID) else {
            return
        }

        viewportRegion = MKCoordinateRegion(
            center: pack.center.coordinate,
            span: MKCoordinateSpan(latitudeDelta: pack.latitudeDelta, longitudeDelta: pack.longitudeDelta)
        )
        viewportRevision += 1
    }

    func symbolName(for kind: MarkerKind) -> String {
        if let id = kind.resourceCategoryID, let category = resourceCategoryIndex[id] {
            return category.icon
        }
        return kind.defaultSymbolName
    }

    func tint(for kind: MarkerKind) -> Color {
        if let id = kind.resourceCategoryID, let category = resourceCategoryIndex[id] {
            return Color(hex: category.color)
        }
        return kind.tint
    }

    func categoryDescription(for kind: MarkerKind) -> String? {
        guard let id = kind.resourceCategoryID else {
            return nil
        }
        return resourceCategoryIndex[id]?.description
    }

    func resourceTrustItems(for marker: ResourceMarker) -> [TrustPillItem] {
        if marker.isUserGenerated {
            return [
                TrustPillItem(title: "Personal marker", tone: .info),
                TrustPillItem(title: "Offline only", tone: .info)
            ]
        }

        return [
            TrustPillItem(title: "Verified", tone: .verified),
            TrustPillItem(title: "Offline only", tone: .info),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: resourceDatasetLastUpdated), tone: .neutral)
        ]
    }

    func shelterTrustItems(for shelter: ShelterLocation) -> [TrustPillItem] {
        var items = [
            TrustPillItem(title: sourceKindLabel(for: shelter.sourceKind), tone: sourceKindTone(for: shelter.sourceKind)),
            TrustPillItem(title: availabilityLabel(for: shelter.availability), tone: availabilityTone(for: shelter.availability)),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: freshnessDate(for: shelter)), tone: .neutral)
        ]
        if shelter.availability == .networkNearby {
            items.append(TrustPillItem(title: "Confirm activation", tone: .caution))
        }
        return items
    }

    func waterTrustItems(for point: WaterPoint) -> [TrustPillItem] {
        var items = [
            TrustPillItem(title: sourceKindLabel(for: point.sourceKind), tone: sourceKindTone(for: point.sourceKind)),
            TrustPillItem(title: availabilityLabel(for: point.availability), tone: availabilityTone(for: point.availability)),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: freshnessDate(for: point)), tone: .neutral)
        ]
        if point.availability == .networkNearby {
            items.append(TrustPillItem(title: "Review on site", tone: .caution))
        }
        return items
    }

    func trackTrustItems(for track: TrackSegment) -> [TrustPillItem] {
        [
            TrustPillItem(title: "Verified", tone: .verified),
            TrustPillItem(title: "Offline only", tone: .info),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: freshnessDate(forPackIDs: track.packIDs)), tone: .neutral)
        ]
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

    func beaconTint(for type: BeaconType) -> Color {
        switch type.tone {
        case .safe:
            ColorTheme.ready
        case .resource:
            ColorTheme.info
        case .help:
            ColorTheme.danger
        case .hazard:
            ColorTheme.warning
        }
    }

    func beaconDistanceText(for beacon: CommunityBeacon) -> String {
        beaconService.distanceText(for: beacon)
    }

    func beaconTrustItems(for beacon: CommunityBeacon) -> [TrustPillItem] {
        var items = [
            TrustPillItem(title: "Community-reported", tone: .caution),
            TrustPillItem(title: "Not verified", tone: .danger),
            TrustPillItem(title: beacon.relayTrustLabel, tone: beacon.isRelayed ? .caution : .info),
            TrustPillItem(title: "Approximate", tone: .caution),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: beacon.updatedAt), tone: .neutral)
        ]
        if beacon.sharedEmergencyMedicalSummary != nil {
            items.insert(TrustPillItem(title: "Medical note shared", tone: .info), at: 3)
        }
        return items
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

    func beaconStaleWarning(for beacon: CommunityBeacon) -> String? {
        guard Date().timeIntervalSince(beacon.updatedAt) >= beacon.type.staleAfter else {
            return nil
        }

        return "Stale report. Treat this as last known information until you confirm it."
    }

    func shelterTint(for type: ShelterType) -> Color {
        switch type {
        case .evacuationCentre:
            ColorTheme.ready
        case .communityShelter:
            ColorTheme.info
        case .cycloneShelter:
            ColorTheme.warning
        case .temporaryReliefCentre:
            ColorTheme.warning
        case .publicAssemblyPoint:
            ColorTheme.info
        }
    }

    func selectShelter(withID shelterID: String?) {
        guard let shelterID else {
            selectedShelterID = nil
            return
        }

        selectedShelterID = shelters.contains(where: { $0.id == shelterID }) ? shelterID : nil
    }

    func shelterNavigationURL(for shelter: ShelterLocation) -> URL? {
        var components = URLComponents(string: "http://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: "\(shelter.latitude),\(shelter.longitude)"),
            URLQueryItem(name: "dirflg", value: "d"),
            URLQueryItem(name: "q", value: shelter.name)
        ]
        return components?.url
    }

    func waterPriorityHeading(for point: WaterPoint) -> String {
        point.availability == .networkNearby ? "NEAREST LIVE WATER SOURCE" : "NEAREST OFFLINE WATER POINT"
    }

    func waterReferenceLabel(for point: WaterPoint) -> String {
        point.availability == .networkNearby ? "live nearby distance" : "installed-pack distance"
    }

    func waterDistanceText(for point: WaterPoint) -> String {
        distanceText(to: point.location)
    }

    func shelterDistanceText(for shelter: ShelterLocation) -> String {
        distanceText(to: shelter.coordinate)
    }

    func distanceText(to coordinate: CLLocationCoordinate2D) -> String {
        let metres = distance(to: coordinate)
        guard metres.isFinite else {
            return "Offline reference"
        }
        if metres >= 1000 {
            return String(format: "%.1f km", metres / 1000)
        }
        return "\(Int(metres.rounded())) m"
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

    private var officialCoverageTrustLabel: String {
        officialAlertService.cachedJurisdictions.count == AustralianJurisdiction.allCases.count
            ? "Australia-wide"
            : officialCoverageSummary
    }

    private var officialCoverageSummary: String {
        let count = officialAlertService.cachedJurisdictions.count
        if count == AustralianJurisdiction.allCases.count {
            return "Australia-wide"
        }
        if count == 1, let jurisdiction = officialAlertService.cachedJurisdictions.first {
            return jurisdiction.title
        }
        return "\(count) jurisdictions"
    }

    func trackSafetyColor(for label: TrackSafetyLabel) -> Color {
        switch label {
        case .emergencyVehicleRoute:
            ColorTheme.info
        case .fourWheelDriveOnly, .seasonalAccess:
            ColorTheme.warning
        case .unmaintainedTrack, .confirmLocalAccess:
            ColorTheme.danger
        }
    }

    var headingText: String {
        Self.headingText(from: heading)
    }

    private func reloadOfflineMapFeatures() {
        offlineLayerLastUpdated = mapDataService.lastUpdated
        dirtRoads = mapDataService.dirtRoads(for: installedPackIDs)
        fireTrails = mapDataService.fireTrails(for: installedPackIDs)
        waterPoints = mapDataService.waterPoints(for: installedPackIDs, near: currentLocation?.coordinate)
        shelters = mapDataService.shelters(for: installedPackIDs, near: currentLocation?.coordinate)
        refreshLastUpdatedText()
        if let selectedShelterID, !shelters.contains(where: { $0.id == selectedShelterID }) {
            self.selectedShelterID = nil
        }
    }

    @MainActor
    private func refreshNearbyNetworkResources(near coordinate: CLLocationCoordinate2D) async {
        async let waterRefresh = waterPointService.refreshNearbyNetworkData(near: coordinate)
        async let shelterRefresh = shelterService.refreshNearbyNetworkData(near: coordinate)
        _ = await (waterRefresh, shelterRefresh)
        reloadOfflineMapFeatures()
    }

    private func reloadOfficialAlerts() {
        nearbyOfficialAlerts = officialAlertService.nearbyAlerts(
            currentLocation: currentLocation,
            installedPacks: installedPacks
        )
    }

    private func preferredRegion() -> MKCoordinateRegion {
        if let location = currentLocation {
            return MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            )
        }
        if let firstInstalledPack = installedPacks.first {
            return MKCoordinateRegion(
                center: firstInstalledPack.center.coordinate,
                span: MKCoordinateSpan(latitudeDelta: firstInstalledPack.latitudeDelta, longitudeDelta: firstInstalledPack.longitudeDelta)
            )
        }
        return mapService.fallbackRegion()
    }

    private func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        guard let currentLocation else {
            return .infinity
        }
        return currentLocation.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    private func refreshLastUpdatedText() {
        let latestOfflineDate = max(resourceDatasetLastUpdated, offlineLayerLastUpdated)
        let hasAnyOfflineData = mapService.didLoadBundledResources || mapDataService.didLoadOfflineData
        lastUpdatedText = hasAnyOfflineData ? DateFormatter.rediM8MonthYear.string(from: latestOfflineDate) : "Unavailable"
    }

    private func freshnessDate(for point: WaterPoint) -> Date {
        point.lastUpdated ?? freshnessDate(forPackIDs: point.packIDs)
    }

    private func freshnessDate(for shelter: ShelterLocation) -> Date {
        shelter.lastUpdated ?? freshnessDate(forPackIDs: shelter.packIDs)
    }

    private func freshnessDate(forPackIDs packIDs: [String]) -> Date {
        let requestedPackIDs = Set(packIDs)
        if let packDate = availablePacks.first(where: { !requestedPackIDs.isDisjoint(with: [$0.id]) })?.lastUpdated {
            return max(offlineLayerLastUpdated, packDate)
        }
        return offlineLayerLastUpdated
    }

    private func availabilityLabel(for availability: MapFeatureAvailability) -> String {
        switch availability {
        case .offlinePack:
            "Offline pack"
        case .networkNearby:
            "Network nearby"
        }
    }

    private func availabilityTone(for availability: MapFeatureAvailability) -> TrustPillTone {
        switch availability {
        case .offlinePack:
            .info
        case .networkNearby:
            .caution
        }
    }

    private func sourceKindLabel(for sourceKind: MapFeatureSourceKind) -> String {
        switch sourceKind {
        case .curatedBundle:
            "Curated bundle"
        case .baselineFacility:
            "Baseline facility"
        case .openMapData:
            "Open map data"
        case .official:
            "Official"
        }
    }

    private func sourceKindTone(for sourceKind: MapFeatureSourceKind) -> TrustPillTone {
        switch sourceKind {
        case .curatedBundle, .official:
            .verified
        case .baselineFacility:
            .info
        case .openMapData:
            .caution
        }
    }

    private func shelterPriority(for type: ShelterType, scenarios: Set<ScenarioKind>) -> Int {
        if scenarios.contains(.cyclones) {
            switch type {
            case .cycloneShelter:
                return 0
            case .communityShelter:
                return 1
            case .evacuationCentre:
                return 2
            case .temporaryReliefCentre:
                return 3
            case .publicAssemblyPoint:
                return 4
            }
        }

        return 0
    }

    private static func orderedLayers(for scenarios: [ScenarioKind]) -> [MapLayer] {
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

    private static func headingText(from value: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]
        let index = Int((value / 45.0).rounded()) % 8
        return "\(Int(value.rounded()))° \(directions[index])"
    }
}
