import CoreLocation
import Foundation

@MainActor
final class OfficialAlertService: ObservableObject {
    private enum StorageKey {
        static let library = "official_alerts.library.v2"
    }

    enum FeedFormat: Equatable {
        case cap
        case waWarningsJSON
        case vicIncidentsJSON
        case tasIncidentsJSON
        case rss
    }

    struct FeedSource: Equatable {
        let id: String
        let name: String
        let jurisdiction: AustralianJurisdiction
        let url: URL
        let format: FeedFormat
    }

    @Published private(set) var library: OfficialAlertLibrary
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshError: String?

    private let store: SQLiteStore?
    private let session: URLSession
    private let feedSources: [FeedSource]

    init(
        store: SQLiteStore?,
        session: URLSession = .shared,
        feedSources: [FeedSource]? = nil,
        cachedLibrary: OfficialAlertLibrary? = nil
    ) {
        self.store = store
        self.session = session
        self.feedSources = feedSources ?? Self.defaultFeedSources
        library = cachedLibrary ?? ((try? store?.load(OfficialAlertLibrary.self, for: StorageKey.library)) ?? .empty)
    }

    var activeAlerts: [OfficialAlert] {
        library.alerts
            .filter(\.isActive)
            .sorted(by: Self.sort(lhs:rhs:))
    }

    var hasCachedData: Bool {
        library.lastUpdated > .distantPast
    }

    var cachedJurisdictions: Set<AustralianJurisdiction> {
        Set(library.sources.map(\.jurisdiction))
    }

    var coverageSummary: String {
        let coverage = cachedJurisdictions
        guard !coverage.isEmpty else {
            return "Offline cache empty"
        }

        if coverage.count == AustralianJurisdiction.allCases.count {
            return "Australia-wide"
        }

        if coverage.count == 1, let jurisdiction = coverage.first {
            return jurisdiction.title
        }

        return "\(coverage.count) jurisdictions cached"
    }

    func refreshIfNeeded(maxAge: TimeInterval = 300) async {
        guard !isRefreshing else {
            return
        }

        let cacheAge = Date().timeIntervalSince(library.lastUpdated)
        guard !hasCachedData || cacheAge > maxAge else {
            return
        }

        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        var mergedAlerts: [OfficialAlert] = []
        var availableSources: [OfficialAlertSource] = []
        var failures: [FeedSource] = []

        for source in feedSources {
            do {
                let request = URLRequest(url: source.url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 15)
                let (data, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, !(200 ..< 300).contains(httpResponse.statusCode) {
                    throw URLError(.badServerResponse)
                }

                let librarySource = OfficialAlertSource(
                    id: source.id,
                    name: source.name,
                    jurisdiction: source.jurisdiction,
                    urlString: source.url.absoluteString
                )
                let alerts = try Self.parseFeed(data, source: librarySource, format: source.format)
                mergedAlerts.append(contentsOf: alerts)
                availableSources.append(librarySource)
            } catch {
                failures.append(source)
            }
        }

        if mergedAlerts.isEmpty {
            if !hasCachedData {
                lastRefreshError = "No cached official warnings available yet. Connect once to mirror current public alerts."
            } else if !failures.isEmpty {
                lastRefreshError = "Official warning refresh failed. Showing the last cached snapshot."
            }
            return
        }

        library = OfficialAlertLibrary(
            lastUpdated: .now,
            sources: availableSources,
            alerts: Self.deduplicate(alerts: mergedAlerts)
        )
        try? store?.save(library, for: StorageKey.library)

        if failures.isEmpty {
            lastRefreshError = nil
        } else {
            let failedJurisdictions = Set(failures.map(\.jurisdiction))
            if failedJurisdictions.count == 1, let jurisdiction = failedJurisdictions.first {
                lastRefreshError = "Some \(jurisdiction.title) official feeds could not be refreshed. Showing the latest successful snapshot."
            } else {
                lastRefreshError = "Some official feeds could not be refreshed. Showing the latest successful snapshot."
            }
        }
    }

    func nearbyAlerts(currentLocation: CLLocation?, installedPacks: [OfflineMapPack]) -> [OfficialAlert] {
        let activeAlerts = activeAlerts
        guard !activeAlerts.isEmpty else {
            return []
        }

        let scopeJurisdictions = Self.matchingJurisdictions(
            currentLocation: currentLocation,
            installedPacks: installedPacks
        )

        var matchedAlerts: [OfficialAlert] = []

        if let currentLocation {
            matchedAlerts.append(contentsOf: activeAlerts.filter { $0.isRelevant(to: currentLocation) })
        }

        matchedAlerts.append(contentsOf: activeAlerts.filter { alert in
            guard alert.isAreaScoped else {
                return false
            }
            return installedPacks.contains { pack in
                Self.alert(alert, intersects: pack)
            }
        })

        matchedAlerts.append(contentsOf: activeAlerts.filter { alert in
            !alert.isAreaScoped && scopeJurisdictions.contains(alert.jurisdiction)
        })

        let deduplicated = Self.deduplicate(alerts: matchedAlerts)
        if let currentLocation {
            return deduplicated.sorted {
                Self.compareDistanceAware(lhs: $0, rhs: $1, referenceLocation: currentLocation)
            }
        }
        return deduplicated.sorted(by: Self.sort(lhs:rhs:))
    }

    func safeModeAlert(currentLocation: CLLocation?, installedPacks: [OfflineMapPack]) -> OfficialAlert? {
        nearbyAlerts(currentLocation: currentLocation, installedPacks: installedPacks)
            .first(where: { $0.isAreaScoped && $0.severity.triggersSafeMode })
    }

    static func parseCAPFeed(_ data: Data, source: OfficialAlertSource) throws -> [OfficialAlert] {
        let parser = XMLParser(data: data)
        let delegate = CAPFeedParser(source: source)
        parser.delegate = delegate

        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }

        return delegate.alerts
    }

    static func parseRSSFeed(_ data: Data, source: OfficialAlertSource) throws -> [OfficialAlert] {
        let parser = XMLParser(data: data)
        let delegate = RSSFeedParser(source: source)
        parser.delegate = delegate

        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }

        return delegate.alerts
    }

    static func parseWAWarningsFeed(_ data: Data, source: OfficialAlertSource) throws -> [OfficialAlert] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let warningDictionaries = root["warnings"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        return warningDictionaries.compactMap { payload in
            let status = text(for: "publishing-status", in: payload)?.lowercased()
            if let status, status != "published" {
                return nil
            }

            let title = text(for: "title", in: payload)
                ?? text(for: "headline", in: payload)
                ?? text(for: "warning-type", in: payload)
                ?? "Official Warning"
            let warningType = text(for: "warning-type", in: payload)
            let headline = text(for: "headline", in: payload)
            let eventTypes = arrayOfStrings(for: "cap-event-type", in: payload)
            let message = stripHTML(text(for: "alert-line", in: payload))
                ?? stripHTML(text(for: "description-note", in: payload))
                ?? stripHTML(text(for: "what-to-do-note", in: payload))
                ?? "Official warning mirrored from public emergency feeds."
            let instruction = stripHTML(text(for: "what-to-do-note", in: payload))
            let areaDescription = text(for: "value", in: payload["location"])
                ?? headline
                ?? source.jurisdiction.title

            let issuedAt = parseDate(text(for: "issued-date-time", in: payload))
                ?? parseDate(text(for: "published-date-time", in: payload))
                ?? parseDate(text(for: "updatedAt", in: payload))
                ?? .now
            let lastUpdated = parseDate(text(for: "updatedAt", in: payload))
                ?? parseDate(text(for: "published-date-time", in: payload))
                ?? issuedAt

            return OfficialAlert(
                id: text(for: "id", in: payload) ?? UUID().uuidString,
                title: title,
                message: message,
                instruction: instruction,
                issuer: "Emergency WA",
                sourceName: source.name,
                sourceURLString: source.urlString,
                jurisdiction: source.jurisdiction,
                kind: inferredKind(from: eventTypes.map { Optional($0) } + [warningType, title, headline, message]),
                severity: inferredSeverity(
                    from: [
                        text(for: "action-statement", in: payload),
                        text(for: "cap-severity", in: payload),
                        warningType,
                        title,
                        message
                    ],
                    defaultValue: .advice
                ),
                regionScope: areaDescription,
                area: geoArea(
                    from: payload["geo-source"],
                    description: areaDescription
                ),
                issuedAt: issuedAt,
                lastUpdated: lastUpdated,
                expiresAt: nil
            )
        }
    }

    static func parseVicIncidentsFeed(_ data: Data, source: OfficialAlertSource) throws -> [OfficialAlert] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        return results.compactMap { payload in
            let incidentStatus = text(for: "incidentStatus", in: payload) ?? ""
            let category1 = text(for: "category1", in: payload)
            let category2 = text(for: "category2", in: payload)
            let incidentType = text(for: "incidentType", in: payload)
            let name = text(for: "name", in: payload)
            let location = text(for: "incidentLocation", in: payload)
            let sourceText = [category1, category2, incidentType, name, location]
            let kind = inferredKind(from: sourceText)

            let isRelevantIncident = kind != .other
                || sourceText.compactMap { $0?.lowercased() }.joined(separator: " ").contains("warning")
            if !isRelevantIncident {
                return nil
            }

            let loweredStatus = incidentStatus.lowercased()
            if loweredStatus.contains("safe")
                || loweredStatus.contains("under control")
                || loweredStatus.contains("contained")
                || loweredStatus.contains("patrol") {
                return nil
            }

            guard let latitude = double(for: "latitude", in: payload),
                  let longitude = double(for: "longitude", in: payload) else {
                return nil
            }

            let title = name?.nilIfBlank ?? incidentType?.nilIfBlank ?? "Victorian Incident"
            let regionScope = text(for: "municipality", in: payload)
                ?? location
                ?? source.jurisdiction.title
            let message = [incidentStatus.nilIfBlank, location?.nilIfBlank, text(for: "fireDistrict", in: payload)?.nilIfBlank]
                .compactMap { $0 }
                .joined(separator: " • ")

            return OfficialAlert(
                id: text(for: "incidentNo", in: payload) ?? UUID().uuidString,
                title: title,
                message: message.nilIfBlank ?? "Official incident mirrored from Victorian emergency feeds.",
                instruction: nil,
                issuer: text(for: "agency", in: payload) ?? source.name,
                sourceName: source.name,
                sourceURLString: source.urlString,
                jurisdiction: source.jurisdiction,
                kind: kind,
                severity: inferredSeverity(
                    from: [incidentStatus, category2, incidentType],
                    defaultValue: kind == .bushfire ? .watchAndAct : .advice
                ),
                regionScope: regionScope,
                area: OfficialAlertArea(
                    description: regionScope,
                    center: GeoPoint(latitude: latitude, longitude: longitude),
                    radiusKilometres: kind == .bushfire ? 12 : 6
                ),
                issuedAt: parseDate(text(for: "originDateTime", in: payload)) ?? .now,
                lastUpdated: parseDate(text(for: "lastUpdateDateTime", in: payload))
                    ?? parseDate(text(for: "lastUpdatedDtStr", in: payload))
                    ?? .now,
                expiresAt: nil
            )
        }
    }

    static func parseTasIncidentsFeed(_ data: Data, source: OfficialAlertSource) throws -> [OfficialAlert] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let incidents = root["data"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        let included = root["included"] as? [[String: Any]] ?? []
        let includedByID = Dictionary(uniqueKeysWithValues: included.compactMap { item -> (String, [String: Any])? in
            guard let id = text(for: "id", in: item) else {
                return nil
            }
            return (id, item)
        })

        return incidents.compactMap { payload in
            guard let attributes = payload["attributes"] as? [String: Any],
                  (attributes["published"] as? Bool) == true else {
                return nil
            }

            let incidentTypeID = text(for: "relationships", "incident_type", "data", "id", in: payload)
            let incidentType = incidentTypeID.flatMap { includedByID[$0] }
            let incidentTypeName = text(for: "name", in: incidentType?["attributes"])
            let incidentTypeIcon = text(for: "event_icon", in: incidentType?["attributes"])
            let status = text(for: "incident_status", in: attributes) ?? ""
            let address = text(for: "address", in: attributes)
            let body = stripHTML(text(for: "body_html", in: attributes))

            let likelyBushfire = [incidentTypeName, incidentTypeIcon, body, address]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
                .contains("bushfire")
            if !likelyBushfire {
                return nil
            }

            let loweredStatus = status.lowercased()
            if loweredStatus.contains("patrol")
                || loweredStatus.contains("contained")
                || loweredStatus.contains("safe") {
                return nil
            }

            let agencyID = text(for: "relationships", "agency", "data", "id", in: payload)
            let agency = agencyID.flatMap { includedByID[$0] }
            let agencyName = text(for: "name", in: agency?["attributes"]) ?? source.name
            let title = incidentTypeName ?? "Tasmanian Bushfire"
            let regionScope = address?.nilIfBlank ?? source.jurisdiction.title

            return OfficialAlert(
                id: text(for: "id", in: payload) ?? UUID().uuidString,
                title: title,
                message: body ?? "Official incident mirrored from Tasmanian public alerts.",
                instruction: nil,
                issuer: agencyName,
                sourceName: source.name,
                sourceURLString: text(for: "links", "self", "href", in: payload),
                jurisdiction: source.jurisdiction,
                kind: .bushfire,
                severity: inferredSeverity(from: [status, title, body], defaultValue: .advice),
                regionScope: regionScope,
                area: nil,
                issuedAt: parseDate(text(for: "published_at", in: attributes))
                    ?? parseDate(text(for: "created", in: attributes))
                    ?? .now,
                lastUpdated: parseDate(text(for: "changed", in: attributes)) ?? .now,
                expiresAt: nil
            )
        }
    }

    private static func parseFeed(_ data: Data, source: OfficialAlertSource, format: FeedFormat) throws -> [OfficialAlert] {
        switch format {
        case .cap:
            try parseCAPFeed(data, source: source)
        case .waWarningsJSON:
            try parseWAWarningsFeed(data, source: source)
        case .vicIncidentsJSON:
            try parseVicIncidentsFeed(data, source: source)
        case .tasIncidentsJSON:
            try parseTasIncidentsFeed(data, source: source)
        case .rss:
            try parseRSSFeed(data, source: source)
        }
    }

    nonisolated private static let defaultFeedSources: [FeedSource] = {
        let raw: [(id: String, name: String, jurisdiction: AustralianJurisdiction, urlString: String, format: FeedFormat)] = [
            (
                "act_cap_warnings",
                "ACT ESA Official Warnings",
                .act,
                "https://data.esa.act.gov.au/feeds/esa-cap-incidents.xml",
                .cap
            ),
            (
                "nsw_cap_warnings",
                "NSW RFS Official Warnings",
                .nsw,
                "https://www.rfs.nsw.gov.au/feeds/majorIncidentsCAP.xml",
                .cap
            ),
            (
                "nt_bom_land_warnings",
                "Northern Territory Official Weather Warnings",
                .nt,
                "https://www.bom.gov.au/fwo/IDZ00062.warnings_land_nt.xml",
                .rss
            ),
            (
                "qld_cap_warnings",
                "Queensland Official Warnings",
                .qld,
                "https://publiccontent-qld-alerts.s3.ap-southeast-2.amazonaws.com/content/Feeds/StormFloodCycloneWarnings/StormWarnings_capau.xml",
                .cap
            ),
            (
                "sa_cap_warnings",
                "South Australia Official Warnings",
                .sa,
                "https://data.eso.sa.gov.au/prod/cfs/criimson/alertsa-fire.xml",
                .cap
            ),
            (
                "tas_incidents",
                "Tasmania Official Incidents",
                .tas,
                "https://api.alert.tas.gov.au/jsonapi/incidents?sort=-changed&page%5Blimit%5D=50&include=agency,incident_type",
                .tasIncidentsJSON
            ),
            (
                "vic_incidents",
                "Victoria Official Incidents",
                .vic,
                "https://data.emergency.vic.gov.au/Show?pageId=getIncidentJSON",
                .vicIncidentsJSON
            ),
            (
                "wa_warnings",
                "Western Australia Official Warnings",
                .wa,
                "https://api.emergency.wa.gov.au/v1/warnings",
                .waWarningsJSON
            )
        ]
        return raw.compactMap { item in
            guard let url = URL(string: item.urlString) else {
                assertionFailure("Invalid feed source URL: \(item.urlString)")
                return nil
            }
            return FeedSource(id: item.id, name: item.name, jurisdiction: item.jurisdiction, url: url, format: item.format)
        }
    }()

    private static func sort(lhs: OfficialAlert, rhs: OfficialAlert) -> Bool {
        if lhs.severity.rank != rhs.severity.rank {
            return lhs.severity.rank < rhs.severity.rank
        }
        if lhs.isAreaScoped != rhs.isAreaScoped {
            return lhs.isAreaScoped
        }
        if lhs.lastUpdated != rhs.lastUpdated {
            return lhs.lastUpdated > rhs.lastUpdated
        }
        return lhs.title < rhs.title
    }

    private static func compareDistanceAware(lhs: OfficialAlert, rhs: OfficialAlert, referenceLocation: CLLocation) -> Bool {
        if lhs.severity.rank != rhs.severity.rank {
            return lhs.severity.rank < rhs.severity.rank
        }

        if lhs.isAreaScoped != rhs.isAreaScoped {
            return lhs.isAreaScoped
        }

        let lhsDistance = lhs.distance(from: referenceLocation)
        let rhsDistance = rhs.distance(from: referenceLocation)
        if lhsDistance != rhsDistance {
            return lhsDistance < rhsDistance
        }

        return lhs.lastUpdated > rhs.lastUpdated
    }

    private static func deduplicate(alerts: [OfficialAlert]) -> [OfficialAlert] {
        let uniqueAlerts = Dictionary(grouping: alerts, by: \.id)
            .compactMap { _, values in
                values.max { lhs, rhs in
                    lhs.lastUpdated < rhs.lastUpdated
                }
            }

        return uniqueAlerts.sorted(by: sort(lhs:rhs:))
    }

    private static func matchingJurisdictions(
        currentLocation: CLLocation?,
        installedPacks: [OfflineMapPack]
    ) -> Set<AustralianJurisdiction> {
        var jurisdictions = Set(installedPacks.compactMap { AustralianJurisdiction.containing($0.center.coordinate) })
        if let currentLocation,
           let jurisdiction = AustralianJurisdiction.containing(currentLocation.coordinate) {
            jurisdictions.insert(jurisdiction)
        }
        return jurisdictions
    }

    private static func alert(_ alert: OfficialAlert, intersects pack: OfflineMapPack) -> Bool {
        guard let area = alert.area else {
            return false
        }

        let packCenter = CLLocation(latitude: pack.center.latitude, longitude: pack.center.longitude)
        let packDiagonalKilometres = max(pack.latitudeDelta, pack.longitudeDelta) * 111
        return alert.distance(from: packCenter) <= area.radiusMetres + (packDiagonalKilometres * 500)
    }

    nonisolated fileprivate static func inferredKind(from texts: [String?]) -> OfficialAlertKind {
        let sourceText = texts
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if sourceText.contains("bushfire")
            || sourceText.contains("grassfire")
            || sourceText.contains("vegetation fire")
            || sourceText.contains("smoke alert") {
            return .bushfire
        }
        if sourceText.contains("flood") {
            return .flood
        }
        if sourceText.contains("cyclone") {
            return .cyclone
        }
        if sourceText.contains("storm")
            || sourceText.contains("rain")
            || sourceText.contains("wind")
            || sourceText.contains("hail") {
            return .severeStorm
        }
        if sourceText.contains("heat") {
            return .heatwave
        }
        return .other
    }

    nonisolated fileprivate static func inferredSeverity(
        from texts: [String?],
        defaultValue: OfficialAlertSeverity = .advice
    ) -> OfficialAlertSeverity {
        let sourceText = texts
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if sourceText.contains("emergency warning")
            || sourceText.contains("leave now")
            || sourceText.contains("evacuate")
            || sourceText.contains("extreme")
            || sourceText.contains("catastrophic") {
            return .emergencyWarning
        }
        if sourceText.contains("watch and act")
            || sourceText.contains("warning")
            || sourceText.contains("prepare")
            || sourceText.contains("responding")
            || sourceText.contains("not yet under control")
            || sourceText.contains("advice")
            || sourceText.contains("severe") {
            return .watchAndAct
        }
        return defaultValue
    }

    nonisolated fileprivate static func parseDate(_ value: String?) -> Date? {
        guard let value = value?.nilIfBlank else {
            return nil
        }

        let sanitized = sanitizeDate(value)
        for formatter in makeISO8601Formatters() {
            if let date = formatter.date(from: sanitized) {
                return date
            }
        }

        for formatter in makeFallbackDateFormatters() {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    nonisolated fileprivate static func stripHTML(_ value: String?) -> String? {
        guard let value = value?.nilIfBlank else {
            return nil
        }

        let withoutBreaks = value.replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
        let withoutTags = withoutBreaks.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let decoded = withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        let condensed = decoded.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return condensed.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
    }

    private static func text(for key: String, in value: Any?) -> String? {
        guard let dictionary = value as? [String: Any] else {
            return nil
        }
        return dictionary[key] as? String
    }

    private static func text(for keyPath: String..., in value: Any?) -> String? {
        var current = value
        for key in keyPath {
            guard let dictionary = current as? [String: Any] else {
                return nil
            }
            current = dictionary[key]
        }
        return current as? String
    }

    private static func arrayOfStrings(for key: String, in value: Any?) -> [String] {
        guard let dictionary = value as? [String: Any],
              let values = dictionary[key] as? [String] else {
            return []
        }
        return values
    }

    private static func double(for key: String, in value: Any?) -> Double? {
        guard let dictionary = value as? [String: Any] else {
            return nil
        }

        if let double = dictionary[key] as? Double {
            return double
        }
        if let number = dictionary[key] as? NSNumber {
            return number.doubleValue
        }
        if let string = dictionary[key] as? String {
            return Double(string)
        }
        return nil
    }

    private static func geoArea(from value: Any?, description: String) -> OfficialAlertArea? {
        guard let dictionary = value as? [String: Any],
              let features = dictionary["features"] as? [[String: Any]] else {
            return nil
        }

        let polygonPairs = features.flatMap { feature -> [CLLocationCoordinate2D] in
            guard let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String,
                  type != "Point" else {
                return []
            }
            return coordinatePairs(from: geometry["coordinates"])
        }

        if let area = buildArea(from: polygonPairs, description: description) {
            return area
        }

        let pointPairs = features.flatMap { feature -> [CLLocationCoordinate2D] in
            guard let geometry = feature["geometry"] as? [String: Any] else {
                return []
            }
            return coordinatePairs(from: geometry["coordinates"])
        }

        if let point = pointPairs.first {
            return OfficialAlertArea(
                description: description,
                center: GeoPoint(latitude: point.latitude, longitude: point.longitude),
                radiusKilometres: 5
            )
        }

        return nil
    }

    private static func buildArea(from coordinates: [CLLocationCoordinate2D], description: String) -> OfficialAlertArea? {
        guard !coordinates.isEmpty else {
            return nil
        }

        let latitude = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let longitude = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        let center = CLLocation(latitude: latitude, longitude: longitude)
        let radiusMetres = coordinates
            .map { point in
                center.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
            }
            .max() ?? 5_000

        return OfficialAlertArea(
            description: description,
            center: GeoPoint(latitude: latitude, longitude: longitude),
            radiusKilometres: max(radiusMetres / 1_000, 1)
        )
    }

    private static func coordinatePairs(from value: Any?) -> [CLLocationCoordinate2D] {
        if let pair = value as? [Double], pair.count >= 2 {
            return [CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])]
        }

        if let pair = value as? [NSNumber], pair.count >= 2 {
            return [CLLocationCoordinate2D(latitude: pair[1].doubleValue, longitude: pair[0].doubleValue)]
        }

        if let array = value as? [Any] {
            return array.flatMap { coordinatePairs(from: $0) }
        }

        return []
    }

    nonisolated private static func sanitizeDate(_ value: String) -> String {
        let pattern = #"([+-]\d{2}:\d{2})([+-]\d{2}:\d{2})$"#
        return value.replacingOccurrences(of: pattern, with: "$2", options: .regularExpression)
    }

    nonisolated private static func makeISO8601Formatters() -> [ISO8601DateFormatter] {
        let internet = ISO8601DateFormatter()
        internet.formatOptions = [.withInternetDateTime]

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return [fractional, internet]
    }

    nonisolated private static func makeFallbackDateFormatters() -> [DateFormatter] {
        let australian = DateFormatter()
        australian.locale = Locale(identifier: "en_AU_POSIX")
        australian.timeZone = TimeZone(secondsFromGMT: 0)
        australian.dateFormat = "dd/MM/yyyy HH:mm:ss"

        let abbreviated = DateFormatter()
        abbreviated.locale = Locale(identifier: "en_US_POSIX")
        abbreviated.timeZone = TimeZone(secondsFromGMT: 0)
        abbreviated.dateFormat = "EEE dd MMM hh:mm a"

        let rss = DateFormatter()
        rss.locale = Locale(identifier: "en_US_POSIX")
        rss.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

        return [australian, abbreviated, rss]
    }
}

private final class CAPFeedParser: NSObject, XMLParserDelegate {
    private struct RawAlert {
        var identifier = ""
        var sent: String?
        var infos: [RawInfo] = []
    }

    private struct RawInfo {
        var language: String?
        var event: String?
        var responseType: String?
        var severity: String?
        var senderName: String?
        var headline: String?
        var description: String?
        var instruction: String?
        var web: String?
        var expires: String?
        var parameters: [String: String] = [:]
        var areas: [RawArea] = []
        var mapURL: String?
    }

    private struct RawArea {
        var areaDescription: String?
        var circle: String?
        var polygon: String?
    }

    private struct RawParameter {
        var name: String?
        var value: String?
    }

    private struct RawResource {
        var description: String?
        var uri: String?
    }

    let source: OfficialAlertSource
    private(set) var alerts: [OfficialAlert] = []

    private var currentText = ""
    private var currentAlert: RawAlert?
    private var currentInfo: RawInfo?
    private var currentArea: RawArea?
    private var currentParameter: RawParameter?
    private var currentResource: RawResource?

    init(source: OfficialAlertSource) {
        self.source = source
    }

    func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes _: [String: String] = [:]
    ) {
        currentText = ""

        switch localName(for: elementName) {
        case "alert":
            currentAlert = RawAlert()
        case "info":
            currentInfo = RawInfo()
        case "area":
            currentArea = RawArea()
        case "parameter":
            currentParameter = RawParameter()
        case "resource":
            currentResource = RawResource()
        default:
            break
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _: XMLParser,
        didEndElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        let name = localName(for: elementName)
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name {
        case "identifier":
            if currentInfo == nil, currentArea == nil, currentParameter == nil, currentResource == nil {
                currentAlert?.identifier = text
            }
        case "sent":
            if currentInfo == nil {
                currentAlert?.sent = text
            }
        case "language":
            currentInfo?.language = text
        case "event":
            currentInfo?.event = text
        case "responseType":
            currentInfo?.responseType = text
        case "severity":
            currentInfo?.severity = text
        case "senderName":
            currentInfo?.senderName = text
        case "headline":
            currentInfo?.headline = text
        case "description":
            currentInfo?.description = text
        case "instruction":
            currentInfo?.instruction = text
        case "web":
            currentInfo?.web = text
        case "expires":
            currentInfo?.expires = text
        case "valueName":
            currentParameter?.name = text
        case "value":
            currentParameter?.value = text
        case "parameter":
            if let parameterName = currentParameter?.name?.nilIfBlank,
               let parameterValue = currentParameter?.value?.nilIfBlank {
                currentInfo?.parameters[parameterName] = parameterValue
            }
            currentParameter = nil
        case "resourceDesc":
            currentResource?.description = text
        case "uri":
            currentResource?.uri = text
        case "resource":
            if currentResource?.description?.lowercased() == "map" {
                currentInfo?.mapURL = currentResource?.uri
            }
            currentResource = nil
        case "areaDesc":
            currentArea?.areaDescription = text
        case "circle":
            currentArea?.circle = text
        case "polygon":
            currentArea?.polygon = text
        case "area":
            if let currentArea {
                currentInfo?.areas.append(currentArea)
            }
            self.currentArea = nil
        case "info":
            if let currentInfo {
                currentAlert?.infos.append(currentInfo)
            }
            self.currentInfo = nil
        case "alert":
            if let alert = buildAlert(from: currentAlert) {
                alerts.append(alert)
            }
            currentAlert = nil
        default:
            break
        }

        currentText = ""
    }

    private func buildAlert(from rawAlert: RawAlert?) -> OfficialAlert? {
        guard let rawAlert, let info = selectInfo(from: rawAlert.infos) else {
            return nil
        }

        let area = info.areas.compactMap(resolveArea(from:)).first
        guard let area else {
            return nil
        }

        let issuer = info.parameters["ControlAuthority"]?.nilIfBlank
            ?? info.senderName?.nilIfBlank
            ?? source.name
        let headline = info.headline?.nilIfBlank ?? OfficialAlertService.inferredKind(from: [info.event, info.parameters["Hazard"]]).title
        let message = info.description?.nilIfBlank
            ?? info.instruction?.nilIfBlank
            ?? "Official warning mirrored from public emergency feeds."
        let sent = OfficialAlertService.parseDate(rawAlert.sent) ?? .now
        let expires = OfficialAlertService.parseDate(info.expires)
        let areaDescription = info.parameters["Location"]?.nilIfBlank
            ?? info.areas.first?.areaDescription?.nilIfBlank
            ?? "\(source.jurisdiction.title) official warning area"

        return OfficialAlert(
            id: rawAlert.identifier.nilIfBlank ?? UUID().uuidString,
            title: headline,
            message: message,
            instruction: info.instruction?.nilIfBlank,
            issuer: issuer,
            sourceName: source.name,
            sourceURLString: info.mapURL?.nilIfBlank ?? info.web?.nilIfBlank ?? source.urlString,
            jurisdiction: source.jurisdiction,
            kind: OfficialAlertService.inferredKind(from: [info.event, info.parameters["Hazard"], info.headline, info.description]),
            severity: OfficialAlertService.inferredSeverity(
                from: [info.parameters["AlertLevel"], info.responseType, info.severity, info.headline, info.description],
                defaultValue: .advice
            ),
            regionScope: areaDescription,
            area: area,
            issuedAt: sent,
            lastUpdated: sent,
            expiresAt: expires
        )
    }

    private func selectInfo(from infos: [RawInfo]) -> RawInfo? {
        infos.first { ($0.language?.lowercased().hasPrefix("en")) ?? true } ?? infos.first
    }

    private func resolveArea(from rawArea: RawArea) -> OfficialAlertArea? {
        if let circle = rawArea.circle?.nilIfBlank,
           let resolved = Self.resolveCircle(circle) {
            return OfficialAlertArea(
                description: rawArea.areaDescription?.nilIfBlank ?? "Official warning area",
                center: resolved.center,
                radiusKilometres: resolved.radiusKilometres
            )
        }

        if let polygon = rawArea.polygon?.nilIfBlank,
           let resolved = Self.resolvePolygon(polygon) {
            return OfficialAlertArea(
                description: rawArea.areaDescription?.nilIfBlank ?? "Official warning area",
                center: resolved.center,
                radiusKilometres: resolved.radiusKilometres
            )
        }

        return nil
    }

    private func localName(for elementName: String) -> String {
        elementName.split(separator: ":").last.map(String.init) ?? elementName
    }

    private static func resolveCircle(_ value: String) -> (center: GeoPoint, radiusKilometres: Double)? {
        let parts = value.split(separator: " ")
        guard parts.count >= 2 else {
            return nil
        }

        let coordinates = parts[0].split(separator: ",")
        guard coordinates.count == 2,
              let latitude = Double(coordinates[0]),
              let longitude = Double(coordinates[1]),
              let radiusKilometres = Double(parts[1]) else {
            return nil
        }

        return (
            center: GeoPoint(latitude: latitude, longitude: longitude),
            radiusKilometres: max(radiusKilometres, 1)
        )
    }

    private static func resolvePolygon(_ value: String) -> (center: GeoPoint, radiusKilometres: Double)? {
        let coordinates: [CLLocationCoordinate2D] = value
            .split(separator: " ")
            .compactMap { pair in
                let parts = pair.split(separator: ",")
                guard parts.count == 2,
                      let latitude = Double(parts[0]),
                      let longitude = Double(parts[1]) else {
                    return nil
                }
                return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }

        guard !coordinates.isEmpty else {
            return nil
        }

        let latitude = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let longitude = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        let center = CLLocation(latitude: latitude, longitude: longitude)
        let maxRadius = coordinates
            .map { point in
                center.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
            }
            .max() ?? 1_000

        return (
            center: GeoPoint(latitude: latitude, longitude: longitude),
            radiusKilometres: max(maxRadius / 1_000, 1)
        )
    }
}

private final class RSSFeedParser: NSObject, XMLParserDelegate {
    private struct RawItem {
        var title: String?
        var description: String?
        var link: String?
        var pubDate: String?
    }

    let source: OfficialAlertSource
    private(set) var alerts: [OfficialAlert] = []

    private var currentText = ""
    private var currentItem: RawItem?

    init(source: OfficialAlertSource) {
        self.source = source
    }

    func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes _: [String: String] = [:]
    ) {
        currentText = ""
        if localName(for: elementName) == "item" {
            currentItem = RawItem()
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _: XMLParser,
        didEndElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        let name = localName(for: elementName)
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch name {
        case "title":
            currentItem?.title = text
        case "description":
            currentItem?.description = text
        case "link":
            currentItem?.link = text
        case "pubDate":
            currentItem?.pubDate = text
        case "item":
            if let alert = buildAlert(from: currentItem) {
                alerts.append(alert)
            }
            currentItem = nil
        default:
            break
        }

        currentText = ""
    }

    private func buildAlert(from rawItem: RawItem?) -> OfficialAlert? {
        guard let rawItem,
              let title = rawItem.title?.nilIfBlank else {
            return nil
        }

        let description = OfficialAlertService.stripHTML(rawItem.description) ?? "Official warning mirrored from public weather feeds."
        return OfficialAlert(
            id: rawItem.link?.nilIfBlank ?? title,
            title: title,
            message: description,
            instruction: nil,
            issuer: "Bureau of Meteorology",
            sourceName: source.name,
            sourceURLString: rawItem.link?.nilIfBlank ?? source.urlString,
            jurisdiction: source.jurisdiction,
            kind: OfficialAlertService.inferredKind(from: [title, description]),
            severity: OfficialAlertService.inferredSeverity(from: [title, description], defaultValue: .advice),
            regionScope: source.jurisdiction.title,
            area: nil,
            issuedAt: OfficialAlertService.parseDate(rawItem.pubDate) ?? .now,
            lastUpdated: OfficialAlertService.parseDate(rawItem.pubDate) ?? .now,
            expiresAt: nil
        )
    }

    private func localName(for elementName: String) -> String {
        elementName.split(separator: ":").last.map(String.init) ?? elementName
    }
}
