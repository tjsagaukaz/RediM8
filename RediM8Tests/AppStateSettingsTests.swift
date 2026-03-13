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
    func testOnboardingViewModelFinishPersistsPlanBasicsAndTrustDefaults() {
        let store = try? SQLiteStore(filename: "OnboardingFinish-\(UUID().uuidString).sqlite")
        let appState = AppState(store: store)
        let viewModel = OnboardingViewModel(appState: appState)

        viewModel.selectedScenarios = [.bushfires, .remoteTravel]
        viewModel.peopleCount = 3
        viewModel.petCount = 2
        viewModel.primaryMeetingPoint = "South Oval"
        viewModel.primaryEvacuationRoute = "Pacific Motorway northbound"
        viewModel.emergencyContactName = "Alex"
        viewModel.emergencyContactPhone = "0400 123 456"
        viewModel.medicalNotes = "Ventolin inhaler in glove box"
        viewModel.emergencyMedicalConditions = [.asthma, .bloodThinnerMedication]
        viewModel.severeAllergies = "Peanuts"
        viewModel.bloodType = "O+"
        viewModel.emergencyMedication = "Inhaler in glove box"
        viewModel.otherCriticalCondition = "Uses hearing aid"
        viewModel.isAnonymousModeEnabled = true
        viewModel.locationShareMode = .off
        viewModel.enablesSurvivalModeAtFifteenPercent = false
        viewModel.reducesMapAnimations = true

        viewModel.finish()

        XCTAssertEqual(appState.profile.selectedScenarios, [.bushfires, .remoteTravel])
        XCTAssertEqual(appState.profile.household.peopleCount, 3)
        XCTAssertEqual(appState.profile.household.petCount, 2)
        XCTAssertEqual(appState.profile.meetingPoints.primary, "South Oval")
        XCTAssertEqual(appState.profile.evacuationRoutes.first, "Pacific Motorway northbound")
        XCTAssertEqual(appState.profile.emergencyContacts.first?.name, "Alex")
        XCTAssertEqual(appState.profile.emergencyContacts.first?.phone, "0400 123 456")
        XCTAssertEqual(appState.profile.medicalNotes, "Ventolin inhaler in glove box")
        XCTAssertEqual(appState.profile.emergencyMedicalInfo.criticalConditions, [.asthma, .bloodThinnerMedication])
        XCTAssertEqual(appState.profile.emergencyMedicalInfo.severeAllergies, "Peanuts")
        XCTAssertEqual(appState.profile.emergencyMedicalInfo.bloodType, "O+")
        XCTAssertEqual(appState.profile.emergencyMedicalInfo.emergencyMedication, "Inhaler in glove box")
        XCTAssertEqual(appState.profile.emergencyMedicalInfo.otherCriticalCondition, "Uses hearing aid")
        XCTAssertTrue(appState.profile.isOnboardingComplete)
        XCTAssertNotNil(appState.profile.lastAcknowledgedSafetyNoticeAt)

        XCTAssertTrue(appState.settings.privacy.isAnonymousModeEnabled)
        XCTAssertEqual(appState.settings.privacy.locationShareMode, .off)
        XCTAssertFalse(appState.settings.battery.enablesSurvivalModeAtFifteenPercent)
        XCTAssertTrue(appState.settings.battery.reducesMapAnimations)
        XCTAssertTrue(appState.settings.maps.defaultLayers.contains(.evacuationPoints))
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
