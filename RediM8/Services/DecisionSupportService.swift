import Foundation

final class DecisionSupportService {
    func prioritySummary(
        for situation: PrioritySituation,
        profile: UserProfile,
        goBagPlan: GoBagPlan,
        waterEstimate: WaterRuntimeEstimate,
        nearbyWaterSources: [NearbyWaterPoint],
        nearbyShelters: [NearbyShelter]
    ) -> PriorityModeSummary {
        let routes = profile.evacuationRoutes.compactMap(\.nilIfBlank)
        let contactsCount = profile.emergencyContacts.count + profile.familyMembers.count
        let goBagDetail = goBagPlan.readiness.percentage >= 67
            ? "\(goBagPlan.readiness.percentage)% packed and ready to grab."
            : "\(goBagPlan.readiness.totalCount - goBagPlan.readiness.completedCount) go-bag items still incomplete."
        let contactDetail = contactsCount > 0
            ? "\(contactsCount) saved family or emergency contacts are available offline."
            : "No saved contacts yet. Use RediM8's emergency tools and call for help if needed."
        let routeDetail = routes.first ?? "No route saved yet. Open Plan and add one before you move."
        let shelterDetail = nearbyShelters.first
            .map { "\($0.shelter.name) • \($0.distanceText)" }
            ?? "Use the map to review nearby shelters, assembly points, or baseline facilities."
        let waterSourceDetail = nearbyWaterSources.first
            .map { "\($0.point.name) • \($0.distanceText)" }
            ?? "\(waterEstimate.estimatedDaysText) of stored water remains at the current usage rate."

        let actions: [PriorityAction]
        let resources: [PriorityResource]
        let evacuationOptions: [String]
        let subtitle: String

        switch situation {
        case .bushfire:
            subtitle = "Top actions, critical tools, nearby resources, and evacuation options for rapid fire movement."
            actions = [
                PriorityAction(id: "grab_go_bag", title: "Grab Go Bag", detail: goBagDetail, systemImage: "go_bag"),
                PriorityAction(id: "contact_family", title: "Contact Family", detail: contactDetail, systemImage: "family"),
                PriorityAction(id: "check_route", title: "Check Evacuation Route", detail: routeDetail, systemImage: "route"),
                PriorityAction(id: "water_masks", title: "Water + Masks", detail: "\(waterEstimate.estimatedDaysText) of water available. Carry masks and medications together.", systemImage: "first_aid"),
                PriorityAction(id: "nearest_shelter", title: "Nearest Shelter", detail: shelterDetail, systemImage: "shelter")
            ]
            resources = [
                PriorityResource(id: "shelter", title: "Nearest Shelter", detail: shelterDetail, systemImage: "shelter"),
                PriorityResource(id: "water", title: "Nearest Water", detail: waterSourceDetail, systemImage: "water")
            ]
            evacuationOptions = routes.isEmpty
                ? ["No saved route yet. Open Plan and save at least one exit route now.", "Use the Map tab to verify nearby shelter and water coverage."]
                : Array(routes.prefix(3))
        case .flood:
            subtitle = "Immediate flood response with movement, documents, higher-ground options, and local shelter context."
            actions = [
                PriorityAction(id: "move_to_higher_ground", title: "Move to Higher Ground", detail: "Avoid low crossings and floodwater. Shift early if your route can close.", systemImage: "water"),
                PriorityAction(id: "contact_family", title: "Contact Family", detail: contactDetail, systemImage: "family"),
                PriorityAction(id: "check_route", title: "Check Evacuation Route", detail: routeDetail, systemImage: "route"),
                PriorityAction(id: "documents_and_meds", title: "Documents + Medications", detail: "Keep IDs, medications, chargers, and dry bags together before leaving.", systemImage: "documents"),
                PriorityAction(id: "nearest_shelter", title: "Nearest Shelter", detail: shelterDetail, systemImage: "shelter")
            ]
            resources = [
                PriorityResource(id: "shelter", title: "Nearest Shelter", detail: shelterDetail, systemImage: "shelter"),
                PriorityResource(id: "water", title: "Nearest Water", detail: waterSourceDetail, systemImage: "water")
            ]
            evacuationOptions = routes.isEmpty
                ? ["No saved evacuation route yet. Add one in Plan before roads close.", "Use nearby shelters and assembly points as fallback options."]
                : Array(routes.prefix(3))
        case .blackout:
            subtitle = "Power-loss triage focused on battery preservation, lighting, offline tools, and short movement decisions."
            actions = [
                PriorityAction(id: "reduce_power_draw", title: "Enter Low-Draw Mode", detail: "Use Blackout or Stealth features to conserve battery and reduce distractions.", systemImage: "battery"),
                PriorityAction(id: "protect_battery", title: "Protect Battery Reserve", detail: "Current battery tracker: \(profile.supplies.batteryCapacity.roundedIntString)% reserve stored.", systemImage: "battery"),
                PriorityAction(id: "lighting_and_radio", title: "Torch + Radio", detail: "Check torch, radio, and power bank access before conditions worsen.", systemImage: "flashlight"),
                PriorityAction(id: "water_snapshot", title: "Water Runtime", detail: waterEstimate.statusMessage, systemImage: "water"),
                PriorityAction(id: "offline_guides", title: "Offline Guides", detail: "Keep blackout and first-aid guides ready in case coverage drops.", systemImage: "book.fill")
            ]
            resources = [
                PriorityResource(id: "water", title: "Nearest Water", detail: waterSourceDetail, systemImage: "water"),
                PriorityResource(id: "shelter", title: "Community Shelter", detail: shelterDetail, systemImage: "shelter")
            ]
            evacuationOptions = routes.isEmpty
                ? ["Stay put if safe, limit travel at night, and keep one meeting point ready.", "If conditions escalate, use the offline map to choose the safest lit route."]
                : Array(routes.prefix(2))
        case .remoteTravel:
            subtitle = "Remote-travel triage with vehicle readiness, route checks, water, and extraction options first."
            actions = [
                PriorityAction(id: "check_vehicle_kit", title: "Check Vehicle Kit", detail: "Confirm recovery gear, spare tyre, compressor, maps, and a jump starter before moving.", systemImage: "four_wd"),
                PriorityAction(id: "open_offline_map", title: "Check Offline Route", detail: routeDetail, systemImage: "map_marker"),
                PriorityAction(id: "water_and_fuel", title: "Water + Fuel", detail: "\(waterEstimate.estimatedDaysText) of water at current use. Fuel tracker shows \(profile.supplies.fuelLitres.roundedIntString)L.", systemImage: "fuel"),
                PriorityAction(id: "contact_family", title: "Check In", detail: contactDetail, systemImage: "family"),
                PriorityAction(id: "nearest_help", title: "Nearest Shelter / Water", detail: "\(shelterDetail) • \(waterSourceDetail)", systemImage: "first_aid")
            ]
            resources = [
                PriorityResource(id: "water", title: "Nearest Water", detail: waterSourceDetail, systemImage: "water"),
                PriorityResource(id: "shelter", title: "Nearest Shelter", detail: shelterDetail, systemImage: "shelter")
            ]
            evacuationOptions = routes.isEmpty
                ? ["No saved route yet. Review offline maps and tracks before leaving your current position.", "Keep a turnaround point and fallback shelter in mind before moving."]
                : Array(routes.prefix(3))
        }

        return PriorityModeSummary(
            situation: situation,
            title: situation.summaryTitle,
            subtitle: subtitle,
            actions: actions,
            resources: resources,
            evacuationOptions: evacuationOptions
        )
    }

    func leaveNowActions(for profile: UserProfile, goBagPlan: GoBagPlan) -> [LeaveNowAction] {
        let routes = profile.evacuationRoutes.compactMap(\.nilIfBlank)
        var actions = [
            LeaveNowAction(
                id: "grab_go_bag",
                title: "Grab Go Bag",
                detail: goBagPlan.readiness.percentage >= 67
                    ? "\(goBagPlan.readiness.percentage)% packed and ready."
                    : "Take the packed bag first, then load missing essentials only if time allows."
            ),
            LeaveNowAction(
                id: "grab_folder",
                title: "Grab Folder",
                detail: profile.medicalNotes.nilIfBlank == nil
                    ? "Take the ready folder with IDs, insurance papers, printed contacts, prescriptions, and chargers."
                    : "Take the ready folder with IDs, prescriptions, chargers, and the medical notes already saved in your plan."
            )
        ]

        if profile.household.petCount > 0 {
            actions.append(
                LeaveNowAction(
                    id: "load_pets",
                    title: "Load Pets",
                    detail: "Move pets, leads, carriers, food, water, and medications into the vehicle immediately."
                )
            )
        }

        actions.append(
            LeaveNowAction(
                id: "keys_phone",
                title: "Keys + Phone",
                detail: "Take phones, power banks, chargers, wallets, and vehicle or house keys now."
            )
        )
        actions.append(
            LeaveNowAction(
                id: "evacuate",
                title: "Evacuate",
                detail: routes.first ?? "Use your safest saved route or open the offline map before moving."
            )
        )

        return actions
    }
}
