import Foundation

enum RediM8PlanTier: String, CaseIterable, Identifiable {
    case free = "Free"
    case pro = "RediM8 Pro"

    var id: String { rawValue }
}

enum RediM8PlanInterval: String, CaseIterable, Identifiable {
    case monthly
    case annual
    case lifetime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly:
            L10n.tr("paywall.plan.monthly.title", "Monthly")
        case .annual:
            L10n.tr("paywall.plan.annual.title", "Annual")
        case .lifetime:
            L10n.tr("paywall.plan.lifetime.title", "Lifetime")
        }
    }

    var billingSummary: String {
        switch self {
        case .monthly:
            L10n.tr("paywall.plan.monthly.billing_summary", "Per month")
        case .annual:
            L10n.tr("paywall.plan.annual.billing_summary", "Per year")
        case .lifetime:
            L10n.tr("paywall.plan.lifetime.billing_summary", "One-time")
        }
    }

    var ctaTitle: String {
        switch self {
        case .monthly:
            L10n.tr("paywall.plan.monthly.cta", "Choose Monthly")
        case .annual:
            L10n.tr("paywall.plan.annual.cta", "Start Annual")
        case .lifetime:
            L10n.tr("paywall.plan.lifetime.cta", "Choose Lifetime")
        }
    }

    var productID: ProProductID {
        switch self {
        case .monthly: .monthly
        case .annual: .annual
        case .lifetime: .lifetime
        }
    }
}

struct RediM8ProOffer: Identifiable, Equatable {
    let interval: RediM8PlanInterval
    let priceAUD: Decimal
    let badge: String?
    let detail: String
    let supportingLine: String
    let highlights: [String]

    var id: RediM8PlanInterval { interval }
    var title: String { interval.title }
    var priceText: String { "AUD \(shortPriceText)" }
    var shortPriceText: String { "$\(priceAUD.audString)" }
    var billingSummary: String { interval.billingSummary }
    var ctaTitle: String { interval.ctaTitle }
    var isRecommended: Bool { interval == .annual }
    var isFoundingOffer: Bool { interval == .lifetime }
}

struct RediM8FeatureMatrixRow: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let freeValue: String
    let proValue: String
    let isCoreSafety: Bool
}

enum EmergencyUnlockPhase: String, Equatable {
    case inactive
    case active
    case recentlyEnded
}

struct EmergencyUnlockState: Equatable {
    let phase: EmergencyUnlockPhase
    let triggerAlert: OfficialAlert?
    let activatedAt: Date?
    let accessEndsAt: Date?
    let endedAt: Date?
    let unlockedFeatureIDs: [String]

    static let inactive = EmergencyUnlockState(
        phase: .inactive,
        triggerAlert: nil,
        activatedAt: nil,
        accessEndsAt: nil,
        endedAt: nil,
        unlockedFeatureIDs: []
    )

    static func active(
        alert: OfficialAlert,
        activatedAt: Date,
        accessEndsAt: Date?,
        unlockedFeatureIDs: [String]
    ) -> EmergencyUnlockState {
        EmergencyUnlockState(
            phase: .active,
            triggerAlert: alert,
            activatedAt: activatedAt,
            accessEndsAt: accessEndsAt,
            endedAt: nil,
            unlockedFeatureIDs: unlockedFeatureIDs
        )
    }

    static func recentlyEnded(
        triggerAlert: OfficialAlert?,
        activatedAt: Date?,
        endedAt: Date,
        unlockedFeatureIDs: [String]
    ) -> EmergencyUnlockState {
        EmergencyUnlockState(
            phase: .recentlyEnded,
            triggerAlert: triggerAlert,
            activatedAt: activatedAt,
            accessEndsAt: nil,
            endedAt: endedAt,
            unlockedFeatureIDs: unlockedFeatureIDs
        )
    }

    var isActive: Bool {
        phase == .active
    }

    var isRecentlyEnded: Bool {
        phase == .recentlyEnded
    }

    var isVisible: Bool {
        phase != .inactive
    }

    var featureCount: Int {
        unlockedFeatureIDs.count
    }

    var calloutTitle: String {
        switch phase {
        case .inactive:
            L10n.tr("paywall.emergency_unlock.standby_title", "Emergency Unlock Standby")
        case .active:
            L10n.tr("paywall.emergency_unlock.active_title", "Emergency Unlock Active")
        case .recentlyEnded:
            L10n.tr("paywall.emergency_unlock.ended_title", "Emergency Access Ended")
        }
    }

    var calloutDetail: String {
        switch phase {
        case .inactive:
            return L10n.tr(
                "paywall.emergency_unlock.standby_detail",
                "During qualifying severe official emergencies, RediM8 may temporarily unlock selected Pro capabilities so payment does not become the first decision."
            )
        case .active:
            if let triggerAlert {
                return L10n.format(
                    "paywall.emergency_unlock.active_detail_with_severity",
                    "A qualifying %@ official warning has temporarily unlocked selected RediM8 Pro capabilities while the incident remains active.",
                    triggerAlert.severity.title
                )
            }
            return L10n.tr(
                "paywall.emergency_unlock.active_detail",
                "A qualifying severe official warning has temporarily unlocked selected RediM8 Pro capabilities."
            )
        case .recentlyEnded:
            return L10n.tr(
                "paywall.emergency_unlock.ended_detail",
                "Temporary emergency access has ended. Upgrade to keep these additional tools available anytime."
            )
        }
    }
}

struct RediM8MonetizationCatalog: Equatable {
    let offers: [RediM8ProOffer]
    let featureMatrix: [RediM8FeatureMatrixRow]
    let alwaysFreePromise: String
    let proPromise: String
    let emergencyUnlockPromise: String

    var monthlyOffer: RediM8ProOffer {
        offers.first(where: { $0.interval == .monthly }) ?? offers[0]
    }

    var annualOffer: RediM8ProOffer {
        offers.first(where: { $0.interval == .annual }) ?? offers[0]
    }

    var lifetimeOffer: RediM8ProOffer {
        offers.first(where: { $0.interval == .lifetime }) ?? offers[0]
    }

    var recommendedOffer: RediM8ProOffer {
        offers.first(where: \.isRecommended) ?? annualOffer
    }

    var alwaysFreeRows: [RediM8FeatureMatrixRow] {
        featureMatrix.filter(\.isCoreSafety)
    }

    var proUpgradeRows: [RediM8FeatureMatrixRow] {
        featureMatrix.filter { $0.freeValue != $0.proValue }
    }

    var emergencyUnlockRows: [RediM8FeatureMatrixRow] {
        proUpgradeRows
    }

    var emergencyUnlockFeatureIDs: [String] {
        emergencyUnlockRows.map(\.id)
    }

    var launchPricingSummary: String {
        L10n.format(
            "paywall.pricing.summary",
            "%1$@/mo • %2$@/yr • %3$@ lifetime",
            monthlyOffer.shortPriceText,
            annualOffer.shortPriceText,
            lifetimeOffer.shortPriceText
        )
    }

    static let launch = RediM8MonetizationCatalog(
        offers: [
            RediM8ProOffer(
                interval: .monthly,
                priceAUD: Decimal(string: "6.99") ?? 6.99,
                badge: nil,
                detail: L10n.tr(
                    "paywall.offer.monthly.detail",
                    "Flexible access for storm seasons, travel, or short-term readiness."
                ),
                supportingLine: L10n.tr(
                    "paywall.offer.monthly.supporting_line",
                    "Best for seasonal or short-term readiness."
                ),
                highlights: [
                    L10n.tr("paywall.offer.monthly.highlight.planning", "Advanced planning"),
                    L10n.tr("paywall.offer.monthly.highlight.maps", "Expanded map coverage"),
                    L10n.tr("paywall.offer.monthly.highlight.assistant", "Offline assistant")
                ]
            ),
            RediM8ProOffer(
                interval: .annual,
                priceAUD: Decimal(string: "39.99") ?? 39.99,
                badge: L10n.tr("paywall.offer.annual.badge", "Best Value"),
                detail: L10n.tr(
                    "paywall.offer.annual.detail",
                    "For households who want RediM8 ready year-round."
                ),
                supportingLine: L10n.tr(
                    "paywall.offer.annual.supporting_line",
                    "Best for year-round readiness."
                ),
                highlights: [
                    L10n.tr("paywall.offer.annual.highlight.maps", "Advanced planning tools"),
                    L10n.tr("paywall.offer.annual.highlight.vault", "Expanded offline maps"),
                    L10n.tr("paywall.offer.annual.highlight.value", "Better long-term value")
                ]
            ),
            RediM8ProOffer(
                interval: .lifetime,
                priceAUD: Decimal(string: "119.99") ?? 119.99,
                badge: L10n.tr("paywall.offer.lifetime.badge", "Founding Price"),
                detail: L10n.tr(
                    "paywall.offer.lifetime.detail",
                    "One-time purchase for households that want permanent Pro access."
                ),
                supportingLine: L10n.tr(
                    "paywall.offer.lifetime.supporting_line",
                    "Best for committed long-term use."
                ),
                highlights: [
                    L10n.tr("paywall.offer.lifetime.highlight.access", "One payment"),
                    L10n.tr("paywall.offer.lifetime.highlight.support", "Permanent Pro access"),
                    L10n.tr("paywall.offer.lifetime.highlight.launch", "Supports ongoing map and alert maintenance")
                ]
            )
        ],
        featureMatrix: [
            RediM8FeatureMatrixRow(
                id: "emergency_mode",
                title: L10n.tr("paywall.matrix.emergency_mode.title", "Emergency Mode + Leave Now"),
                detail: L10n.tr(
                    "paywall.matrix.emergency_mode.detail",
                    "Large-button panic flow, emergency actions, and offline quick access."
                ),
                systemImage: "exclamationmark.triangle.fill",
                freeValue: L10n.tr("paywall.matrix.value.included", "Included"),
                proValue: L10n.tr("paywall.matrix.value.included", "Included"),
                isCoreSafety: true
            ),
            RediM8FeatureMatrixRow(
                id: "official_alerts",
                title: L10n.tr("paywall.matrix.official_alerts.title", "Official Alerts Mirror"),
                detail: L10n.tr(
                    "paywall.matrix.official_alerts.detail",
                    "Australian public warning feeds surfaced with trust labels and Safe Mode prompts."
                ),
                systemImage: "antenna.radiowaves.left.and.right",
                freeValue: L10n.tr("paywall.matrix.value.included", "Included"),
                proValue: L10n.tr("paywall.matrix.value.included", "Included"),
                isCoreSafety: true
            ),
            RediM8FeatureMatrixRow(
                id: "basic_routing",
                title: L10n.tr("paywall.matrix.basic_routing.title", "Basic Offline Routing"),
                detail: L10n.tr(
                    "paywall.matrix.basic_routing.detail",
                    "A-to-B offline evacuation routing with a single recommended route."
                ),
                systemImage: "arrow.triangle.turn.up.right.diamond",
                freeValue: L10n.tr("paywall.matrix.value.included", "Included"),
                proValue: L10n.tr("paywall.matrix.value.included", "Included"),
                isCoreSafety: true
            ),
            RediM8FeatureMatrixRow(
                id: "guide_library",
                title: L10n.tr("paywall.matrix.guide_library.title", "Guide Library"),
                detail: L10n.tr(
                    "paywall.matrix.guide_library.detail",
                    "Curated first aid, survival, and evacuation guidance with traceable sources."
                ),
                systemImage: "book.fill",
                freeValue: L10n.tr("paywall.matrix.value.included", "Included"),
                proValue: L10n.tr("paywall.matrix.value.included", "Included"),
                isCoreSafety: true
            ),
            RediM8FeatureMatrixRow(
                id: "mesh_receive",
                title: L10n.tr("paywall.matrix.mesh_receive.title", "Signal — Receive"),
                detail: L10n.tr(
                    "paywall.matrix.mesh_receive.detail",
                    "Receive mesh messages, beacons, and community reports from nearby devices."
                ),
                systemImage: "dot.radiowaves.left.and.right",
                freeValue: L10n.tr("paywall.matrix.value.included", "Included"),
                proValue: L10n.tr("paywall.matrix.value.included", "Included"),
                isCoreSafety: true
            ),
            RediM8FeatureMatrixRow(
                id: "vault",
                title: L10n.tr("paywall.matrix.vault.title", "Secure Vault"),
                detail: L10n.tr(
                    "paywall.matrix.vault.detail",
                    "Emergency info card and critical document access stay local and available offline."
                ),
                systemImage: "lock.doc.fill",
                freeValue: L10n.tr("paywall.matrix.value.documents_3", "3 documents"),
                proValue: L10n.tr("paywall.matrix.value.unlimited", "Unlimited"),
                isCoreSafety: true
            ),
            RediM8FeatureMatrixRow(
                id: "readiness_score",
                title: L10n.tr("paywall.matrix.readiness_score.title", "Readiness Score"),
                detail: L10n.tr(
                    "paywall.matrix.readiness_score.detail",
                    "Overall household preparedness score and priority actions."
                ),
                systemImage: "shield.fill",
                freeValue: L10n.tr("paywall.matrix.value.included", "Included"),
                proValue: L10n.tr("paywall.matrix.value.included", "Included"),
                isCoreSafety: true
            ),
            RediM8FeatureMatrixRow(
                id: "routing_intelligence",
                title: L10n.tr("paywall.matrix.routing_intelligence.title", "Evacuation Intelligence"),
                detail: L10n.tr(
                    "paywall.matrix.routing_intelligence.detail",
                    "Hazard-aware routing, multi-route comparison, corridor analysis, safe zone discovery, and auto-guidance."
                ),
                systemImage: "map.fill",
                freeValue: L10n.tr("paywall.matrix.value.not_included", "—"),
                proValue: L10n.tr("paywall.matrix.value.included", "Included"),
                isCoreSafety: false
            ),
            RediM8FeatureMatrixRow(
                id: "mesh_send",
                title: L10n.tr("paywall.matrix.mesh_send.title", "Signal — Send"),
                detail: L10n.tr(
                    "paywall.matrix.mesh_send.detail",
                    "Send messages, share location and routes, broadcast alerts, and report hazards via mesh."
                ),
                systemImage: "antenna.radiowaves.left.and.right",
                freeValue: L10n.tr("paywall.matrix.value.not_included", "—"),
                proValue: L10n.tr("paywall.matrix.value.included", "Included"),
                isCoreSafety: false
            ),
            RediM8FeatureMatrixRow(
                id: "premium_map_packs",
                title: L10n.tr("paywall.matrix.premium_map_packs.title", "Additional Map Regions"),
                detail: L10n.tr(
                    "paywall.matrix.premium_map_packs.detail",
                    "Download extra offline map regions and basemap packages beyond the default baseline."
                ),
                systemImage: "square.stack.3d.up.fill",
                freeValue: L10n.tr("paywall.matrix.value.region_1", "1 region"),
                proValue: L10n.tr("paywall.matrix.value.unlimited", "Unlimited"),
                isCoreSafety: false
            ),
            RediM8FeatureMatrixRow(
                id: "analytics",
                title: L10n.tr("paywall.matrix.analytics.title", "Preparedness Breakdown"),
                detail: L10n.tr(
                    "paywall.matrix.analytics.detail",
                    "Full category scores, household targets, action plans, and family export."
                ),
                systemImage: "chart.line.uptrend.xyaxis",
                freeValue: L10n.tr("paywall.matrix.value.not_included", "—"),
                proValue: L10n.tr("paywall.matrix.value.included", "Included"),
                isCoreSafety: false
            ),
            RediM8FeatureMatrixRow(
                id: "assistant",
                title: L10n.tr("paywall.matrix.assistant.title", "AI Safe Summaries"),
                detail: L10n.tr(
                    "paywall.matrix.assistant.detail",
                    "AI-generated summaries, context-aware recommendations, and predictive guidance."
                ),
                systemImage: "sparkles",
                freeValue: L10n.tr("paywall.matrix.value.guide_retrieval", "Guide retrieval"),
                proValue: L10n.tr("paywall.matrix.value.safe_summaries", "Safe summaries"),
                isCoreSafety: false
            ),
            RediM8FeatureMatrixRow(
                id: "exports",
                title: L10n.tr("paywall.matrix.exports.title", "Family Export"),
                detail: L10n.tr(
                    "paywall.matrix.exports.detail",
                    "Share comprehensive preparedness bundles with the household."
                ),
                systemImage: "square.and.arrow.up.fill",
                freeValue: L10n.tr("paywall.matrix.value.pdf_export", "PDF export"),
                proValue: L10n.tr("paywall.matrix.value.family_bundle", "Family bundle"),
                isCoreSafety: false
            )
        ],
        alwaysFreePromise: L10n.tr(
            "paywall.promise.always_free",
            "Emergency Mode, official alerts, basic offline routing, guide library, mesh receive, readiness score, and 3 vault documents remain free."
        ),
        proPromise: L10n.tr(
            "paywall.promise.pro",
            "RediM8 Pro adds evacuation intelligence, outbound mesh, additional map regions, deeper readiness analysis, AI summaries, and unlimited vault access."
        ),
        emergencyUnlockPromise: L10n.tr(
            "paywall.promise.emergency_unlock",
            "During qualifying severe official emergencies, RediM8 may temporarily unlock selected Pro capabilities so people can access more help without payment becoming the first decision."
        )
    )
}

private extension Decimal {
    var audString: String {
        String(format: "%.2f", NSDecimalNumber(decimal: self).doubleValue)
    }
}
