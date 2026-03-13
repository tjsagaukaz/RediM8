import Foundation

struct PrepTargets {
    let waterLitres: Double
    let foodDays: Double
    let fuelLitres: Double
    let batteryCapacity: Double
}

final class PrepService {
    func calculateScore(for profile: UserProfile, scenarios: [PrepScenario], engine: ScenarioEngine) -> PrepScore {
        let targets = recommendedTargets(for: profile, scenarios: scenarios)
        let categoryScores = PrepCategory.allCases.map { category in
            CategoryScore(category: category, score: score(for: category, profile: profile, targets: targets, scenarios: scenarios, engine: engine))
        }
        let overall = Int((Double(categoryScores.map(\.score).reduce(0, +)) / Double(categoryScores.count)).rounded())
        let suggestions = buildSuggestions(
            for: profile,
            targets: targets,
            scenarios: scenarios,
            categoryScores: categoryScores,
            engine: engine
        )
        return PrepScore(overall: overall, tier: .from(score: overall), categoryScores: categoryScores, suggestions: suggestions)
    }

    func recommendedTargets(for profile: UserProfile, scenarios: [PrepScenario]) -> PrepTargets {
        let householdSize = Double(max(profile.household.peopleCount, 1))
        let pets = Double(profile.household.petCount)
        let scenarioKinds = Set(scenarios.map(\.kind))

        var waterBase = householdSize * 21 + pets * 6
        if scenarioKinds.contains(.extremeHeat) {
            waterBase += householdSize * 6
        }
        if scenarioKinds.contains(.cyclones) || scenarioKinds.contains(.floods) || scenarioKinds.contains(.extendedInfrastructureDisruption) {
            waterBase += 6
        }

        var foodBase = 7.0
        if scenarioKinds.contains(.remoteTravel) || scenarioKinds.contains(.campingOffGrid) || scenarioKinds.contains(.extendedInfrastructureDisruption) {
            foodBase = 10
        } else if scenarioKinds.contains(.earthquake) || scenarioKinds.contains(.severeStorm) {
            foodBase = 8
        }

        var fuelBase = 20.0
        if scenarioKinds.contains(.fuelShortages) || scenarioKinds.contains(.remoteTravel) {
            fuelBase = 40
        } else if scenarioKinds.contains(.bushfires) || scenarioKinds.contains(.cyclones) || scenarioKinds.contains(.severeStorm) {
            fuelBase = 25
        }

        let batteryBase: Double
        if scenarioKinds.contains(.powerOutages) || scenarioKinds.contains(.cyclones) || scenarioKinds.contains(.severeStorm) || scenarioKinds.contains(.extendedInfrastructureDisruption) {
            batteryBase = 80
        } else {
            batteryBase = 60
        }

        return PrepTargets(waterLitres: waterBase, foodDays: foodBase, fuelLitres: fuelBase, batteryCapacity: batteryBase)
    }

    private func score(for category: PrepCategory, profile: UserProfile, targets: PrepTargets, scenarios: [PrepScenario], engine: ScenarioEngine) -> Int {
        let baseScore: Double
        switch category {
        case .water:
            baseScore = normalized(profile.supplies.waterLitres, target: targets.waterLitres)
        case .food:
            baseScore = normalized(profile.supplies.foodDays, target: targets.foodDays)
        case .medical:
            let relevantGear = [ChecklistItemKind.firstAidKit, .fireBlanket]
            let present = relevantGear.filter { profile.checklistState(for: $0) }.count
            let familyCoverage = min(profile.familyMembers.filter { !$0.medicalNotes.isEmpty }.count, 2)
            baseScore = normalized(Double(present + familyCoverage), target: 4)
        case .power:
            let gearScore = Double([ChecklistItemKind.torch, .powerBank, .batteryRadio].filter { profile.checklistState(for: $0) }.count) / 3 * 60
            let batteryScore = normalized(profile.supplies.batteryCapacity, target: targets.batteryCapacity) * 0.4
            baseScore = min(gearScore + batteryScore, 100)
        case .communication:
            let radio = profile.checklistState(for: .batteryRadio) ? 30.0 : 0
            let familyPlan = !profile.emergencyContacts.isEmpty ? 35.0 : 0
            let meetingPoint = profile.meetingPoints.primary.nilIfBlank != nil ? 20.0 : 0
            let routes = min(Double(profile.evacuationRoutes.filter { !$0.isEmpty }.count) * 7.5, 15)
            baseScore = radio + familyPlan + meetingPoint + routes
        case .evacuation:
            let meetingPoints = [profile.meetingPoints.primary, profile.meetingPoints.secondary, profile.meetingPoints.fallback]
                .filter { !$0.isEmpty }
                .count
            let routes = min(profile.evacuationRoutes.filter { !$0.isEmpty }.count, 3)
            let goBag = [ChecklistItemKind.torch, .firstAidKit, .powerBank].filter { profile.checklistState(for: $0) }.count
            let fuelScore = normalized(profile.supplies.fuelLitres, target: targets.fuelLitres) * 0.25
            baseScore = min(Double(meetingPoints) * 20 + Double(routes) * 15 + Double(goBag) * 10 + fuelScore, 100)
        }

        let scenarioKinds = Set(scenarios.map(\.kind))
        let scenarioAdjustedScore = bushfireAdjustedScore(baseScore, for: category, profile: profile, scenarioKinds: scenarioKinds)
        let multiplier = engine.weightMultiplier(for: category, scenarios: scenarios)
        let adjusted = (scenarioAdjustedScore / multiplier.clamped(to: 0.8...1.4)).rounded()
        return min(max(Int(adjusted), 0), 100)
    }

    private func buildSuggestions(
        for profile: UserProfile,
        targets: PrepTargets,
        scenarios: [PrepScenario],
        categoryScores: [CategoryScore],
        engine: ScenarioEngine
    ) -> [ImprovementSuggestion] {
        let scenarioKinds = Set(scenarios.map(\.kind))
        var suggestions: [ImprovementSuggestion] = []

        if profile.supplies.waterLitres < targets.waterLitres {
            let delta = Int((targets.waterLitres - profile.supplies.waterLitres).rounded(.up))
            suggestions.append(
                ImprovementSuggestion(
                    title: "Add \(delta)L water storage",
                    detail: "Lift your stored drinking water toward the current household target and use offline Water Points only as fallback reference.",
                    impact: min(max(delta / 5, 6), 14),
                    category: .water
                )
            )
        }

        if profile.supplies.foodDays < targets.foodDays {
            let delta = Int((targets.foodDays - profile.supplies.foodDays).rounded(.up))
            suggestions.append(
                ImprovementSuggestion(
                    title: "Add \(delta) more food days",
                    detail: "Increase shelf-stable meals and ready-to-eat food for your selected scenarios.",
                    impact: min(max(delta * 2, 5), 12),
                    category: .food
                )
            )
        }

        if !profile.checklistState(for: .firstAidKit) {
            suggestions.append(
                ImprovementSuggestion(
                    title: "Add a first aid kit",
                    detail: "Medical coverage is one of the fastest ways to improve baseline resilience.",
                    impact: 6,
                    category: .medical
                )
            )
        }

        if !profile.checklistState(for: .batteryRadio) {
            suggestions.append(
                ImprovementSuggestion(
                    title: "Add a battery radio",
                    detail: "Battery-powered warnings and updates are critical during outages and storms.",
                    impact: 5,
                    category: .communication
                )
            )
        }

        if scenarioKinds.contains(.bushfires) && !profile.checklistState(for: .fireBlanket) {
            suggestions.append(
                ImprovementSuggestion(
                    title: "Add a fire blanket",
                    detail: "Bushfire and kitchen flare scenarios are easier to manage with immediate suppression gear.",
                    impact: 5,
                    category: .medical
                )
            )
        }

        if scenarioKinds.contains(.bushfires) && !profile.bushfirePropertyState(for: .defensibleSpaceCleared) {
            suggestions.append(
                ImprovementSuggestion(
                    title: "Clear defensible space",
                    detail: "Reduce fine fuel and debris around the house before severe fire weather arrives.",
                    impact: 7,
                    category: .evacuation
                )
            )
        }

        if scenarioKinds.contains(.bushfires) && !profile.bushfirePropertyState(for: .waterPumpReady) {
            suggestions.append(
                ImprovementSuggestion(
                    title: "Confirm bushfire water supply",
                    detail: "Check pumps, hoses, and stored tank water so your property water plan is usable under pressure.",
                    impact: 6,
                    category: .water
                )
            )
        }

        if scenarioKinds.contains(.bushfires),
           profile.household.petCount > 0,
           profile.bushfireReadiness.petEvacuationPlan.nilIfBlank == nil
        {
            suggestions.append(
                ImprovementSuggestion(
                    title: "Add a pet evacuation plan",
                    detail: "Decide carriers, transport, medication, and who takes each pet before smoke or embers force a rapid departure.",
                    impact: 10,
                    category: .evacuation
                )
            )
        }

        if scenarioKinds.contains(.bushfires), profile.bushfireRoute(at: 0).nilIfBlank == nil {
            suggestions.append(
                ImprovementSuggestion(
                    title: "Save a primary evacuation route",
                    detail: "Store your main leave-early route before smoke, embers, or closures force a rushed decision.",
                    impact: 9,
                    category: .evacuation
                )
            )
        } else if scenarioKinds.contains(.bushfires), profile.bushfireRoute(at: 1).nilIfBlank == nil {
            suggestions.append(
                ImprovementSuggestion(
                    title: "Save a second evacuation route",
                    detail: "Bushfire movement can close roads quickly, so store a backup route before conditions worsen.",
                    impact: 8,
                    category: .evacuation
                )
            )
        }

        if profile.meetingPoints.primary.nilIfBlank == nil {
            suggestions.append(
                ImprovementSuggestion(
                    title: "Set a primary meeting point",
                    detail: "A simple family rally point materially improves movement and reunification under stress.",
                    impact: 4,
                    category: .evacuation
                )
            )
        }

        if profile.emergencyContacts.isEmpty {
            suggestions.append(
                ImprovementSuggestion(
                    title: "Add emergency contacts",
                    detail: "Store key numbers locally so they remain available without coverage or power.",
                    impact: 4,
                    category: .communication
                )
            )
        }

        let lowCategories = Set(
            categoryScores
                .sorted { lhs, rhs in
                    if lhs.score == rhs.score {
                        return lhs.category.title < rhs.category.title
                    }
                    return lhs.score < rhs.score
                }
                .prefix(2)
                .map(\.category)
        )

        for task in engine.personalizedTasks(for: profile) where lowCategories.contains(task.category.scoreCategory) {
            suggestions.append(
                ImprovementSuggestion(
                    title: task.title,
                    detail: task.description,
                    impact: min(max(task.prepScoreValue, 4), 12),
                    category: task.category.scoreCategory
                )
            )
        }

        var seenTitles = Set<String>()
        return suggestions
            .filter { seenTitles.insert($0.title).inserted }
            .sorted { lhs, rhs in
                if lhs.impact == rhs.impact {
                    return lhs.title < rhs.title
                }
                return lhs.impact > rhs.impact
            }
            .prefix(4)
            .map { $0 }
    }

    private func normalized(_ value: Double, target: Double) -> Double {
        guard target > 0 else { return 100 }
        return min((value / target) * 100, 100)
    }

    private func bushfireAdjustedScore(
        _ baseScore: Double,
        for category: PrepCategory,
        profile: UserProfile,
        scenarioKinds: Set<ScenarioKind>
    ) -> Double {
        guard scenarioKinds.contains(.bushfires) else {
            return baseScore
        }

        switch category {
        case .water:
            let waterReadiness = readinessScore([
                profile.bushfireChecklistState(for: .fillWaterTanks),
                profile.bushfireChecklistState(for: .checkGardenHoses),
                profile.bushfirePropertyState(for: .waterPumpReady),
                profile.supplies.waterLitres > 0
            ])
            return mixedScore(baseScore: baseScore, overlayScore: waterReadiness, overlayWeight: 0.25)
        case .medical:
            let fireEquipmentReadiness = readinessScore([
                profile.checklistState(for: .fireBlanket),
                profile.bushfireChecklistState(for: .prepareFireBlankets),
                profile.checklistState(for: .firstAidKit)
            ])
            return mixedScore(baseScore: baseScore, overlayScore: fireEquipmentReadiness, overlayWeight: 0.3)
        case .evacuation:
            let routeReadiness = readinessScore([
                profile.bushfireChecklistState(for: .prepareEvacuationBag),
                profile.bushfireRoute(at: 0).nilIfBlank != nil,
                profile.bushfireRoute(at: 1).nilIfBlank != nil,
                profile.meetingPoints.primary.nilIfBlank != nil,
                profile.household.petCount == 0 || profile.bushfireReadiness.petEvacuationPlan.nilIfBlank != nil
            ])
            let propertyScore = profile.bushfireReadiness.propertyProgress * 100
            let evacuationOverlay = routeReadiness * 0.65 + propertyScore * 0.35
            return mixedScore(baseScore: baseScore, overlayScore: evacuationOverlay, overlayWeight: 0.35)
        default:
            return baseScore
        }
    }

    private func readinessScore(_ states: [Bool]) -> Double {
        guard !states.isEmpty else { return 0 }
        let completed = states.filter { $0 }.count
        return Double(completed) / Double(states.count) * 100
    }

    private func mixedScore(baseScore: Double, overlayScore: Double, overlayWeight: Double) -> Double {
        let clampedWeight = overlayWeight.clamped(to: 0...1)
        return baseScore * (1 - clampedWeight) + overlayScore * clampedWeight
    }
}
