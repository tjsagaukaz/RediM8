import CoreLocation
import Foundation

/// Predicts future collapse by analyzing hazard trends over time.
///
/// **What this answers**: "Where is the situation heading?"
///
/// The existing `assessCollapse()` on `HazardIntelligenceService` compares the current
/// snapshot against the previous one. This service maintains a time-series of snapshots
/// and computes rates of change — hazard growth, severity escalation, route degradation —
/// to estimate how long until the situation becomes critical.
///
/// **Why a separate service?** Trend analysis requires its own state (history ring buffer,
/// regression weights) and runs on a different cadence than the hazard sweep timer.
/// Keeping it separate avoids bloating HazardIntelligenceService and allows independent
/// testing of the prediction logic.
@MainActor
final class PredictiveCollapseService: ObservableObject {

    // MARK: - Types

    /// Extends CollapseLevel with `imminent` — collapse not yet happened but predicted soon.
    enum PredictiveLevel: String, Comparable {
        case stable
        case degrading
        case critical
        case imminent

        var rank: Int {
            switch self {
            case .stable: 0
            case .degrading: 1
            case .critical: 2
            case .imminent: 3
            }
        }

        static func < (lhs: PredictiveLevel, rhs: PredictiveLevel) -> Bool {
            lhs.rank < rhs.rank
        }
    }

    struct PredictiveAssessment {
        let level: PredictiveLevel
        let probability: Double
        let estimatedTimeToFailure: TimeInterval?
        let hazardGrowthRate: Double      // hazards per minute
        let severityTrend: Double          // positive = escalating
        let routeDegradationRate: Double   // viable routes lost per assessment
        let reasons: [String]
        let timestamp: Date

        var timeToFailureText: String? {
            guard let ttf = estimatedTimeToFailure else { return nil }
            let minutes = Int(ttf / 60)
            if minutes <= 0 { return "NOW" }
            if minutes < 60 { return "\(minutes) MIN" }
            return "\(minutes / 60)H \(minutes % 60)M"
        }

        /// True when the system should trigger automatic safe zone discovery.
        var shouldAutoTrigger: Bool {
            level >= .critical || probability > 0.7
        }
    }

    // MARK: - Configuration

    private enum Config {
        static let maxSnapshotHistory = 20
        static let assessmentCacheTTL: TimeInterval = 30
        static let minSnapshotsForPrediction = 3

        // Thresholds
        static let highGrowthRate: Double = 0.5       // ≥0.5 hazards/min = alarming
        static let criticalGrowthRate: Double = 1.0   // ≥1.0/min = imminent
        static let routeLossThreshold: Double = 0.5   // losing ≥0.5 routes/assessment
    }

    // MARK: - Snapshot History

    private struct Snapshot {
        let timestamp: Date
        let hazardCount: Int
        let maxSeverityRank: Int
        let criticalHazardCount: Int
        let viableRouteCount: Int
        let totalRouteCount: Int
        let averageHazardExposure: Double
    }

    // MARK: - State

    @Published private(set) var lastAssessment: PredictiveAssessment?

    private var snapshots: [Snapshot] = []
    private var cachedAssessment: PredictiveAssessment?
    private var cachedAt: Date = .distantPast

    private let hazardIntelligenceService: HazardIntelligenceService
    private let hazardFeedService: HazardFeedService

    // MARK: - Init

    init(
        hazardIntelligenceService: HazardIntelligenceService,
        hazardFeedService: HazardFeedService
    ) {
        self.hazardIntelligenceService = hazardIntelligenceService
        self.hazardFeedService = hazardFeedService
    }

    // MARK: - Assessment

    /// Record a snapshot and compute predictive assessment.
    /// Call this periodically (e.g. every sweep cycle) or when hazard state changes.
    func assess(
        rankedRoutes: [OfflineRoutingService.RankedRoute] = [],
        destination: CLLocationCoordinate2D? = nil
    ) -> PredictiveAssessment {
        // Check cache
        if let cached = cachedAssessment,
           Date.now.timeIntervalSince(cachedAt) < Config.assessmentCacheTTL {
            return cached
        }

        // Record current snapshot
        let active = hazardIntelligenceService.reports.filter { !$0.isExpired }
        let viableRoutes = rankedRoutes.filter { $0.hazardExposure < 3.0 }
        let avgExposure = rankedRoutes.isEmpty ? 0 :
            rankedRoutes.map(\.hazardExposure).reduce(0, +) / Double(rankedRoutes.count)

        let snapshot = Snapshot(
            timestamp: .now,
            hazardCount: active.count,
            maxSeverityRank: (active.map(\.severity).max() ?? .low).rank,
            criticalHazardCount: active.filter { $0.severity >= .high }.count,
            viableRouteCount: viableRoutes.count,
            totalRouteCount: rankedRoutes.count,
            averageHazardExposure: avgExposure
        )

        snapshots.append(snapshot)
        if snapshots.count > Config.maxSnapshotHistory {
            snapshots.removeFirst(snapshots.count - Config.maxSnapshotHistory)
        }

        // Compute trends
        let growthRate = computeHazardGrowthRate()
        let severityTrend = computeSeverityTrend()
        let routeDegradation = computeRouteDegradationRate()

        // Estimate probability and time to failure
        let (probability, ttf) = estimateCollapse(
            growthRate: growthRate,
            severityTrend: severityTrend,
            routeDegradation: routeDegradation,
            currentSnapshot: snapshot,
            destination: destination
        )

        // Determine predictive level
        let level = classifyLevel(
            probability: probability,
            growthRate: growthRate,
            currentSnapshot: snapshot
        )

        // Build reasons
        let reasons = buildReasons(
            growthRate: growthRate,
            severityTrend: severityTrend,
            routeDegradation: routeDegradation,
            currentSnapshot: snapshot,
            destination: destination
        )

        let assessment = PredictiveAssessment(
            level: level,
            probability: probability,
            estimatedTimeToFailure: ttf,
            hazardGrowthRate: growthRate,
            severityTrend: severityTrend,
            routeDegradationRate: routeDegradation,
            reasons: reasons,
            timestamp: .now
        )

        cachedAssessment = assessment
        cachedAt = .now
        lastAssessment = assessment
        return assessment
    }

    /// Clear history — use when context changes significantly (e.g. user relocates).
    func resetHistory() {
        snapshots.removeAll()
        cachedAssessment = nil
        lastAssessment = nil
    }

    // MARK: - Trend Computation

    /// Hazards per minute over recent history.
    /// Positive = growing, negative = subsiding.
    private func computeHazardGrowthRate() -> Double {
        guard snapshots.count >= Config.minSnapshotsForPrediction else { return 0 }

        let recent = Array(snapshots.suffix(Config.minSnapshotsForPrediction))
        guard let first = recent.first, let last = recent.last else { return 0 }

        let timeDelta = last.timestamp.timeIntervalSince(first.timestamp)
        guard timeDelta > 10 else { return 0 } // Need meaningful time span

        let countDelta = Double(last.hazardCount - first.hazardCount)
        return countDelta / (timeDelta / 60) // per minute
    }

    /// Severity trend: positive = escalating, zero = stable, negative = de-escalating.
    private func computeSeverityTrend() -> Double {
        guard snapshots.count >= Config.minSnapshotsForPrediction else { return 0 }

        let recent = Array(snapshots.suffix(Config.minSnapshotsForPrediction))
        guard let first = recent.first, let last = recent.last else { return 0 }

        return Double(last.maxSeverityRank - first.maxSeverityRank)
    }

    /// Rate of viable route loss per assessment cycle.
    private func computeRouteDegradationRate() -> Double {
        guard snapshots.count >= 2 else { return 0 }

        let recent = Array(snapshots.suffix(min(5, snapshots.count)))
        guard recent.count >= 2, let first = recent.first, let last = recent.last else { return 0 }

        // Only meaningful if routes were available at some point
        guard first.totalRouteCount > 0 else { return 0 }

        let routeLoss = Double(first.viableRouteCount - last.viableRouteCount)
        return max(0, routeLoss / Double(recent.count - 1))
    }

    // MARK: - Collapse Estimation

    private func estimateCollapse(
        growthRate: Double,
        severityTrend: Double,
        routeDegradation: Double,
        currentSnapshot: Snapshot,
        destination: CLLocationCoordinate2D?
    ) -> (probability: Double, timeToFailure: TimeInterval?) {
        var probability: Double = 0

        // Factor 1: Hazard growth rate
        if growthRate >= Config.criticalGrowthRate {
            probability += 0.4
        } else if growthRate >= Config.highGrowthRate {
            probability += 0.2
        } else if growthRate > 0.1 {
            probability += 0.1
        }

        // Factor 2: Severity escalation
        if severityTrend >= 2 { probability += 0.2 }
        else if severityTrend >= 1 { probability += 0.1 }

        // Factor 3: Route degradation
        if routeDegradation >= Config.routeLossThreshold {
            probability += 0.2
        }
        if currentSnapshot.viableRouteCount == 0 && currentSnapshot.totalRouteCount > 0 {
            probability += 0.3
        }

        // Factor 4: Absolute hazard density
        if currentSnapshot.criticalHazardCount >= 5 { probability += 0.15 }
        else if currentSnapshot.criticalHazardCount >= 3 { probability += 0.1 }

        // Factor 5: Data staleness reduces confidence (not probability)
        // If feeds are stale, we can't know things are getting better
        if hazardFeedService.isFeedStale && currentSnapshot.hazardCount > 0 {
            probability += 0.05
        }

        // Factor 6: Destination threat
        if let dest = destination {
            let destLoc = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
            let active = hazardIntelligenceService.reports.filter { !$0.isExpired }
            let threatsNearDest = active.filter { report in
                let rLoc = CLLocation(latitude: report.center.latitude, longitude: report.center.longitude)
                return destLoc.distance(from: rLoc) < report.radiusMetres * 2
            }
            if !threatsNearDest.isEmpty {
                probability += min(0.15, Double(threatsNearDest.count) * 0.05)
            }
        }

        probability = min(1.0, probability)

        // Estimate time to failure based on growth rate
        var timeToFailure: TimeInterval? = nil
        if growthRate > 0.1 && probability > 0.3 {
            // Rough estimate: how long until hazard count doubles from current
            let currentCount = Double(max(currentSnapshot.hazardCount, 1))
            let minutesToDouble = currentCount / growthRate
            // Scale by inverse probability — higher prob = sooner
            let rawTTF = minutesToDouble * 60 * (1.0 - probability + 0.1)
            // Cap at reasonable bounds: 1 min to 2 hours
            timeToFailure = max(60, min(rawTTF, 3600 * 2))
        }

        return (probability, timeToFailure)
    }

    // MARK: - Classification

    private func classifyLevel(
        probability: Double,
        growthRate: Double,
        currentSnapshot: Snapshot
    ) -> PredictiveLevel {
        // Imminent: high probability + active deterioration
        if probability > 0.8 || (probability > 0.6 && growthRate >= Config.criticalGrowthRate) {
            return .imminent
        }

        // Critical: significant probability or no viable routes with active growth
        if probability > 0.5 ||
           (currentSnapshot.viableRouteCount == 0 && currentSnapshot.totalRouteCount > 0) {
            return .critical
        }

        // Degrading: moderate signals
        if probability > 0.25 || growthRate >= Config.highGrowthRate {
            return .degrading
        }

        return .stable
    }

    // MARK: - Reason Building

    private func buildReasons(
        growthRate: Double,
        severityTrend: Double,
        routeDegradation: Double,
        currentSnapshot: Snapshot,
        destination: CLLocationCoordinate2D?
    ) -> [String] {
        var reasons: [String] = []

        // Hazard growth
        if growthRate >= Config.criticalGrowthRate {
            reasons.append(String(format: "Hazard reports surging (+%.1f/min)", growthRate))
        } else if growthRate >= Config.highGrowthRate {
            reasons.append(String(format: "Hazard reports increasing (+%.1f/min)", growthRate))
        } else if growthRate > 0.1 {
            reasons.append(String(format: "Hazard reports rising (+%.1f/min)", growthRate))
        } else if growthRate < -0.1 {
            reasons.append("Hazard situation stabilizing")
        }

        // Severity
        if severityTrend >= 2 {
            reasons.append("Severity escalating rapidly")
        } else if severityTrend >= 1 {
            reasons.append("Hazard severity increasing")
        }

        // Route viability
        if currentSnapshot.viableRouteCount == 0 && currentSnapshot.totalRouteCount > 0 {
            reasons.append("ALL routes now pass through hazard zones")
        } else if routeDegradation >= Config.routeLossThreshold {
            reasons.append(String(format: "Routes losing viability (%.0f safe → %d)",
                Double(snapshots.first?.viableRouteCount ?? 0),
                currentSnapshot.viableRouteCount))
        }

        // Destination threat
        if let dest = destination {
            let destLoc = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
            let active = hazardIntelligenceService.reports.filter { !$0.isExpired }
            let threats = active.filter { report in
                let rLoc = CLLocation(latitude: report.center.latitude, longitude: report.center.longitude)
                return destLoc.distance(from: rLoc) < report.radiusMetres * 2
            }
            if !threats.isEmpty {
                reasons.append("Destination threatened by \(threats.count) nearby hazard(s)")
            }
        }

        // Data freshness
        if hazardFeedService.isFeedStale {
            reasons.append("Official data may be outdated (\(hazardFeedService.feedFreshnessText))")
        }

        // Critical mass
        if currentSnapshot.criticalHazardCount >= 3 {
            reasons.append("\(currentSnapshot.criticalHazardCount) high/critical hazards active")
        }

        if reasons.isEmpty {
            reasons.append("Situation appears stable")
        }

        return reasons
    }
}
