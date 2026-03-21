import XCTest
@testable import RediM8

final class PreparednessGearRecommendationServiceTests: XCTestCase {
    func testRecommendationsPrioritizeTopCriticalGaps() {
        let service = PreparednessGearRecommendationService(gearIndex: sampleGearIndex)

        var profile = UserProfile.empty
        profile.selectedScenarios = [.generalEmergencies, .powerOutages]
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 0)
        profile.checklistItems = ChecklistItemKind.allCases.map { ChecklistItem(kind: $0, isChecked: false) }

        let recommendations = service.recommendations(
            for: profile,
            prepScore: sampleScore(suggestions: [.water, .medical, .communication]),
            emergencyPlan: samplePlan(waterRequired: 30, currentWater: 8),
            forgottenItems: [],
            activePrioritySituation: nil
        )

        XCTAssertEqual(recommendations.map(\.id), ["go_bag_bundle_gap", "water_storage_gap", "first_aid_gap"])
        XCTAssertEqual(recommendations.count, 3)
    }

    func testBundleRecommendationUsesPartnerBundleAndHeroThumbnail() throws {
        let service = PreparednessGearRecommendationService(gearIndex: sampleGearIndex)

        var profile = UserProfile.empty
        profile.selectedScenarios = [.generalEmergencies, .powerOutages]
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 1)
        profile.checklistItems = ChecklistItemKind.allCases.map { ChecklistItem(kind: $0, isChecked: false) }

        let recommendations = service.recommendations(
            for: profile,
            prepScore: sampleScore(suggestions: [.water, .communication, .power]),
            emergencyPlan: samplePlan(waterRequired: 24, currentWater: 6),
            forgottenItems: [],
            activePrioritySituation: nil
        )

        let bundleRecommendation = try XCTUnwrap(recommendations.first)
        XCTAssertEqual(bundleRecommendation.id, "go_bag_bundle_gap")
        XCTAssertEqual(bundleRecommendation.featuredOption?.kind, .bundle)
        XCTAssertEqual(bundleRecommendation.heroThumbnailAssetName, "gobag_loadout")
        XCTAssertNotNil(bundleRecommendation.featuredOption?.partnerURL)
    }

    func testPriorityModeSuppressesPreparednessRecommendations() {
        let service = PreparednessGearRecommendationService(gearIndex: sampleGearIndex)

        var profile = UserProfile.empty
        profile.selectedScenarios = [.powerOutages]

        let recommendations = service.recommendations(
            for: profile,
            prepScore: sampleScore(suggestions: [.communication]),
            emergencyPlan: samplePlan(waterRequired: 20, currentWater: 10),
            forgottenItems: [],
            activePrioritySituation: .blackout
        )

        XCTAssertTrue(recommendations.isEmpty)
    }

    func testBushfireRecommendationIncludesFireBlanketWhenCoreGapsCovered() {
        let service = PreparednessGearRecommendationService(gearIndex: sampleGearIndex)

        var profile = UserProfile.empty
        profile.selectedScenarios = [.bushfires]
        profile.checklistItems = ChecklistItemKind.allCases.map {
            ChecklistItem(kind: $0, isChecked: $0 != .fireBlanket)
        }

        let recommendations = service.recommendations(
            for: profile,
            prepScore: sampleScore(suggestions: [.evacuation]),
            emergencyPlan: samplePlan(waterRequired: 12, currentWater: 12),
            forgottenItems: [],
            activePrioritySituation: nil
        )

        XCTAssertTrue(recommendations.contains(where: { $0.id == "fire_blanket_gap" }))
    }

    func testMappedPartnerItemUsesPartnerURLWhileGenericFallbackStaysLocalOnly() throws {
        let service = PreparednessGearRecommendationService(gearIndex: sampleGearIndex)

        var profile = UserProfile.empty
        profile.selectedScenarios = [.bushfires]
        profile.checklistItems = ChecklistItemKind.allCases.map {
            ChecklistItem(kind: $0, isChecked: $0 != .fireBlanket)
        }

        let recommendations = service.recommendations(
            for: profile,
            prepScore: sampleScore(suggestions: [.medical, .communication]),
            emergencyPlan: samplePlan(waterRequired: 12, currentWater: 12),
            forgottenItems: [],
            activePrioritySituation: nil
        )

        let fireBlanketRecommendation = try XCTUnwrap(recommendations.first(where: { $0.id == "fire_blanket_gap" }))
        XCTAssertNil(fireBlanketRecommendation.options.first?.partnerURL)

        var gapProfile = UserProfile.empty
        gapProfile.selectedScenarios = [.powerOutages]
        gapProfile.checklistItems = ChecklistItemKind.allCases.map {
            ChecklistItem(kind: $0, isChecked: $0 != .batteryRadio)
        }

        let radioRecommendations = service.recommendations(
            for: gapProfile,
            prepScore: sampleScore(suggestions: [.communication]),
            emergencyPlan: samplePlan(waterRequired: 9, currentWater: 9),
            forgottenItems: [],
            activePrioritySituation: nil
        )

        let radioRecommendation = try XCTUnwrap(radioRecommendations.first(where: { $0.id == "radio_gap" }))
        XCTAssertNotNil(radioRecommendation.options.first?.partnerURL)
    }

    func testDocumentCopiesGapMapsToDocumentProtection() throws {
        let service = PreparednessGearRecommendationService(gearIndex: sampleGearIndex)

        var profile = UserProfile.empty
        profile.selectedScenarios = [.generalEmergencies]
        profile.checklistItems = ChecklistItemKind.allCases.map { ChecklistItem(kind: $0, isChecked: true) }

        let forgottenItems = [
            ForgottenItemInsight(
                id: "document_copies",
                title: "Document copies",
                detail: "Store IDs, insurance, scripts, and key numbers together.",
                systemImage: "documents",
                priority: 86
            )
        ]

        let recommendations = service.recommendations(
            for: profile,
            prepScore: sampleScore(suggestions: [.medical]),
            emergencyPlan: samplePlan(waterRequired: 9, currentWater: 9),
            forgottenItems: forgottenItems,
            activePrioritySituation: nil
        )

        let documentRecommendation = try XCTUnwrap(recommendations.first(where: { $0.id == "document_protection_gap" }))
        XCTAssertEqual(documentRecommendation.options.map(\.id), [
            "waterproof_document_pouch",
            "laminated_contact_sheet",
        ])
        XCTAssertNil(documentRecommendation.options.first?.partnerURL)
        XCTAssertEqual(documentRecommendation.gearTypes, [.documentProtection, .waterproofStorage])
    }

    func testWaterPurificationRecommendationAppearsForFloodScenarios() throws {
        let service = PreparednessGearRecommendationService(gearIndex: sampleGearIndex)

        var profile = UserProfile.empty
        profile.selectedScenarios = [.floods]
        profile.checklistItems = ChecklistItemKind.allCases.map { ChecklistItem(kind: $0, isChecked: true) }

        let recommendations = service.recommendations(
            for: profile,
            prepScore: sampleScore(suggestions: [.water]),
            emergencyPlan: samplePlan(waterRequired: 12, currentWater: 12),
            forgottenItems: [],
            activePrioritySituation: nil
        )

        let purificationRecommendation = try XCTUnwrap(recommendations.first(where: { $0.id == "water_purification_gap" }))
        XCTAssertEqual(purificationRecommendation.options.map(\.id), [
            "water_filter_straw",
            "gravity_water_filter"
        ])
        XCTAssertNotNil(purificationRecommendation.options.first?.partnerURL)
    }

    func testScenarioConstrainedRecommendationsIncludeBundleAndRequestedTypes() {
        let service = PreparednessGearRecommendationService(gearIndex: sampleGearIndex)

        var profile = UserProfile.empty
        profile.selectedScenarios = [.generalEmergencies]
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 0)
        profile.checklistItems = ChecklistItemKind.allCases.map { ChecklistItem(kind: $0, isChecked: false) }

        let recommendations = service.recommendations(
            for: profile,
            prepScore: sampleScore(suggestions: [.water, .communication, .power]),
            emergencyPlan: samplePlan(waterRequired: 24, currentWater: 6),
            forgottenItems: [],
            activePrioritySituation: nil,
            constrainedTo: [.waterStorage, .communicationRadio, .lighting, .backupPower],
            scenarioOverrides: [.powerOutages],
            includeBundle: true
        )

        XCTAssertEqual(recommendations.first?.id, "go_bag_bundle_gap")
        XCTAssertTrue(recommendations.contains(where: { $0.id == "radio_gap" }))
        XCTAssertTrue(recommendations.contains(where: { $0.id == "lighting_gap" }))
        XCTAssertFalse(recommendations.contains(where: { $0.id == "fire_blanket_gap" }))
    }

    func testScenarioConstrainedRecommendationsCanSuppressBundle() {
        let service = PreparednessGearRecommendationService(gearIndex: sampleGearIndex)

        var profile = UserProfile.empty
        profile.selectedScenarios = [.generalEmergencies]
        profile.household = HouseholdDetails(peopleCount: 2, petCount: 0)
        profile.checklistItems = ChecklistItemKind.allCases.map { ChecklistItem(kind: $0, isChecked: false) }

        let recommendations = service.recommendations(
            for: profile,
            prepScore: sampleScore(suggestions: [.water, .communication, .power]),
            emergencyPlan: samplePlan(waterRequired: 24, currentWater: 6),
            forgottenItems: [],
            activePrioritySituation: nil,
            constrainedTo: [.waterStorage, .communicationRadio, .lighting, .backupPower],
            scenarioOverrides: [.powerOutages],
            includeBundle: false
        )

        XCTAssertFalse(recommendations.contains(where: { $0.id == "go_bag_bundle_gap" }))
        XCTAssertTrue(recommendations.contains(where: { $0.id == "radio_gap" }))
    }

    private func sampleScore(suggestions categories: [PrepCategory]) -> PrepScore {
        PrepScore(
            overall: 48,
            tier: .notReady,
            categoryScores: [],
            suggestions: categories.map { category in
                ImprovementSuggestion(
                    title: "Improve \(category.title)",
                    detail: "Test suggestion",
                    impact: 8,
                    category: category
                )
            }
        )
    }

    private func samplePlan(waterRequired: Double, currentWater: Double) -> Emergency72HourPlan {
        Emergency72HourPlan(
            days: 3,
            waterPerPersonPerDayLitres: 3,
            foodCaloriesPerPersonPerDay: 2_000,
            waterRequiredLitres: waterRequired,
            foodRequiredCalories: 6_000,
            supplyTargets: [
                EmergencySupplyTarget(id: "water", title: "Water", required: waterRequired, current: currentWater, unit: "L")
            ],
            recommendedGear: [],
            essentialTasks: [],
            checklists: []
        )
    }

    private var sampleGearIndex: [String: GearItem] {
        Dictionary(uniqueKeysWithValues: [
            GearItem(id: "water_jerry_can", name: "20L water jerry can", category: .water, description: "Water storage.", recommendedScenarios: [.generalEmergencies]),
            GearItem(id: "bottled_water_case", name: "Sealed bottled water case", category: .water, description: "Immediate drinking water.", recommendedScenarios: [.powerOutages]),
            GearItem(id: "collapsible_water_container", name: "Collapsible water container", category: .water, description: "Fold-flat water backup.", recommendedScenarios: [.floods]),
            GearItem(id: "gravity_water_filter", name: "Gravity water filter", category: .water, description: "Backup treatment without power.", recommendedScenarios: [.floods, .remoteTravel]),
            GearItem(id: "comprehensive_first_aid_kit", name: "Comprehensive first aid kit", category: .medical, description: "Casualty care kit.", recommendedScenarios: [.generalEmergencies]),
            GearItem(id: "burn_dressing_pack", name: "Burn dressing pack", category: .medical, description: "Burn dressings.", recommendedScenarios: [.bushfires]),
            GearItem(id: "battery_radio", name: "Battery-powered emergency radio", category: .communication, description: "Receives warnings.", recommendedScenarios: [.powerOutages]),
            GearItem(id: "hand_crank_radio", name: "Hand-crank radio", category: .communication, description: "Self-powered updates.", recommendedScenarios: [.powerOutages]),
            GearItem(id: "led_torch", name: "LED torch", category: .lighting, description: "Primary torch.", recommendedScenarios: [.generalEmergencies]),
            GearItem(id: "headlamp", name: "Headlamp", category: .lighting, description: "Hands-free light.", recommendedScenarios: [.powerOutages]),
            GearItem(id: "aa_aaa_battery_pack", name: "AA/AAA battery pack", category: .power, description: "Backup batteries.", recommendedScenarios: [.powerOutages]),
            GearItem(id: "power_bank_20000", name: "20,000 mAh power bank", category: .power, description: "Backup power.", recommendedScenarios: [.powerOutages]),
            GearItem(id: "usb_car_charger", name: "USB car charger", category: .power, description: "Vehicle charging.", recommendedScenarios: [.powerOutages]),
            GearItem(id: "solar_panel_charger", name: "Small solar panel charger", category: .power, description: "Remote recharge.", recommendedScenarios: [.remoteTravel]),
            GearItem(id: "fire_blanket", name: "Fire blanket", category: .fireSafety, description: "Immediate suppression.", recommendedScenarios: [.bushfires]),
            GearItem(id: "abc_fire_extinguisher", name: "ABC fire extinguisher", category: .fireSafety, description: "Home extinguisher.", recommendedScenarios: [.bushfires]),
            GearItem(id: "p2_mask_pack", name: "P2 mask pack", category: .medical, description: "Smoke and cleanup protection.", recommendedScenarios: [.bushfires, .severeStorm]),
            GearItem(id: "waterproof_document_pouch", name: "Waterproof document pouch", category: .tools, description: "Protect key documents.", recommendedScenarios: [.floods]),
            GearItem(id: "laminated_contact_sheet", name: "Laminated contact sheet", category: .communication, description: "Printed contacts.", recommendedScenarios: [.generalEmergencies]),
            GearItem(id: "prescription_copy_wallet_card", name: "Prescription copy wallet card", category: .medical, description: "Medication record.", recommendedScenarios: [.generalEmergencies])
        ].map { ($0.id, $0) })
    }
}
