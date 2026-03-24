import XCTest
@testable import RediM8

final class DataFreshnessTests: XCTestCase {

    // MARK: - Threshold Evaluation

    func testCurrentDataReturnsCurrentFreshness() {
        let now = Date()
        let recent = now.addingTimeInterval(-7 * 86400) // 7 days ago
        let result = TrustLayer.dataFreshness(lastUpdated: recent, sourceKind: .curatedBundle, reference: now)
        XCTAssertEqual(result, .current)
    }

    func testAgingDataReturnsAgingFreshness() {
        let now = Date()
        let aging = now.addingTimeInterval(-120 * 86400) // 120 days ago — past 90-day current threshold
        let result = TrustLayer.dataFreshness(lastUpdated: aging, sourceKind: .curatedBundle, reference: now)
        XCTAssertEqual(result, .aging)
    }

    func testStaleDataReturnsStaleFreshness() {
        let now = Date()
        let stale = now.addingTimeInterval(-200 * 86400) // 200 days ago — past 180-day aging threshold
        let result = TrustLayer.dataFreshness(lastUpdated: stale, sourceKind: .curatedBundle, reference: now)
        XCTAssertEqual(result, .stale)
    }

    func testOutdatedDataReturnsOutdatedFreshness() {
        let now = Date()
        let outdated = now.addingTimeInterval(-400 * 86400) // 400 days ago — past 365-day stale threshold
        let result = TrustLayer.dataFreshness(lastUpdated: outdated, sourceKind: .curatedBundle, reference: now)
        XCTAssertEqual(result, .outdated)
    }

    // MARK: - Source Kind Thresholds

    func testBaselineFacilityHasLongerThresholds() {
        let now = Date()
        // 200 days is stale for curatedBundle but current for baselineFacility (180-day threshold)
        let age = now.addingTimeInterval(-150 * 86400)
        XCTAssertEqual(TrustLayer.dataFreshness(lastUpdated: age, sourceKind: .curatedBundle, reference: now), .aging)
        XCTAssertEqual(TrustLayer.dataFreshness(lastUpdated: age, sourceKind: .baselineFacility, reference: now), .current)
    }

    func testOpenMapDataHasShorterThresholds() {
        let now = Date()
        // 70 days is current for curatedBundle but aging for openMapData (60-day threshold)
        let age = now.addingTimeInterval(-70 * 86400)
        XCTAssertEqual(TrustLayer.dataFreshness(lastUpdated: age, sourceKind: .curatedBundle, reference: now), .current)
        XCTAssertEqual(TrustLayer.dataFreshness(lastUpdated: age, sourceKind: .openMapData, reference: now), .aging)
    }

    // MARK: - Warning Properties

    func testCurrentDoesNotWarn() {
        XCTAssertFalse(DataFreshness.current.shouldWarn)
    }

    func testAgingDoesNotWarn() {
        XCTAssertFalse(DataFreshness.aging.shouldWarn)
    }

    func testStaleWarns() {
        XCTAssertTrue(DataFreshness.stale.shouldWarn)
    }

    func testOutdatedWarns() {
        XCTAssertTrue(DataFreshness.outdated.shouldWarn)
    }

    // MARK: - Severity Ordering

    func testSeverityIncreasesWithStaleness() {
        XCTAssertLessThan(DataFreshness.current.severity, DataFreshness.aging.severity)
        XCTAssertLessThan(DataFreshness.aging.severity, DataFreshness.stale.severity)
        XCTAssertLessThan(DataFreshness.stale.severity, DataFreshness.outdated.severity)
    }

    // MARK: - Labels

    func testStaleHasWarningText() {
        XCTAssertNotNil(DataFreshness.stale.warningText)
    }

    func testOutdatedHasWarningText() {
        XCTAssertNotNil(DataFreshness.outdated.warningText)
    }

    func testCurrentHasNoWarningText() {
        XCTAssertNil(DataFreshness.current.warningText)
    }

    // MARK: - Distant Past Edge Case

    func testDistantPastIsOutdated() {
        let result = TrustLayer.dataFreshness(lastUpdated: .distantPast, sourceKind: .curatedBundle)
        XCTAssertEqual(result, .outdated)
    }

    // MARK: - Impact Messages

    func testImpactMessageExistsForAllSourceKinds() {
        for kind in MapFeatureSourceKind.allCases {
            let message = DataFreshness.impactMessage(for: kind)
            XCTAssertFalse(message.isEmpty, "Impact message should not be empty for \(kind)")
        }
    }

    func testImpactMessageVariesBySourceKind() {
        let water = DataFreshness.impactMessage(for: .curatedBundle)
        let facility = DataFreshness.impactMessage(for: .baselineFacility)
        XCTAssertNotEqual(water, facility, "Different source kinds should have distinct impact messages")
    }
}
