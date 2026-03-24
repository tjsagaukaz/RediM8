import CoreLocation
import Foundation
import Network

@MainActor
final class AssistantNetworkStatusService: ObservableObject {
    @Published private(set) var isOffline = false

    private nonisolated let monitor: NWPathMonitor
    private nonisolated let queue = DispatchQueue(label: "au.com.redim8.assistant.network")

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOffline = path.status != .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    nonisolated deinit {
        monitor.cancel()
    }
}

@MainActor
protocol AssistantContextProviding {
    func contextPayload(
        for query: String,
        classification: AssistantIntentClassification
    ) -> AssistantContextPayload
}

extension AssistantContextProviding {
    func contextSections(
        for query: String,
        classification: AssistantIntentClassification
    ) -> [AssistantContextSection] {
        contextPayload(for: query, classification: classification).sections
    }
}

@MainActor
final class AssistantContextEnricher: AssistantContextProviding {
    private let waterPointService: WaterPointService
    private let shelterService: ShelterService
    private let fireTrailService: FireTrailService
    private let officialAlertService: OfficialAlertService
    private let beaconService: BeaconService
    private let mapDataService: MapDataService
    private let locationProvider: () -> CLLocation?
    private let survivalContextService: SurvivalContextService?
    private let isOfflineProvider: () -> Bool

    private var cachedResult: CachedContext?

    private struct CachedContext {
        let query: String
        let topic: AssistantIntentTopic
        let payload: AssistantContextPayload
        let builtAt: Date

        var isValid: Bool {
            Date().timeIntervalSince(builtAt) < 30
        }
    }

    init(
        waterPointService: WaterPointService,
        shelterService: ShelterService,
        fireTrailService: FireTrailService,
        officialAlertService: OfficialAlertService,
        beaconService: BeaconService,
        mapDataService: MapDataService,
        locationProvider: @escaping () -> CLLocation?,
        survivalContextService: SurvivalContextService? = nil,
        isOfflineProvider: @escaping () -> Bool = { false }
    ) {
        self.waterPointService = waterPointService
        self.shelterService = shelterService
        self.fireTrailService = fireTrailService
        self.officialAlertService = officialAlertService
        self.beaconService = beaconService
        self.mapDataService = mapDataService
        self.locationProvider = locationProvider
        self.survivalContextService = survivalContextService
        self.isOfflineProvider = isOfflineProvider
    }

    func contextPayload(
        for query: String,
        classification: AssistantIntentClassification
    ) -> AssistantContextPayload {
        if let cached = cachedResult,
           cached.isValid,
           cached.query == query,
           cached.topic == classification.topic {
            return cached.payload
        }

        let payload = buildContextPayload(for: query, classification: classification)

        cachedResult = CachedContext(
            query: query,
            topic: classification.topic,
            payload: payload,
            builtAt: .now
        )

        return payload
    }

    private func buildContextPayload(
        for query: String,
        classification: AssistantIntentClassification
    ) -> AssistantContextPayload {
        let normalizedQuery = AssistantIntentClassifier.normalize(query)
        let queryTokens = Set(normalizedQuery.split(separator: " ").map(String.init))
        let currentLocation = locationProvider()
        let installedPackIDs = mapDataService.loadInstalledPackIDs()
        let installedPacks = mapDataService.packs(withIDs: installedPackIDs)
        let isEvacuationQuery = wantsEvacuationContext(tokens: queryTokens, classification: classification)
        let nearbyAlerts = officialAlertService.nearbyAlerts(
            currentLocation: currentLocation,
            installedPacks: installedPacks
        )
        let topAlert = nearbyAlerts.first
        let survivalState = survivalContextService?.computeState()
        let profileSnapshot = survivalContextService?.profileSnapshot()
        let snapshot = buildSituationSnapshot(
            classification: classification,
            currentLocation: currentLocation,
            topAlert: topAlert,
            survivalState: survivalState,
            profileSnapshot: profileSnapshot
        )

        var sections: [AssistantContextSection] = []

        // --- Hazard warnings always come first ---
        if wantsAlertContext(tokens: queryTokens, classification: classification) {
            if !nearbyAlerts.isEmpty {
                sections.append(alertSection(from: nearbyAlerts, isEvacuation: isEvacuationQuery))
            }
        }

        // --- Hazard beacons (community reports of danger) ---
        let hazardBeacons = nearbyHazardBeacons(limit: 5)
        if !hazardBeacons.isEmpty && wantsHazardBeaconContext(tokens: queryTokens, classification: classification) {
            sections.append(hazardBeaconSection(from: hazardBeacons))
        }

        // --- Shelter context ---
        if wantsShelterContext(tokens: queryTokens, classification: classification) || isEvacuationQuery {
            if let coordinate = currentLocation?.coordinate {
                let shelters = shelterService.nearbyShelters(
                    near: coordinate,
                    installedPackIDs: installedPackIDs,
                    limit: 5
                )
                if !shelters.isEmpty {
                    sections.append(shelterSection(from: shelters))
                }
            } else {
                sections.append(locationNeededSection(
                    title: "Shelter Nearby",
                    detail: "Allow location to rank nearby shelters, evacuation centres, and assembly points."
                ))
            }
        }

        // --- Fire trail / evacuation route context ---
        if wantsFireTrailContext(tokens: queryTokens, classification: classification) {
            let trails = fireTrailService.fireTrails(for: installedPackIDs)
            if !trails.isEmpty {
                sections.append(fireTrailSection(trailCount: trails.count))
            }
        }

        // --- Water context ---
        if wantsWaterContext(tokens: queryTokens, classification: classification) {
            if let coordinate = currentLocation?.coordinate {
                let waters = waterPointService.nearbyWaterPoints(
                    near: coordinate,
                    installedPackIDs: installedPackIDs,
                    limit: 5
                )
                if !waters.isEmpty {
                    sections.append(waterSection(from: waters))
                }
            } else {
                sections.append(locationNeededSection(
                    title: "Water Nearby",
                    detail: "Allow location to sort nearby taps, tanks, creeks, and other offline water references."
                ))
            }
        }

        // --- Community beacon resource context (non-hazard) ---
        if wantsResourceBeaconContext(tokens: queryTokens, classification: classification) {
            let resourceBeacons = nearbyResourceBeacons(limit: 5)
            if !resourceBeacons.isEmpty {
                sections.append(beaconSection(from: resourceBeacons))
            }
        }

        // --- Proactive survival context (state-aware) ---
        if let survivalContextService, let survivalState {
            let survivalSections = survivalContextService.contextSections(for: survivalState)

            // Only inject survival sections that don't duplicate already-shown categories.
            let existingIDs = Set(sections.map(\.id))
            for section in survivalSections where !existingIDs.contains(section.id) {
                // Don't inject water survival warning if we already showed nearby water sources.
                if section.id == "survival-water" && existingIDs.contains("nearby-water") { continue }
                // Don't inject shelter survival warning if we already showed nearby shelters.
                if section.id == "survival-shelter" && existingIDs.contains("nearby-shelters") { continue }
                sections.append(section)
            }
        }

        return AssistantContextPayload(
            sections: sections,
            snapshot: snapshot,
            status: buildAdvisorContextStatus(
                classification: classification,
                queryTokens: queryTokens,
                snapshot: snapshot
            )
        )
    }

    // MARK: - Section Builders

    private func alertSection(from alerts: [OfficialAlert], isEvacuation: Bool) -> AssistantContextSection {
        let topAlert = alerts[0]
        let items = alerts.prefix(3).map { alert in
            AssistantContextItem(
                title: alert.title,
                detail: "\(alert.severity.title) • \(alert.regionScope)",
                caption: "Updated \(alert.lastUpdated.rediM8FreshnessLabel())",
                actions: [.openMap]
            )
        }

        let detail: String
        if isEvacuation && topAlert.severity == .emergencyWarning {
            detail = "\(topAlert.kind.title) emergency warning active. Evacuation recommended. Follow official warnings and leave early if safe to do so."
        } else if isEvacuation {
            detail = "\(topAlert.kind.title) alerts are active nearby. Check evacuation routes and be ready to leave."
        } else {
            detail = "\(topAlert.kind.title) alerts are active nearby. Follow official warnings first."
        }

        return AssistantContextSection(
            id: "official-alerts",
            title: isEvacuation ? "Hazard Alert" : "Current Alerts",
            detail: detail,
            tone: topAlert.severity == .emergencyWarning ? .danger : .warning,
            items: Array(items),
            isHazardWarning: topAlert.severity == .emergencyWarning || topAlert.severity == .watchAndAct
        )
    }

    private func waterSection(from waters: [NearbyWaterPoint]) -> AssistantContextSection {
        let items = waters.map { point in
            AssistantContextItem(
                title: point.point.name,
                detail: "\(point.point.kind.title) • \(point.distanceText)",
                caption: "\(point.point.quality.title) • \(point.point.source)",
                actions: [
                    .navigateToCoordinate(
                        latitude: point.point.coordinate.latitude,
                        longitude: point.point.coordinate.longitude,
                        label: point.point.name
                    ),
                    .openMap
                ]
            )
        }

        return AssistantContextSection(
            id: "nearby-water",
            title: "Water Nearby",
            detail: "Nearby sources can help, but water still needs safe treatment before drinking.",
            tone: .info,
            items: items
        )
    }

    private func shelterSection(from shelters: [NearbyShelter]) -> AssistantContextSection {
        let items = shelters.map { shelter in
            let capacityLine = shelter.shelter.capacity.map { "Capacity \($0)" } ?? "Capacity unknown"
            return AssistantContextItem(
                title: shelter.shelter.name,
                detail: "\(shelter.shelter.type.title) • \(shelter.distanceText)",
                caption: "\(capacityLine) • Confirm activation before travel",
                actions: [
                    .navigateToCoordinate(
                        latitude: shelter.shelter.latitude,
                        longitude: shelter.shelter.longitude,
                        label: shelter.shelter.name
                    ),
                    .openMap
                ]
            )
        }

        return AssistantContextSection(
            id: "nearby-shelters",
            title: "Shelter Nearby",
            detail: "Use these as nearby shelter references, then confirm official activation if conditions are changing.",
            tone: .ready,
            items: items
        )
    }

    private func fireTrailSection(trailCount: Int) -> AssistantContextSection {
        AssistantContextSection(
            id: "fire-trails",
            title: "Fire Trails Available",
            detail: "\(trailCount) fire access trail\(trailCount == 1 ? "" : "s") loaded from installed offline packs. Open the map to view routes.",
            tone: .info,
            items: [
                AssistantContextItem(
                    title: "View Fire Trails on Map",
                    detail: "Fire access trails can serve as evacuation or access routes in rural areas.",
                    actions: [.openMap]
                )
            ]
        )
    }

    private func hazardBeaconSection(from beacons: [CommunityBeacon]) -> AssistantContextSection {
        let items = beacons.map { beacon in
            AssistantContextItem(
                title: beacon.statusText,
                detail: "\(beacon.type.title) • \(beacon.locationName)",
                caption: "\(beacon.relayTrustLabel) • \(beacon.updatedAt.rediM8FreshnessLabel())",
                actions: [
                    .navigateToCoordinate(
                        latitude: beacon.latitude,
                        longitude: beacon.longitude,
                        label: beacon.statusText
                    )
                ]
            )
        }

        return AssistantContextSection(
            id: "hazard-signals",
            title: "Nearby Hazard Reports",
            detail: "Community-reported hazards nearby. These are assistive only and may be delayed if relayed.",
            tone: .danger,
            items: items,
            isHazardWarning: true
        )
    }

    private func beaconSection(from beacons: [CommunityBeacon]) -> AssistantContextSection {
        let items = beacons.map { beacon in
            AssistantContextItem(
                title: beacon.statusText,
                detail: "\(beacon.type.title) • \(beacon.locationName)",
                caption: "\(beacon.relayTrustLabel) • \(beacon.updatedAt.rediM8FreshnessLabel())",
                actions: [
                    .navigateToCoordinate(
                        latitude: beacon.latitude,
                        longitude: beacon.longitude,
                        label: beacon.statusText
                    )
                ]
            )
        }

        return AssistantContextSection(
            id: "community-signals",
            title: "Community Signals",
            detail: "Nearby reports are assistive only and may be delayed if relayed across other devices.",
            tone: .warning,
            items: items
        )
    }

    private func locationNeededSection(title: String, detail: String) -> AssistantContextSection {
        AssistantContextSection(
            id: "location-needed-\(title)",
            title: title,
            detail: detail,
            tone: .neutral,
            items: []
        )
    }

    private func buildSituationSnapshot(
        classification: AssistantIntentClassification,
        currentLocation: CLLocation?,
        topAlert: OfficialAlert?,
        survivalState: SurvivalContextState?,
        profileSnapshot: SurvivalProfileSnapshot?
    ) -> AssistantSituationSnapshot {
        let proximity = alertProximity(for: topAlert, currentLocation: currentLocation)
        let hazard = topAlert?.kind ?? inferredHazard(from: classification.topic)
        let severity = topAlert?.severity
        let hasDependents = profileSnapshot?.hasDependents ?? false
        let routeStatus = inferredRouteStatus(
            classification: classification,
            severity: severity,
            hasSavedRoutes: profileSnapshot?.hasSavedRoutes ?? false
        )

        return AssistantSituationSnapshot(
            hazard: hazard,
            severity: severity,
            proximity: proximity,
            mode: inferredMode(
                classification: classification,
                severity: severity,
                proximity: proximity,
                survivalState: survivalState
            ),
            routeStatus: routeStatus,
            lastSyncMinutes: lastOfficialAlertSyncMinutes(),
            hasDependents: hasDependents
        )
    }

    private func buildAdvisorContextStatus(
        classification: AssistantIntentClassification,
        queryTokens: Set<String>,
        snapshot: AssistantSituationSnapshot?
    ) -> AdvisorContextStatus {
        let isOffline = isOfflineProvider()

        guard usesAlertDrivenStatus(
            tokens: queryTokens,
            classification: classification,
            snapshot: snapshot
        ) else {
            return AdvisorContextStatus(
                source: .generalGuidance,
                freshnessMinutes: nil,
                isOffline: isOffline,
                hazard: nil,
                routeStatus: nil
            )
        }

        let freshnessMinutes = snapshot?.lastSyncMinutes
        let staleThresholdMinutes = 30
        let source: AdvisorContextSource

        if isOffline || freshnessMinutes.map({ $0 > staleThresholdMinutes }) ?? true {
            source = .lastSyncedAlerts
        } else {
            source = .officialAlerts
        }

        return AdvisorContextStatus(
            source: source,
            freshnessMinutes: freshnessMinutes,
            isOffline: isOffline,
            hazard: snapshot?.hazard,
            routeStatus: snapshot?.routeStatus
        )
    }

    private func usesAlertDrivenStatus(
        tokens _: Set<String>,
        classification: AssistantIntentClassification,
        snapshot: AssistantSituationSnapshot?
    ) -> Bool {
        guard let snapshot else {
            return false
        }

        let hasMatchedOfficialHazard = snapshot.hasEnvironmentalHazard
            || (
                snapshot.hazard != nil
                && officialAlertService.activeAlerts.contains { alert in
                    alert.kind == snapshot.hazard
                }
            )

        guard hasMatchedOfficialHazard else {
            return false
        }

        switch classification.topic {
        case .bushfireEvacuation,
             .floodSafety,
             .routePlanning,
             .survivalFire,
             .survivalFloodStorm,
             .preparednessPlanning,
             .waterPlanning,
             .waterPurification,
             .fieldComms,
             .communicationsResponse,
             .navigationResponse,
             .vehicleSurvival,
            .unknown:
            return true
        default:
            return false
        }
    }

    private func alertProximity(
        for alert: OfficialAlert?,
        currentLocation: CLLocation?
    ) -> AssistantSituationProximity {
        guard let alert else {
            return .unknown
        }

        guard let currentLocation else {
            return .unknown
        }

        guard let area = alert.area else {
            return .near
        }

        let distance = alert.distance(from: currentLocation)
        if distance <= area.radiusMetres {
            return .inside
        }
        if alert.isRelevant(to: currentLocation) {
            return .near
        }
        return .far
    }

    private func inferredMode(
        classification: AssistantIntentClassification,
        severity: OfficialAlertSeverity?,
        proximity: AssistantSituationProximity,
        survivalState: SurvivalContextState?
    ) -> AssistantSituationMode {
        if let severity {
            switch severity {
            case .emergencyWarning:
                return proximity == .inside ? .crisis : .elevated
            case .watchAndAct:
                return .elevated
            case .advice:
                return .prep
            }
        }

        if classification.riskBand == .critical {
            return .crisis
        }

        if let survivalState {
            switch survivalState.highestRisk {
            case .critical:
                return .elevated
            case .high:
                return .prep
            case .moderate, .low:
                break
            }
        }

        return .normal
    }

    private func inferredRouteStatus(
        classification: AssistantIntentClassification,
        severity: OfficialAlertSeverity?,
        hasSavedRoutes: Bool
    ) -> AssistantRouteStatus? {
        guard hasSavedRoutes else {
            return nil
        }

        switch classification.topic {
        case .bushfireEvacuation, .floodSafety, .routePlanning, .vehicleSurvival:
            switch severity {
            case .emergencyWarning, .watchAndAct:
                return .atRisk
            case .advice, nil:
                return .clear
            }
        default:
            return nil
        }
    }

    private func inferredHazard(from topic: AssistantIntentTopic) -> OfficialAlertKind? {
        switch topic {
        case .bushfireEvacuation, .survivalFire:
            return .bushfire
        case .floodSafety, .survivalFloodStorm:
            return .flood
        default:
            return nil
        }
    }

    private func lastOfficialAlertSyncMinutes() -> Int? {
        let lastUpdated = officialAlertService.library.lastUpdated
        guard lastUpdated > .distantPast else {
            return nil
        }
        return max(Int(Date().timeIntervalSince(lastUpdated) / 60), 0)
    }

    // MARK: - Beacon Filtering

    private static let hazardBeaconTypes: Set<BeaconType> = [
        .fireSpotted, .floodedRoad, .roadBlocked, .medicalHelp, .needHelp
    ]

    private static let resourceBeaconTypes: Set<BeaconType> = [
        .safeLocation, .waterAvailable, .fuelAvailable, .shelter
    ]

    private func nearbyHazardBeacons(limit: Int) -> [CommunityBeacon] {
        sortedBeacons(matching: Self.hazardBeaconTypes, limit: limit)
    }

    private func nearbyResourceBeacons(limit: Int) -> [CommunityBeacon] {
        sortedBeacons(matching: Self.resourceBeaconTypes, limit: limit)
    }

    private func sortedBeacons(matching types: Set<BeaconType>, limit: Int) -> [CommunityBeacon] {
        beaconService.nearbyBeacons
            .filter { types.contains($0.type) }
            .sorted { lhs, rhs in
                if lhs.type.priority != rhs.type.priority {
                    return lhs.type.priority < rhs.type.priority
                }
                if lhs.severity.rank != rhs.severity.rank {
                    return lhs.severity.rank > rhs.severity.rank
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Intent Detection

    private func wantsWaterContext(tokens: Set<String>, classification: AssistantIntentClassification) -> Bool {
        let waterTokens: Set<String> = [
            "boil", "clean", "creek", "dehydration", "drink", "drinking",
            "hydration", "purify", "rain", "rainwater", "river", "stream",
            "tap", "tank", "water", "well"
        ]
        return classification.topic == .waterPurification
            || classification.topic == .waterPlanning
            || classification.topic == .waterSourcingSurvival
            || !tokens.isDisjoint(with: waterTokens)
    }

    private func wantsShelterContext(tokens: Set<String>, classification: AssistantIntentClassification) -> Bool {
        let shelterTokens: Set<String> = [
            "cover", "evacuation", "evacuate", "hall", "hide", "indoors",
            "leave", "refuge", "route", "safe", "safety", "shelter", "stay"
        ]
        return classification.topic == .bushfireEvacuation
            || classification.topic == .floodSafety
            || classification.topic == .routePlanning
            || classification.topic == .shelterBuildingSurvival
            || !tokens.isDisjoint(with: shelterTokens)
    }

    private func wantsAlertContext(tokens: Set<String>, classification: AssistantIntentClassification) -> Bool {
        let hazardTokens: Set<String> = [
            "alert", "bushfire", "cyclone", "danger", "dangerous", "emergency",
            "evacuate", "evacuation", "fire", "flood", "hazard", "heatwave",
            "storm", "threat", "warning"
        ]
        return classification.topic == .bushfireEvacuation
            || classification.topic == .floodSafety
            || !tokens.isDisjoint(with: hazardTokens)
    }

    private func wantsHazardBeaconContext(tokens: Set<String>, classification: AssistantIntentClassification) -> Bool {
        let hazardTokens: Set<String> = [
            "blocked", "danger", "dangerous", "fire", "flood", "hazard",
            "help", "road", "safe", "unsafe"
        ]
        return classification.topic == .bushfireEvacuation
            || classification.topic == .floodSafety
            || classification.topic == .routePlanning
            || !tokens.isDisjoint(with: hazardTokens)
    }

    private func wantsResourceBeaconContext(tokens: Set<String>, classification: AssistantIntentClassification) -> Bool {
        let beaconTokens: Set<String> = [
            "available", "community", "fuel", "petrol", "pickup", "report",
            "resource", "shelter", "signal", "supply", "water"
        ]
        return classification.topic == .routePlanning
            || classification.topic == .waterPlanning
            || !tokens.isDisjoint(with: beaconTokens)
    }

    private func wantsFireTrailContext(tokens: Set<String>, classification: AssistantIntentClassification) -> Bool {
        let trailTokens: Set<String> = [
            "access", "bushfire", "escape", "evacuation", "exit", "fire",
            "route", "trail", "track"
        ]
        return classification.topic == .bushfireEvacuation
            || !tokens.isDisjoint(with: trailTokens)
    }

    private func wantsEvacuationContext(tokens: Set<String>, classification: AssistantIntentClassification) -> Bool {
        let evacuationTokens: Set<String> = [
            "evacuate", "evacuation", "flee", "leave", "escape", "getout"
        ]
        return classification.topic == .bushfireEvacuation
            || classification.topic == .floodSafety
            || !tokens.isDisjoint(with: evacuationTokens)
    }
}
