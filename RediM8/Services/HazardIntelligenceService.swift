import CoreLocation
import Foundation

/// Centralized hazard intelligence system for RediM8.
///
/// Long-lived, stateful service that manages the full lifecycle of hazard data from
/// all sources — manual reports, mesh network peers, terrain analysis, official feeds.
///
/// **Why stateful?** Collapse detection, trend analysis, and hazard growth rate tracking
/// require persisted state across calls. A fresh instance per call loses the baseline
/// (previousHazardCount, previousMaxSeverity) that makes "things are getting worse"
/// detection possible.
///
/// **Persistence**: Reports survive app restarts via SQLiteStore. On launch, persisted
/// reports are loaded and expired ones are swept before the zone cache is rebuilt.
///
/// Feeds directly into `OfflineRoutingService.setHazardZones()`.
@MainActor
final class HazardIntelligenceService: ObservableObject {

    // MARK: - Persistence Key

    private static let storageKey = "hazard_intelligence_reports"

    // MARK: - Types

    /// A hazard report from any source, with metadata for scoring and expiry.
    /// Codable for SQLite persistence.
    struct HazardReport: Identifiable, Equatable, Codable {
        let id: UUID
        let kind: HazardKind
        let centerLatitude: Double
        let centerLongitude: Double
        let radiusMetres: CLLocationDistance
        let source: HazardSource
        let severity: HazardSeverity
        let description: String
        let reportedAt: Date
        let expiresAt: Date
        var confirmations: Int
        var lastConfirmedAt: Date
        var confidence: HazardConfidence

        /// CLLocationCoordinate2D accessor (not Codable, so stored as lat/lon).
        var center: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
        }

        var isExpired: Bool { Date.now >= expiresAt }
        var isStale: Bool { Date.now.timeIntervalSince(lastConfirmedAt) > staleDuration }

        var staleDuration: TimeInterval {
            switch kind {
            case .fire: 30 * 60
            case .flood: 2 * 3600
            case .stormSurge: 6 * 3600
            case .roadClosure: 12 * 3600
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
                kind: OfflineRoutingService.HazardZone.HazardKind(rawValue: kind.rawValue) ?? .roadClosure
            )
        }

        /// Convenience initializer using CLLocationCoordinate2D.
        init(
            id: UUID,
            kind: HazardKind,
            center: CLLocationCoordinate2D,
            radiusMetres: CLLocationDistance,
            source: HazardSource,
            severity: HazardSeverity,
            description: String,
            reportedAt: Date,
            expiresAt: Date,
            confirmations: Int,
            lastConfirmedAt: Date,
            confidence: HazardConfidence
        ) {
            self.id = id
            self.kind = kind
            self.centerLatitude = center.latitude
            self.centerLongitude = center.longitude
            self.radiusMetres = radiusMetres
            self.source = source
            self.severity = severity
            self.description = description
            self.reportedAt = reportedAt
            self.expiresAt = expiresAt
            self.confirmations = confirmations
            self.lastConfirmedAt = lastConfirmedAt
            self.confidence = confidence
        }

        static func == (lhs: HazardReport, rhs: HazardReport) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// Mirrors OfflineRoutingService.HazardZone.HazardKind but is Codable.
    /// Kept in sync manually — same raw values.
    enum HazardKind: String, Codable, Equatable {
        case flood
        case fire
        case stormSurge = "storm_surge"
        case roadClosure = "road_closure"

        init(from routingKind: OfflineRoutingService.HazardZone.HazardKind) {
            self = HazardKind(rawValue: routingKind.rawValue) ?? .roadClosure
        }
    }

    enum HazardSource: String, Codable, Equatable {
        case manual
        case mesh
        case terrain
        case officialAlert
    }

    enum HazardSeverity: String, Codable, Comparable, Equatable {
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

    enum HazardConfidence: String, Codable, Comparable, Equatable {
        case low
        case medium
        case high
        case verified

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

    struct RouteSnapshot: Identifiable {
        let id = UUID()
        let computedAt: Date
        let hazardHash: Int
        let destination: String
    }

    struct RouteRejection: Identifiable {
        let id = UUID()
        let routeLabel: String
        let reasons: [String]
    }

    struct EvacuationAdvisory {
        let recommendedRouteIndex: Int
        let reasons: [String]
        let rejections: [RouteRejection]
        let confidence: HazardConfidence
        let hazardSummary: String
        let timestamp: Date
    }

    // MARK: - Configuration

    /// Public for testability — tests can call Config methods to verify radius logic.
    enum Config {
        static func defaultTTL(for kind: HazardKind) -> TimeInterval {
            switch kind {
            case .fire: 2 * 3600
            case .flood: 6 * 3600
            case .stormSurge: 12 * 3600
            case .roadClosure: 24 * 3600
            }
        }

        static let deduplicationRadiusMetres: CLLocationDistance = 500
        static let sweepIntervalBase: TimeInterval = 60
        static let sweepIntervalLowPower: TimeInterval = 300
        static let zoneCacheTTL: TimeInterval = 30
        static let maxReportCount: Int = 5000

        static func baseRadius(for kind: HazardKind) -> CLLocationDistance {
            switch kind {
            case .fire: 1000
            case .flood: 800
            case .stormSurge: 2000
            case .roadClosure: 200
            }
        }

        static func severityMultiplier(for severity: HazardSeverity) -> Double {
            switch severity {
            case .low: 1.0
            case .moderate: 2.0
            case .high: 3.0
            case .critical: 5.0
            }
        }

        static func dynamicRadius(kind: HazardKind, severity: HazardSeverity) -> CLLocationDistance {
            baseRadius(for: kind) * severityMultiplier(for: severity)
        }
    }

    // MARK: - State

    @Published private(set) var reports: [HazardReport] = []
    @Published private(set) var lastSweepAt: Date = .now
    @Published private(set) var routeSnapshots: [RouteSnapshot] = []
    @Published private(set) var isLowPowerMode: Bool = false

    private let store: SQLiteStore?
    private var sweepTimer: Timer?
    private var cachedZones: [OfflineRoutingService.HazardZone]?
    private var cachedZonesHash: Int = 0
    private var cachedZonesAt: Date = .distantPast
    private var lowPowerObserver: NSObjectProtocol?

    /// Collapse detection state — persists across calls because this is a long-lived instance.
    private(set) var lastCollapseLevel: CollapseLevel = .stable
    private(set) var previousHazardCount: Int = 0
    private(set) var previousMaxSeverity: HazardSeverity = .low

    // MARK: - Init

    /// - Parameter store: Optional SQLiteStore for persistence. Pass `nil` for in-memory only (tests).
    init(store: SQLiteStore? = nil) {
        self.store = store
        loadPersistedReports()
    }

    // MARK: - Persistence

    /// Load hazard reports from SQLite on startup.
    /// Sweeps expired reports immediately so the zone cache starts clean.
    private func loadPersistedReports() {
        guard let store else { return }
        do {
            if let persisted = try store.load([HazardReport].self, for: Self.storageKey) {
                reports = persisted.filter { !$0.isExpired }
                previousHazardCount = reports.count
                previousMaxSeverity = reports.map(\.severity).max() ?? .low
            }
        } catch {
            #if DEBUG
            print("[HazardIntelligence] Failed to load persisted reports: \(error)")
            #endif
        }
    }

    /// Persist current reports to SQLite. Called after mutations.
    private func persistReports() {
        enforceCapacity()
        guard let store else { return }
        do {
            try store.save(reports, for: Self.storageKey)
        } catch {
            #if DEBUG
            print("[HazardIntelligence] Failed to persist reports: \(error)")
            #endif
        }
    }

    /// Enforce hard cap on report count. Evicts expired first, then oldest.
    private func enforceCapacity() {
        guard reports.count > Config.maxReportCount else { return }

        // Remove expired first
        reports.removeAll { $0.isExpired }

        // If still over cap, drop oldest non-official reports first, then oldest overall
        if reports.count > Config.maxReportCount {
            reports.sort { lhs, rhs in
                // Keep official alerts longer — sort non-official before official
                if lhs.source == .officialAlert && rhs.source != .officialAlert { return false }
                if lhs.source != .officialAlert && rhs.source == .officialAlert { return true }
                return lhs.reportedAt < rhs.reportedAt
            }
            reports = Array(reports.suffix(Config.maxReportCount))
        }
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        sweepTimer?.invalidate()
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        scheduleSweepTimer()

        lowPowerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                self.scheduleSweepTimer()
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

    @discardableResult
    func addReport(
        kind: HazardKind,
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

        if let existingIndex = findDuplicate(kind: kind, center: center) {
            reports[existingIndex].confirmations += 1
            reports[existingIndex].lastConfirmedAt = now
            reports[existingIndex].confidence = computeConfidence(
                source: reports[existingIndex].source,
                confirmations: reports[existingIndex].confirmations,
                reportedAt: reports[existingIndex].reportedAt
            )
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
            persistReports()
            return reports[existingIndex]
        }

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
        persistReports()
        return report
    }

    /// Overload accepting routing engine's HazardKind for backward compatibility.
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
        addReport(
            kind: HazardKind(from: kind),
            center: center,
            radiusMetres: radiusMetres,
            source: source,
            severity: severity,
            description: description,
            ttl: ttl
        )
    }

    /// Ingest hazard reports received from mesh network.
    /// Batched — persists once after all reports are processed.
    func ingestMeshHazards(_ messages: [MeshMessage]) {
        var added = false
        for msg in messages where msg.kind == .hazardReport {
            guard let report = msg.hazardReport else { continue }
            let kind: HazardKind = switch report.kind {
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
                ttl: 24 * 3600
            )
        }
    }

    // MARK: - Deduplication

    private func findDuplicate(kind: HazardKind, center: CLLocationCoordinate2D) -> Int? {
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

    /// Public for testability.
    func computeConfidence(
        source: HazardSource,
        confirmations: Int,
        reportedAt: Date
    ) -> HazardConfidence {
        if source == .officialAlert { return .verified }

        let countScore: Int = switch confirmations {
        case 1: 0
        case 2...3: 1
        case 4...7: 2
        default: 3
        }

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

    func sweepExpired() {
        let now = Date.now
        var changed = false

        let before = reports.count
        reports.removeAll { $0.isExpired }
        if reports.count != before { changed = true }

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

        if changed {
            invalidateZoneCache()
            persistReports()
        }
        lastSweepAt = now
    }

    // MARK: - Routing Integration

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

    func recordRouteComputation(destination: String) {
        let snapshot = RouteSnapshot(computedAt: .now, hazardHash: reportsHash, destination: destination)
        routeSnapshots.append(snapshot)
        if routeSnapshots.count > 10 {
            routeSnapshots.removeFirst(routeSnapshots.count - 10)
        }
    }

    func isRouteFresh(_ snapshot: RouteSnapshot) -> Bool {
        snapshot.hazardHash == reportsHash
    }

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

    func evaluateRoutes(
        _ rankedRoutes: [OfflineRoutingService.RankedRoute],
        currentLocation: CLLocationCoordinate2D?
    ) -> EvacuationAdvisory? {
        guard !rankedRoutes.isEmpty else { return nil }

        let activeReports = reports.filter { !$0.isExpired }

        struct RouteScore {
            var total: Double = 0
            var penalties: [(reason: String, score: Double)] = []
        }

        var scores = rankedRoutes.map { _ in RouteScore() }

        for (i, ranked) in rankedRoutes.enumerated() {
            let distKM = ranked.route.distanceMetres / 1000
            scores[i].total += distKM * 0.5

            if ranked.hazardExposure > 0 {
                let penalty = ranked.hazardExposure * 10.0
                scores[i].total += penalty
                scores[i].penalties.append(("Passes through \(Int(ranked.hazardExposure)) hazard zone(s)", penalty))
            }

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

            let timePenalty = ranked.route.durationSeconds / 3600 * 2.0
            scores[i].total += timePenalty
        }

        let bestIndex = scores.enumerated().min(by: { $0.element.total < $1.element.total })?.offset ?? 0
        let best = rankedRoutes[bestIndex]

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

        var rejections: [RouteRejection] = []
        for (i, ranked) in rankedRoutes.enumerated() where i != bestIndex {
            let topPenalties = scores[i].penalties
                .sorted { $0.score > $1.score }
                .prefix(3)
                .map { $0.reason }
            var rejectionReasons = topPenalties
            let scoreDiff = scores[i].total - scores[bestIndex].total
            if scoreDiff > 10 {
                rejectionReasons.insert("Scored \(Int(scoreDiff)) points worse than recommended", at: 0)
            }
            rejections.append(RouteRejection(
                routeLabel: ranked.label,
                reasons: rejectionReasons.isEmpty ? ["No specific issues — recommended route is simply better overall"] : rejectionReasons
            ))
        }

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

    enum CollapseLevel: String, Comparable {
        case stable
        case degrading
        case critical
        case collapsed

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

    struct CollapseAssessment {
        let level: CollapseLevel
        let warnings: [String]
        let timestamp: Date
    }

    func assessCollapse(
        rankedRoutes: [OfflineRoutingService.RankedRoute],
        destination: CLLocationCoordinate2D?
    ) -> CollapseAssessment {
        let active = reports.filter { !$0.isExpired }
        var warnings: [String] = []
        var score: Int = 0

        if active.count > previousHazardCount + 2 {
            let delta = active.count - previousHazardCount
            warnings.append("\(delta) new hazards since last check")
            score += min(delta, 5)
        }

        let maxSeverity = active.map(\.severity).max() ?? .low
        if maxSeverity > previousMaxSeverity {
            warnings.append("Hazard severity escalated to \(maxSeverity.rawValue.uppercased())")
            score += maxSeverity.rank
        }

        let viableRoutes = rankedRoutes.filter { $0.hazardExposure < 3.0 }
        if !rankedRoutes.isEmpty {
            if viableRoutes.isEmpty {
                warnings.append("ALL routes pass through hazard zones")
                score += 5
            } else if viableRoutes.count == 1 {
                warnings.append("Only 1 viable route remaining")
                score += 3
            }
        }

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

        let criticalHazards = active.filter { $0.severity >= .high }
        if criticalHazards.count >= 3 {
            warnings.append("\(criticalHazards.count) high/critical hazards active")
            score += 3
        }

        let level: CollapseLevel
        switch score {
        case 0...1: level = .stable
        case 2...4: level = .degrading
        case 5...7: level = .critical
        default: level = .collapsed
        }

        previousHazardCount = active.count
        previousMaxSeverity = maxSeverity
        lastCollapseLevel = level

        return CollapseAssessment(level: level, warnings: warnings, timestamp: .now)
    }
}
