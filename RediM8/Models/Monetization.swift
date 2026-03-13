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
            "Monthly"
        case .annual:
            "Annual"
        case .lifetime:
            "Lifetime"
        }
    }

    var billingSummary: String {
        switch self {
        case .monthly:
            "Billed monthly"
        case .annual:
            "Billed yearly"
        case .lifetime:
            "One-time purchase"
        }
    }

    var ctaTitle: String {
        switch self {
        case .monthly:
            "Choose Monthly"
        case .annual:
            "Choose Annual"
        case .lifetime:
            "Choose Lifetime"
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
            "Emergency Unlock Standby"
        case .active:
            "Emergency Unlock Active"
        case .recentlyEnded:
            "Emergency Access Ended"
        }
    }

    var calloutDetail: String {
        switch phase {
        case .inactive:
            return "When RediM8 detects a nearby severe official warning, it can temporarily unlock Pro tools without billing."
        case .active:
            if let triggerAlert {
                return "\(triggerAlert.severity.title) official warning near you has temporarily unlocked RediM8 Pro tools while the incident remains active."
            }
            return "A nearby severe official warning has temporarily unlocked RediM8 Pro tools."
        case .recentlyEnded:
            return "Temporary emergency access has ended. Upgrade to keep RediM8 Pro tools available anytime."
        }
    }
}

struct RediM8MonetizationCatalog: Equatable {
    let offers: [RediM8ProOffer]
    let featureMatrix: [RediM8FeatureMatrixRow]
    let alwaysFreePromise: String
    let proPromise: String
    let emergencyUnlockPromise: String
    let billingPreviewNotice: String

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
        "\(monthlyOffer.shortPriceText)/mo • \(annualOffer.shortPriceText)/yr • \(lifetimeOffer.shortPriceText) lifetime"
    }

    static let launch = RediM8MonetizationCatalog(
        offers: [
            RediM8ProOffer(
                interval: .monthly,
                priceAUD: Decimal(string: "6.99") ?? 6.99,
                badge: nil,
                detail: "Flexible month-to-month access for seasonal readiness, remote travel, and storm periods.",
                supportingLine: "Best for short-term travel or bushfire season prep.",
                highlights: [
                    "Advanced planning tools",
                    "Expanded offline map coverage",
                    "Offline assistant safe summaries"
                ]
            ),
            RediM8ProOffer(
                interval: .annual,
                priceAUD: Decimal(string: "39.99") ?? 39.99,
                badge: "Best Value",
                detail: "The strongest year-round value for households who want RediM8 ready across every season.",
                supportingLine: "Recommended default plan for most users.",
                highlights: [
                    "Premium map packs and planning analytics",
                    "Expanded vault and export tools",
                    "Less than six monthly renewals over a full year"
                ]
            ),
            RediM8ProOffer(
                interval: .lifetime,
                priceAUD: Decimal(string: "79.99") ?? 79.99,
                badge: "Founding Price",
                detail: "A one-time launch offer for early supporters who want long-term access without renewals.",
                supportingLine: "Ideal for committed households, remote workers, and touring rigs.",
                highlights: [
                    "One payment",
                    "Supports ongoing map and alert maintenance",
                    "Launch pricing can be reviewed later"
                ]
            )
        ],
        featureMatrix: [
            RediM8FeatureMatrixRow(
                id: "emergency_mode",
                title: "Emergency Mode + Leave Now",
                detail: "Large-button panic flow, emergency actions, and offline quick access.",
                systemImage: "exclamationmark.triangle.fill",
                freeValue: "Included",
                proValue: "Included",
                isCoreSafety: true
            ),
            RediM8FeatureMatrixRow(
                id: "official_alerts",
                title: "Official Alerts Mirror",
                detail: "Australian public warning feeds surfaced with trust labels and Safe Mode prompts.",
                systemImage: "antenna.radiowaves.left.and.right",
                freeValue: "Included",
                proValue: "Included",
                isCoreSafety: true
            ),
            RediM8FeatureMatrixRow(
                id: "offline_map",
                title: "Offline Tactical Map",
                detail: "Shelters, water, routes, and fallback navigation that stays available without signal.",
                systemImage: "map.fill",
                freeValue: "Included",
                proValue: "Included",
                isCoreSafety: true
            ),
            RediM8FeatureMatrixRow(
                id: "guide_library",
                title: "Guide Library",
                detail: "Curated first aid, survival, and evacuation guidance with traceable sources.",
                systemImage: "book.fill",
                freeValue: "Included",
                proValue: "Included",
                isCoreSafety: true
            ),
            RediM8FeatureMatrixRow(
                id: "community_reports",
                title: "Signal + Community Reports",
                detail: "Nearby mesh discovery, structured local reports, and situational markers.",
                systemImage: "dot.radiowaves.left.and.right",
                freeValue: "Included",
                proValue: "Included",
                isCoreSafety: true
            ),
            RediM8FeatureMatrixRow(
                id: "vault",
                title: "Secure Vault",
                detail: "Emergency info card and critical document access stay local and available offline.",
                systemImage: "lock.doc.fill",
                freeValue: "Essentials",
                proValue: "Expanded",
                isCoreSafety: true
            ),
            RediM8FeatureMatrixRow(
                id: "planning",
                title: "Preparedness Planning",
                detail: "72-hour plan, go bag, vehicle kit, and readiness tasks for the household.",
                systemImage: "checkmark.square.fill",
                freeValue: "Included",
                proValue: "Expanded",
                isCoreSafety: false
            ),
            RediM8FeatureMatrixRow(
                id: "premium_map_packs",
                title: "Premium Map Packs",
                detail: "Higher-detail offline basemaps and broader regional pack coverage.",
                systemImage: "square.stack.3d.up.fill",
                freeValue: "Basic",
                proValue: "Premium",
                isCoreSafety: false
            ),
            RediM8FeatureMatrixRow(
                id: "analytics",
                title: "Preparedness Analytics",
                detail: "Richer readiness trends, category analysis, and tailored improvement guidance.",
                systemImage: "chart.line.uptrend.xyaxis",
                freeValue: "Snapshot",
                proValue: "Advanced",
                isCoreSafety: false
            ),
            RediM8FeatureMatrixRow(
                id: "assistant",
                title: "Offline Assistant",
                detail: "Retrieval-first guide answers with safe summarization for lower-risk questions.",
                systemImage: "sparkles",
                freeValue: "Guide retrieval",
                proValue: "Safe summaries",
                isCoreSafety: false
            ),
            RediM8FeatureMatrixRow(
                id: "exports",
                title: "Exports + Sharing",
                detail: "Preparedness report exports and richer family handoff bundles.",
                systemImage: "square.and.arrow.up.fill",
                freeValue: "PDF export",
                proValue: "Family bundle",
                isCoreSafety: false
            )
        ],
        alwaysFreePromise: "Emergency Mode, official alerts, guide library, basic tactical maps, community reports, and emergency document essentials stay free.",
        proPromise: "RediM8 Pro funds premium maps, advanced planning, expanded vault tools, analytics, and the offline assistant without putting core safety behind a paywall.",
        emergencyUnlockPromise: "During nearby severe official emergencies, RediM8 can temporarily unlock Pro upgrades so people can access more help without thinking about payment first.",
        billingPreviewNotice: "Launch pricing is defined, but billing is not active in this internal build yet."
    )
}

private extension Decimal {
    var audString: String {
        String(format: "%.2f", NSDecimalNumber(decimal: self).doubleValue)
    }
}
