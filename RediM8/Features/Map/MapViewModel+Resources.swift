import CoreLocation
import Foundation
import SwiftUI

// MARK: - Resources, Shelters, Water, Tracks & Beacons

extension MapViewModel {
    // MARK: - Resource Markers

    var allMarkers: [ResourceMarker] {
        bundledResources + userMarkers
    }

    var visibleResourceMarkers: [ResourceMarker] {
        enabledLayers.contains(.resources) ? allMarkers : []
    }

    var groupedBundledResources: [(MarkerKind, [ResourceMarker])] {
        Dictionary(grouping: bundledResources, by: \.kind)
            .sorted { $0.key.title < $1.key.title }
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

    // MARK: - Tracks

    var visibleDirtRoads: [TrackSegment] {
        enabledLayers.contains(.dirtRoads) ? dirtRoads : []
    }

    var visibleFireTrails: [TrackSegment] {
        enabledLayers.contains(.fireTrails) ? fireTrails : []
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

    func trackTrustItems(for track: TrackSegment) -> [TrustPillItem] {
        [
            TrustPillItem(title: "Verified", tone: .verified),
            TrustPillItem(title: "Offline only", tone: .info),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: freshnessDate(forPackIDs: track.packIDs)), tone: .neutral)
        ]
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

    // MARK: - Water Points

    var visibleWaterPoints: [WaterPoint] {
        enabledLayers.contains(.waterPoints) ? waterPoints : []
    }

    var featuredWaterPoints: [WaterPoint] {
        visibleWaterPoints.sorted { lhs, rhs in
            distance(to: lhs.location) < distance(to: rhs.location)
        }
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

    func waterPriorityHeading(for point: WaterPoint) -> String {
        point.availability == .networkNearby ? "NEAREST LIVE WATER SOURCE" : "NEAREST OFFLINE WATER POINT"
    }

    func waterReferenceLabel(for point: WaterPoint) -> String {
        point.availability == .networkNearby ? "live nearby distance" : "installed-pack distance"
    }

    func waterDistanceText(for point: WaterPoint) -> String {
        distanceText(to: point.location)
    }

    // MARK: - Shelters

    var visibleShelters: [ShelterLocation] {
        enabledLayers.contains(.evacuationPoints) ? shelters : []
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

    func shelterDistanceText(for shelter: ShelterLocation) -> String {
        distanceText(to: shelter.coordinate)
    }

    // MARK: - Beacons

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
            if lhs.severity.rank != rhs.severity.rank {
                return lhs.severity.rank > rhs.severity.rank
            }
            return lhs.updatedAt > rhs.updatedAt
        }
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
            TrustPillItem(title: beacon.severity.badgeTitle, tone: severityTone(for: beacon.severity)),
            TrustPillItem(title: beacon.confidence.badgeTitle, tone: confidenceTone(for: beacon.confidence)),
            TrustPillItem(title: beacon.relayTrustLabel, tone: beacon.isRelayed ? .caution : .info),
            TrustPillItem(title: "Approximate", tone: .caution),
            TrustPillItem(title: TrustLayer.freshnessLabel(for: beacon.updatedAt), tone: .neutral)
        ]
        if beacon.sharedEmergencyMedicalSummary != nil {
            items.insert(TrustPillItem(title: "Medical note shared", tone: .info), at: 4)
        }
        return items
    }

    func beaconStaleWarning(for beacon: CommunityBeacon) -> String? {
        guard Date().timeIntervalSince(beacon.updatedAt) >= beacon.type.staleAfter else {
            return nil
        }

        return "Stale report. Treat this as last known information until you confirm it."
    }

    // MARK: - Routes & Heading

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

    var headingText: String {
        Self.headingText(from: heading)
    }

    internal static func headingText(from value: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]
        let index = Int((value / 45.0).rounded()) % 8
        return "\(Int(value.rounded()))° \(directions[index])"
    }

    // MARK: - Internal Helpers

    internal func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        guard let currentLocation else {
            return .infinity
        }
        return currentLocation.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
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

    internal func freshnessDate(for point: WaterPoint) -> Date {
        point.lastUpdated ?? freshnessDate(forPackIDs: point.packIDs)
    }

    internal func freshnessDate(for shelter: ShelterLocation) -> Date {
        shelter.lastUpdated ?? freshnessDate(forPackIDs: shelter.packIDs)
    }

    internal func freshnessDate(forPackIDs packIDs: [String]) -> Date {
        let requestedPackIDs = Set(packIDs)
        if let packDate = availablePacks.first(where: { !requestedPackIDs.isDisjoint(with: [$0.id]) })?.lastUpdated {
            return max(offlineLayerLastUpdated, packDate)
        }
        return offlineLayerLastUpdated
    }

    internal func availabilityLabel(for availability: MapFeatureAvailability) -> String {
        switch availability {
        case .offlinePack:
            "Offline pack"
        case .networkNearby:
            "Network nearby"
        }
    }

    internal func availabilityTone(for availability: MapFeatureAvailability) -> TrustPillTone {
        switch availability {
        case .offlinePack:
            .info
        case .networkNearby:
            .caution
        }
    }

    internal func sourceKindLabel(for sourceKind: MapFeatureSourceKind) -> String {
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

    internal func sourceKindTone(for sourceKind: MapFeatureSourceKind) -> TrustPillTone {
        switch sourceKind {
        case .curatedBundle, .official:
            .verified
        case .baselineFacility:
            .info
        case .openMapData:
            .caution
        }
    }

    internal func shelterPriority(for type: ShelterType, scenarios: Set<ScenarioKind>) -> Int {
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

    internal func severityTone(for severity: BeaconSeverity) -> TrustPillTone {
        switch severity {
        case .low:
            .neutral
        case .moderate:
            .info
        case .high:
            .caution
        case .critical:
            .danger
        }
    }

    internal func confidenceTone(for confidence: BeaconConfidence) -> TrustPillTone {
        switch confidence {
        case .low:
            .danger
        case .medium:
            .caution
        case .high:
            .verified
        }
    }

    @MainActor
    internal func refreshNearbyNetworkResources(near coordinate: CLLocationCoordinate2D) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        async let waterRefresh = waterPointService.refreshNearbyNetworkData(near: coordinate)
        async let shelterRefresh = shelterService.refreshNearbyNetworkData(near: coordinate)
        _ = await (waterRefresh, shelterRefresh)
        reloadOfflineMapFeatures(useBackgroundQueue: true)
        let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        let installedPackCount = installedPackIDs.count
        let waterPointCount = waterPoints.count
        let shelterCount = shelters.count
        RediLogger.performance.debug(
            "Nearby map resources refreshed in \(elapsed, privacy: .public) ms (\(installedPackCount, privacy: .public) packs, \(waterPointCount, privacy: .public) water points, \(shelterCount, privacy: .public) shelters)"
        )
    }
}
