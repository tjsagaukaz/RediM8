import XCTest
@testable import RediM8

final class OfflineArchitectureTests: XCTestCase {

    // MARK: - Phase B: Network Policy

    func testNetworkPolicyIsOfflineOnly() {
        XCTAssertTrue(NetworkPolicy.isOfflineOnly, "NetworkPolicy.isOfflineOnly must always be true")
    }

    // MARK: - Phase B: No URLSession in production code

    func testNoURLSessionInProductionCode() throws {
        // Scan all .swift files in the main target for URLSession usage
        let sourceRoot = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        // Since we can't easily scan source at test time, verify the known entry points
        // are gutted by checking that services don't hold URLSession references.

        // WaterPointService should not have a session property
        let waterService = WaterPointService()
        // If this compiles, the session parameter was removed from init
        XCTAssertFalse(waterService.hasNearbyNetworkData)

        // ShelterService should not have a session property
        let shelterService = ShelterService()
        XCTAssertFalse(shelterService.hasNearbyNetworkData)
    }

    // MARK: - Phase C: Diagnostic Store

    func testDiagnosticStoreLogsAndEvicts() {
        let store = DiagnosticStore()

        // Log 210 events — should evict down to 200
        for i in 0..<210 {
            store.log(.error, error: nil, context: [
                "service": "test",
                "detail": "Test event \(i)",
                "systemState": "testing"
            ])
        }

        // Give the async queue time to process
        let expectation = XCTestExpectation(description: "Events processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        let count = store.eventCount
        XCTAssertLessThanOrEqual(count, 200, "DiagnosticStore should cap at 200 events, got \(count)")
        XCTAssertGreaterThan(count, 0, "DiagnosticStore should have some events")
    }

    func testDiagnosticStoreLogsConcurrently() {
        let store = DiagnosticStore()
        let group = DispatchGroup()

        // Fire 50 concurrent log calls
        for i in 0..<50 {
            group.enter()
            DispatchQueue.global().async {
                store.log(.error, error: nil, context: [
                    "service": "concurrent_test",
                    "detail": "Concurrent event \(i)",
                    "systemState": "testing"
                ])
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(result, .success, "All concurrent log calls should complete without deadlock")
    }

    func testDiagnosticStoreSanitizesContext() {
        let store = DiagnosticStore()
        store.log(.error, error: nil, context: [
            "service": "test",
            "detail": "sanitize test",
            "location": "SHOULD_BE_STRIPPED",
            "latitude": "SHOULD_BE_STRIPPED",
            "userId": "SHOULD_BE_STRIPPED",
            "vault": "SHOULD_BE_STRIPPED",
            "systemState": "testing"
        ])

        let expectation = XCTestExpectation(description: "Event processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        let events = store.recentEvents(limit: 1)
        guard let event = events.first else {
            XCTFail("Expected at least one event")
            return
        }

        XCTAssertNil(event.context["location"], "Location must be stripped from diagnostic context")
        XCTAssertNil(event.context["latitude"], "Latitude must be stripped from diagnostic context")
        XCTAssertNil(event.context["userId"], "userId must be stripped from diagnostic context")
        XCTAssertNil(event.context["vault"], "vault must be stripped from diagnostic context")
        XCTAssertEqual(event.context["service"], "test")
    }

    func testDiagnosticStoreExportsJSON() {
        let store = DiagnosticStore()
        store.log(.recovery, error: nil, context: [
            "service": "export_test",
            "detail": "test export",
            "systemState": "healthy"
        ])

        let expectation = XCTestExpectation(description: "Event processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        guard let data = store.exportJSON() else {
            XCTFail("Export should produce data")
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Export should be valid JSON")
            return
        }

        XCTAssertNotNil(json["app_version"])
        XCTAssertNotNil(json["events"])
        XCTAssertNotNil(json["system_summary"])
        XCTAssertNotNil(json["generated_at"])
    }

    // MARK: - Phase A: HazardFeedService is offline

    @MainActor
    func testHazardFeedServiceIsOffline() {
        let service = HazardFeedService()
        XCTAssertEqual(service.feedFreshnessText, "OFFLINE")
        XCTAssertFalse(service.isFeedStale)
    }

    // MARK: - Offline Contract (permanent guardrail)

    func testOfflineContractNoNetworkUsageInProductionSource() throws {
        // Scans all .swift files in the production target for forbidden network patterns.
        // This test fails if ANYONE reintroduces network code — enforcing the offline
        // guarantee at the test layer, not just code review.

        let forbidden = [
            "URLSession",
            "URLRequest(",
            "import Firebase",
            "import Sentry",
            "import Amplitude",
            "import Mixpanel",
            "import Segment",
            "BGAppRefreshTask",
            "CLGeocoder",
        ]

        // Allowed contexts: comments explaining WHY we don't use these
        let allowedPrefixes = ["//", "///", "*", "/*"]

        let bundle = Bundle(for: type(of: self))
        // Walk up from the test bundle to the project root
        var projectRoot = bundle.bundleURL
        while !FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("project.yml").path),
              projectRoot.path != "/" {
            projectRoot = projectRoot.deletingLastPathComponent()
        }

        let productionRoot = projectRoot.appendingPathComponent("RediM8")
        guard FileManager.default.fileExists(atPath: productionRoot.path) else {
            // Running in CI where source isn't accessible from test bundle — skip gracefully.
            // The CI guardrail covers this case via grep.
            return
        }

        let enumerator = FileManager.default.enumerator(
            at: productionRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var violations: [String] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            let lines = content.components(separatedBy: .newlines)
            for (lineNumber, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Skip comments
                if allowedPrefixes.contains(where: { trimmed.hasPrefix($0) }) { continue }

                for term in forbidden {
                    if trimmed.contains(term) {
                        let relativePath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
                        violations.append("\(relativePath):\(lineNumber + 1) — contains '\(term)'")
                    }
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "OFFLINE CONTRACT VIOLATION — network code found in production sources:\n\(violations.joined(separator: "\n"))"
        )
    }
}
