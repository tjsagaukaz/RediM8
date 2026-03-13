import Combine
import CoreLocation
import Foundation
import SwiftUI

@MainActor
final class PlanViewModel: ObservableObject {
    @Published var draft: UserProfile
    @Published private(set) var scenarioTasks: [PreparednessTask] = []
    @Published private(set) var recommendedGear: [GearItem] = []
    @Published private(set) var emergencyPlan: Emergency72HourPlan
    @Published private(set) var waterRuntimeEstimate: WaterRuntimeEstimate
    @Published private(set) var forgottenItems: [ForgottenItemInsight] = []
    @Published private(set) var expiryReminders: [SupplyExpiryReminder] = []
    @Published private(set) var familyRoleTasks: [FamilyRoleTask] = []
    @Published var completedEmergencyChecklistItemIDs: Set<String>
    @Published private(set) var nearbyWaterSources: [NearbyWaterPoint] = []
    @Published private(set) var waterSourceContext = ""
    @Published private(set) var waterSourceStatusMessage: String?

    private let appState: AppState
    private let locationService: LocationService
    private let mapDataService: MapDataService
    private let waterPointService: WaterPointService
    private let waterRuntimeService: WaterRuntimeService
    private let preparednessInsightsService: PreparednessInsightsService
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        let initialDraft = appState.profile
        let initialPlan = appState.emergencyPlanService.generatePlan(for: initialDraft)
        let initialCompletedIDs = appState.emergencyPlanService.loadCompletedChecklistItemIDs()
        let initialWaterEstimate = appState.waterRuntimeService.estimate(
            for: initialDraft,
            scenarios: appState.scenarioEngine.selectedScenarios(for: initialDraft.selectedScenarios)
        )

        self.appState = appState
        locationService = appState.locationService
        mapDataService = appState.mapDataService
        waterPointService = appState.waterPointService
        waterRuntimeService = appState.waterRuntimeService
        preparednessInsightsService = appState.preparednessInsightsService
        draft = initialDraft
        emergencyPlan = initialPlan
        waterRuntimeEstimate = initialWaterEstimate
        completedEmergencyChecklistItemIDs = initialCompletedIDs
        refreshDerivedState(for: initialDraft)

        appState.$profile
            .sink { [weak self] profile in
                guard let self else { return }
                if self.draft != profile {
                    self.draft = profile
                }
                self.refreshDerivedState(for: profile)
            }
            .store(in: &cancellables)

        $draft
            .removeDuplicates()
            .sink { [weak self] profile in
                self?.refreshDerivedState(for: profile)
            }
            .store(in: &cancellables)

        $draft
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] profile in
                self?.appState.applyProfile(profile)
            }
            .store(in: &cancellables)

        $completedEmergencyChecklistItemIDs
            .dropFirst()
            .sink { [weak self] ids in
                self?.appState.emergencyPlanService.saveCompletedChecklistItemIDs(ids)
            }
            .store(in: &cancellables)

        locationService.$currentLocation
            .sink { [weak self] location in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.refreshNearbyNetworkResources(for: location)
                    self.refreshWaterSourceGuidance()
                }
            }
            .store(in: &cancellables)
    }

    func addFamilyMember() {
        draft.familyMembers.append(.empty)
    }

    func removeFamilyMember(_ memberID: UUID) {
        draft.familyMembers.removeAll { $0.id == memberID }
    }

    func setPrimaryFamilyMember(_ memberID: UUID) {
        for index in draft.familyMembers.indices {
            draft.familyMembers[index].isPrimaryUser = draft.familyMembers[index].id == memberID
        }
    }

    func assignEmergencyRole(_ role: String, to memberID: UUID) {
        guard let index = draft.familyMembers.firstIndex(where: { $0.id == memberID }) else {
            return
        }
        draft.familyMembers[index].emergencyRole = role
    }

    func addEmergencyContact() {
        draft.emergencyContacts.append(.empty)
    }

    func removeEmergencyContact(_ contactID: UUID) {
        draft.emergencyContacts.removeAll { $0.id == contactID }
    }

    func addEvacuationRoute() {
        draft.evacuationRoutes.append("")
    }

    func removeEvacuationRoute(at index: Int) {
        guard draft.evacuationRoutes.indices.contains(index) else { return }
        draft.evacuationRoutes.remove(at: index)
    }

    func addSupplyExpiryItem(category: SupplyExpiryCategory) {
        draft.supplies.trackedExpiryItems.append(SupplyExpiryItem.starter(category: category))
    }

    func removeSupplyExpiryItem(_ itemID: UUID) {
        draft.supplies.trackedExpiryItems.removeAll { $0.id == itemID }
    }

    var isBushfireModeEnabled: Bool {
        draft.isBushfireModeEnabled
    }

    func bushfireRoute(at index: Int) -> String {
        draft.bushfireRoute(at: index)
    }

    func setBushfireRoute(_ route: String, at index: Int) {
        while draft.evacuationRoutes.count <= index {
            draft.evacuationRoutes.append("")
        }
        draft.evacuationRoutes[index] = route
    }

    func bushfireMeetingPoint() -> String {
        draft.meetingPoints.primary
    }

    func setBushfireMeetingPoint(_ value: String) {
        draft.meetingPoints.primary = value
    }

    func bushfirePetPlan() -> String {
        draft.bushfireReadiness.petEvacuationPlan
    }

    func setBushfirePetPlan(_ value: String) {
        draft.bushfireReadiness.petEvacuationPlan = value
    }

    func isEmergencyChecklistItemComplete(_ itemID: String) -> Bool {
        completedEmergencyChecklistItemIDs.contains(itemID)
    }

    func setEmergencyChecklistItem(_ itemID: String, isComplete: Bool) {
        if isComplete {
            completedEmergencyChecklistItemIDs.insert(itemID)
        } else {
            completedEmergencyChecklistItemIDs.remove(itemID)
        }
    }

    func onAppear() {
        locationService.start()
    }

    func onDisappear() {
        locationService.stop()
    }

    private func refreshDerivedState(for profile: UserProfile) {
        scenarioTasks = appState.scenarioEngine.personalizedTasks(for: profile)
        recommendedGear = appState.scenarioEngine.recommendedGear(for: profile)
        emergencyPlan = appState.emergencyPlanService.generatePlan(for: profile)
        waterRuntimeEstimate = waterRuntimeService.estimate(
            for: profile,
            scenarios: appState.scenarioEngine.selectedScenarios(for: profile.selectedScenarios)
        )
        forgottenItems = preparednessInsightsService.forgottenItems(for: profile)
        expiryReminders = preparednessInsightsService.expiryReminders(for: profile)
        familyRoleTasks = preparednessInsightsService.familyRoleTasks(for: profile)
        refreshWaterSourceGuidance()
    }

    private func refreshWaterSourceGuidance() {
        let waterGap = emergencyPlan.supplyTargets.first(where: { $0.id == "water" })?.gap ?? 0

        guard waterGap > 0 else {
            nearbyWaterSources = []
            waterSourceContext = ""
            waterSourceStatusMessage = nil
            return
        }

        let installedPackIDs = mapDataService.loadInstalledPackIDs()
        let installedPacks = mapDataService.packs(withIDs: installedPackIDs)
        let hasCurrentLocation = locationService.currentLocation != nil

        if let guide = waterPointService.guide(
            installedPacks: installedPacks,
            installedPackIDs: installedPackIDs,
            currentLocation: locationService.currentLocation,
            limit: 4
        ) {
            nearbyWaterSources = guide.nearbySources
            waterSourceContext = guide.context
            waterSourceStatusMessage = nil
        } else {
            nearbyWaterSources = []
            waterSourceContext = ""
            if let nearbyNetworkError = waterPointService.lastNearbyNetworkError, installedPackIDs.isEmpty {
                waterSourceStatusMessage = "\(nearbyNetworkError) Install a regional pack for dependable offline fallback."
            } else if hasCurrentLocation {
                waterSourceStatusMessage = installedPackIDs.isEmpty
                    ? "No nearby water sources were found from live nearby data. Install a regional pack for dependable offline fallback."
                    : "No nearby water sources were found from live nearby data or the installed offline packs."
            } else if installedPackIDs.isEmpty {
                waterSourceStatusMessage = "Allow location or install a regional pack so RediM8 can rank nearby water sources for your plan."
            } else {
                waterSourceStatusMessage = "No bundled water points are available inside the currently installed map coverage."
            }
        }
    }

    private func refreshNearbyNetworkResources(for location: CLLocation?) async {
        guard let coordinate = location?.coordinate else {
            return
        }

        _ = await waterPointService.refreshNearbyNetworkData(near: coordinate)
    }
}
