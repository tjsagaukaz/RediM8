import CoreLocation
import Foundation

/// Fetches and parses official Australian hazard data feeds.
///
/// **Why this exists**: The hazard intelligence system is only as good as its inputs.
/// Without real data, hazard zones are limited to manual reports and mesh gossip.
/// Official feeds (BOM, state fire services) provide verified, authoritative data
/// that anchors the entire routing and advisory system.
///
/// **Design decisions**:
/// - Uses URLSession directly (no third-party dependencies) for offline-first alignment.
/// - Feed failures do not block the app, but they are surfaced so the UI can warn
///   when route hazard overlays may be stale or incomplete.
/// - All official feed hazards are marked `.officialAlert` source and `.verified`
///   confidence — they override mesh/manual reports via deduplication merging.
/// - Parsing is fault-tolerant: invalid entries are skipped, partial results are used.
///
/// **Data sources**:
/// - BOM severe weather warnings (RSS/XML → GeoRSS)
/// - State fire services (GeoJSON hotspots)
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

    // MARK: - Configuration

    private enum FeedURL {
        /// BOM severe weather warnings — national RSS feed with GeoRSS points.
        /// Contains: severe thunderstorm, flood, cyclone, fire weather warnings.
        static let bomWarnings = "https://www.bom.gov.au/fwo/IDZ00054.warnings_land.xml"

        /// NSW RFS current fires GeoJSON.
        /// Returns active fire incidents with severity and coordinates.
        static let nswRFS = "https://feeds.nsw.gov.au/fire/data.json"

        /// Victoria CFA incidents GeoJSON.
        static let vicCFA = "https://data.emergency.vic.gov.au/Show?pageId=getIncidentJSON"
    }

    // MARK: - State

    @Published private(set) var lastFetchAt: Date?
    @Published private(set) var lastSuccessfulFetch: Date?
    @Published private(set) var lastFetchErrors: [String] = []
    @Published private(set) var lastRefreshError: String?
    @Published private(set) var isFetching = false

    /// Human-readable staleness indicator for the UI.
    var feedFreshnessText: String {
        guard let last = lastSuccessfulFetch else {
            return "NO DATA"
        }
        let elapsed = Date.now.timeIntervalSince(last)
        if elapsed < 120 { return "LIVE" }
        if elapsed < 3600 { return "\(Int(elapsed / 60))M AGO" }
        if elapsed < 86400 { return "\(Int(elapsed / 3600))H AGO" }
        return "\(Int(elapsed / 86400))D AGO"
    }

    /// True when last successful fetch is older than 2× the refresh interval.
    var isFeedStale: Bool {
        guard let last = lastSuccessfulFetch else { return true }
        return Date.now.timeIntervalSince(last) > refreshInterval * 2
    }

    private let session: URLSession
    private var fetchTimer: Timer?

    /// Refresh interval — 15 minutes balances freshness vs battery.
    private let refreshInterval: TimeInterval = 15 * 60

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Lifecycle

    func startPeriodicFetch(into hazardService: HazardIntelligenceService) {
        fetchTimer?.invalidate()
        // Fetch immediately on start, then periodically
        Task { await fetchAllFeeds(into: hazardService) }
        fetchTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.fetchAllFeeds(into: hazardService)
            }
        }
    }

    func stopPeriodicFetch() {
        fetchTimer?.invalidate()
        fetchTimer = nil
    }

    // MARK: - Fetch All

    /// Fetch all configured feeds and push results into the hazard intelligence service.
    /// Failures are non-blocking, but they remain visible so the UI can warn when
    /// hazard overlays may be stale or incomplete.
    func fetchAllFeeds(into hazardService: HazardIntelligenceService) async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        let results = [
            await fetchBOMWarnings(),
            await fetchNSWRFS(),
            await fetchVicCFA()
        ]

        let allErrors = results.flatMap(\.errors)
        results.forEach { ingest($0.hazards, into: hazardService) }

        lastFetchAt = .now
        if let newestSuccessfulFetch = results
            .filter(\.didSucceed)
            .map(\.fetchedAt)
            .max() {
            lastSuccessfulFetch = newestSuccessfulFetch
        }
        lastFetchErrors = allErrors
        lastRefreshError = refreshErrorMessage(for: results)
    }

    /// Push parsed hazards into the intelligence service.
    /// All official feeds get `.officialAlert` source → `.verified` confidence.
    private func ingest(_ hazards: [ParsedHazard], into service: HazardIntelligenceService) {
        for hazard in hazards {
            service.addReport(
                kind: hazard.kind,
                center: hazard.coordinate,
                radiusMetres: hazard.radiusMetres,
                source: .officialAlert,
                severity: hazard.severity,
                description: hazard.description
            )
        }
    }

    // MARK: - BOM Severe Weather Warnings

    /// Parse BOM RSS feed with GeoRSS extensions.
    /// Expected structure: <item> elements with <title>, <description>, <georss:point>.
    private func fetchBOMWarnings() async -> FeedResult {
        guard let url = URL(string: FeedURL.bomWarnings) else {
            return FeedResult(
                source: "BOM",
                hazards: [],
                fetchedAt: .now,
                errors: ["BOM feed URL is invalid."],
                didSucceed: false
            )
        }

        do {
            let (data, _) = try await session.data(from: url)
            let parser = BOMRSSParser(data: data)
            let hazards = parser.parse()
            return FeedResult(
                source: "BOM",
                hazards: hazards,
                fetchedAt: .now,
                errors: parser.errors,
                didSucceed: parser.didParseSuccessfully
            )
        } catch {
            return FeedResult(
                source: "BOM",
                hazards: [],
                fetchedAt: .now,
                errors: [feedErrorMessage(source: "BOM", error: error)],
                didSucceed: false
            )
        }
    }

    // MARK: - NSW RFS Active Fires

    /// Parse NSW RFS GeoJSON feed.
    /// Expected: FeatureCollection with Point geometries and properties including
    /// "category" (1-3), "title", "description".
    private func fetchNSWRFS() async -> FeedResult {
        guard let url = URL(string: FeedURL.nswRFS) else {
            return FeedResult(
                source: "NSW RFS",
                hazards: [],
                fetchedAt: .now,
                errors: ["NSW RFS feed URL is invalid."],
                didSucceed: false
            )
        }

        do {
            let (data, _) = try await session.data(from: url)
            let hazards = try parseGeoJSONFires(data: data, source: "NSW RFS")
            return FeedResult(source: "NSW RFS", hazards: hazards, fetchedAt: .now, errors: [], didSucceed: true)
        } catch {
            return FeedResult(
                source: "NSW RFS",
                hazards: [],
                fetchedAt: .now,
                errors: [feedErrorMessage(source: "NSW RFS", error: error)],
                didSucceed: false
            )
        }
    }

    // MARK: - Victoria CFA Incidents

    private func fetchVicCFA() async -> FeedResult {
        guard let url = URL(string: FeedURL.vicCFA) else {
            return FeedResult(
                source: "Vic CFA",
                hazards: [],
                fetchedAt: .now,
                errors: ["Vic CFA feed URL is invalid."],
                didSucceed: false
            )
        }

        do {
            let (data, _) = try await session.data(from: url)
            let hazards = try parseGeoJSONFires(data: data, source: "Vic CFA")
            return FeedResult(source: "Vic CFA", hazards: hazards, fetchedAt: .now, errors: [], didSucceed: true)
        } catch {
            return FeedResult(
                source: "Vic CFA",
                hazards: [],
                fetchedAt: .now,
                errors: [feedErrorMessage(source: "Vic CFA", error: error)],
                didSucceed: false
            )
        }
    }

    // MARK: - GeoJSON Fire Parser

    /// Generic GeoJSON fire parser. Works for NSW RFS, Vic CFA, and similar feeds.
    /// Expects FeatureCollection → Feature[] → geometry.coordinates + properties.
    private func parseGeoJSONFires(data: Data, source: String) throws -> [ParsedHazard] {
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

            // Determine severity from category/status fields
            let severity = parseSeverity(from: properties)

            // Determine hazard kind — most fire feeds are fires, but some include floods
            let kind = parseKind(from: properties)

            // Title or description
            let title = (properties["title"] as? String)
                ?? (properties["name"] as? String)
                ?? (properties["feedType"] as? String)
                ?? "\(source) incident"

            // Radius from size/area if available, otherwise default
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

    private func refreshErrorMessage(for results: [FeedResult]) -> String? {
        let failedSources = results.filter { !$0.didSucceed }.map(\.source)
        guard !failedSources.isEmpty else {
            return nil
        }

        if failedSources.count == results.count {
            if let lastSuccessfulFetch {
                return "Live hazard feeds could not be refreshed. Route hazard overlays may be stale. Last successful update \(DateFormatter.rediM8Short.string(from: lastSuccessfulFetch))."
            }
            return "Live hazard feeds are unavailable until RediM8 can connect at least once."
        }

        let sourceList = failedSources.joined(separator: ", ")
        return "Some live hazard feeds could not be refreshed (\(sourceList)). Route hazard overlays may be incomplete until those feeds recover."
    }

    private func feedErrorMessage(source: String, error: Error) -> String {
        "\(source) feed unavailable: \(readableError(from: error))"
    }

    private func readableError(from error: Error) -> String {
        if let urlError = error as? URLError {
            return urlError.localizedDescription
        }

        if let cocoaError = error as? CocoaError,
           let description = cocoaError.userInfo[NSLocalizedDescriptionKey] as? String {
            return description
        }

        return error.localizedDescription
    }

    /// Map feed properties to HazardSeverity.
    /// Looks for common fields: category, status, alertLevel, size.
    private func parseSeverity(from properties: [String: Any]) -> HazardIntelligenceService.HazardSeverity {
        // NSW RFS uses integer category (1=watch, 2=advice, 3=emergency)
        if let category = properties["category"] as? Int {
            switch category {
            case 3: return .critical
            case 2: return .high
            default: return .moderate
            }
        }

        // String-based status/alertLevel
        let status = ((properties["status"] as? String) ?? (properties["alertLevel"] as? String) ?? "").lowercased()
        if status.contains("emergency") || status.contains("warning") { return .critical }
        if status.contains("watch") || status.contains("advice") { return .high }
        if status.contains("going") || status.contains("active") { return .moderate }

        return .moderate
    }

    /// Map properties to HazardKind. Default is fire for fire feeds.
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
        // Some feeds include size in hectares
        if let hectares = properties["size"] as? Double, hectares > 0 {
            // Convert hectares to approximate radius: A = πr² → r = √(A/π)
            let areaM2 = hectares * 10_000
            return max(500, sqrt(areaM2 / .pi))
        }
        return HazardIntelligenceService.Config.dynamicRadius(kind: kind, severity: severity)
    }
}

// MARK: - BOM RSS Parser

/// Minimal XML parser for BOM's GeoRSS weather warning feed.
/// Extracts <item> elements with <title>, <description>, and <georss:point>.
private final class BOMRSSParser: NSObject, XMLParserDelegate {
    private let data: Data
    private(set) var errors: [String] = []
    private(set) var didParseSuccessfully = false

    private var hazards: [HazardFeedService.ParsedHazard] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentPoint = ""
    private var inItem = false

    init(data: Data) {
        self.data = data
    }

    func parse() -> [HazardFeedService.ParsedHazard] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        didParseSuccessfully = parser.parse()
        if !didParseSuccessfully {
            errors.append(parser.parserError?.localizedDescription ?? "BOM warning feed could not be parsed.")
        }
        return hazards
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            inItem = true
            currentTitle = ""
            currentDescription = ""
            currentPoint = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "description": currentDescription += string
        case "georss:point", "point": currentPoint += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        guard elementName == "item", inItem else {
            currentElement = ""
            return
        }
        inItem = false

        // Parse georss:point "lat lon"
        let trimmedPoint = currentPoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedPoint.split(separator: " ")
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]),
              (-90...90).contains(lat),
              (-180...180).contains(lon) else {
            if !trimmedPoint.isEmpty {
                errors.append("Invalid GeoRSS point: \(trimmedPoint)")
            }
            return
        }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        // Classify hazard kind from title
        let kind = classifyBOMKind(title: title, description: desc)
        let severity = classifyBOMSeverity(title: title, description: desc)

        hazards.append(HazardFeedService.ParsedHazard(
            kind: kind,
            coordinate: coordinate,
            radiusMetres: HazardIntelligenceService.Config.dynamicRadius(kind: kind, severity: severity),
            severity: severity,
            description: title.isEmpty ? "BOM weather warning" : title
        ))
    }

    /// Classify BOM warning kind from title keywords.
    private func classifyBOMKind(title: String, description: String) -> HazardIntelligenceService.HazardKind {
        let text = (title + " " + description).lowercased()
        if text.contains("flood") { return .flood }
        if text.contains("fire") || text.contains("bushfire") { return .fire }
        if text.contains("storm surge") || text.contains("tsunami") || text.contains("cyclone") { return .stormSurge }
        if text.contains("road") { return .roadClosure }
        // Default severe weather to storm surge (closest match for wind/rain warnings)
        return .stormSurge
    }

    /// Classify BOM warning severity from keywords.
    private func classifyBOMSeverity(title: String, description: String) -> HazardIntelligenceService.HazardSeverity {
        let text = (title + " " + description).lowercased()
        if text.contains("severe") || text.contains("extreme") || text.contains("emergency") { return .critical }
        if text.contains("warning") || text.contains("dangerous") { return .high }
        if text.contains("watch") || text.contains("alert") { return .moderate }
        return .moderate
    }
}
