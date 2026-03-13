import Foundation

@MainActor
final class VehicleReadinessService: ObservableObject {
    private enum StorageKey {
        static let completedItems = "vehicle_kit.completedItems.v1"
    }

    private struct VehicleKitTemplate {
        let id: String
        let title: String
        let detail: String
        let systemImage: String
        let priorityScenarios: Set<ScenarioKind>
    }

    @Published private(set) var completedItemIDs: Set<String>

    private let store: SQLiteStore?

    init(store: SQLiteStore?) {
        self.store = store
        let storedIDs = (try? store?.load([String].self, for: StorageKey.completedItems)) ?? []
        completedItemIDs = Set(storedIDs)
    }

    func plan(for profile: UserProfile) -> VehicleReadinessPlan {
        let selectedScenarios = Set(profile.selectedScenarios)
        let items = templates
            .map { template in
                VehicleKitItem(
                    id: template.id,
                    title: template.title,
                    detail: template.detail,
                    systemImage: template.systemImage,
                    isCritical: template.priorityScenarios.isEmpty || !selectedScenarios.isDisjoint(with: template.priorityScenarios)
                )
            }
            .sorted { lhs, rhs in
                if lhs.isCritical != rhs.isCritical {
                    return lhs.isCritical && !rhs.isCritical
                }
                return lhs.title < rhs.title
            }

        let completedCount = items.filter { completedItemIDs.contains($0.id) }.count
        let nextActions = items
            .filter { !completedItemIDs.contains($0.id) }
            .prefix(3)
            .map(\.title)

        let scenarioTitles = profile.selectedScenarios.map(\.title)
        let contextLines = [
            "Fuel tracked in Plan: \(profile.supplies.fuelLitres.roundedIntString)L",
            scenarioTitles.isEmpty
                ? "Keep the vehicle kit packed for day trips, storms, and rural breakdowns."
                : "Priority for \(scenarioTitles.joined(separator: ", "))."
        ]

        return VehicleReadinessPlan(
            readiness: GoBagReadiness(completedCount: completedCount, totalCount: items.count),
            items: items,
            scenarioTitles: scenarioTitles,
            contextLines: contextLines,
            nextActions: nextActions
        )
    }

    func isItemComplete(_ itemID: String) -> Bool {
        completedItemIDs.contains(itemID)
    }

    func setItem(_ itemID: String, isComplete: Bool) {
        if isComplete {
            completedItemIDs.insert(itemID)
        } else {
            completedItemIDs.remove(itemID)
        }
        try? store?.save(completedItemIDs.sorted(), for: StorageKey.completedItems)
    }

    private var templates: [VehicleKitTemplate] {
        [
            VehicleKitTemplate(
                id: "vehicle_water",
                title: "Water",
                detail: "Keep a dedicated water cache in the vehicle for breakdowns, detours, and heat exposure.",
                systemImage: "water",
                priorityScenarios: [.remoteTravel, .campingOffGrid, .extremeHeat]
            ),
            VehicleKitTemplate(
                id: "vehicle_fuel",
                title: "Fuel",
                detail: "Avoid starting remote or storm travel with a low tank. Keep extra fuel where legal and safe.",
                systemImage: "fuel",
                priorityScenarios: [.remoteTravel, .fuelShortages, .bushfires]
            ),
            VehicleKitTemplate(
                id: "vehicle_first_aid",
                title: "First Aid",
                detail: "Carry trauma basics, medications, gloves, and emergency contact details inside the vehicle.",
                systemImage: "first_aid",
                priorityScenarios: []
            ),
            VehicleKitTemplate(
                id: "vehicle_jump_starter",
                title: "Jump Starter",
                detail: "A battery starter reduces reliance on another vehicle in isolated areas.",
                systemImage: "vehicle",
                priorityScenarios: [.remoteTravel, .powerOutages]
            ),
            VehicleKitTemplate(
                id: "vehicle_recovery_gear",
                title: "Recovery Gear",
                detail: "Store straps, shackles, gloves, and traction tools for boggy, sandy, or damaged roads.",
                systemImage: "wrench.and.screwdriver.fill",
                priorityScenarios: [.remoteTravel, .floods, .campingOffGrid]
            ),
            VehicleKitTemplate(
                id: "vehicle_torch",
                title: "Torch",
                detail: "A dedicated vehicle torch helps at night, during outages, and when checking tyres or engine bays.",
                systemImage: "flashlight",
                priorityScenarios: [.powerOutages, .severeStorm]
            ),
            VehicleKitTemplate(
                id: "vehicle_compressor",
                title: "Compressor",
                detail: "A compressor helps after punctures and when adjusting tyre pressure on rough roads.",
                systemImage: "gauge.with.dots.needle.33percent",
                priorityScenarios: [.remoteTravel, .campingOffGrid]
            ),
            VehicleKitTemplate(
                id: "vehicle_spare_tyre",
                title: "Spare Tyre",
                detail: "Carry a usable spare and the tools needed to change it without roadside help.",
                systemImage: "circlebadge.2.fill",
                priorityScenarios: []
            ),
            VehicleKitTemplate(
                id: "vehicle_maps",
                title: "Maps",
                detail: "Keep offline maps or paper backups in the vehicle before leaving coverage.",
                systemImage: "map_marker",
                priorityScenarios: [.remoteTravel, .campingOffGrid, .floods, .bushfires]
            )
        ]
    }
}
