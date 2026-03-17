import CoreLocation
import Foundation

/// Discovers, scores, and ranks safe evacuation destinations.
///
/// **What this answers**: "Where should I go to survive?"
///
/// When collapse is detected or the user requests safe zone discovery, this service:
/// 1. Generates candidate destinations (shelters, towns, high ground)
/// 2. Filters unreachable or hazard-engulfed candidates
/// 3. Scores each by distance, hazard exposure, elevation safety, and resources
/// 4. Returns ranked recommendations with reasons
///
/// **Design decisions**:
/// - Synchronous scoring — all spatial queries are R-tree backed, routing is CH Dijkstra.
///   Total compute budget: ~50ms for 20 candidates.
/// - Leverages existing `NearestResourceService` for candidate generation and
///   `RouteCorridor` for per-route resource analysis.
/// - Results cached for 60s to avoid redundant computation on rapid UI refreshes.
/// - Elevation data is optional — service degrades gracefully when not loaded.
@MainActor
final class SafeZoneService: ObservableObject {

    // MARK: - Types

    /// Confidence level for a safe zone recommendation.
    enum SafeZoneConfidence: String, Comparable {
        case low        // routing data only, no hazard intel, stale feeds
        case moderate   // some hazard data, partial route coverage
        case high       // recent hazard data, full route, verified destination
        case verified   // official shelter with fresh hazard sweep, clear route

        var rank: Int {
            switch self {
            case .low: 0
            case .moderate: 1
            case .high: 2
            case .verified: 3
            }
        }

        static func < (lhs: SafeZoneConfidence, rhs: SafeZoneConfidence) -> Bool {
            lhs.rank < rhs.rank
        }

        var label: String {
            switch self {
            case .low: "LOW CONFIDENCE"
            case .moderate: "MODERATE"
            case .high: "HIGH CONFIDENCE"
            case .verified: "VERIFIED"
            }
        }
    }

    struct SafeZoneRecommendation: Identifiable {
        let id: String
        let name: String
        let coordinate: CLLocationCoordinate2D
        let distanceMetres: CLLocationDistance
        let travelTimeSeconds: TimeInterval
        let hazardExposure: Double
        let elevationMetres: Int16?
        let waterSourceCount: Int
        let shelterCount: Int
        let score: Double
        let confidence: SafeZoneConfidence
        let reasons: [String]
        let routeCoordinates: [CLLocationCoordinate2D]

        var distanceText: String {
            if distanceMetres >= 1000 {
                return String(format: "%.0f KM", distanceMetres / 1000)
            }
            return "\(Int(distanceMetres.rounded())) M"
        }

        var travelTimeText: String {
            let minutes = Int(travelTimeSeconds / 60)
            if minutes >= 60 {
                return "\(minutes / 60)H \(minutes % 60)M"
            }
            return "\(minutes) MIN"
        }

        var hazardLevelText: String {
            if hazardExposure < 0.1 { return "CLEAR" }
            if hazardExposure < 1.0 { return "LOW RISK" }
            if hazardExposure < 3.0 { return "MODERATE RISK" }
            return "HIGH RISK"
        }

        var elevationText: String {
            guard let elev = elevationMetres else { return "N/A" }
            return "\(elev)M ASL"
        }
    }

    struct DiscoveryResult {
        let recommendations: [SafeZoneRecommendation]
        let timestamp: Date
        let candidatesEvaluated: Int
        let candidatesRejected: Int
        let computeTimeMs: Int

        var isEmpty: Bool { recommendations.isEmpty }
        var bestZone: SafeZoneRecommendation? { recommendations.first }
    }

    // MARK: - Configuration

    private enum Config {
        static let maxCandidates = 20
        static let maxResults = 5
        static let cacheTTLSeconds: TimeInterval = 60
        static let maxRoutingDistanceMetres: CLLocationDistance = 200_000 // 200km cap
        static let corridorWidthMetres: CLLocationDistance = 500

        // Scoring weights
        static let distanceWeight: Double = 1.0
        static let hazardWeight: Double = 10.0
        static let elevationWeight: Double = 2.0
        static let resourceWeight: Double = 2.0
        static let shelterBonusWeight: Double = 1.5

        // Elevation thresholds
        static let floodSafeElevation: Int16 = 50  // metres ASL
        static let highGroundElevation: Int16 = 200
    }

    // MARK: - Dependencies

    private let nearestResourceService: NearestResourceService
    private let offlineRoutingService: OfflineRoutingService
    private let hazardIntelligenceService: HazardIntelligenceService
    private let shelterService: ShelterService
    private let hazardFeedService: HazardFeedService?
    private let elevationService: ElevationService?
    private let installedPackIDs: () -> Set<String>

    // MARK: - State

    @Published private(set) var lastResult: DiscoveryResult?
    @Published private(set) var isComputing = false

    private var cachedResult: DiscoveryResult?
    private var cachedOrigin: CLLocationCoordinate2D?

    // MARK: - Init

    init(
        nearestResourceService: NearestResourceService,
        offlineRoutingService: OfflineRoutingService,
        hazardIntelligenceService: HazardIntelligenceService,
        shelterService: ShelterService,
        hazardFeedService: HazardFeedService? = nil,
        elevationService: ElevationService? = nil,
        installedPackIDs: @escaping () -> Set<String> = { [] }
    ) {
        self.nearestResourceService = nearestResourceService
        self.offlineRoutingService = offlineRoutingService
        self.hazardIntelligenceService = hazardIntelligenceService
        self.shelterService = shelterService
        self.hazardFeedService = hazardFeedService
        self.elevationService = elevationService
        self.installedPackIDs = installedPackIDs
    }

    // MARK: - Discovery

    /// Discover and rank safe zones from the user's current location.
    /// Returns cached result if origin hasn't moved significantly and cache is fresh.
    func discoverSafeZones(
        from origin: CLLocationCoordinate2D
    ) -> DiscoveryResult {
        // Check cache
        if let cached = cachedResult,
           let cachedOrigin,
           Date.now.timeIntervalSince(cached.timestamp) < Config.cacheTTLSeconds,
           CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: cachedOrigin.latitude, longitude: cachedOrigin.longitude)) < 500 {
            return cached
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        isComputing = true
        defer { isComputing = false }

        // 1. Generate candidates
        let candidates = generateCandidates(from: origin)

        // 2. Score and filter
        let scored = candidates.compactMap { candidate -> SafeZoneRecommendation? in
            score(candidate: candidate, from: origin)
        }

        // 3. Rank by score (lower is better) and take top N
        let ranked = scored
            .sorted { $0.score < $1.score }
            .prefix(Config.maxResults)

        let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        let result = DiscoveryResult(
            recommendations: Array(ranked),
            timestamp: .now,
            candidatesEvaluated: candidates.count,
            candidatesRejected: candidates.count - scored.count,
            computeTimeMs: elapsed
        )

        cachedResult = result
        cachedOrigin = origin
        lastResult = result
        return result
    }

    /// Force clear the cache and recompute.
    func invalidateCache() {
        cachedResult = nil
        cachedOrigin = nil
    }

    // MARK: - Candidate Generation

    private struct Candidate {
        let id: String
        let name: String
        let coordinate: CLLocationCoordinate2D
        let distanceMetres: CLLocationDistance
        let category: NearestResourceService.ResourceCategory
    }

    private func generateCandidates(from origin: CLLocationCoordinate2D) -> [Candidate] {
        let packIDs = installedPackIDs()
        var candidates: [Candidate] = []
        var seenIDs = Set<String>()

        // Shelters — primary evacuation points (up to 10)
        let shelters = nearestResourceService.nearest(
            .shelter,
            to: origin,
            installedPackIDs: packIDs,
            limit: 10
        )
        for s in shelters where s.distanceMetres <= Config.maxRoutingDistanceMetres {
            guard seenIDs.insert(s.id).inserted else { continue }
            candidates.append(Candidate(
                id: s.id, name: s.name, coordinate: s.coordinate,
                distanceMetres: s.distanceMetres, category: .shelter
            ))
        }

        // Towns — hospitals, fuel, police, etc. (up to 10)
        let towns = nearestResourceService.nearest(
            .town,
            to: origin,
            installedPackIDs: packIDs,
            limit: 10
        )
        for t in towns where t.distanceMetres <= Config.maxRoutingDistanceMetres {
            guard seenIDs.insert(t.id).inserted else { continue }
            candidates.append(Candidate(
                id: t.id, name: t.name, coordinate: t.coordinate,
                distanceMetres: t.distanceMetres, category: .town
            ))
        }

        // Cap at maxCandidates, sorted by straight-line distance
        return Array(
            candidates
                .sorted { $0.distanceMetres < $1.distanceMetres }
                .prefix(Config.maxCandidates)
        )
    }

    // MARK: - Scoring

    private func score(
        candidate: Candidate,
        from origin: CLLocationCoordinate2D
    ) -> SafeZoneRecommendation? {
        // Try to route to the candidate
        let route: OfflineRoutingService.Route
        do {
            route = try offlineRoutingService.route(from: origin, to: candidate.coordinate)
        } catch {
            // Unreachable — reject
            return nil
        }

        // Compute hazard exposure along route
        let hazardZones = hazardIntelligenceService.activeHazardZones
        let exposure = computeHazardExposure(route: route, hazardZones: hazardZones)

        // Check if destination itself is inside a high-confidence hazard zone
        let destInHazard = hazardZones.contains { zone in
            zone.contains(candidate.coordinate) && zone.penalty >= 6.0
        }
        if destInHazard { return nil }

        // Elevation at destination
        let elevation = elevationService?.elevation(at: candidate.coordinate)

        // Corridor analysis for resources along route
        let corridor = RouteCorridor(
            nearestService: nearestResourceService,
            installedPackIDs: installedPackIDs()
        )
        let analysis = corridor.analyze(
            route: route,
            corridorWidthMetres: Config.corridorWidthMetres
        )

        // Resources at/near destination
        let destWater = nearestResourceService.nearest(
            .water,
            to: candidate.coordinate,
            installedPackIDs: installedPackIDs(),
            limit: 5
        ).filter { $0.distanceMetres <= 5000 }

        let destShelters = nearestResourceService.nearest(
            .shelter,
            to: candidate.coordinate,
            installedPackIDs: installedPackIDs(),
            limit: 5
        ).filter { $0.distanceMetres <= 5000 }

        // Build score (lower = better)
        var score: Double = 0
        var reasons: [String] = []

        // Distance penalty (per 10km)
        let distKM = route.distanceMetres / 1000
        score += distKM * 0.1 * Config.distanceWeight
        reasons.append(String(format: "%.0f km drive", distKM))

        // Hazard exposure (dominant factor)
        score += exposure * Config.hazardWeight
        if exposure < 0.1 {
            reasons.append("No active hazards along route")
        } else if exposure < 1.0 {
            reasons.append("Low hazard exposure en route")
        } else {
            reasons.append(String(format: "%.1f hazard zone exposure", exposure))
        }

        // Elevation safety bonus (negative = good)
        if let elev = elevation {
            if elev >= Config.highGroundElevation {
                score -= 5.0 * Config.elevationWeight
                reasons.append("High ground (\(elev)m — flood safe)")
            } else if elev >= Config.floodSafeElevation {
                score -= 2.0 * Config.elevationWeight
                reasons.append("Elevated terrain (\(elev)m)")
            } else if elev < 10 {
                score += 3.0 * Config.elevationWeight
                reasons.append("Low elevation (\(elev)m — flood risk)")
            }
        }

        // Resource availability bonus
        let waterCount = destWater.count + analysis.waterSources.count
        let shelterCount = destShelters.count + analysis.shelters.count

        if waterCount > 0 {
            score -= Double(min(waterCount, 5)) * 0.5 * Config.resourceWeight
            if analysis.hasWaterAccess {
                reasons.append("Water every \(analysis.longestWaterGapText) along route")
            }
        } else {
            score += 5.0 * Config.resourceWeight
            reasons.append("No water along route — carry extra supply")
        }

        if shelterCount > 0 {
            score -= Double(min(shelterCount, 3)) * Config.shelterBonusWeight
            reasons.append("\(destShelters.count) shelter(s) at destination")
        }

        // Shelter type bonus — evacuation centres are purpose-built
        if candidate.category == .shelter {
            score -= 3.0 * Config.shelterBonusWeight
        }

        // Travel time factor (per hour)
        let hours = route.durationSeconds / 3600
        score += hours * 2.0

        let confidence = computeConfidence(
            candidate: candidate,
            hazardExposure: exposure,
            hasElevation: elevation != nil
        )

        return SafeZoneRecommendation(
            id: candidate.id,
            name: candidate.name,
            coordinate: candidate.coordinate,
            distanceMetres: route.distanceMetres,
            travelTimeSeconds: route.durationSeconds,
            hazardExposure: exposure,
            elevationMetres: elevation,
            waterSourceCount: waterCount,
            shelterCount: shelterCount,
            score: score,
            confidence: confidence,
            reasons: reasons,
            routeCoordinates: route.coordinates
        )
    }

    // MARK: - Confidence Scoring

    /// Compute confidence based on data freshness, route quality, and destination type.
    private func computeConfidence(
        candidate: Candidate,
        hazardExposure: Double,
        hasElevation: Bool
    ) -> SafeZoneConfidence {
        var score = 0

        // Fresh hazard data = +2, stale = +0
        if let feedService = hazardFeedService {
            if !feedService.isFeedStale { score += 2 }
        }

        // Hazard intel available and clear route = +2
        let activeHazards = hazardIntelligenceService.reports.filter { !$0.isExpired }
        if !activeHazards.isEmpty {
            score += 1 // We have hazard data at all
            if hazardExposure < 0.5 { score += 1 } // Route is clear
        }

        // Official shelter = +1
        if candidate.category == .shelter { score += 1 }

        // Elevation data available = +1
        if hasElevation { score += 1 }

        switch score {
        case 6...: return .verified
        case 4...5: return .high
        case 2...3: return .moderate
        default: return .low
        }
    }

    // MARK: - Hazard Exposure

    /// Compute aggregate hazard exposure along a route.
    /// Samples route at ~200m intervals, sums penalty for each sample inside a hazard zone.
    /// Normalized by route length to produce a per-km exposure metric.
    private func computeHazardExposure(
        route: OfflineRoutingService.Route,
        hazardZones: [OfflineRoutingService.HazardZone]
    ) -> Double {
        guard !hazardZones.isEmpty, route.coordinates.count >= 2 else { return 0 }

        let sampleInterval: CLLocationDistance = 200
        let coords = route.coordinates
        var totalExposure: Double = 0
        var sampledDistance: CLLocationDistance = 0
        var cumulativeDistance: CLLocationDistance = 0

        for i in 1 ..< coords.count {
            let prev = CLLocation(latitude: coords[i - 1].latitude, longitude: coords[i - 1].longitude)
            let curr = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            let segmentLength = prev.distance(from: curr)
            cumulativeDistance += segmentLength

            if cumulativeDistance - sampledDistance >= sampleInterval || i == coords.count - 1 {
                sampledDistance = cumulativeDistance
                for zone in hazardZones where zone.contains(coords[i]) {
                    totalExposure += zone.penalty * (sampleInterval / 1000)
                }
            }
        }

        // Normalize by route length in km
        let routeKM = max(route.distanceMetres / 1000, 1)
        return totalExposure / routeKM
    }
}
