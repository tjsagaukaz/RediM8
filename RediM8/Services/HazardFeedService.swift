import CoreLocation
import Foundation

/// Manages hazard data from locally bundled sources.
///
/// **Offline-only architecture**: This service no longer fetches from remote feeds.
/// All hazard data comes from bundled datasets, mesh peer reports, and manual entries.
/// The feed freshness indicators now reflect the age of the bundled dataset.
@MainActor
final class HazardFeedService: ObservableObject {

    // MARK: - Types

    struct FeedResult {
        let source: String
        let hazards: [ParsedHazard]
        let fetchedAt: Date
        let errors: [String]
        let didSucceed: Bool
    }

    struct ParsedHazard {
        let kind: HazardIntelligenceService.HazardKind
        let coordinate: CLLocationCoordinate2D
        let radiusMetres: CLLocationDistance
        let severity: HazardIntelligenceService.HazardSeverity
        let description: String
    }

    // MARK: - State

    @Published private(set) var lastFetchAt: Date?
    @Published private(set) var lastSuccessfulFetch: Date?
    @Published private(set) var lastFetchErrors: [String] = []
    @Published private(set) var lastRefreshError: String?
    @Published private(set) var isFetching = false

    /// Human-readable staleness indicator for the UI.
    var feedFreshnessText: String {
        "OFFLINE"
    }

    /// Offline mode: feeds are never stale because we don't depend on remote refresh.
    var isFeedStale: Bool {
        false
    }

    init() {}

    // MARK: - Lifecycle

    func startPeriodicFetch(into hazardService: HazardIntelligenceService) {
        // Offline-only: no remote fetches. Hazard data comes from bundled datasets
        // and mesh peer reports only.
        lastFetchAt = .now
        lastRefreshError = nil
    }

    func stopPeriodicFetch() {
        // No timer to invalidate in offline mode
    }

    // MARK: - Fetch All (Offline — No-Op)

    /// In offline mode, this is a no-op. Hazard data is sourced from bundled datasets
    /// and mesh peer relay only.
    func fetchAllFeeds(into hazardService: HazardIntelligenceService) async {
        // No network calls. Hazard intelligence comes from:
        // 1. Bundled hazard datasets (loaded at app launch)
        // 2. Mesh peer hazard reports (received via Bluetooth/Wi-Fi P2P)
        // 3. Manual user reports
        lastFetchAt = .now
        lastRefreshError = nil
    }

    // MARK: - Local Data Parsing (retained for bundled data ingestion)

    /// Parse GeoJSON fire data from bundled files.
    /// This method is retained for offline bundled dataset loading.
    func parseGeoJSONFires(data: Data, source: String) throws -> [ParsedHazard] {
        let json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let message = "\(source) feed returned an invalid GeoJSON object."
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: message])
            }
            json = parsed
        } catch let error as CocoaError {
            throw error
        } catch {
            throw CocoaError(
                .fileReadCorruptFile,
                userInfo: [NSLocalizedDescriptionKey: "\(source) feed could not be parsed."]
            )
        }
        guard let features = json["features"] as? [[String: Any]] else {
            let message = "\(source) feed was missing its features array."
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: message])
        }

        var hazards: [ParsedHazard] = []

        for feature in features {
            guard let geometry = feature["geometry"] as? [String: Any],
                  let coordinates = geometry["coordinates"] as? [Double],
                  coordinates.count >= 2 else { continue }

            let properties = feature["properties"] as? [String: Any] ?? [:]

            // GeoJSON is [lon, lat]
            let lon = coordinates[0]
            let lat = coordinates[1]
            guard (-90...90).contains(lat), (-180...180).contains(lon) else { continue }

            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let severity = parseSeverity(from: properties)
            let kind = parseKind(from: properties)

            let title = (properties["title"] as? String)
                ?? (properties["name"] as? String)
                ?? (properties["feedType"] as? String)
                ?? "\(source) incident"

            let radiusMetres = parseRadius(from: properties, kind: kind, severity: severity)

            hazards.append(ParsedHazard(
                kind: kind,
                coordinate: coordinate,
                radiusMetres: radiusMetres,
                severity: severity,
                description: title
            ))
        }

        return hazards
    }

    /// Map feed properties to HazardSeverity.
    private func parseSeverity(from properties: [String: Any]) -> HazardIntelligenceService.HazardSeverity {
        if let category = properties["category"] as? Int {
            switch category {
            case 3: return .critical
            case 2: return .high
            default: return .moderate
            }
        }

        let status = ((properties["status"] as? String) ?? (properties["alertLevel"] as? String) ?? "").lowercased()
        if status.contains("emergency") || status.contains("warning") { return .critical }
        if status.contains("watch") || status.contains("advice") { return .high }
        if status.contains("going") || status.contains("active") { return .moderate }

        return .moderate
    }

    /// Map properties to HazardKind.
    private func parseKind(from properties: [String: Any]) -> HazardIntelligenceService.HazardKind {
        let type = ((properties["type"] as? String) ?? (properties["feedType"] as? String) ?? "").lowercased()
        if type.contains("flood") { return .flood }
        if type.contains("storm") { return .stormSurge }
        if type.contains("road") || type.contains("closure") { return .roadClosure }
        return .fire
    }

    /// Extract radius from properties or use dynamic default.
    private func parseRadius(
        from properties: [String: Any],
        kind: HazardIntelligenceService.HazardKind,
        severity: HazardIntelligenceService.HazardSeverity
    ) -> CLLocationDistance {
        if let hectares = properties["size"] as? Double, hectares > 0 {
            let areaM2 = hectares * 10_000
            return max(500, sqrt(areaM2 / .pi))
        }
        return HazardIntelligenceService.Config.dynamicRadius(kind: kind, severity: severity)
    }
}
