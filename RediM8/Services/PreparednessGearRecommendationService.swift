import Foundation

final class PreparednessGearRecommendationService {
    private struct ScoredRecommendation {
        let recommendation: PreparednessGearRecommendation
        let score: Int
    }

    private static let partnerDisclosure = "RediM8 partners with PrepPro Australia."

    private let gearIndex: [String: GearItem]
    private let catalog: [String: PreparednessGearCatalogItem]

    convenience init(dataService: PreparednessDataService) {
        self.init(gearIndex: dataService.gearIndex())
    }

    init(
        gearIndex: [String: GearItem],
        catalog: [PreparednessGearCatalogItem] = PreparednessGearRecommendationService.defaultCatalog
    ) {
        self.gearIndex = gearIndex
        self.catalog = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    }

    func recommendations(
        for profile: UserProfile,
        prepScore: PrepScore,
        emergencyPlan: Emergency72HourPlan,
        forgottenItems: [ForgottenItemInsight],
        activePrioritySituation: PrioritySituation?
    ) -> [PreparednessGearRecommendation] {
        allRecommendations(
            for: profile,
            prepScore: prepScore,
            emergencyPlan: emergencyPlan,
            forgottenItems: forgottenItems,
            activePrioritySituation: activePrioritySituation
        )
        .prefix(3)
        .map { $0 }
    }

    func recommendations(
        for profile: UserProfile,
        prepScore: PrepScore,
        emergencyPlan: Emergency72HourPlan,
        forgottenItems: [ForgottenItemInsight],
        activePrioritySituation: PrioritySituation?,
        constrainedTo gearTypes: [GearType],
        scenarioOverrides: [ScenarioKind] = [],
        includeBundle: Bool = true
    ) -> [PreparednessGearRecommendation] {
        let requestedGearTypes = Set(gearTypes)
        guard !requestedGearTypes.isEmpty else {
            return []
        }

        return allRecommendations(
            for: profile,
            prepScore: prepScore,
            emergencyPlan: emergencyPlan,
            forgottenItems: forgottenItems,
            activePrioritySituation: activePrioritySituation,
            scenarioOverrides: Set(scenarioOverrides),
            includeBundle: includeBundle
        )
        .filter { recommendation in
            if recommendation.gearTypes.contains(.goBagBundle) {
                return includeBundle && !requestedGearTypes.isDisjoint(with: Set(recommendation.gearTypes))
            }
            return !requestedGearTypes.isDisjoint(with: Set(recommendation.gearTypes))
        }
    }

    private func allRecommendations(
        for profile: UserProfile,
        prepScore: PrepScore,
        emergencyPlan: Emergency72HourPlan,
        forgottenItems: [ForgottenItemInsight],
        activePrioritySituation: PrioritySituation?,
        scenarioOverrides: Set<ScenarioKind> = [],
        includeBundle: Bool = true
    ) -> [PreparednessGearRecommendation] {
        let visibilityPolicy = PreparednessGearVisibilityPolicy(activePrioritySituation: activePrioritySituation)
        guard visibilityPolicy.allowsRecommendations else {
            return []
        }

        let scenarios = Set(profile.selectedScenarios).union(scenarioOverrides)
        let topCategories = Array(prepScore.suggestions.prefix(3).map(\.category))
        let waterGap = emergencyPlan.supplyTargets.first(where: { $0.id == "water" })?.gap ?? 0
        let householdGroupCount = profile.household.peopleCount + profile.household.petCount
        let forgottenIDs = Set(forgottenItems.map(\.id))
        let missingCoreGearTypes = missingCoreGearTypes(
            profile: profile,
            scenarios: scenarios,
            waterGap: waterGap,
            householdGroupCount: householdGroupCount
        )
        var candidates: [ScoredRecommendation] = []

        if includeBundle, missingCoreGearTypes.count >= 3 {
            appendBundleRecommendation(
                to: &candidates,
                missingCoreGearTypes: missingCoreGearTypes,
                score: 132 + (missingCoreGearTypes.count * 6)
            )
        }

        if waterGap > 0 {
            let litres = waterGap.roundedIntString
            let ids = scenarios.contains(.floods) || scenarios.contains(.remoteTravel) || scenarios.contains(.campingOffGrid)
                ? ["water_jerry_can", "collapsible_water_container"]
                : ["water_jerry_can", "bottled_water_case"]

            appendRecommendation(
                to: &candidates,
                id: "water_storage_gap",
                title: "Water storage",
                reason: "Your 72-hour plan is short by \(litres)L, so stored drinking water is the fastest critical gap to close.",
                systemImage: "water",
                category: .water,
                priority: .critical,
                gearTypes: [.waterStorage],
                optionIDs: ids,
                fallbackType: .waterStorage,
                score: 120 + boost(for: .water, topCategories: topCategories)
            )
        }

        if scenarios.contains(.floods) || scenarios.contains(.remoteTravel) || scenarios.contains(.campingOffGrid) {
            appendRecommendation(
                to: &candidates,
                id: "water_purification_gap",
                title: "Water purification",
                reason: "Stored water comes first, but a backup treatment option matters when travel, floodwater, or long disruptions could cut resupply.",
                systemImage: "water",
                category: .water,
                priority: .recommended,
                gearTypes: [.waterPurification],
                optionIDs: ["water_filter_straw", "gravity_water_filter"],
                fallbackType: .waterPurification,
                score: 74 + boost(for: .water, topCategories: topCategories)
            )
        }

        if !profile.checklistState(for: .firstAidKit) {
            appendRecommendation(
                to: &candidates,
                id: "first_aid_gap",
                title: "First aid kit",
                reason: "Baseline casualty care should be ready before less critical gear or comfort items.",
                systemImage: "first_aid",
                category: .medical,
                priority: .critical,
                gearTypes: [.firstAid],
                optionIDs: orderedUnique([
                    "comprehensive_first_aid_kit",
                    scenarios.contains(.bushfires) || scenarios.contains(.powerOutages) ? "burn_dressing_pack" : nil
                ]),
                fallbackType: .firstAid,
                score: 114 + boost(for: .medical, topCategories: topCategories)
            )
        }

        if !profile.checklistState(for: .batteryRadio) {
            appendRecommendation(
                to: &candidates,
                id: "radio_gap",
                title: "Emergency radio",
                reason: "Warnings need a backup path when mobile networks or internet access fail.",
                systemImage: "radio",
                category: .communication,
                priority: .critical,
                gearTypes: [.communicationRadio],
                optionIDs: ["battery_radio", "hand_crank_radio"],
                fallbackType: .communicationRadio,
                score: 108 + boost(for: .communication, topCategories: topCategories)
            )
        }

        if !profile.checklistState(for: .torch) || householdGroupCount > 1 {
            appendRecommendation(
                to: &candidates,
                id: "lighting_gap",
                title: "Backup lighting",
                reason: householdGroupCount > 1
                    ? "One light source is rarely enough once more than one person or pet needs to move in the dark."
                    : "A single stored torch makes blackout movement and first aid much safer.",
                systemImage: "flashlight",
                category: .power,
                priority: .recommended,
                gearTypes: [.lighting],
                optionIDs: ["headlamp", "led_torch"],
                fallbackType: .lighting,
                score: 82 + boost(for: .power, topCategories: topCategories)
            )
        }

        if !profile.checklistState(for: .powerBank),
           supportsExtendedOutage(in: scenarios) || profile.supplies.batteryCapacity < 50
        {
            appendRecommendation(
                to: &candidates,
                id: "backup_power_gap",
                title: "Backup power",
                reason: "Phones, lights, and radios need a simple recharge path during outages or evacuation travel.",
                systemImage: "battery",
                category: .power,
                priority: .recommended,
                gearTypes: [.backupPower],
                optionIDs: ["power_bank_20000", "power_bank_rugged_24000"],
                fallbackType: .backupPower,
                score: 78 + boost(for: .power, topCategories: topCategories)
            )
        }

        if scenarios.contains(.bushfires), !profile.checklistState(for: .fireBlanket) {
            appendRecommendation(
                to: &candidates,
                id: "fire_blanket_gap",
                title: "Fire blanket",
                reason: "Bushfire and kitchen flare scenarios both benefit from immediate suppression gear already in place.",
                systemImage: "fire_blanket",
                category: .evacuation,
                priority: .recommended,
                gearTypes: [.fireBlanket],
                optionIDs: ["fire_blanket", "abc_fire_extinguisher"],
                fallbackType: .fireBlanket,
                score: 76 + boost(for: .evacuation, topCategories: topCategories)
            )
        }

        if scenarios.contains(.bushfires) || scenarios.contains(.severeStorm) {
            appendRecommendation(
                to: &candidates,
                id: "respiratory_mask_gap",
                title: "Respiratory protection",
                reason: "Smoke, ash, dust, and cleanup conditions are easier to manage when masks are packed before conditions change.",
                systemImage: "shield",
                category: .medical,
                priority: .recommended,
                gearTypes: [.respiratoryMasks],
                optionIDs: ["p2_mask_pack"],
                fallbackType: .respiratoryMasks,
                score: 70 + boost(for: .medical, topCategories: topCategories)
            )
        }

        if forgottenIDs.contains("document_copies") {
            appendRecommendation(
                to: &candidates,
                id: "document_protection_gap",
                title: "Document protection",
                reason: "IDs, scripts, and contact numbers leave faster when they are already grouped together and protected from water.",
                systemImage: "documents",
                category: .medical,
                priority: .recommended,
                gearTypes: [.documentProtection, .waterproofStorage],
                optionIDs: ["waterproof_document_pouch", "laminated_contact_sheet"],
                fallbackType: .documentProtection,
                score: 72 + boost(for: .medical, topCategories: topCategories)
            )
        }

        if scenarios.contains(.floods) || scenarios.contains(.cyclones) {
            appendRecommendation(
                to: &candidates,
                id: "waterproof_storage_gap",
                title: "Waterproof storage",
                reason: "Flood and severe-weather plans work better when critical items can move in one weatherproof grab-and-go container.",
                systemImage: "documents",
                category: .evacuation,
                priority: .recommended,
                gearTypes: [.waterproofStorage],
                optionIDs: ["waterproof_document_pouch"],
                fallbackType: .waterproofStorage,
                score: 68 + boost(for: .evacuation, topCategories: topCategories)
            )
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.recommendation.title < rhs.recommendation.title
                }
                return lhs.score > rhs.score
            }
            .map(\.recommendation)
    }

    private func appendBundleRecommendation(
        to candidates: inout [ScoredRecommendation],
        missingCoreGearTypes: [GearType],
        score: Int
    ) {
        let options = buildCatalogOptions(ids: ["basecamp_bundle", "scout_bundle"])
        guard !options.isEmpty else {
            return
        }

        let missingTitles = missingCoreGearTypes.prefix(3).map { $0.title.lowercased() }
        let summaryTail = ListFormatter.localizedString(byJoining: missingTitles)
        let reason = "You are missing multiple core readiness needs. A bundle is the fastest way to cover \(summaryTail) in one setup."

        candidates.append(
            ScoredRecommendation(
                recommendation: PreparednessGearRecommendation(
                    id: "go_bag_bundle_gap",
                    title: "Emergency go-bag bundle",
                    reason: reason,
                    systemImage: "go_bag",
                    category: .evacuation,
                    priority: .critical,
                    gearTypes: [.goBagBundle] + missingCoreGearTypes,
                    options: options,
                    disclosureText: Self.partnerDisclosure
                ),
                score: score
            )
        )
    }

    private func appendRecommendation(
        to candidates: inout [ScoredRecommendation],
        id: String,
        title: String,
        reason: String,
        systemImage: String,
        category: PrepCategory,
        priority: PreparednessGearRecommendationPriority,
        gearTypes: [GearType],
        optionIDs: [String],
        fallbackType: GearType,
        score: Int
    ) {
        let options = buildOptions(ids: optionIDs, fallbackType: fallbackType)
        guard !options.isEmpty else {
            return
        }

        let disclosureText = options.contains(where: { $0.partnerURL != nil }) ? Self.partnerDisclosure : nil

        candidates.append(
            ScoredRecommendation(
                recommendation: PreparednessGearRecommendation(
                    id: id,
                    title: title,
                    reason: reason,
                    systemImage: systemImage,
                    category: category,
                    priority: priority,
                    gearTypes: gearTypes,
                    options: options,
                    disclosureText: disclosureText
                ),
                score: score
            )
        )
    }

    private func buildOptions(ids: [String], fallbackType: GearType, limit: Int = 2) -> [PreparednessGearOption] {
        orderedUnique(ids.map(Optional.some))
            .compactMap { option(for: $0, fallbackType: fallbackType) }
            .prefix(limit)
            .map { $0 }
    }

    private func buildCatalogOptions(ids: [String], limit: Int = 2) -> [PreparednessGearOption] {
        orderedUnique(ids.map(Optional.some))
            .compactMap { catalog[$0] }
            .map(PreparednessGearOption.init)
            .prefix(limit)
            .map { $0 }
    }

    private func option(for id: String, fallbackType: GearType) -> PreparednessGearOption? {
        if let catalogItem = catalog[id] {
            return PreparednessGearOption(catalogItem: catalogItem)
        }

        guard let item = gearIndex[id] else {
            return nil
        }

        return PreparednessGearOption(item: item, gearType: fallbackType)
    }

    private func missingCoreGearTypes(
        profile: UserProfile,
        scenarios: Set<ScenarioKind>,
        waterGap: Double,
        householdGroupCount: Int
    ) -> [GearType] {
        var missing: [GearType] = []

        if waterGap > 0 {
            missing.append(.waterStorage)
        }

        if !profile.checklistState(for: .firstAidKit) {
            missing.append(.firstAid)
        }

        if !profile.checklistState(for: .batteryRadio) {
            missing.append(.communicationRadio)
        }

        if !profile.checklistState(for: .torch) || householdGroupCount > 1 {
            missing.append(.lighting)
        }

        if !profile.checklistState(for: .powerBank),
           supportsExtendedOutage(in: scenarios) || profile.supplies.batteryCapacity < 50
        {
            missing.append(.backupPower)
        }

        return missing
    }

    private func boost(for category: PrepCategory, topCategories: [PrepCategory]) -> Int {
        guard let index = topCategories.firstIndex(of: category) else {
            return 0
        }

        switch index {
        case 0:
            return 24
        case 1:
            return 14
        case 2:
            return 8
        default:
            return 0
        }
    }

    private func orderedUnique(_ ids: [String?]) -> [String] {
        var seen = Set<String>()

        return ids.compactMap { $0 }.filter { id in
            seen.insert(id).inserted
        }
    }

    private func supportsExtendedOutage(in scenarios: Set<ScenarioKind>) -> Bool {
        !scenarios.isDisjoint(with: [.powerOutages, .cyclones, .severeStorm, .extendedInfrastructureDisruption, .bushfires])
    }

    private static let defaultCatalog: [PreparednessGearCatalogItem] = [
        PreparednessGearCatalogItem(
            id: "basecamp_bundle",
            title: "PrepPro Basecamp Survival Contents Pack",
            detail: "Bundle-first option for closing multiple go-bag and evacuation gaps in one setup.",
            category: .vehicle,
            gearType: .goBagBundle,
            kind: .bundle,
            partnerURL: URL(string: "https://preppro.com.au/products/preppro-basecamp-survival-contents-pack-build-your-own-bug-out-bag"),
            thumbnailAssetName: "gobag_loadout",
            coveredTypes: [.goBagBundle, .firstAid, .communicationRadio, .lighting, .backupPower, .waterStorage]
        ),
        PreparednessGearCatalogItem(
            id: "scout_bundle",
            title: "PrepPro Scout Survival Kit",
            detail: "Compact bundle for users who want a simpler one-step preparedness upgrade.",
            category: .tools,
            gearType: .goBagBundle,
            kind: .bundle,
            partnerURL: URL(string: "https://preppro.com.au/products/scout-v1"),
            thumbnailAssetName: "preparedness_flatlay",
            coveredTypes: [.goBagBundle, .firstAid, .lighting, .communicationRadio]
        ),
        PreparednessGearCatalogItem(
            id: "comprehensive_first_aid_kit",
            title: "PrepPro Large First Aid Kit",
            detail: "Family-ready casualty care kit for home, vehicle, and go-bag use.",
            category: .medical,
            gearType: .firstAid,
            partnerURL: URL(string: "https://preppro.com.au/products/preppro%C2%AE-large-first-aid-kit")
        ),
        PreparednessGearCatalogItem(
            id: "battery_radio",
            title: "PrepPro R-N31 Emergency Radio",
            detail: "Emergency radio with charging backup for warnings when mobile networks fail.",
            category: .communication,
            gearType: .communicationRadio,
            partnerURL: URL(string: "https://preppro.com.au/products/emergency-am-fm-radio-solar-battery-bank-hand-crank-with-torch")
        ),
        PreparednessGearCatalogItem(
            id: "hand_crank_radio",
            title: "PrepPro Weatherband Emergency Radio",
            detail: "Compact hand-crank backup radio for outage and severe-weather kits.",
            category: .communication,
            gearType: .communicationRadio,
            partnerURL: URL(string: "https://preppro.com.au/products/emergency-weatherband-am-fm-radio-solar-battery-bank-hand-crank-with-torch")
        ),
        PreparednessGearCatalogItem(
            id: "headlamp",
            title: "PrepPro LED Headlamp",
            detail: "Hands-free lighting for outages, first aid, vehicle work, and night movement.",
            category: .lighting,
            gearType: .lighting,
            partnerURL: URL(string: "https://preppro.com.au/products/headlamp")
        ),
        PreparednessGearCatalogItem(
            id: "power_bank_20000",
            title: "PrepPro 20,000mAh Folding Solar Power Bank",
            detail: "High-capacity backup power for phones, radios, and lights during outages.",
            category: .power,
            gearType: .backupPower,
            partnerURL: URL(string: "https://preppro.com.au/products/20-000mah-folding-solar-power-bank-wireless-charging-built-in-cables-ip65-rugged-protection")
        ),
        PreparednessGearCatalogItem(
            id: "power_bank_rugged_24000",
            title: "PrepPro 24,000mAh Rugged Solar Power Bank",
            detail: "Heavy-duty backup battery for longer disruptions or vehicle-based kits.",
            category: .power,
            gearType: .backupPower,
            partnerURL: URL(string: "https://preppro.com.au/products/24-000mah-rugged-solar-power-bank")
        ),
        PreparednessGearCatalogItem(
            id: "water_filter_straw",
            title: "PrepPro Portable Water Purification Straw",
            detail: "Compact backup filtration for remote, flood, and resupply-loss scenarios.",
            category: .water,
            gearType: .waterPurification,
            partnerURL: URL(string: "https://preppro.com.au/products/portable-survival-water-purification-straw")
        )
    ]
}
