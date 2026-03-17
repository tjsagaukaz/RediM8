import CoreLocation
import Foundation

/// Centralized hazard intelligence system for RediM8.
///
/// Manages the lifecycle of hazard data from all sources — manual reports,
/// mesh network peers, terrain analysis, and official alerts. Provides:
///
///   - **Expiry**: Hazards have TTL and auto-expire (A)
///   - **Confidence**: Trust scoring based on report count, recency, proximity (B)
///   - **Deduplication**: Spatial clustering merges nearby duplicate reports (C)
///   - **Route freshness**: Detects when new hazards invalidate cached routes (D)
///   - **Evacuation advisor**: Recommends best route with reasoning (E)
///
/// Feeds directly into `OfflineRoutingService.setHazardZones()`.
@MainActor
final class HazardIntelligenceService: ObservableObject {

    // MARK: - Types

    /// A hazard report from any source, with metadata for scoring and expiry.
    struct HazardReport: Identifiable, Equatable {
        let id: UUID
        let kind: OfflineRoutingService.HazardZone.HazardKind
        let center: CLLocationCoordinate2D
        let radiusMetres: CLLocationDistance
        let source: HazardSource
        let severity: HazardSeverity
        let description: String
        let reportedAt: Date
        let expiresAt: Date
        var confirmations: Int // Number of corroborating reports merged in
        var lastConfirmedAt: Date
        var confidence: HazardConfidence

        var isExpired: Bool { Date.now >= expiresAt }
        var isStale: Bool { Date.now.timeIntervalSince(lastConfirmedAt) > staleDuration }

        var staleDuration: TimeInterval {
            switch kind {
            case .fire: 30 * 60            // 30 min — fires move fast
            case .flood: 2 * 3600          // 2 hours
            case .stormSurge: 6 * 3600     // 6 hours
            case .roadClosure: 12 * 3600   // 12 hours
            }
        }

        var ageText: String {
            let elapsed = Date.now.timeIntervalSince(reportedAt)
            if elapsed < 60 { return "JUST NOW" }
            if elapsed < 3600 { return "\(Int(elapsed / 60)) MIN AGO" }
            if elapsed < 86400 { return "\(Int(elapsed / 3600))H AGO" }
            return "\(Int(elapsed / 86400))D AGO"
        }

        var confidenceText: String { confidence.title }

        /// Convert to a HazardZone for the routing engine, scaled by confidence.
        var routingZone: OfflineRoutingService.HazardZone {
            let basePenalty: Double = switch severity {
            case .critical: 10.0
            case .high: 6.0
            case .moderate: 3.0
            case .low: 1.5
            }
            let confidenceScale: Double = switch confidence {
            case .verified: 1.0
            case .high: 0.9
            case .medium: 0.6
            case .low: 0.3
            }
            return OfflineRoutingService.HazardZone(
                center: center,
                radiusMetres: radiusMetres,
                penalty: basePenalty * confidenceScale,
                kind: kind
            )
        }

        static func == (lhs: HazardReport, rhs: HazardReport) -> Bool {
            lhs.id == rhs.id
        }
    }

    enum HazardSource: String, Equatable {
        case manual          // User-reported in this app
        case mesh            // Received from mesh peer
        case terrain         // From elevation analysis
        case officialAlert   // From official alert feed
    }

    enum HazardSeverity: String, Comparable, Equatable {
        case low
        case moderate
        case high
        case critical

        var rank: Int {
            switch self {
            case .low: 0
            case .moderate: 1
            case .high: 2
            case .critical: 3
            }
        }

        static func < (lhs: HazardSeverity, rhs: HazardSeverity) -> Bool {
            lhs.rank < rhs.rank
        }
    }

    enum HazardConfidence: String, Comparable, Equatable {
        case low       // 1 unconfirmed report
        case medium    // 2-3 reports or recent single report
        case high      // 4+ reports or official source
        case verified  // Official alert or many confirmations

        var title: String {
            switch self {
            case .low: "LOW"
            case .medium: "MEDIUM"
            case .high: "HIGH"
            case .verified: "VERIFIED"
            }
        }

        var rank: Int {
            switch self {
            case .low: 0
            case .medium: 1
            case .high: 2
            case .verified: 3
            }
        }

        static func < (lhs: HazardConfidence, rhs: HazardConfidence) -> Bool {
            lhs.rank < rhs.rank
        }
    }

    // MARK: - Route Freshness

    /// Tracks when a route was computed and what hazard state it was based on.
    struct RouteSnapshot: Identifiable {
        let id = UUID()
        let computedAt: Date
        let hazardHash: Int  // Hash of active hazards at computation time
        let destination: String
    }

    /// Why a route was NOT recommended.
    struct RouteRejection: Identifiable {
        let id = UUID()
        let routeLabel: String
        let reasons: [String]
    }

    /// Evacuation intelligence recommendation.
    struct EvacuationAdvisory {
        let recommendedRouteIndex: Int
        let reasons: [String]
        let rejections: [RouteRejection]
        let confidence: HazardConfidence
        let hazardSummary: String
        let timestamp: Date
    }

    // MARK: - Configuration

    private enum Config {
        /// Default TTL by hazard kind.
        static func defaultTTL(for kind: OfflineRoutingService.HazardZone.HazardKind) -> TimeInterval {
            switch kind {
            case .fire: 2 * 3600          // 2 hours
            case .flood: 6 * 3600         // 6 hours
            case .stormSurge: 12 * 3600   // 12 hours
            case .roadClosure: 24 * 3600  // 24 hours
            }
        }

        /// Radius within which reports are considered duplicates (metres).
        static let deduplicationRadiusMetres: CLLocationDistance = 500

        /// Expiry sweep interval (adaptive — see BatteryOptimizer).
        static let sweepIntervalBase: TimeInterval = 60 // Every minute
        static let sweepIntervalLowPower: TimeInterval = 300 // Every 5 min in low-power

        /// Cache validity for hazard zone computation.
        static let zoneCacheTTL: TimeInterval = 30  // 30 seconds

        /// Dynamic radius by hazard kind (base radius in metres at severity=low).
        static func baseRadius(for kind: OfflineRoutingService.HazardZone.HazardKind) -> CLLocationDistance {
            switch kind {
            case .fire: 1000          // Fire: 1–5 km
            case .flood: 800          // Flood: 0.8–4 km
            case .stormSurge: 2000    // Storm surge: 2–10 km
            case .roadClosure: 200    // Road closure: 0.2–1 km (linear)
            }
        }

        /// Severity multiplier for radius scaling: radius = baseRadius × severityMultiplier.
        static func severityMultiplier(for severity: HazardSeverity) -> Double {
            switch severity {
            case .low: 1.0
            case .moderate: 2.0
            case .high: 3.0
            case .critical: 5.0
            }
        }

        /// Compute dynamic radius for a hazard.
        static func dynamicRadius(
            kind: OfflineRoutingService.HazardZone.HazardKind,
            severity: HazardSeverity
        ) -> CLLocationDistance {
            baseRadius(for: kind) * severityMultiplier(for: severity)
        }
    }

    // MARK: - State

    @Published private(set) var reports: [HazardReport] = []
    @Published private(set) var lastSweepAt: Date = .now
    @Published private(set) var routeSnapshots: [RouteSnapshot] = []
    @Published private(set) var isLowPowerMode: Bool = false

    private var sweepTimer: Timer?
    private var cachedZones: [OfflineRoutingService.HazardZone]?
    private var cachedZonesHash: Int = 0
    private var cachedZonesAt: Date = .distantPast
    private var lowPowerObserver: NSObjectProtocol?

    // MARK: - Lifecycle

    func startMonitoring() {
        sweepTimer?.invalidate()
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        scheduleSweepTimer()

        // Observe Low Power Mode changes
        lowPowerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                self.scheduleSweepTimer() // Reschedule with appropriate interval
            }
        }
    }

    func stopMonitoring() {
        sweepTimer?.invalidate()
        sweepTimer = nil
        if let observer = lowPowerObserver {
            NotificationCenter.default.removeObserver(observer)
            lowPowerObserver = nil
        }
    }

    private func scheduleSweepTimer() {
        sweepTimer?.invalidate()
        let interval = isLowPowerMode ? Config.sweepIntervalLowPower : Config.sweepIntervalBase
        sweepTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sweepExpired()
            }
        }
    }

    // MARK: - Report Ingestion

    /// Add a hazard report from any source. Automatically deduplicates and scores.
    @discardableResult
    func addReport(
        kind: OfflineRoutingService.HazardZone.HazardKind,
        center: CLLocationCoordinate2D,
        radiusMetres: CLLocationDistance? = nil,
        source: HazardSource,
        severity: HazardSeverity,
        description: String,
        ttl: TimeInterval? = nil
    ) -> HazardReport {
        let effectiveTTL = ttl ?? Config.defaultTTL(for: kind)
        let effectiveRadius = radiusMetres ?? Config.dynamicRadius(kind: kind, severity: severity)
        let now = Date.now

        // Check for duplicates within deduplication radius
        if let existingIndex = findDuplicate(kind: kind, center: center) {
            // Merge into existing report: increase confidence, update timestamp
            reports[existingIndex].confirmations += 1
            reports[existingIndex].lastConfirmedAt = now
            reports[existingIndex].confidence = computeConfidence(
                source: reports[existingIndex].source,
                confirmations: reports[existingIndex].confirmations,
                reportedAt: reports[existingIndex].reportedAt
            )
            // Escalate severity if new report is higher
            if severity > reports[existingIndex].severity {
                reports[existingIndex] = HazardReport(
                    id: reports[existingIndex].id,
                    kind: reports[existingIndex].kind,
                    center: reports[existingIndex].center,
                    radiusMetres: max(reports[existingIndex].radiusMetres, effectiveRadius),
                    source: reports[existingIndex].source,
                    severity: severity,
                    description: reports[existingIndex].description,
                    reportedAt: reports[existingIndex].reportedAt,
                    expiresAt: reports[existingIndex].expiresAt,
                    confirmations: reports[existingIndex].confirmations,
                    lastConfirmedAt: now,
                    confidence: reports[existingIndex].confidence
                )
            }
            invalidateZoneCache()
            return reports[existingIndex]
        }

        // New report
        let confidence = computeConfidence(source: source, confirmations: 1, reportedAt: now)
        let report = HazardReport(
            id: UUID(),
            kind: kind,
            center: center,
            radiusMetres: effectiveRadius,
            source: source,
            severity: severity,
            description: description,
            reportedAt: now,
            expiresAt: now.addingTimeInterval(effectiveTTL),
            confirmations: 1,
            lastConfirmedAt: now,
            confidence: confidence
        )
        reports.append(report)
        invalidateZoneCache()
        return report
    }

    /// Ingest hazard reports received from mesh network.
    /// Batched — defers cache invalidation until all reports are processed.
    func ingestMeshHazards(_ messages: [MeshMessage]) {
        var added = false
        for msg in messages where msg.kind == .hazardReport {
            guard let report = msg.hazardReport else { continue }
            let kind: OfflineRoutingService.HazardZone.HazardKind = switch report.kind {
            case "flood": .flood
            case "fire": .fire
            case "storm_surge": .stormSurge
            default: .roadClosure
            }
            let severity: HazardSeverity = switch report.severity {
            case "critical": .critical
            case "high": .high
            case "moderate": .moderate
            default: .low
            }
            addReport(
                kind: kind,
                center: CLLocationCoordinate2D(latitude: report.latitude, longitude: report.longitude),
                radiusMetres: report.radiusMetres,
                source: .mesh,
                severity: severity,
                description: report.description
            )
            added = true
        }
        if added { invalidateZoneCache() }
    }

    /// Ingest terrain hazards from elevation analysis.
    func ingestTerrainHazards(_ zones: [OfflineRoutingService.HazardZone]) {
        for zone in zones {
            addReport(
                kind: zone.kind,
                center: zone.center,
                radiusMetres: zone.radiusMetres,
                source: .terrain,
                severity: .moderate,
                description: "Terrain-detected \(zone.kind.rawValue) risk",
                ttl: 24 * 3600 // Terrain hazards valid for 24h
            )
        }
    }

    // MARK: - Deduplication

    /// Find an existing report that overlaps spatially and matches kind.
    private func findDuplicate(
        kind: OfflineRoutingService.HazardZone.HazardKind,
        center: CLLocationCoordinate2D
    ) -> Int? {
        let loc = CLLocation(latitude: center.latitude, longitude: center.longitude)

        for (index, report) in reports.enumerated() {
            guard report.kind == kind, !report.isExpired else { continue }
            let reportLoc = CLLocation(latitude: report.center.latitude, longitude: report.center.longitude)
            if loc.distance(from: reportLoc) <= Config.deduplicationRadiusMetres {
                return index
            }
        }
        return nil
    }

    // MARK: - Confidence Scoring

    private func computeConfidence(
        source: HazardSource,
        confirmations: Int,
        reportedAt: Date
    ) -> HazardConfidence {
        // Official sources are always verified
        if source == .officialAlert { return .verified }

        // Base on confirmation count
        let countScore: Int = switch confirmations {
        case 1: 0
        case 2...3: 1
        case 4...7: 2
        default: 3
        }

        // Recency bonus (reports confirmed in last 30 min get +1)
        let recencyBonus = Date.now.timeIntervalSince(reportedAt) < 1800 ? 1 : 0

        let totalScore = countScore + recencyBonus
        switch totalScore {
        case 0: return .low
        case 1: return .medium
        case 2: return .high
        default: return .verified
        }
    }

    // MARK: - Expiry Sweep

    /// Remove expired hazard reports and update stale confidence.
    func sweepExpired() {
        let now = Date.now
        var changed = false

        // Remove expired
        let before = reports.count
        reports.removeAll { $0.isExpired }
        if reports.count != before { changed = true }

        // Downgrade confidence of stale reports
        for i in reports.indices {
            if reports[i].isStale && reports[i].confidence > .low {
                reports[i] = HazardReport(
                    id: reports[i].id,
                    kind: reports[i].kind,
                    center: reports[i].center,
                    radiusMetres: reports[i].radiusMetres,
                    source: reports[i].source,
                    severity: reports[i].severity,
                    description: reports[i].description,
                    reportedAt: reports[i].reportedAt,
                    expiresAt: reports[i].expiresAt,
                    confirmations: reports[i].confirmations,
                    lastConfirmedAt: reports[i].lastConfirmedAt,
                    confidence: .low
                )
                changed = true
            }
        }

        if changed { invalidateZoneCache() }
        lastSweepAt = now
    }

    // MARK: - Routing Integration

    /// Active (non-expired) hazard zones for the routing engine, with confidence-scaled penalties.
    /// Cached for performance — recomputed only when reports change.
    var activeHazardZones: [OfflineRoutingService.HazardZone] {
        let now = Date.now
        if let cached = cachedZones,
           now.timeIntervalSince(cachedZonesAt) < Config.zoneCacheTTL,
           reportsHash == cachedZonesHash {
            return cached
        }

        let zones = reports
            .filter { !$0.isExpired }
            .map { $0.routingZone }

        cachedZones = zones
        cachedZonesHash = reportsHash
        cachedZonesAt = now
        return zones
    }

    /// Push current hazard zones to the routing service.
    func syncToRoutingService(_ routingService: OfflineRoutingService) {
        routingService.setHazardZones(activeHazardZones)
    }

    private var reportsHash: Int {
        var hasher = Hasher()
        for r in reports {
            hasher.combine(r.id)
            hasher.combine(r.confirmations)
            hasher.combine(r.confidence.rank)
        }
        return hasher.finalize()
    }

    private func invalidateZoneCache() {
        cachedZones = nil
    }

    // MARK: - Route Freshness

    /// Record that a route was computed against the current hazard state.
    func recordRouteComputation(destination: String) {
        let snapshot = RouteSnapshot(
            computedAt: .now,
            hazardHash: reportsHash,
            destination: destination
        )
        routeSnapshots.append(snapshot)
        // Keep last 10
        if routeSnapshots.count > 10 {
            routeSnapshots.removeFirst(routeSnapshots.count - 10)
        }
    }

    /// Check if a route snapshot is still fresh (no new/changed hazards since computation).
    func isRouteFresh(_ snapshot: RouteSnapshot) -> Bool {
        snapshot.hazardHash == reportsHash
    }

    /// Check freshness and return a warning if stale.
    func routeFreshnessWarning(_ snapshot: RouteSnapshot) -> String? {
        guard !isRouteFresh(snapshot) else { return nil }

        let elapsed = Date.now.timeIntervalSince(snapshot.computedAt)
        let timeText: String
        if elapsed < 60 { timeText = "just now" }
        else if elapsed < 3600 { timeText = "\(Int(elapsed / 60)) min ago" }
        else { timeText = "\(Int(elapsed / 3600))h ago" }

        return "Route computed \(timeText) — new hazards reported since. Consider recomputing."
    }

    // MARK: - Evacuation Intelligence Advisor

    /// Analyze ranked routes and produce an advisory recommendation.
    /// Now includes per-route rejection reasons for transparency.
    func evaluateRoutes(
        _ rankedRoutes: [OfflineRoutingService.RankedRoute],
        currentLocation: CLLocationCoordinate2D?
    ) -> EvacuationAdvisory? {
        guard !rankedRoutes.isEmpty else { return nil }

        let activeReports = reports.filter { !$0.isExpired }

        // Score every route, track penalties per route for rejection reasons
        struct RouteScore {
            var total: Double = 0
            var penalties: [(reason: String, score: Double)] = []
        }

        var scores = rankedRoutes.map { _ in RouteScore() }

        for (i, ranked) in rankedRoutes.enumerated() {
            // Factor 1: Distance
            let distKM = ranked.route.distanceMetres / 1000
            scores[i].total += distKM * 0.5

            // Factor 2: Hazard exposure (dominant)
            if ranked.hazardExposure > 0 {
                let penalty = ranked.hazardExposure * 10.0
                scores[i].total += penalty
                scores[i].penalties.append(("Passes through \(Int(ranked.hazardExposure)) hazard zone(s)", penalty))
            }

            // Factor 3: Active hazard proximity
            for report in activeReports {
                let reportLoc = CLLocation(latitude: report.center.latitude, longitude: report.center.longitude)
                for coord in ranked.route.coordinates {
                    let routeLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    if routeLoc.distance(from: reportLoc) < report.radiusMetres * 1.5 {
                        let penalty = report.severity.rank > 1 ? 20.0 : 5.0
                        scores[i].total += penalty
                        let distKm = String(format: "%.1f", routeLoc.distance(from: reportLoc) / 1000)
                        scores[i].penalties.append(("Active \(report.kind.rawValue) within \(distKm) km", penalty))
                        break
                    }
                }
            }

            // Factor 4: Resource availability
            if let analysis = ranked.corridorAnalysis {
                if !analysis.hasWaterAccess {
                    scores[i].total += 30.0
                    scores[i].penalties.append(("No water access along route", 30.0))
                }
                if !analysis.hasShelterAccess {
                    scores[i].total += 15.0
                    scores[i].penalties.append(("No shelter access along route", 15.0))
                }
                if analysis.longestWaterGapMetres > 50_000 {
                    let gapKM = Int(analysis.longestWaterGapMetres / 1000)
                    scores[i].total += 20.0
                    scores[i].penalties.append(("Water gap of \(gapKM) km", 20.0))
                }
            }

            // Factor 5: Travel time
            let timePenalty = ranked.route.durationSeconds / 3600 * 2.0
            scores[i].total += timePenalty
        }

        // Find best
        let bestIndex = scores.enumerated().min(by: { $0.element.total < $1.element.total })?.offset ?? 0
        let best = rankedRoutes[bestIndex]

        // Build reasons for recommended route
        var reasons: [String] = []
        if bestIndex == 0 {
            reasons.append("Fastest route to destination")
        } else {
            let primary = rankedRoutes[0]
            if best.hazardExposure < primary.hazardExposure {
                reasons.append("Avoids \(Int(primary.hazardExposure - best.hazardExposure)) hazard zone(s)")
            }
            if best.route.distanceMetres < primary.route.distanceMetres {
                let savedKM = (primary.route.distanceMetres - best.route.distanceMetres) / 1000
                reasons.append(String(format: "%.0f km shorter", savedKM))
            }
        }

        if let analysis = best.corridorAnalysis {
            if analysis.hasWaterAccess {
                let gapKM = analysis.longestWaterGapMetres / 1000
                reasons.append(String(format: "Water every %.0f km", gapKM))
            } else {
                reasons.append("No water along route — carry extra supply")
            }
            if analysis.hasShelterAccess {
                reasons.append("\(analysis.shelters.count) shelter(s) along corridor")
            }
        }

        let activeNearRoute = activeReports.filter { report in
            let rLoc = CLLocation(latitude: report.center.latitude, longitude: report.center.longitude)
            return best.route.coordinates.contains { coord in
                CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    .distance(from: rLoc) < report.radiusMetres * 2
            }
        }

        if activeNearRoute.isEmpty {
            reasons.append("No active hazards along this route")
        } else {
            let kinds = Set(activeNearRoute.map { $0.kind.rawValue }).joined(separator: ", ")
            reasons.append("Caution: \(activeNearRoute.count) hazard(s) nearby (\(kinds))")
        }

        // Build rejection reasons for non-recommended routes
        var rejections: [RouteRejection] = []
        for (i, ranked) in rankedRoutes.enumerated() where i != bestIndex {
            let topPenalties = scores[i].penalties
                .sorted { $0.score > $1.score }
                .prefix(3)
                .map { $0.reason }
            var rejectionReasons = topPenalties
            // Add comparative reasons
            let scoreDiff = scores[i].total - scores[bestIndex].total
            if scoreDiff > 10 {
                rejectionReasons.insert("Scored \(Int(scoreDiff)) points worse than recommended", at: 0)
            }
            rejections.append(RouteRejection(
                routeLabel: ranked.label,
                reasons: rejectionReasons.isEmpty ? ["No specific issues — recommended route is simply better overall"] : rejectionReasons
            ))
        }

        // Overall confidence
        let confidence: HazardConfidence
        if activeReports.isEmpty {
            confidence = .low
        } else if activeReports.allSatisfy({ $0.confidence >= .high }) {
            confidence = .verified
        } else if activeReports.contains(where: { $0.confidence >= .medium }) {
            confidence = .high
        } else {
            confidence = .medium
        }

        let hazardSummary: String
        if activeReports.isEmpty {
            hazardSummary = "No active hazards reported"
        } else {
            let counts = Dictionary(grouping: activeReports, by: { $0.kind.rawValue })
                .map { "\($0.value.count) \($0.key)" }
                .joined(separator: ", ")
            hazardSummary = "\(activeReports.count) active hazards: \(counts)"
        }

        return EvacuationAdvisory(
            recommendedRouteIndex: bestIndex,
            reasons: reasons,
            rejections: rejections,
            confidence: confidence,
            hazardSummary: hazardSummary,
            timestamp: .now
        )
    }

    // MARK: - Stats

    var activeReportCount: Int {
        reports.filter { !$0.isExpired }.count
    }

    var highConfidenceCount: Int {
        reports.filter { !$0.isExpired && $0.confidence >= .high }.count
    }

    var hazardSummaryText: String {
        let active = reports.filter { !$0.isExpired }
        guard !active.isEmpty else { return "NO ACTIVE HAZARDS" }
        return "\(active.count) ACTIVE HAZARD\(active.count == 1 ? "" : "S")"
    }

    // MARK: - Collapse Detection

    /// Severity level for collapse alerts.
    enum CollapseLevel: String, Comparable {
        case stable    // No degradation
        case degrading // Conditions worsening
        case critical  // Route viability at risk
        case collapsed // Destination unreachable or all routes blocked

        var rank: Int {
            switch self {
            case .stable: 0
            case .degrading: 1
            case .critical: 2
            case .collapsed: 3
            }
        }

        static func < (lhs: CollapseLevel, rhs: CollapseLevel) -> Bool {
            lhs.rank < rhs.rank
        }
    }

    /// Result of collapse analysis.
    struct CollapseAssessment {
        let level: CollapseLevel
        let warnings: [String]
        let timestamp: Date
    }

    /// Previous collapse state for detecting transitions.
    private var lastCollapseLevel: CollapseLevel = .stable
    private var previousHazardCount: Int = 0
    private var previousMaxSeverity: HazardSeverity = .low

    /// Assess whether evacuation conditions are collapsing.
    ///
    /// Monitors:
    ///   - Hazard count increasing (more hazards appearing)
    ///   - Hazard severity escalating
    ///   - Route coverage shrinking (hazards blocking more routes)
    ///   - Resource gaps widening
    func assessCollapse(
        rankedRoutes: [OfflineRoutingService.RankedRoute],
        destination: CLLocationCoordinate2D?
    ) -> CollapseAssessment {
        let active = reports.filter { !$0.isExpired }
        var warnings: [String] = []
        var score: Int = 0

        // 1. Hazard count increasing
        if active.count > previousHazardCount + 2 {
            let delta = active.count - previousHazardCount
            warnings.append("\(delta) new hazards since last check")
            score += min(delta, 5)
        }

        // 2. Severity escalation
        let maxSeverity = active.map(\.severity).max() ?? .low
        if maxSeverity > previousMaxSeverity {
            warnings.append("Hazard severity escalated to \(maxSeverity.rawValue.uppercased())")
            score += maxSeverity.rank
        }

        // 3. Route viability
        let viableRoutes = rankedRoutes.filter { $0.hazardExposure < 3.0 }
        if rankedRoutes.count > 0 {
            if viableRoutes.isEmpty {
                warnings.append("ALL routes pass through hazard zones")
                score += 5
            } else if viableRoutes.count == 1 {
                warnings.append("Only 1 viable route remaining")
                score += 3
            }
        }

        // 4. Destination proximity to hazards
        if let dest = destination {
            let destLoc = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
            let hazardsNearDest = active.filter { report in
                let rLoc = CLLocation(latitude: report.center.latitude, longitude: report.center.longitude)
                return destLoc.distance(from: rLoc) < report.radiusMetres * 2
            }
            if !hazardsNearDest.isEmpty {
                warnings.append("Destination threatened by \(hazardsNearDest.count) nearby hazard(s)")
                score += hazardsNearDest.count * 2
            }
        }

        // 5. High-severity hazards blocking corridor
        let criticalHazards = active.filter { $0.severity >= .high }
        if criticalHazards.count >= 3 {
            warnings.append("\(criticalHazards.count) high/critical hazards active")
            score += 3
        }

        // Determine level
        let level: CollapseLevel
        switch score {
        case 0...1: level = .stable
        case 2...4: level = .degrading
        case 5...7: level = .critical
        default: level = .collapsed
        }

        // Update tracking state
        previousHazardCount = active.count
        previousMaxSeverity = maxSeverity
        lastCollapseLevel = level

        return CollapseAssessment(
            level: level,
            warnings: warnings,
            timestamp: .now
        )
    }
}
