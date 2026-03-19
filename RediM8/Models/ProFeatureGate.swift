import Foundation

/// Central feature-gating model for RediM8 Pro.
///
/// Philosophy: "Free = survive. Pro = survive smarter, faster, safer."
/// Core safety features are always free. Intelligence, analytics,
/// expanded capacity, and outbound mesh are gated behind Pro.
///
/// Emergency unlock temporarily grants full Pro access during
/// nearby severe official warnings — no billing check required.
enum ProFeatureGate {

    // MARK: - Routing Intelligence

    /// Basic A→B offline routing is always free.
    static func allowsBasicRouting(isProUser: Bool) -> Bool { true }

    /// Multi-route comparison, hazard-aware ranking, corridor analysis,
    /// safe zone discovery, and auto-guidance require Pro.
    static func allowsAdvancedRoutingIntelligence(isProUser: Bool) -> Bool { isProUser }

    // MARK: - AI / Assistant

    /// Deterministic guide retrieval is always free.
    static func allowsGuideRetrieval(isProUser: Bool) -> Bool { true }

    /// AI safe summaries, context-aware recommendations, and predictive
    /// warnings require Pro.
    static func allowsAISummaries(isProUser: Bool) -> Bool { isProUser }

    // MARK: - Maps

    /// One offline map region (the recommended/bundled baseline) is free.
    static let freeMapPackLimit = 1

    /// Additional regions and advanced overlays require Pro.
    static func allowsAdditionalMapPacks(isProUser: Bool, currentPackCount: Int) -> Bool {
        isProUser || currentPackCount < freeMapPackLimit
    }

    // MARK: - Mesh / Signal

    /// Receiving mesh messages, beacons, and community reports is always free.
    static func allowsMeshReceive(isProUser: Bool) -> Bool { true }

    /// Sending mesh messages, sharing location/routes, broadcasting alerts,
    /// and reporting hazards require Pro.
    static func allowsMeshSend(isProUser: Bool) -> Bool { isProUser }

    // MARK: - Vault

    /// Free tier stores up to 3 documents.
    static let freeVaultDocumentLimit = 3

    /// Additional documents and biometric unlock require Pro.
    static func allowsAdditionalVaultDocuments(isProUser: Bool, currentDocumentCount: Int) -> Bool {
        isProUser || currentDocumentCount < freeVaultDocumentLimit
    }

    // MARK: - Preparedness Analytics

    /// Overall readiness score is always free.
    static func allowsReadinessScore(isProUser: Bool) -> Bool { true }

    /// Category breakdown, household targets, action plans,
    /// and family export require Pro.
    static func allowsPreparednessBreakdown(isProUser: Bool) -> Bool { isProUser }

    // MARK: - Exports

    /// Basic PDF export is free. Family bundle export requires Pro.
    static func allowsFamilyExport(isProUser: Bool) -> Bool { isProUser }

    // MARK: - Contextual Paywall Copy

    /// Returns a short, action-oriented upgrade prompt for the given context.
    /// Uses "Unlock X Intelligence" framing, not "Upgrade to Pro".
    static func paywallTitle(for context: PaywallContext) -> String {
        switch context {
        case .routingIntelligence:
            "Unlock Advanced Evacuation Intelligence"
        case .safeZoneDiscovery:
            "Unlock Safe Zone Discovery"
        case .corridorAnalysis:
            "Unlock Corridor Analysis"
        case .multiRoute:
            "Unlock Multi-Route Comparison"
        case .meshSend:
            "Unlock Outbound Signal"
        case .vault:
            "Unlock Expanded Vault"
        case .mapPacks:
            "Unlock Additional Map Regions"
        case .aiSummaries:
            "Unlock AI Safe Summaries"
        case .preparedness:
            "Unlock Preparedness Breakdown"
        case .familyExport:
            "Unlock Family Export"
        }
    }

    /// Returns a contextual subtitle explaining the value proposition.
    static func paywallSubtitle(for context: PaywallContext) -> String {
        switch context {
        case .routingIntelligence:
            "Hazard-aware routing, corridor analysis, and safe zone discovery help you move smarter when it matters most."
        case .safeZoneDiscovery:
            "Scan for the safest nearby destinations based on distance, hazard exposure, and available resources."
        case .corridorAnalysis:
            "See water, shelter, and service coverage along every route before you commit to moving."
        case .multiRoute:
            "Compare alternative routes ranked by distance, hazard exposure, and resource access."
        case .meshSend:
            "Send messages, share your location, and broadcast alerts to nearby devices via short-range mesh."
        case .vault:
            "Store unlimited emergency documents with encryption. Free tier includes 3 documents."
        case .mapPacks:
            "Download additional offline map regions for broader coverage. Free tier includes 1 region."
        case .aiSummaries:
            "Get AI-generated safe summaries and context-aware guidance from the offline assistant."
        case .preparedness:
            "See full category scores, household targets, and tailored improvement guidance."
        case .familyExport:
            "Share a comprehensive preparedness bundle with your household."
        }
    }

    enum PaywallContext: String, CaseIterable {
        case routingIntelligence
        case safeZoneDiscovery
        case corridorAnalysis
        case multiRoute
        case meshSend
        case vault
        case mapPacks
        case aiSummaries
        case preparedness
        case familyExport
    }
}
