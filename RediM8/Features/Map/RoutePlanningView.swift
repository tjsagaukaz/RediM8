import CoreLocation
import SwiftUI

struct RoutePlanningView: View {
    let appState: AppState
    let currentLocation: CLLocation?

    @State private var destinationType: DestinationType = .shelter
    @State private var selectedDestination: NearestResourceService.NearestResult?
    @State private var computedRoute: OfflineRoutingService.Route?
    @State private var routeError: String?
    @State private var isComputing = false
    @State private var destinations: [NearestResourceService.NearestResult] = []

    enum DestinationType: String, CaseIterable, Identifiable {
        case shelter
        case town
        case water

        var id: String { rawValue }

        var title: String {
            switch self {
            case .shelter: "SHELTER"
            case .town: "TOWN"
            case .water: "WATER"
            }
        }

        var icon: String {
            switch self {
            case .shelter: "house"
            case .town: "building.2"
            case .water: "drop"
            }
        }

        var resourceCategory: NearestResourceService.ResourceCategory {
            switch self {
            case .shelter: .shelter
            case .town: .town
            case .water: .water
            }
        }
    }

    private var nearestService: NearestResourceService {
        NearestResourceService(
            waterPointService: appState.waterPointService,
            shelterService: appState.shelterService,
            mapService: appState.mapService,
            mapDataService: appState.mapDataService
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            originHeader
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.content)
                .padding(.bottom, RediSpacing.compact)

            Divider()
                .background(ColorTheme.divider)

            destinationSelector
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.content)
                .padding(.bottom, RediSpacing.compact)

            Divider()
                .background(ColorTheme.divider)

            if isComputing {
                computingState
            } else if let route = computedRoute {
                routeResult(route)
            } else if let error = routeError {
                errorState(error)
            } else {
                destinationList
            }
        }
        .background(ColorTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("ROUTE PLANNER")
                        .font(RediTypography.data)
                        .foregroundStyle(ColorTheme.text)
                    Text("OFFLINE ROUTING ENGINE")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: destinationType) { _, _ in
            selectedDestination = nil
            computedRoute = nil
            routeError = nil
            loadDestinations()
        }
        .onAppear {
            loadDestinations()
        }
    }

    // MARK: - Origin

    private var originHeader: some View {
        VStack(alignment: .leading, spacing: RediSpacing.micro) {
            Text("ORIGIN")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)

            if let location = currentLocation {
                HStack(spacing: RediSpacing.tight) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTheme.accent)
                    Text(coordinateString(location.coordinate))
                        .font(RediTypography.data)
                        .foregroundStyle(ColorTheme.text)
                    Text("CURRENT POSITION")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
            } else {
                HStack(spacing: RediSpacing.tight) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text("LOCATION UNAVAILABLE")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
            }
        }
    }

    // MARK: - Destination Type Selector

    private var destinationSelector: some View {
        VStack(alignment: .leading, spacing: RediSpacing.compact) {
            Text("DESTINATION TYPE")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)

            HStack(spacing: RediSpacing.compact) {
                ForEach(DestinationType.allCases) { type in
                    Button {
                        destinationType = type
                    } label: {
                        HStack(spacing: RediSpacing.tight) {
                            Image(systemName: type.icon)
                                .font(.system(size: 12, weight: .medium))
                            Text(type.title)
                                .font(RediTypography.label)
                                .tracking(1.2)
                        }
                        .foregroundStyle(
                            destinationType == type
                                ? ColorTheme.accent
                                : ColorTheme.textTertiary
                        )
                        .padding(.horizontal, RediSpacing.content)
                        .padding(.vertical, RediSpacing.compact)
                        .background(
                            destinationType == type
                                ? ColorTheme.accent.opacity(0.1)
                                : ColorTheme.graphite,
                            in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                                .stroke(
                                    destinationType == type
                                        ? ColorTheme.accent.opacity(0.3)
                                        : ColorTheme.divider,
                                    lineWidth: 0.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Destination List

    private var destinationList: some View {
        ScrollView {
            if destinations.isEmpty {
                emptyState
                    .padding(.top, RediSpacing.section)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text("SELECT DESTINATION")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                        .padding(.horizontal, RediSpacing.screen)
                        .padding(.top, RediSpacing.content)
                        .padding(.bottom, RediSpacing.compact)

                    ForEach(Array(destinations.enumerated()), id: \.element.id) { index, dest in
                        Button {
                            selectedDestination = dest
                            computeRoute(to: dest)
                        } label: {
                            destinationRow(dest, index: index + 1)
                        }
                        .buttonStyle(.plain)

                        if index < destinations.count - 1 {
                            Divider()
                                .background(ColorTheme.dividerSubtle)
                                .padding(.leading, RediSpacing.screen)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func destinationRow(_ result: NearestResourceService.NearestResult, index: Int) -> some View {
        HStack(alignment: .top, spacing: RediSpacing.content) {
            Text("\(index)")
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.accent)
                .frame(width: 20, alignment: .trailing)

            VStack(alignment: .leading, spacing: RediSpacing.micro) {
                Text(result.name.uppercased())
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                    .lineLimit(1)

                Text(result.subtitle)
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: RediSpacing.micro) {
                Text(result.distanceText)
                    .font(RediTypography.data)
                    .foregroundStyle(ColorTheme.text)
                Text("DIRECT")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)
            }
        }
        .padding(.horizontal, RediSpacing.screen)
        .padding(.vertical, RediSpacing.content)
        .contentShape(Rectangle())
    }

    // MARK: - Route Result

    private func routeResult(_ route: OfflineRoutingService.Route) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Route summary
                routeSummary(route)
                    .padding(.horizontal, RediSpacing.screen)
                    .padding(.vertical, RediSpacing.content)

                Divider()
                    .background(ColorTheme.divider)

                // Turn-by-turn steps
                if !route.steps.isEmpty {
                    Text("TURN-BY-TURN")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                        .padding(.horizontal, RediSpacing.screen)
                        .padding(.top, RediSpacing.content)
                        .padding(.bottom, RediSpacing.compact)

                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
                            stepRow(step, index: index + 1)

                            if index < route.steps.count - 1 {
                                Divider()
                                    .background(ColorTheme.dividerSubtle)
                                    .padding(.leading, RediSpacing.screen)
                            }
                        }
                    }
                }

                // Actions
                VStack(spacing: RediSpacing.compact) {
                    if let dest = selectedDestination {
                        Button {
                            openInMaps(dest)
                        } label: {
                            Label("OPEN IN MAPS", systemImage: "map")
                                .font(RediTypography.button)
                                .tracking(0.3)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }

                    Button {
                        computedRoute = nil
                        selectedDestination = nil
                        routeError = nil
                    } label: {
                        Label("NEW ROUTE", systemImage: "arrow.triangle.turn.up.right.diamond")
                            .font(RediTypography.button)
                            .tracking(0.3)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
                .padding(.horizontal, RediSpacing.screen)
                .padding(.vertical, RediSpacing.content)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func routeSummary(_ route: OfflineRoutingService.Route) -> some View {
        VStack(alignment: .leading, spacing: RediSpacing.content) {
            if let dest = selectedDestination {
                Text(dest.name.uppercased())
                    .font(RediTypography.heading)
                    .foregroundStyle(ColorTheme.text)
            }

            HStack(spacing: RediSpacing.section) {
                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text("DISTANCE")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text(formatDistance(route.distanceMetres))
                        .font(RediTypography.dataLarge)
                        .foregroundStyle(ColorTheme.text)
                }

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text("EST. TIME")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text(formatDuration(route.durationSeconds))
                        .font(RediTypography.dataLarge)
                        .foregroundStyle(ColorTheme.text)
                }

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text("STEPS")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text("\(route.steps.count)")
                        .font(RediTypography.dataLarge)
                        .foregroundStyle(ColorTheme.text)
                }
            }

            HStack(spacing: RediSpacing.tight) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTheme.ready)
                Text("COMPUTED OFFLINE")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.ready)
            }
        }
    }

    private func stepRow(_ step: OfflineRoutingService.RouteStep, index: Int) -> some View {
        HStack(alignment: .top, spacing: RediSpacing.content) {
            Image(systemName: maneuverIcon(step.maneuver))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(step.maneuver == .arrive ? ColorTheme.ready : ColorTheme.accent)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: RediSpacing.micro) {
                Text(step.instruction.uppercased())
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)

                if step.distanceMetres > 0 {
                    Text(formatDistance(step.distanceMetres))
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                }
            }

            Spacer(minLength: 0)

            Text(coordinateString(step.coordinate))
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.textTertiary)
        }
        .padding(.horizontal, RediSpacing.screen)
        .padding(.vertical, RediSpacing.content)
    }

    private func maneuverIcon(_ maneuver: OfflineRoutingService.Maneuver) -> String {
        switch maneuver {
        case .depart: "location.fill"
        case .arrive: "flag.fill"
        case .continueStraight: "arrow.up"
        case .slightLeft: "arrow.up.left"
        case .slightRight: "arrow.up.right"
        case .turnLeft: "arrow.turn.up.left"
        case .turnRight: "arrow.turn.up.right"
        case .sharpLeft: "arrow.turn.down.left"
        case .sharpRight: "arrow.turn.down.right"
        case .uTurn: "arrow.uturn.down"
        }
    }

    // MARK: - States

    private var computingState: some View {
        VStack(spacing: RediSpacing.content) {
            Spacer()
            ProgressView()
                .tint(ColorTheme.accent)
            Text("COMPUTING ROUTE")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
            Text("Running bidirectional Dijkstra on CH overlay graph.")
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, RediSpacing.screen)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: RediSpacing.content) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(ColorTheme.warning)
            Text("ROUTING UNAVAILABLE")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
            Text(message)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                routeError = nil
                selectedDestination = nil
            } label: {
                Text("TRY AGAIN")
                    .font(RediTypography.button)
                    .tracking(0.3)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .padding(.top, RediSpacing.compact)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, RediSpacing.screen)
    }

    private var emptyState: some View {
        VStack(spacing: RediSpacing.content) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(ColorTheme.textTertiary)
            Text("NO DESTINATIONS")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
            Text("No \(destinationType.title.lowercased()) destinations found in offline data.")
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, RediSpacing.screen)
    }

    // MARK: - Actions

    private func loadDestinations() {
        guard let location = currentLocation else {
            destinations = []
            return
        }

        let installedPackIDs = appState.mapDataService.loadInstalledPackIDs()
        destinations = nearestService.nearest(
            destinationType.resourceCategory,
            to: location.coordinate,
            installedPackIDs: installedPackIDs,
            limit: 10
        )
    }

    private func computeRoute(to destination: NearestResourceService.NearestResult) {
        guard let location = currentLocation else {
            routeError = "Location unavailable. Enable location services to compute routes."
            return
        }

        isComputing = true
        routeError = nil
        computedRoute = nil

        // Try to load best graph for current location
        let installedPackIDs = appState.mapDataService.loadInstalledPackIDs()
        let installedPacks = appState.mapDataService.packs(withIDs: installedPackIDs)

        do {
            try appState.offlineRoutingService.loadBestGraph(
                near: location.coordinate,
                installedPacks: installedPacks
            )

            let route = try appState.offlineRoutingService.route(
                from: location.coordinate,
                to: destination.coordinate
            )
            computedRoute = route
        } catch {
            routeError = error.localizedDescription
        }

        isComputing = false
    }

    private func openInMaps(_ result: NearestResourceService.NearestResult) {
        let encodedName = result.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? result.name
        if let url = URL(string: "maps://?ll=\(result.coordinate.latitude),\(result.coordinate.longitude)&q=\(encodedName)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Formatting

    private func coordinateString(_ coord: CLLocationCoordinate2D) -> String {
        String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
    }

    private func formatDistance(_ metres: CLLocationDistance) -> String {
        if metres >= 1000 {
            return String(format: "%.1f KM", metres / 1000)
        }
        return "\(Int(metres.rounded())) M"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)H \(minutes)M"
        }
        return "\(minutes) MIN"
    }
}
