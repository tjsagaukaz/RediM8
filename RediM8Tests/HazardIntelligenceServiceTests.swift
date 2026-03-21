import CoreLocation
import XCTest
@testable import RediM8

private typealias HazardKind = HazardIntelligenceService.HazardKind

final class HazardIntelligenceServiceTests: XCTestCase {

    // MARK: - TTL Expiry

    @MainActor
    func testExpiredReportsAreRemovedBySweep() {
        let service = HazardIntelligenceService(store: nil)

        // Add a report with a very short TTL (already expired)
        service.addReport(
            kind: HazardKind.fire,
            center: CLLocationCoordinate2D(latitude: -33.8, longitude: 151.2),
            source: .manual,
            severity: .moderate,
            description: "Test fire",
            ttl: -1 // Already expired
        )

        XCTAssertEqual(service.reports.count, 1)

        service.sweepExpired()

        XCTAssertEqual(service.reports.count, 0, "Expired reports should be removed by sweep")
    }

    @MainActor
    func testNonExpiredReportsSurviveSweep() {
        let service = HazardIntelligenceService(store: nil)

        service.addReport(
            kind: HazardKind.flood,
            center: CLLocationCoordinate2D(latitude: -33.8, longitude: 151.2),
            source: .manual,
            severity: .high,
            description: "Active flood",
            ttl: 3600 // 1 hour from now
        )

        service.sweepExpired()

        XCTAssertEqual(service.reports.count, 1, "Non-expired reports should survive sweep")
    }

    // MARK: - Confidence Scaling

    @MainActor
    func testOfficialSourceIsAlwaysVerified() {
        let service = HazardIntelligenceService(store: nil)

        let confidence = service.computeConfidence(source: .officialAlert, confirmations: 1, reportedAt: .now)
        XCTAssertEqual(confidence, .verified, "Official sources must always be verified confidence")
    }

    @MainActor
    func testSingleUnconfirmedReportIsLowConfidence() {
        let service = HazardIntelligenceService(store: nil)

        // Report from 2 hours ago (no recency bonus)
        let oldDate = Date.now.addingTimeInterval(-7200)
        let confidence = service.computeConfidence(source: .manual, confirmations: 1, reportedAt: oldDate)
        XCTAssertEqual(confidence, .low, "Single old unconfirmed report should be low confidence")
    }

    @MainActor
    func testConfidenceScalesRoutingPenalty() {
        let service = HazardIntelligenceService(store: nil)

        // Add a verified hazard
        let report = service.addReport(
            kind: HazardKind.fire,
            center: CLLocationCoordinate2D(latitude: -33.8, longitude: 151.2),
            source: .officialAlert,
            severity: .critical,
            description: "Verified fire"
        )

        let zone = report.routingZone
        // Critical severity (10.0) × verified confidence (1.0) = 10.0
        XCTAssertEqual(zone.penalty, 10.0, accuracy: 0.01, "Verified critical hazard should have full penalty")
    }

    @MainActor
    func testLowConfidenceReducesRoutingPenalty() {
        let service = HazardIntelligenceService(store: nil)

        let report = service.addReport(
            kind: HazardKind.fire,
            center: CLLocationCoordinate2D(latitude: -33.8, longitude: 151.2),
            source: .manual,
            severity: .critical,
            description: "Unconfirmed fire",
            ttl: 3600
        )

        // Low confidence: penalty = 10.0 × 0.3 = 3.0
        // (may be medium if recency bonus applies, so check range)
        let penalty = report.routingZone.penalty
        XCTAssertLessThan(penalty, 10.0, "Low/medium confidence should reduce routing penalty below max")
    }

    // MARK: - Deduplication

    @MainActor
    func testDuplicateReportMergesIntoExisting() {
        let service = HazardIntelligenceService(store: nil)
        let coord = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)

        service.addReport(kind: HazardKind.fire, center: coord, source: .manual, severity: .moderate, description: "Fire 1")

        // Add near-identical report (same kind, within 500m)
        let nearbyCoord = CLLocationCoordinate2D(latitude: -33.869, longitude: 151.209)
        service.addReport(kind: HazardKind.fire, center: nearbyCoord, source: .mesh, severity: .moderate, description: "Fire 2")

        XCTAssertEqual(service.reports.count, 1, "Duplicate reports within 500m should merge")
        XCTAssertEqual(service.reports[0].confirmations, 2, "Merged report should have 2 confirmations")
    }

    @MainActor
    func testDifferentKindsAreNotDeduplicated() {
        let service = HazardIntelligenceService(store: nil)
        let coord = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)

        service.addReport(kind: HazardKind.fire, center: coord, source: .manual, severity: .moderate, description: "Fire")
        service.addReport(kind: HazardKind.flood, center: coord, source: .manual, severity: .moderate, description: "Flood")

        XCTAssertEqual(service.reports.count, 2, "Different hazard kinds at same location should not merge")
    }

    @MainActor
    func testDistantReportsAreNotDeduplicated() {
        let service = HazardIntelligenceService(store: nil)

        let sydney = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
        let melbourne = CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)

        service.addReport(kind: HazardKind.fire, center: sydney, source: .manual, severity: .moderate, description: "Sydney fire")
        service.addReport(kind: HazardKind.fire, center: melbourne, source: .manual, severity: .moderate, description: "Melbourne fire")

        XCTAssertEqual(service.reports.count, 2, "Reports >500m apart should not merge")
    }

    // MARK: - Dynamic Radius

    @MainActor
    func testDynamicRadiusScalesWithSeverity() {
        let lowRadius = HazardIntelligenceService.Config.dynamicRadius(kind: HazardKind.fire, severity: .low)
        let criticalRadius = HazardIntelligenceService.Config.dynamicRadius(kind: HazardKind.fire, severity: .critical)

        XCTAssertEqual(lowRadius, 1000, "Fire at low severity should have 1km radius")
        XCTAssertEqual(criticalRadius, 5000, "Fire at critical severity should have 5km radius")
    }

    @MainActor
    func testDynamicRadiusDiffersByKind() {
        let fireRadius = HazardIntelligenceService.Config.dynamicRadius(kind: HazardKind.fire, severity: .moderate)
        let roadRadius = HazardIntelligenceService.Config.dynamicRadius(kind: HazardKind.roadClosure, severity: .moderate)

        XCTAssertGreaterThan(fireRadius, roadRadius, "Fire radius should be larger than road closure")
    }

    // MARK: - Collapse Detection

    @MainActor
    func testStableWhenNoHazards() {
        let service = HazardIntelligenceService(store: nil)

        let assessment = service.assessCollapse(rankedRoutes: [], destination: nil)
        XCTAssertEqual(assessment.level, .stable, "No hazards should be stable")
        XCTAssertTrue(assessment.warnings.isEmpty)
    }

    @MainActor
    func testCollapseDetectsHazardGrowth() {
        let service = HazardIntelligenceService(store: nil)

        // First assessment establishes baseline
        _ = service.assessCollapse(rankedRoutes: [], destination: nil)

        // Add 4 hazards (exceeds threshold of previousCount + 2)
        for i in 0..<4 {
            service.addReport(
                kind: HazardKind.fire,
                center: CLLocationCoordinate2D(latitude: -33.8 + Double(i) * 0.1, longitude: 151.2),
                source: .manual,
                severity: .high,
                description: "Fire \(i)"
            )
        }

        let assessment = service.assessCollapse(rankedRoutes: [], destination: nil)
        XCTAssertGreaterThan(assessment.level, .stable, "Adding 4 hazards should move beyond stable")
        XCTAssertFalse(assessment.warnings.isEmpty, "Should have warnings about new hazards")
    }

    @MainActor
    func testCollapseDetectsSeverityEscalation() {
        let service = HazardIntelligenceService(store: nil)

        // Baseline with moderate hazard
        service.addReport(
            kind: HazardKind.fire,
            center: CLLocationCoordinate2D(latitude: -33.8, longitude: 151.2),
            source: .manual,
            severity: .moderate,
            description: "Moderate fire"
        )
        _ = service.assessCollapse(rankedRoutes: [], destination: nil)

        // Escalate to critical
        service.addReport(
            kind: HazardKind.flood,
            center: CLLocationCoordinate2D(latitude: -34.0, longitude: 151.0),
            source: .officialAlert,
            severity: .critical,
            description: "Critical flood"
        )

        let assessment = service.assessCollapse(rankedRoutes: [], destination: nil)
        let hasEscalationWarning = assessment.warnings.contains { $0.contains("escalated") }
        XCTAssertTrue(hasEscalationWarning, "Should warn about severity escalation")
    }

    // MARK: - Route Freshness

    @MainActor
    func testRouteBecomesStaleAfterNewHazard() {
        let service = HazardIntelligenceService(store: nil)

        service.recordRouteComputation(destination: "Shelter A")
        let snapshot = service.routeSnapshots.last!

        XCTAssertTrue(service.isRouteFresh(snapshot), "Route should be fresh immediately after computation")

        // Add a new hazard — changes the hash
        service.addReport(
            kind: HazardKind.fire,
            center: CLLocationCoordinate2D(latitude: -33.8, longitude: 151.2),
            source: .manual,
            severity: .high,
            description: "New fire"
        )

        XCTAssertFalse(service.isRouteFresh(snapshot), "Route should be stale after new hazard added")
        XCTAssertNotNil(service.routeFreshnessWarning(snapshot), "Should produce a warning for stale route")
    }

    @MainActor
    func testMeshReportsPersistInSecureStoreWhileOfficialReportsStayInSQLite() throws {
        let context = try makePersistenceContext(testName: #function)
        let service = HazardIntelligenceService(
            store: context.store,
            sensitiveHazardReportService: context.sensitiveHazardReportService,
            sensitiveHazardReportMigrationService: context.sensitiveHazardReportMigrationService
        )

        _ = service.addReport(
            kind: HazardKind.fire,
            center: CLLocationCoordinate2D(latitude: -27.468, longitude: 153.028),
            source: .mesh,
            severity: .high,
            description: "Mesh fire report"
        )
        _ = service.addReport(
            kind: HazardKind.flood,
            center: CLLocationCoordinate2D(latitude: -27.47, longitude: 153.03),
            source: .officialAlert,
            severity: .critical,
            description: "Official flood report"
        )

        let sqliteReports = try context.store.load([HazardIntelligenceService.HazardReport].self, for: HazardStorageKey.reports) ?? []
        let secureReports = try context.sensitiveHazardReportService.loadReports()

        XCTAssertEqual(sqliteReports.map(\.source), [.officialAlert])
        XCTAssertEqual(secureReports.map(\.source), [.mesh])
    }

    @MainActor
    func testLegacySensitiveHazardReportsMigrateOutOfSQLite() throws {
        let context = try makePersistenceContext(testName: #function)
        let meshReport = HazardIntelligenceService.HazardReport(
            id: UUID(),
            kind: .fire,
            center: CLLocationCoordinate2D(latitude: -27.468, longitude: 153.028),
            radiusMetres: 600,
            source: .mesh,
            severity: .high,
            description: "Mesh fire report",
            reportedAt: .now,
            expiresAt: .now.addingTimeInterval(2 * 60 * 60),
            confirmations: 1,
            lastConfirmedAt: .now,
            confidence: .medium
        )
        let officialReport = HazardIntelligenceService.HazardReport(
            id: UUID(),
            kind: .flood,
            center: CLLocationCoordinate2D(latitude: -27.47, longitude: 153.03),
            radiusMetres: 800,
            source: .officialAlert,
            severity: .critical,
            description: "Official flood report",
            reportedAt: .now,
            expiresAt: .now.addingTimeInterval(6 * 60 * 60),
            confirmations: 1,
            lastConfirmedAt: .now,
            confidence: .verified
        )

        try context.store.save([meshReport, officialReport], for: HazardStorageKey.reports)

        let service = HazardIntelligenceService(
            store: context.store,
            sensitiveHazardReportService: context.sensitiveHazardReportService,
            sensitiveHazardReportMigrationService: context.sensitiveHazardReportMigrationService
        )

        let sqliteReports = try context.store.load([HazardIntelligenceService.HazardReport].self, for: HazardStorageKey.reports) ?? []
        let secureReports = try context.sensitiveHazardReportService.loadReports()
        let migrationCompleted = try context.store.load(Bool.self, for: HazardStorageKey.sensitiveMigrationCompleted)

        XCTAssertEqual(Set(service.reports.map(\.source)), Set([.mesh, .officialAlert]))
        XCTAssertEqual(sqliteReports, [officialReport])
        XCTAssertEqual(secureReports, [meshReport])
        XCTAssertEqual(migrationCompleted, true)
    }
}

private extension HazardIntelligenceServiceTests {
    func makePersistenceContext(testName: String) throws -> HazardPersistenceContext {
        let store = try SQLiteStore(filename: "HazardIntelligenceServiceTests-\(UUID().uuidString).sqlite")
        let secureBaseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("HazardIntelligenceServiceTests", isDirectory: true)
            .appendingPathComponent(testName.replacingOccurrences(of: " ", with: "_"), isDirectory: true)
        try? FileManager.default.removeItem(at: secureBaseURL)

        let secureStore = SecureStore(
            namespace: "hazard-service-tests",
            baseURL: secureBaseURL,
            keyProvider: FixedSecureStoreKeyProvider(byte: 7),
            fileManager: .default
        )
        let sensitiveHazardReportService = SensitiveHazardReportService(secureStore: secureStore)
        let sensitiveHazardReportMigrationService = SensitiveHazardReportMigrationService(
            store: store,
            sensitiveHazardReportService: sensitiveHazardReportService
        )

        return HazardPersistenceContext(
            store: store,
            sensitiveHazardReportService: sensitiveHazardReportService,
            sensitiveHazardReportMigrationService: sensitiveHazardReportMigrationService
        )
    }
}

private struct HazardPersistenceContext {
    let store: SQLiteStore
    let sensitiveHazardReportService: SensitiveHazardReportService
    let sensitiveHazardReportMigrationService: SensitiveHazardReportMigrationService
}
