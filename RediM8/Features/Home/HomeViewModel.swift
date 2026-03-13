import Combine
import CoreLocation
import Foundation

struct BushfireStatusRow: Identifiable, Equatable {
    enum Tone: Equatable {
        case ready
        case warning
    }

    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let tone: Tone
}

enum OfficialAlertStatusTone: Equatable {
    case ready
    case info
    case caution
    case danger
}

struct OfficialAlertHomeSummary: Equatable {
    let title: String
    let detail: String
    let tone: OfficialAlertStatusTone
}

struct SafeModeHomeSummary: Equatable {
    let alert: OfficialAlert
    let nearestShelterLine: String
    let nearestWaterLine: String
    let routeLine: String
    let note: String
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var profile: UserProfile
    @Published private(set) var prepScore: PrepScore
    @Published private(set) var readinessReport: ReadinessReport
    @Published private(set) var recommendedGuides: [Guide] = []
    @Published private(set) var scenarioTasks: [PreparednessTask] = []
    @Published private(set) var forgottenItems: [ForgottenItemInsight] = []
    @Published private(set) var expiryReminders: [SupplyExpiryReminder] = []
    @Published private(set) var nearbyWaterSources: [NearbyWaterPoint] = []
    @Published private(set) var waterSourceContext = ""
    @Published private(set) var waterSourceStatusMessage: String?
    @Published private(set) var priorityModeSummary: PriorityModeSummary?
    @Published private(set) var waterRuntimeEstimate: WaterRuntimeEstimate
    @Published private(set) var vehicleReadinessPlan: VehicleReadinessPlan
    @Published private(set) var nearbyOfficialAlerts: [OfficialAlert] = []
    @Published private(set) var officialAlertSummary: OfficialAlertHomeSummary
    @Published private(set) var safeModeSummary: SafeModeHomeSummary?

    private let appState: AppState
    private let officialAlertService: OfficialAlertService
    private let locationService: LocationService
    private let mapDataService: MapDataService
    private let waterPointService: WaterPointService
    private let shelterService: ShelterService
    private let decisionSupportService: DecisionSupportService
    private let preparednessInsightsService: PreparednessInsightsService
    private let waterRuntimeService: WaterRuntimeService
    private let goBagService: GoBagService
    private let vehicleReadinessService: VehicleReadinessService
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        officialAlertService = appState.officialAlertService
        locationService = appState.locationService
        mapDataService = appState.mapDataService
        waterPointService = appState.waterPointService
        shelterService = appState.shelterService
        decisionSupportService = appState.decisionSupportService
        preparednessInsightsService = appState.preparednessInsightsService
        waterRuntimeService = appState.waterRuntimeService
        goBagService = appState.goBagService
        vehicleReadinessService = appState.vehicleReadinessService
        profile = appState.profile
        prepScore = appState.prepScore
        readinessReport = appState.readinessReportService.generateReport(profile: appState.profile, prepScore: appState.prepScore)
        waterRuntimeEstimate = appState.waterRuntimeService.estimate(
            for: appState.profile,
            scenarios: appState.scenarioEngine.selectedScenarios(for: appState.profile.selectedScenarios)
        )
        vehicleReadinessPlan = appState.vehicleReadinessService.plan(for: appState.profile)
        officialAlertSummary = OfficialAlertHomeSummary(
            title: "No warnings for your area",
            detail: "Official alerts will appear here when RediM8 has a cached public warning snapshot for your location.",
            tone: .ready
        )
        refreshDerivedState(for: appState.profile, prepScore: appState.prepScore)

        appState.$profile
            .sink { [weak self] profile in
                guard let self else { return }
                self.profile = profile
                self.refreshDerivedState(for: profile, prepScore: self.prepScore)
            }
            .store(in: &cancellables)

        appState.$prepScore
            .sink { [weak self] prepScore in
                guard let self else { return }
                self.prepScore = prepScore
                self.refreshDerivedState(for: self.profile, prepScore: prepScore)
            }
            .store(in: &cancellables)

        locationService.$currentLocation
            .sink { [weak self] location in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.refreshNearbyNetworkResources(for: location)
                    self.refreshWaterGuidance(for: self.profile)
                    self.refreshPriorityMode(for: self.profile)
                    self.refreshOfficialAlerts()
                }
            }
            .store(in: &cancellables)

        appState.$activePrioritySituation
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshPriorityMode(for: self.profile)
            }
            .store(in: &cancellables)

        vehicleReadinessService.$completedItemIDs
            .sink { [weak self] _ in
                guard let self else { return }
                self.vehicleReadinessPlan = self.vehicleReadinessService.plan(for: self.profile)
            }
            .store(in: &cancellables)

        officialAlertService.$library
            .sink { [weak self] _ in
                self?.refreshOfficialAlerts()
            }
            .store(in: &cancellables)

        officialAlertService.$lastRefreshError
            .sink { [weak self] _ in
                self?.refreshOfficialAlerts()
            }
            .store(in: &cancellables)
    }

    var scenarioSummary: String {
        profile.selectedScenarios.map(\.title).joined(separator: ", ")
    }

    var isBushfireModeEnabled: Bool {
        profile.isBushfireModeEnabled
    }

    var bushfireReadinessPercentage: Int {
        guard isBushfireModeEnabled else {
            return prepScore.overall
        }

        let relevantCategories = prepScore.categoryScores
            .filter { [.water, .medical, .communication, .evacuation].contains($0.category) }
            .map(\.score)
        let categoryAverage = relevantCategories.isEmpty
            ? Double(prepScore.overall)
            : Double(relevantCategories.reduce(0, +)) / Double(relevantCategories.count)
        let checklistScore = profile.bushfireReadiness.checklistProgress * 100
        let propertyScore = profile.bushfireReadiness.propertyProgress * 100
        let planScore = bushfireEvacuationPlanScore(for: profile)

        return Int((categoryAverage * 0.55 + checklistScore * 0.2 + propertyScore * 0.15 + planScore * 0.1).rounded())
    }

    var bushfireStatusRows: [BushfireStatusRow] {
        guard isBushfireModeEnabled else {
            return []
        }

        let fireBlanketReady = profile.checklistState(for: .fireBlanket) && profile.bushfireChecklistState(for: .prepareFireBlankets)
        let evacuationPlanScore = bushfireEvacuationPlanScore(for: profile)
        let waterReady = bushfireWaterSupplyReady(for: profile)

        return [
            BushfireStatusRow(
                id: "water_supply",
                title: "Water Supply",
                detail: waterReady ? "Available" : "Needs review",
                systemImage: waterReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                tone: waterReady ? .ready : .warning
            ),
            BushfireStatusRow(
                id: "fire_equipment",
                title: "Fire Equipment",
                detail: fireBlanketReady ? "Ready" : "Missing fire blanket",
                systemImage: fireBlanketReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                tone: fireBlanketReady ? .ready : .warning
            ),
            BushfireStatusRow(
                id: "evacuation_plan",
                title: "Evacuation Plan",
                detail: evacuationPlanScore >= 80 ? "Complete" : "Needs work",
                systemImage: evacuationPlanScore >= 80 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                tone: evacuationPlanScore >= 80 ? .ready : .warning
            )
        ]
    }

    var bushfireChecklistItems: [BushfireChecklistItem] {
        profile.bushfireReadiness.checklist
    }

    var bushfireEmergencySteps: [String] {
        [
            "Leave early if advised.",
            "Wear protective clothing.",
            "Close windows and doors.",
            "Turn off gas supply.",
            "Follow emergency instructions."
        ]
    }

    var bushfireReminderTitle: String {
        "Fire Season Reminder"
    }

    var bushfireReminderMessage: String {
        "Prepare before summer bushfire season."
    }

    var prioritySituationOptions: [PrioritySituation] {
        PrioritySituation.allCases
    }

    var decisionSupportSubtitle: String {
        "Priority, evacuation, vehicle, and water tools surfaced first."
    }

    var shouldShowWaterSourceGuidance: Bool {
        !nearbyWaterSources.isEmpty || waterSourceStatusMessage != nil
    }

    var shouldShowExpiryReminders: Bool {
        !expiryReminders.isEmpty
    }

    var officialAlertTrustItems: [TrustPillItem] {
        var items = [
            TrustPillItem(title: "Official", tone: .verified),
            TrustPillItem(title: "Mirrored", tone: .info)
        ]

        if let alert = nearbyOfficialAlerts.first {
            items.append(TrustPillItem(title: officialCoverageTrustLabel, tone: .info))
            items.append(TrustPillItem(title: alert.scopeTrustLabel, tone: alert.isAreaScoped ? .verified : .caution))
            items.append(TrustPillItem(title: TrustLayer.freshnessLabel(for: alert.lastUpdated), tone: .neutral))
        } else if officialAlertService.hasCachedData {
            items.append(TrustPillItem(title: officialCoverageTrustLabel, tone: .info))
            items.append(TrustPillItem(title: TrustLayer.freshnessLabel(for: officialAlertService.library.lastUpdated), tone: .neutral))
        } else {
            items.append(TrustPillItem(title: "Offline cache empty", tone: .caution))
        }

        return items
    }

    func onAppear() {
        locationService.start()
        Task {
            await officialAlertService.refreshIfNeeded()
        }
    }

    func onDisappear() {
        locationService.stop()
    }

    func reopenSetup() {
        appState.openOnboarding()
    }

    func togglePrioritySituation(_ situation: PrioritySituation) {
        appState.togglePriorityMode(for: situation)
    }

    func clearPriorityMode() {
        appState.clearPriorityMode()
    }

    func toggleBushfireChecklist(_ kind: BushfireChecklistItemKind) {
        guard let index = profile.bushfireReadiness.checklist.firstIndex(where: { $0.kind == kind }) else {
            return
        }

        appState.mutateProfile { profile in
            profile.bushfireReadiness.checklist[index].isChecked.toggle()
        }
    }

    func shareReadinessReportItems() throws -> [Any] {
        let url = try exportReadinessReportPDF()
        let focusAreas = readinessReport.focusAreas.isEmpty ? "General Emergency" : readinessReport.focusAreas.joined(separator: ", ")
        let summary = """
        \(readinessReport.title)

        Overall score: \(readinessReport.scoreSummary)
        Focus areas: \(focusAreas)
        """
        return [summary, url]
    }

    func sendToFamilyItems() throws -> [Any] {
        let url = try exportReadinessReportPDF()
        return [appState.readinessReportService.familyShareMessage(for: readinessReport), url]
    }

    func saveReadinessReportPDF() throws -> URL {
        try appState.readinessReportService.savePDF(for: readinessReport)
    }

    private func exportReadinessReportPDF() throws -> URL {
        try appState.readinessReportService.exportPDF(for: readinessReport)
    }

    private func refreshDerivedState(for profile: UserProfile, prepScore: PrepScore) {
        let scenarios = appState.scenarioEngine.selectedScenarios(for: profile.selectedScenarios)
        recommendedGuides = appState.guideService
            .guides(ids: appState.scenarioEngine.recommendedGuideIDs(for: profile))
            .prefix(3)
            .map { $0 }
        scenarioTasks = appState.scenarioEngine.personalizedTasks(for: profile).prefix(3).map { $0 }
        readinessReport = appState.readinessReportService.generateReport(profile: profile, prepScore: prepScore)
        waterRuntimeEstimate = waterRuntimeService.estimate(for: profile, scenarios: scenarios)
        vehicleReadinessPlan = vehicleReadinessService.plan(for: profile)
        forgottenItems = preparednessInsightsService.forgottenItems(for: profile)
        expiryReminders = preparednessInsightsService.expiryReminders(for: profile)
        refreshWaterGuidance(for: profile)
        refreshPriorityMode(for: profile)
        refreshOfficialAlerts()
    }

    private func refreshWaterGuidance(for profile: UserProfile) {
        let scenarios = appState.scenarioEngine.selectedScenarios(for: profile.selectedScenarios)
        let waterTarget = appState.prepService.recommendedTargets(for: profile, scenarios: scenarios).waterLitres

        guard profile.supplies.waterLitres < waterTarget else {
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
            currentLocation: locationService.currentLocation
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
                waterSourceStatusMessage = "Allow location or install a regional pack so RediM8 can rank nearby water sources."
            } else {
                waterSourceStatusMessage = "No bundled water points are available inside the currently installed map coverage."
            }
        }
    }

    private func refreshPriorityMode(for profile: UserProfile) {
        guard let situation = appState.activePrioritySituation else {
            priorityModeSummary = nil
            return
        }

        let scenarioKinds = Array(Set(profile.selectedScenarios).union([situation.scenarioKind]))
        let scenarios = appState.scenarioEngine.selectedScenarios(for: scenarioKinds)
        let waterEstimate = waterRuntimeService.estimate(for: profile, scenarios: scenarios)
        let goBagPlan = goBagService.plan(for: profile)

        priorityModeSummary = decisionSupportService.prioritySummary(
            for: situation,
            profile: profile,
            goBagPlan: goBagPlan,
            waterEstimate: waterEstimate,
            nearbyWaterSources: resolvePriorityWaterSources(),
            nearbyShelters: resolvePriorityShelters()
        )
    }

    private func refreshOfficialAlerts() {
        let installedPacks = currentInstalledPacks()
        let nearbyAlerts = officialAlertService.nearbyAlerts(
            currentLocation: locationService.currentLocation,
            installedPacks: installedPacks
        )
        nearbyOfficialAlerts = nearbyAlerts

        if let safeModeAlert = officialAlertService.safeModeAlert(
            currentLocation: locationService.currentLocation,
            installedPacks: installedPacks
        ) {
            officialAlertSummary = OfficialAlertHomeSummary(
                title: safeModeAlert.title,
                detail: "\(safeModeAlert.severity.title) issued by \(safeModeAlert.issuer). Last updated \(DateFormatter.rediM8Short.string(from: safeModeAlert.lastUpdated)).",
                tone: .danger
            )
            safeModeSummary = buildSafeModeSummary(for: safeModeAlert, installedPacks: installedPacks)
            return
        }

        safeModeSummary = nil

        if let alert = nearbyAlerts.first {
            officialAlertSummary = OfficialAlertHomeSummary(
                title: alert.title,
                detail: alert.isAreaScoped
                    ? "\(alert.severity.title) issued by \(alert.issuer). Last updated \(DateFormatter.rediM8Short.string(from: alert.lastUpdated))."
                    : "\(alert.scopeTrustLabel) from \(alert.issuer) for \(alert.jurisdiction.title). Confirm affected areas in the official source. Last updated \(DateFormatter.rediM8Short.string(from: alert.lastUpdated)).",
                tone: alert.isAreaScoped ? (alert.severity == .advice ? .info : .caution) : .info
            )
            return
        }

        if let lastRefreshError = officialAlertService.lastRefreshError, !officialAlertService.hasCachedData {
            officialAlertSummary = OfficialAlertHomeSummary(
                title: "Official alerts unavailable",
                detail: lastRefreshError,
                tone: .caution
            )
            return
        }

        if locationService.currentLocation == nil, installedPacks.isEmpty, officialAlertService.hasCachedData {
            officialAlertSummary = OfficialAlertHomeSummary(
                title: "Warning scope unavailable",
                detail: "Location or installed map coverage is needed before RediM8 can match cached official warnings to your area.",
                tone: .info
            )
            return
        }

        if officialAlertService.hasCachedData {
            officialAlertSummary = OfficialAlertHomeSummary(
                title: "No warnings for your area",
                detail: "Cached \(officialCoverageSummary) official warning feeds show no area-scoped or jurisdiction-matched alerts right now. RediM8 does not replace official emergency alert systems.",
                tone: .ready
            )
        } else {
            officialAlertSummary = OfficialAlertHomeSummary(
                title: "Official alerts syncing",
                detail: "Connect once so RediM8 can cache public warnings for offline access.",
                tone: .info
            )
        }
    }

    private func resolvePriorityWaterSources() -> [NearbyWaterPoint] {
        let installedPackIDs = mapDataService.loadInstalledPackIDs()
        let installedPacks = mapDataService.packs(withIDs: installedPackIDs)
        guard locationService.currentLocation != nil || !installedPacks.isEmpty else {
            return []
        }

        return waterPointService.guide(
            installedPacks: installedPacks,
            installedPackIDs: installedPackIDs,
            currentLocation: locationService.currentLocation,
            limit: 2
        )?.nearbySources ?? []
    }

    private func resolvePriorityShelters() -> [NearbyShelter] {
        let installedPackIDs = mapDataService.loadInstalledPackIDs()
        let anchorCoordinate = locationService.currentLocation?.coordinate
            ?? mapDataService.packs(withIDs: installedPackIDs).sorted { $0.name < $1.name }.first?.center.coordinate

        guard let anchorCoordinate else {
            return []
        }

        return shelterService.nearbyShelters(
            near: anchorCoordinate,
            installedPackIDs: installedPackIDs,
            limit: 2
        )
    }

    private func refreshNearbyNetworkResources(for location: CLLocation?) async {
        guard let coordinate = location?.coordinate else {
            return
        }

        async let waterRefresh = waterPointService.refreshNearbyNetworkData(near: coordinate)
        async let shelterRefresh = shelterService.refreshNearbyNetworkData(near: coordinate)
        _ = await (waterRefresh, shelterRefresh)
    }

    private func currentInstalledPacks() -> [OfflineMapPack] {
        let installedPackIDs = mapDataService.loadInstalledPackIDs()
        return mapDataService.packs(withIDs: installedPackIDs)
    }

    private var officialCoverageTrustLabel: String {
        officialAlertService.cachedJurisdictions.count == AustralianJurisdiction.allCases.count
            ? "Australia-wide"
            : officialCoverageSummary
    }

    private var officialCoverageSummary: String {
        let count = officialAlertService.cachedJurisdictions.count
        if count == AustralianJurisdiction.allCases.count {
            return "Australia-wide"
        }
        if count == 1, let jurisdiction = officialAlertService.cachedJurisdictions.first {
            return jurisdiction.title
        }
        return "\(count) jurisdictions"
    }

    private func buildSafeModeSummary(for alert: OfficialAlert, installedPacks: [OfflineMapPack]) -> SafeModeHomeSummary {
        let referenceCoordinate = locationService.currentLocation?.coordinate
            ?? alert.coordinate
            ?? installedPacks.first?.center.coordinate
        let installedPackIDs = Set(installedPacks.map(\.id))
        let primaryRoute = profile.evacuationRoutes.compactMap(\.nilIfBlank).first

        guard let referenceCoordinate else {
            return SafeModeHomeSummary(
                alert: alert,
                nearestShelterLine: "Nearest shelter: unavailable without location or installed coverage",
                nearestWaterLine: "Nearest water: unavailable without location or installed coverage",
                routeLine: primaryRoute.map { "Evacuation route: \($0)" } ?? "Evacuation route: not set",
                note: "Follow official instructions first. RediM8 mirrors public alerts and keeps your local tools available offline."
            )
        }
        let nearestShelter = shelterService.nearbyShelters(
            near: referenceCoordinate,
            installedPackIDs: installedPackIDs,
            limit: 1
        ).first
        let nearestWater = waterPointService.guide(
            installedPacks: installedPacks,
            installedPackIDs: installedPackIDs,
            currentLocation: locationService.currentLocation ?? CLLocation(latitude: referenceCoordinate.latitude, longitude: referenceCoordinate.longitude),
            limit: 1
        )?.nearbySources.first
        return SafeModeHomeSummary(
            alert: alert,
            nearestShelterLine: nearestShelter.map { "\($0.shelter.name) • \($0.distanceText)" } ?? "Nearest shelter: not available in current map coverage",
            nearestWaterLine: nearestWater.map { "\($0.point.name) • \($0.distanceText)" } ?? "Nearest water: not available in current map coverage",
            routeLine: primaryRoute.map { "Evacuation route: \($0)" } ?? "Evacuation route: not set",
            note: "Follow official instructions first. RediM8 mirrors public alerts and keeps your local tools available offline."
        )
    }

    private func bushfireWaterSupplyReady(for profile: UserProfile) -> Bool {
        let scenarios = appState.scenarioEngine.selectedScenarios(for: profile.selectedScenarios)
        let target = appState.prepService.recommendedTargets(for: profile, scenarios: scenarios).waterLitres
        return profile.supplies.waterLitres >= max(target * 0.5, 20)
            || profile.bushfireChecklistState(for: .fillWaterTanks)
            || profile.bushfirePropertyState(for: .waterPumpReady)
    }

    private func bushfireEvacuationPlanScore(for profile: UserProfile) -> Double {
        let states = [
            profile.bushfireRoute(at: 0).nilIfBlank != nil,
            profile.bushfireRoute(at: 1).nilIfBlank != nil,
            profile.meetingPoints.primary.nilIfBlank != nil,
            profile.household.petCount == 0 || profile.bushfireReadiness.petEvacuationPlan.nilIfBlank != nil
        ]
        let completed = states.filter { $0 }.count
        return Double(completed) / Double(states.count) * 100
    }
}
