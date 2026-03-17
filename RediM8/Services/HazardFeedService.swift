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
/// - Network failures are silent — this is a background enrichment service, not a
///   blocking dependency. The app functions without connectivity.
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
        static let bomWarnings = "http://www.bom.gov.au/fwo/IDZ00054.warnings_land.xml"

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
    /// Network failures are silently absorbed — offline-first.
    func fetchAllFeeds(into hazardService: HazardIntelligenceService) async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        var allErrors: [String] = []

        // Fetch BOM warnings
        let bomResult = await fetchBOMWarnings()
        allErrors.append(contentsOf: bomResult.errors)
        ingest(bomResult.hazards, into: hazardService)

        // Fetch NSW RFS fires
        let rfsResult = await fetchNSWRFS()
        allErrors.append(contentsOf: rfsResult.errors)
        ingest(rfsResult.hazards, into: hazardService)

        // Fetch Vic CFA incidents
        let cfaResult = await fetchVicCFA()
        allErrors.append(contentsOf: cfaResult.errors)
        ingest(cfaResult.hazards, into: hazardService)

        let totalIngested = bomResult.hazards.count + rfsResult.hazards.count + cfaResult.hazards.count
        lastFetchAt = .now
        if totalIngested > 0 {
            lastSuccessfulFetch = .now
        }
        lastFetchErrors = allErrors
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
            return FeedResult(source: "BOM", hazards: [], fetchedAt: .now, errors: ["Invalid BOM URL"])
        }

        do {
            let (data, _) = try await session.data(from: url)
            let parser = BOMRSSParser(data: data)
            let hazards = parser.parse()
            return FeedResult(source: "BOM", hazards: hazards, fetchedAt: .now, errors: parser.errors)
        } catch {
            return FeedResult(source: "BOM", hazards: [], fetchedAt: .now, errors: [])
        }
    }

    // MARK: - NSW RFS Active Fires

    /// Parse NSW RFS GeoJSON feed.
    /// Expected: FeatureCollection with Point geometries and properties including
    /// "category" (1-3), "title", "description".
    private func fetchNSWRFS() async -> FeedResult {
        guard let url = URL(string: FeedURL.nswRFS) else {
            return FeedResult(source: "NSW RFS", hazards: [], fetchedAt: .now, errors: ["Invalid RFS URL"])
        }

        do {
            let (data, _) = try await session.data(from: url)
            let hazards = parseGeoJSONFires(data: data, source: "NSW RFS")
            return FeedResult(source: "NSW RFS", hazards: hazards, fetchedAt: .now, errors: [])
        } catch {
            return FeedResult(source: "NSW RFS", hazards: [], fetchedAt: .now, errors: [])
        }
    }

    // MARK: - Victoria CFA Incidents

    private func fetchVicCFA() async -> FeedResult {
        guard let url = URL(string: FeedURL.vicCFA) else {
            return FeedResult(source: "Vic CFA", hazards: [], fetchedAt: .now, errors: ["Invalid CFA URL"])
        }

        do {
            let (data, _) = try await session.data(from: url)
            let hazards = parseGeoJSONFires(data: data, source: "Vic CFA")
            return FeedResult(source: "Vic CFA", hazards: hazards, fetchedAt: .now, errors: [])
        } catch {
            return FeedResult(source: "Vic CFA", hazards: [], fetchedAt: .now, errors: [])
        }
    }

    // MARK: - GeoJSON Fire Parser

    /// Generic GeoJSON fire parser. Works for NSW RFS, Vic CFA, and similar feeds.
    /// Expects FeatureCollection → Feature[] → geometry.coordinates + properties.
    private func parseGeoJSONFires(data: Data, source: String) -> [ParsedHazard] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else {
            return []
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
        parser.parse()
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
