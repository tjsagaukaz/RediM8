import Foundation

enum GearType: String, CaseIterable, Equatable, Identifiable {
    case waterStorage
    case waterPurification
    case firstAid
    case communicationRadio
    case lighting
    case backupPower
    case goBagBundle
    case backpackBase
    case documentProtection
    case fireBlanket
    case respiratoryMasks
    case waterproofStorage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .waterStorage:
            "Water storage"
        case .waterPurification:
            "Water purification"
        case .firstAid:
            "First aid"
        case .communicationRadio:
            "Emergency radio"
        case .lighting:
            "Lighting"
        case .backupPower:
            "Backup power"
        case .goBagBundle:
            "Go-bag bundle"
        case .backpackBase:
            "Backpack base"
        case .documentProtection:
            "Document protection"
        case .fireBlanket:
            "Fire blanket"
        case .respiratoryMasks:
            "Respiratory masks"
        case .waterproofStorage:
            "Waterproof storage"
        }
    }

    var isCorePreparednessType: Bool {
        switch self {
        case .waterStorage, .firstAid, .communicationRadio, .lighting, .backupPower:
            true
        default:
            false
        }
    }
}

enum PreparednessGearOptionKind: String, Equatable {
    case item
    case bundle

    var badgeTitle: String {
        switch self {
        case .item:
            "Item"
        case .bundle:
            "Bundle"
        }
    }
}

enum PreparednessGearRecommendationPriority: String, Equatable {
    case critical
    case recommended

    var title: String {
        switch self {
        case .critical:
            "Critical"
        case .recommended:
            "Recommended"
        }
    }
}

struct PreparednessGearCatalogItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let category: GearCategory
    let gearType: GearType
    let kind: PreparednessGearOptionKind
    let partnerURL: URL?
    let thumbnailAssetName: String?
    let coveredTypes: [GearType]

    init(
        id: String,
        title: String,
        detail: String,
        category: GearCategory,
        gearType: GearType,
        kind: PreparednessGearOptionKind = .item,
        partnerURL: URL? = nil,
        thumbnailAssetName: String? = nil,
        coveredTypes: [GearType] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.category = category
        self.gearType = gearType
        self.kind = kind
        self.partnerURL = partnerURL
        self.thumbnailAssetName = thumbnailAssetName
        self.coveredTypes = coveredTypes
    }
}

struct PreparednessGearVisibilityPolicy: Equatable {
    let activePrioritySituation: PrioritySituation?

    var allowsRecommendations: Bool {
        activePrioritySituation == nil
    }
}

struct PreparednessGearOption: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let category: GearCategory
    let gearType: GearType
    let kind: PreparednessGearOptionKind
    let partnerURL: URL?
    let thumbnailAssetName: String?
    let coveredTypes: [GearType]

    init(item: GearItem, gearType: GearType, partnerURL: URL? = nil, thumbnailAssetName: String? = nil) {
        id = item.id
        title = item.name
        detail = item.description
        category = item.category
        self.gearType = gearType
        kind = .item
        self.partnerURL = partnerURL
        self.thumbnailAssetName = thumbnailAssetName
        coveredTypes = []
    }

    init(catalogItem: PreparednessGearCatalogItem) {
        id = catalogItem.id
        title = catalogItem.title
        detail = catalogItem.detail
        category = catalogItem.category
        gearType = catalogItem.gearType
        kind = catalogItem.kind
        partnerURL = catalogItem.partnerURL
        thumbnailAssetName = catalogItem.thumbnailAssetName
        coveredTypes = catalogItem.coveredTypes
    }

    var isBundle: Bool {
        kind == .bundle
    }

    var badgeTitle: String {
        kind.badgeTitle
    }
}

struct PreparednessGearRecommendation: Identifiable, Equatable {
    let id: String
    let title: String
    let reason: String
    let systemImage: String
    let category: PrepCategory
    let priority: PreparednessGearRecommendationPriority
    let gearTypes: [GearType]
    let options: [PreparednessGearOption]
    let disclosureText: String?

    var ctaTitle: String {
        if featuredOption?.isBundle == true {
            return "View bundle"
        }
        return "View options"
    }

    var featuredOption: PreparednessGearOption? {
        options.first(where: \.isBundle) ?? options.first
    }

    var heroThumbnailAssetName: String? {
        guard featuredOption?.isBundle == true else {
            return nil
        }
        return featuredOption?.thumbnailAssetName
    }

    var hasPartnerLinks: Bool {
        options.contains { $0.partnerURL != nil }
    }
}
