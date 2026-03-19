import CoreLocation
import UIKit
import XCTest
@testable import RediM8

final class AppStateSettingsTests: XCTestCase {
    @MainActor
    func testAreaScopedSafeModeAlertActivatesEmergencyUnlock() throws {
        let store = try SQLiteStore(filename: "EmergencyUnlockActive-\(UUID().uuidString).sqlite")
        try store.save(
            OfficialAlertLibrary(
                lastUpdated: Date(timeIntervalSince1970: 1_700_000_600),
                sources: [
                    OfficialAlertSource(
                        id: "qld",
                        name: "Queensland Warnings",
                        jurisdiction: .qld,
                        urlString: "https://example.com/qld"
                    )
                ],
                alerts: [
                    sampleOfficialAlert(areaScoped: true)
                ]
            ),
            for: "official_alerts.library.v2"
        )

        let appState = AppState(store: store)

        // Simulate user being near the alert (Brisbane region)
        appState.locationService.simulate(
            location: CLLocation(latitude: -27.38, longitude: 152.87)
        )
        // Refresh the emergency unlock state now that location is available
        appState.map.refreshAfterLocationChange()

        XCTAssertTrue(appState.emergencyUnlockState.isActive)
        XCTAssertEqual(appState.emergencyUnlockState.triggerAlert?.id, "qld-bushfire-test")
        XCTAssertEqual(
            appState.emergencyUnlockState.unlockedFeatureIDs,
            RediM8MonetizationCatalog.launch.emergencyUnlockFeatureIDs
        )
    }

    @MainActor
    func testJurisdictionOnlyAlertDoesNotActivateEmergencyUnlock() throws {
        let store = try SQLiteStore(filename: "EmergencyUnlockStandby-\(UUID().uuidString).sqlite")
        try store.save(
            OfficialAlertLibrary(
                lastUpdated: Date(timeIntervalSince1970: 1_700_000_600),
                sources: [
                    OfficialAlertSource(
                        id: "qld",
                        name: "Queensland Warnings",
                        jurisdiction: .qld,
                        urlString: "https://example.com/qld"
                    )
                ],
                alerts: [
                    sampleOfficialAlert(areaScoped: false)
                ]
            ),
            for: "official_alerts.library.v2"
        )

        let appState = AppState(store: store)

        XCTAssertFalse(appState.emergencyUnlockState.isVisible)
        XCTAssertEqual(appState.emergencyUnlockState.phase, .inactive)
    }

    @MainActor
    func testDisablingSurvivalModeThresholdSuppressesLowBatteryPrompt() {
        let appState = AppState(store: nil)
        appState.mutateSettings { settings in
            settings.battery.enablesSurvivalModeAtFifteenPercent = false
        }

        appState.applyBatteryStatus(BatteryStatus(level: 0.10, state: .unplugged))

        XCTAssertFalse(appState.shouldPromptForSurvivalMode)
    }

    @MainActor
    func testSettingMapLayerUpdatesSettingsAndMapStorage() {
        let store = try? SQLiteStore(filename: "AppStateSettingsTests-\(UUID().uuidString).sqlite")
        let appState = AppState(store: store)

        appState.setMapLayer(.communityBeacons, isEnabled: true)

        XCTAssertTrue(appState.settings.maps.defaultLayers.contains(.communityBeacons))
        XCTAssertTrue(appState.mapDataService.loadEnabledLayers().contains(.communityBeacons))
    }

    @MainActor
    func testStealthModeOverridesRuntimeWithoutMutatingPrivacySettings() {
        let appState = AppState(store: nil)
        let originalPrivacy = appState.settings.privacy

        appState.enableStealthMode()

        XCTAssertTrue(appState.isStealthModeEnabled)
        XCTAssertEqual(appState.settings.privacy, originalPrivacy)
        XCTAssertTrue(appState.meshService.localPeer.displayName.hasPrefix("Node "))

        appState.disableStealthMode()

        XCTAssertFalse(appState.isStealthModeEnabled)
        XCTAssertEqual(appState.settings.privacy, originalPrivacy)
    }

    @MainActor
    func testStealthModeRespectsFeatureFlag() {
        let featureFlags = AppFeatureFlags(
            usesPersistentSQLiteStorage: false,
            enablesStealthMode: false,
            enablesLowBatterySurvivalMode: true,
            enablesMotionFeatures: false
        )
        let appState = AppState(environment: .testing(store: nil, featureFlags: featureFlags))

        appState.enableStealthMode()

        XCTAssertFalse(appState.isStealthModeEnabled)
    }

    @MainActor
    func testCompletingOnboardingWithBushfireEnablesPriorityMapLayers() {
        let store = try? SQLiteStore(filename: "BushfireOnboarding-\(UUID().uuidString).sqlite")
        let appState = AppState(store: store)

        var profile = UserProfile.empty
        profile.selectedScenarios = [.bushfires]

        appState.completeOnboarding(with: profile)

        XCTAssertTrue(appState.settings.maps.defaultLayers.contains(.waterPoints))
        XCTAssertTrue(appState.settings.maps.defaultLayers.contains(.evacuationPoints))
        XCTAssertFalse(appState.settings.maps.defaultLayers.contains(.fireTrails))
    }

    @MainActor
    func testOnboardingViewModelFallsBackToGeneralEmergencyWhenSpecificRisksAreCleared() {
        let appState = AppState(store: nil)
        let viewModel = OnboardingViewModel(appState: appState)

        XCTAssertEqual(viewModel.selectedScenariosOrFallback, [.generalEmergencies])

        viewModel.toggle(.bushfires)
        XCTAssertFalse(viewModel.selectedScenarios.contains(.generalEmergencies))
        XCTAssertEqual(viewModel.selectedScenariosOrFallback, [.bushfires])

        viewModel.toggle(.bushfires)
        XCTAssertEqual(viewModel.selectedScenariosOrFallback, [.generalEmergencies])
    }

    @MainActor
    func testOnboardingSafetyStepAcknowledgesNoticeBeforeContinuing() {
        let appState = AppState(store: nil)
        let viewModel = OnboardingViewModel(appState: appState)

        viewModel.next()

        XCTAssertEqual(viewModel.currentStep, .safety)
        XCTAssertFalse(viewModel.hasAcknowledgedSafetyNotice)

        viewModel.next()

        XCTAssertEqual(viewModel.currentStep, .scenarios)
        XCTAssertTrue(viewModel.hasAcknowledgedSafetyNotice)
    }

    @MainActor
    func testOnboardingViewModelFinishPersistsScenariosAndBushfireLayers() {
        let store = try? SQLiteStore(filename: "OnboardingFinish-\(UUID().uuidString).sqlite")
        let appState = AppState(store: store)
        let viewModel = OnboardingViewModel(appState: appState)

        viewModel.selectedScenarios = [.bushfires, .remoteTravel]

        viewModel.finish()

        XCTAssertEqual(appState.profile.selectedScenarios, [.bushfires, .remoteTravel])
        XCTAssertTrue(appState.profile.isOnboardingComplete)
        XCTAssertNotNil(appState.profile.lastAcknowledgedSafetyNoticeAt)
        XCTAssertTrue(appState.settings.maps.defaultLayers.contains(.evacuationPoints))
        XCTAssertTrue(appState.settings.maps.defaultLayers.contains(.waterPoints))
    }

    @MainActor
    func testProfileCompletionStepsTrackProgressiveDisclosure() {
        var profile = UserProfile.empty
        XCTAssertFalse(profile.isProfileFullyComplete)
        XCTAssertEqual(profile.nextIncompleteProfileStep?.id, "household")

        profile.household = HouseholdDetails(peopleCount: 2, petCount: 1)
        profile.emergencyContacts = [EmergencyContact(name: "Alex", phone: "0400 123 456")]
        profile.evacuationRoutes = ["Pacific Motorway northbound"]
        profile.supplies = Supplies(waterLitres: 20, foodDays: 3, fuelLitres: 10, batteryCapacity: 50)
        profile.emergencyMedicalInfo = EmergencyMedicalInfo(
            criticalConditions: [.asthma],
            severeAllergies: "Peanuts",
            bloodType: "O+"
        )
        profile.checklistItems = [
            ChecklistItem(kind: .firstAidKit, isChecked: true),
            ChecklistItem(kind: .batteryRadio, isChecked: false),
            ChecklistItem(kind: .torch, isChecked: false),
            ChecklistItem(kind: .powerBank, isChecked: false),
            ChecklistItem(kind: .fireBlanket, isChecked: false)
        ]

        XCTAssertTrue(profile.isProfileFullyComplete)
        XCTAssertEqual(profile.profileCompletionFraction, 1.0)
        XCTAssertNil(profile.nextIncompleteProfileStep)
    }

    func testAnalogRescueSnapshotPrefersPrimaryFamilyMemberAndProfileMedicalInfo() {
        var profile = UserProfile.empty
        profile.familyMembers = [
            FamilyMember(name: "Taylor", phone: "0400 000 111", medicalNotes: "", emergencyRole: "Primary", isPrimaryUser: true)
        ]
        profile.emergencyContacts = [
            EmergencyContact(name: "Alex", phone: "0400 123 456")
        ]
        profile.emergencyMedicalInfo = EmergencyMedicalInfo(
            criticalConditions: [.asthma],
            severeAllergies: "Peanuts",
            otherCriticalCondition: "",
            bloodType: "O+",
            emergencyMedication: "Ventolin"
        )

        let snapshot = AnalogRescueSnapshot(
            profile: profile,
            fallbackOwnerName: "Thomas's iPhone",
            location: CLLocation(latitude: -27.4705, longitude: 153.0260)
        )

        XCTAssertEqual(snapshot.ownerName, "Taylor")
        XCTAssertEqual(snapshot.bloodType, "O+")
        XCTAssertEqual(snapshot.allergies, "Peanuts")
        XCTAssertEqual(snapshot.medication, "Ventolin")
        XCTAssertEqual(snapshot.conditionSummary, "Asthma")
        XCTAssertEqual(snapshot.contacts.first?.name, "Alex")
        XCTAssertEqual(snapshot.coordinatesText, "-27.4705, 153.0260")
    }

    func testAnalogRescueSnapshotFallsBackToDeviceNameWhenProfileIsEmpty() {
        let snapshot = AnalogRescueSnapshot(
            profile: .empty,
            fallbackOwnerName: "Thomas's iPhone",
            location: nil
        )

        XCTAssertEqual(snapshot.ownerName, "Thomas's iPhone")
        XCTAssertNil(snapshot.coordinatesText)
        XCTAssertFalse(snapshot.hasAnyMedicalInfo)
        XCTAssertTrue(snapshot.contacts.isEmpty)
    }

    func testScannerSnapshotEscalatesOfflineLowBatteryState() {
        let snapshot = SituationalScannerSnapshot(
            gpsState: .unavailable,
            networkState: .offline,
            radioState: .bluetoothOff,
            pressureTrend: .unavailable,
            powerState: .onBattery,
            batteryStatus: BatteryStatus(level: 0.10, state: .unplugged),
            lastNetworkDropAt: .now,
            updatedAt: .now
        )

        XCTAssertEqual(snapshot.tone, .danger)
        XCTAssertTrue(snapshot.alerts.contains { $0.title == "Network drop detected" })
        XCTAssertTrue(snapshot.alerts.contains { $0.title == "Battery reserve is low" })
    }

    func testScannerSnapshotSurfacesPressureAndRadioDensityCues() {
        let snapshot = SituationalScannerSnapshot(
            gpsState: .locked,
            networkState: .cellularAvailable,
            radioState: .scanning(16),
            pressureTrend: .falling,
            powerState: .charging,
            batteryStatus: BatteryStatus(level: 0.72, state: .charging),
            lastNetworkDropAt: nil,
            updatedAt: .now
        )

        XCTAssertEqual(snapshot.tone, .caution)
        XCTAssertTrue(snapshot.alerts.contains { $0.title == "Pressure trend is falling" })
        XCTAssertTrue(snapshot.alerts.contains { $0.title == "Nearby radio activity is high" })
        XCTAssertEqual(snapshot.statusLabel, "Monitor")
    }

    @MainActor
    func testSignalViewModelSeedsAccountabilityCircleFromProfile() {
        var profile = UserProfile.empty
        profile.familyMembers = [
            FamilyMember(name: "TJ", phone: "0400 000 111", medicalNotes: "", emergencyRole: "Primary", isPrimaryUser: true),
            FamilyMember(name: "Emma", phone: "0400 000 222", medicalNotes: "", emergencyRole: "Family")
        ]
        profile.emergencyContacts = [
            EmergencyContact(name: "Dad", phone: "0400 000 333")
        ]

        let circle = SignalViewModel.synchronizedAccountabilityCircle(
            .empty,
            with: profile,
            fallbackLocalName: "You"
        )

        XCTAssertEqual(circle.title, "Household Status")
        XCTAssertEqual(circle.members.map(\.name), ["TJ", "Emma", "Dad"])
        XCTAssertEqual(circle.members.first?.source, .selfUser)
        XCTAssertEqual(circle.members[1].source, .family)
        XCTAssertEqual(circle.members[2].source, .emergencyContact)
    }

    func testMeshMessageEncodesAccountabilityStatusPayload() throws {
        let message = MeshMessage(
            sender: "TJ",
            body: "TJ: Safe",
            kind: .accountabilityStatus,
            accountabilityStatus: AccountabilityMeshStatus(
                circleTitle: "Family",
                memberName: "TJ",
                status: .safe,
                note: "At rally point"
            )
        )

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(MeshMessage.self, from: data)

        XCTAssertEqual(decoded.kind, .accountabilityStatus)
        XCTAssertEqual(decoded.accountabilityStatus?.circleTitle, "Family")
        XCTAssertEqual(decoded.accountabilityStatus?.memberName, "TJ")
        XCTAssertEqual(decoded.accountabilityStatus?.status, .safe)
        XCTAssertEqual(decoded.accountabilityStatus?.note, "At rally point")
    }

    private func sampleOfficialAlert(areaScoped: Bool) -> OfficialAlert {
        let issuedAt = Date(timeIntervalSinceNow: -600)
        let lastUpdated = Date(timeIntervalSinceNow: -120)
        let expiresAt = Date(timeIntervalSinceNow: 3_600)

        return OfficialAlert(
            id: "qld-bushfire-test",
            title: "Bushfire Warning",
            message: "Leave now if the threat increases.",
            instruction: "Monitor local conditions.",
            issuer: "Queensland Fire Department",
            sourceName: "Queensland Warnings",
            sourceURLString: "https://example.com/alert",
            jurisdiction: .qld,
            kind: .bushfire,
            severity: .watchAndAct,
            regionScope: "Brisbane Region",
            area: areaScoped
                ? OfficialAlertArea(
                    description: "Brisbane hinterland",
                    center: GeoPoint(latitude: -27.3811, longitude: 152.8667),
                    radiusKilometres: 25
                )
                : nil,
            issuedAt: issuedAt,
            lastUpdated: lastUpdated,
            expiresAt: expiresAt
        )
    }
}
