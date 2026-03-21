import SwiftUI

struct MapView: View {
    @StateObject private var viewModel: MapViewModel
    private let appState: AppState
    private let scrollToTopRequestID: Int
    private let openEvacuationRoutes: () -> Void

    init(
        appState: AppState,
        scrollToTopRequestID: Int = 0,
        openEvacuationRoutes: @escaping () -> Void = {},
        disablesAutomaticMapActivity: Bool = false
    ) {
        self.appState = appState
        self.scrollToTopRequestID = scrollToTopRequestID
        self.openEvacuationRoutes = openEvacuationRoutes
        _viewModel = StateObject(
            wrappedValue: MapViewModel(
                appState: appState,
                disablesAutomaticRuntimeActivity: disablesAutomaticMapActivity
            )
        )
    }

    var body: some View {
        MapContainerView(
            viewModel: viewModel,
            appState: appState,
            scrollToTopRequestID: scrollToTopRequestID,
            openEvacuationRoutes: openEvacuationRoutes
        )
    }
}
