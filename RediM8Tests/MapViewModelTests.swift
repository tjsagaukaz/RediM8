import XCTest
@testable import RediM8

@MainActor
final class MapViewModelTests: XCTestCase {
    func testNoInstalledPackFallbackSummariesAreShown() {
        let appState = AppState(store: nil)
        appState.mapDataService.seedInstalledPackIDsForTesting([])
        appState.mutateSettings { settings in
            settings.maps.surfaceMode = .tactical
        }

        let viewModel = MapViewModel(appState: appState, disablesAutomaticRuntimeActivity: true)

        XCTAssertTrue(viewModel.installedPacks.isEmpty)
        XCTAssertEqual(viewModel.coverageLimitHeadline, "No offline pack installed")
        XCTAssertTrue(viewModel.offlineFallbackSummary.contains("Offline map pack not installed"))
        XCTAssertTrue(viewModel.coverageLimitSummary.contains("No regional pack is installed"))
    }

    func testInstallingPackRecoversCoverageAndFocusesViewport() throws {
        let appState = AppState(store: nil)
        appState.mapDataService.seedInstalledPackIDsForTesting([])
        appState.mutateSettings { settings in
            settings.maps.surfaceMode = .tactical
        }

        let viewModel = MapViewModel(appState: appState, disablesAutomaticRuntimeActivity: true)
        let pack = try XCTUnwrap(viewModel.availablePacks.first(where: { $0.id == "brisbane_region" }))
        let initialViewportRevision = viewModel.viewportRevision

        viewModel.installPack(pack.id)

        XCTAssertTrue(viewModel.installedPackIDs.contains(pack.id))
        XCTAssertEqual(viewModel.coverageLimitHeadline, pack.name)
        XCTAssertEqual(viewModel.offlineFallbackSummary, "Regional offline coverage is installed.")
        XCTAssertTrue(viewModel.coverageLimitSummary.contains("Installed coverage: \(pack.name)"))
        XCTAssertEqual(viewModel.viewportRevision, initialViewportRevision + 1)
        XCTAssertEqual(viewModel.viewportRegion.center.latitude, pack.center.latitude, accuracy: 0.001)
        XCTAssertEqual(viewModel.viewportRegion.center.longitude, pack.center.longitude, accuracy: 0.001)
    }

    func testOnAppearSkipsAutomaticRuntimeActivityWhenDisabled() {
        let appState = AppState(store: nil)
        let viewModel = MapViewModel(appState: appState, disablesAutomaticRuntimeActivity: true)

        viewModel.onAppear()

        XCTAssertEqual(appState.locationService.activeClientCount, 0)
        XCTAssertEqual(viewModel.viewportRevision, 1)
    }

    func testUnavailableBasemapFallbackStateIsSurfaced() {
        let appState = AppState(store: nil)
        appState.mutateSettings { settings in
            settings.maps.surfaceMode = .tactical
        }
        appState.offlineBasemapService.seedForTesting(
            configuration: OfflineBasemapService.Configuration(
                styleURL: appState.offlineBasemapService.configuration.styleURL,
                mode: .fallback(reason: "Installed basemap package is incomplete or invalid.")
            )
        )

        let viewModel = MapViewModel(appState: appState, disablesAutomaticRuntimeActivity: true)

        XCTAssertFalse(viewModel.isPremiumBasemapActive)
        XCTAssertEqual(viewModel.mapStatusHeadline, "Offline fallback active")
        XCTAssertTrue(viewModel.basemapStatusMessage.contains("unavailable"))
        XCTAssertTrue(viewModel.workingBasemapSummary.contains("tactical fallback surface is active"))
    }
}
