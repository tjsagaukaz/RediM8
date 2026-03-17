import CoreLocation
import Foundation

/// Autonomous guidance that monitors collapse risk and triggers safe zone discovery.
///
/// **What this answers**: "Should I leave now, and where should I go?"
///
/// This service bridges `PredictiveCollapseService` and `SafeZoneService`:
/// - Monitors predictive collapse level and auto-triggers safe zone discovery
///   when risk crosses the critical threshold.
/// - Re-evaluates the active route periodically and recommends alternatives
///   when conditions change (new hazards, route degradation).
/// - Publishes a single `GuidanceState` that the UI can bind to for
///   evacuation prompts, route updates, and status banners.
///
/// **Why a separate service?** The decision to suggest evacuation combines
/// multiple inputs (prediction, safe zones, user location, active route).
/// Neither PredictiveCollapseService nor SafeZoneService owns that decision.
@MainActor
final class AutoGuidanceService: ObservableObject {

    // MARK: - Types

    enum GuidanceState: Equatable {
        case monitoring          // Normal — watching for changes
        case elevated            // Risk rising — preparing recommendations
        case recommending        // Active recommendation available
        case navigating          // User accepted a recommendation
        case routeCompromised    // Active route degraded — re-evaluating

        var isActive: Bool {
            switch self {
            case .monitoring: false
            default: true
            }
        }
    }

    struct GuidanceUpdate {
        let state: GuidanceState
        let assessment: PredictiveCollapseService.PredictiveAssessment?
        let recommendation: SafeZoneService.SafeZoneRecommendation?
        let alternativeCount: Int
        let reasons: [String]
        let timestamp: Date
    }

    // MARK: - Configuration

    private enum Config {
        static let reevaluationInterval: TimeInterval = 120   // Re-check every 2 min
        static let exposureDegradationThreshold: Double = 2.0 // Route considered compromised
        static let significantExposureIncrease: Double = 1.0  // Delta that triggers re-eval
    }

    // MARK: - Dependencies

    private let predictiveCollapseService: PredictiveCollapseService
    private let safeZoneService: SafeZoneService
    private let hazardIntelligenceService: HazardIntelligenceService
    private let offlineRoutingService: OfflineRoutingService

    // MARK: - State

    @Published private(set) var state: GuidanceState = .monitoring
    @Published private(set) var lastUpdate: GuidanceUpdate?
    @Published private(set) var activeRecommendation: SafeZoneService.SafeZoneRecommendation?

    private var activeRouteExposure: Double = 0
    private var lastEvaluationTime: Date = .distantPast
    private var acceptedDestination: CLLocationCoordinate2D?

    // MARK: - Init

    init(
        predictiveCollapseService: PredictiveCollapseService,
        safeZoneService: SafeZoneService,
        hazardIntelligenceService: HazardIntelligenceService,
        offlineRoutingService: OfflineRoutingService
    ) {
        self.predictiveCollapseService = predictiveCollapseService
        self.safeZoneService = safeZoneService
        self.hazardIntelligenceService = hazardIntelligenceService
        self.offlineRoutingService = offlineRoutingService
    }

    // MARK: - Evaluation

    /// Main evaluation loop — call periodically or when hazard state changes.
    /// Coordinates prediction, safe zone discovery, and route monitoring.
    func evaluate(
        userLocation: CLLocationCoordinate2D,
        rankedRoutes: [OfflineRoutingService.RankedRoute] = [],
        destination: CLLocationCoordinate2D? = nil
    ) -> GuidanceUpdate {
        // 1. Get predictive assessment
        let assessment = predictiveCollapseService.assess(
            rankedRoutes: rankedRoutes,
            destination: destination
        )

        // 2. Determine if we should auto-trigger safe zone discovery
        let shouldDiscover = assessment.shouldAutoTrigger ||
            state == .navigating ||
            state == .routeCompromised

        // 3. Discover safe zones if warranted
        var discoveryResult: SafeZoneService.DiscoveryResult?
        if shouldDiscover {
            safeZoneService.invalidateCache()
            discoveryResult = safeZoneService.discoverSafeZones(from: userLocation)
        }

        // 4. Check if active route is compromised
        let routeCompromised = checkRouteCompromised(
            userLocation: userLocation,
            destination: acceptedDestination
        )

        // 5. Classify guidance state
        let newState = classifyState(
            assessment: assessment,
            hasRecommendations: !(discoveryResult?.isEmpty ?? true),
            routeCompromised: routeCompromised
        )

        // 6. Select best recommendation
        let recommendation: SafeZoneService.SafeZoneRecommendation?
        if routeCompromised, let result = discoveryResult {
            // When route is compromised, pick the best alternative
            // (which may differ from current destination)
            recommendation = result.bestZone
        } else if newState == .recommending || newState == .elevated {
            recommendation = discoveryResult?.bestZone
        } else {
            recommendation = activeRecommendation
        }

        // 7. Build reasons
        var reasons = assessment.reasons
        if routeCompromised {
            reasons.insert("Active route now passes through hazard zone", at: 0)
        }
        if let rec = recommendation {
            reasons.append("Recommended: \(rec.name) (\(rec.distanceText))")
        }

        // 8. Update state
        state = newState
        if let rec = recommendation {
            activeRecommendation = rec
        }
        lastEvaluationTime = .now

        let update = GuidanceUpdate(
            state: newState,
            assessment: assessment,
            recommendation: recommendation,
            alternativeCount: discoveryResult?.recommendations.count ?? 0,
            reasons: reasons,
            timestamp: .now
        )
        lastUpdate = update
        return update
    }

    /// User accepts a recommendation and begins navigating to it.
    func acceptRecommendation(_ recommendation: SafeZoneService.SafeZoneRecommendation) {
        activeRecommendation = recommendation
        acceptedDestination = recommendation.coordinate
        activeRouteExposure = recommendation.hazardExposure
        state = .navigating
    }

    /// User dismisses the current recommendation.
    func dismissRecommendation() {
        // Don't clear activeRecommendation — keep it available but go back to monitoring
        acceptedDestination = nil
        state = .monitoring
    }

    /// Reset all guidance state — e.g. when user reaches destination or cancels navigation.
    func reset() {
        state = .monitoring
        activeRecommendation = nil
        acceptedDestination = nil
        activeRouteExposure = 0
        lastUpdate = nil
        predictiveCollapseService.resetHistory()
    }

    // MARK: - Route Monitoring

    /// Check if the currently accepted route has become compromised by new hazards.
    private func checkRouteCompromised(
        userLocation: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D?
    ) -> Bool {
        guard state == .navigating, let dest = destination else { return false }

        // Re-route and check new exposure
        guard let route = try? offlineRoutingService.route(from: userLocation, to: dest) else {
            // Can't even route anymore — definitely compromised
            return true
        }

        let hazardZones = hazardIntelligenceService.activeHazardZones
        let newExposure = computeRouteExposure(route: route, hazardZones: hazardZones)

        // Compromised if exposure exceeds threshold or increased significantly
        let exposureIncrease = newExposure - activeRouteExposure
        if newExposure >= Config.exposureDegradationThreshold {
            return true
        }
        if exposureIncrease >= Config.significantExposureIncrease {
            return true
        }

        return false
    }

    /// Simplified route exposure calculation for monitoring.
    private func computeRouteExposure(
        route: OfflineRoutingService.Route,
        hazardZones: [OfflineRoutingService.HazardZone]
    ) -> Double {
        guard !hazardZones.isEmpty, route.coordinates.count >= 2 else { return 0 }

        let sampleInterval: CLLocationDistance = 500 // Coarser sampling for monitoring
        let coords = route.coordinates
        var totalExposure: Double = 0
        var sampledDistance: CLLocationDistance = 0
        var cumulativeDistance: CLLocationDistance = 0

        for i in 1 ..< coords.count {
            let prev = CLLocation(latitude: coords[i - 1].latitude, longitude: coords[i - 1].longitude)
            let curr = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            cumulativeDistance += prev.distance(from: curr)

            if cumulativeDistance - sampledDistance >= sampleInterval || i == coords.count - 1 {
                sampledDistance = cumulativeDistance
                for zone in hazardZones where zone.contains(coords[i]) {
                    totalExposure += zone.penalty * (sampleInterval / 1000)
                }
            }
        }

        let routeKM = max(route.distanceMetres / 1000, 1)
        return totalExposure / routeKM
    }

    // MARK: - State Classification

    private func classifyState(
        assessment: PredictiveCollapseService.PredictiveAssessment,
        hasRecommendations: Bool,
        routeCompromised: Bool
    ) -> GuidanceState {
        // Route compromised takes priority if we're navigating
        if routeCompromised && state == .navigating {
            return .routeCompromised
        }

        // If user is navigating and route is fine, stay navigating
        if state == .navigating && !routeCompromised {
            return .navigating
        }

        // Auto-trigger threshold crossed with recommendations available
        if assessment.shouldAutoTrigger && hasRecommendations {
            return .recommending
        }

        // Risk is elevated but not yet critical
        if assessment.level >= .degrading {
            return .elevated
        }

        return .monitoring
    }
}
