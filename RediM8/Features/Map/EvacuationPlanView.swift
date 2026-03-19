import CoreLocation
import SwiftUI

/// Evacuation Mode — computes a full survival corridor plan.
///
/// User selects a destination (shelter/town), app computes:
///   - Offline route via CH engine
///   - Water sources along path
///   - Shelters along path
///   - Towns/services along path
///   - Route corridor summary (water gap, shelter coverage)
///
/// Presented as an actionable evacuation briefing.
struct EvacuationPlanView: View {
    let appState: AppState
    let currentLocation: CLLocation?

    @State private var selectedDestination: NearestResourceService.NearestResult?
    @State private var corridorAnalysis: RouteCorridor.CorridorAnalysis?
    @State private var routeError: String?
    @State private var isComputing = false
    @State private var destinations: [NearestResourceService.NearestResult] = []
    @State private var selectedProfile: OfflineRoutingService.RoutingProfile = .vehicle
    @State private var selectedTab: CorridorTab = .summary
    @State private var rankedRoutes: [OfflineRoutingService.RankedRoute] = []
    @State private var selectedRouteID: UUID?
    @State private var isShowingProPaywall = false

    private var isProUser: Bool { appState.isProUser }

    enum CorridorTab: String, CaseIterable, Identifiable {
        case summary
        case water
        case shelters
        case steps

        var id: String { rawValue }

        var title: String {
            switch self {
            case .summary: "SUMMARY"
            case .water: "WATER"
            case .shelters: "SHELTERS"
            case .steps: "ROUTE"
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
            if let analysis = corridorAnalysis {
                corridorResultView(analysis)
            } else if !rankedRoutes.isEmpty {
                routeSelectionView
            } else if isComputing {
                computingState
            } else if let error = routeError {
                errorState(error)
            } else {
                destinationSelector
            }
        }
        .background(ColorTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("EVACUATION PLAN")
                        .font(RediTypography.data)
                        .foregroundStyle(ColorTheme.text)
                    Text("SURVIVAL CORRIDOR ANALYSIS")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { loadDestinations() }
        .sheet(isPresented: $isShowingProPaywall) {
            NavigationStack {
                RediM8ProView(
                    storeKitService: appState.storeKitService,
                    emergencyUnlockState: appState.emergencyUnlockState
                )
            }
            .rediSheetPresentation()
        }
    }

    // MARK: - Destination Selection

    private var destinationSelector: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile selector
            profileSelector
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.content)
                .padding(.bottom, RediSpacing.compact)

            Divider().background(ColorTheme.divider)

            // Origin info
            originInfo
                .padding(.horizontal, RediSpacing.screen)
                .padding(.vertical, RediSpacing.content)

            Divider().background(ColorTheme.divider)

            // Destination list
            ScrollView {
                if destinations.isEmpty {
                    emptyDestinationsState
                        .padding(.top, RediSpacing.section)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Text("SELECT EVACUATION DESTINATION")
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)
                            .padding(.horizontal, RediSpacing.screen)
                            .padding(.top, RediSpacing.content)
                            .padding(.bottom, RediSpacing.compact)

                        ForEach(Array(destinations.enumerated()), id: \.element.id) { index, dest in
                            Button { computeEvacuation(to: dest) } label: {
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
    }

    private var profileSelector: some View {
        VStack(alignment: .leading, spacing: RediSpacing.compact) {
            Text("TRAVEL MODE")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)

            HStack(spacing: RediSpacing.compact) {
                ForEach(OfflineRoutingService.RoutingProfile.allCases) { profile in
                    Button {
                        selectedProfile = profile
                    } label: {
                        Text(profile.title.uppercased())
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(
                                selectedProfile == profile
                                    ? ColorTheme.accent
                                    : ColorTheme.textTertiary
                            )
                            .padding(.horizontal, RediSpacing.content)
                            .padding(.vertical, RediSpacing.compact)
                            .background(
                                selectedProfile == profile
                                    ? ColorTheme.accent.opacity(0.1)
                                    : ColorTheme.graphite,
                                in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                                    .stroke(
                                        selectedProfile == profile
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

    private var originInfo: some View {
        HStack(spacing: RediSpacing.tight) {
            Image(systemName: currentLocation != nil ? "location.fill" : "location.slash")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(currentLocation != nil ? ColorTheme.accent : ColorTheme.textTertiary)
            Text(currentLocation != nil ? "CURRENT POSITION" : "LOCATION UNAVAILABLE")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
        }
    }

    // MARK: - Route Selection (Ranked Alternatives)

    private var routeSelectionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let dest = selectedDestination {
                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text("EVACUATING TO")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text(dest.name.uppercased())
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)
                }
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.content)
                .padding(.bottom, RediSpacing.compact)
            }

            // Evacuation Intelligence Advisory
            if let advisory = computeAdvisory() {
                advisoryPanel(advisory)
                    .padding(.horizontal, RediSpacing.screen)
                    .padding(.bottom, RediSpacing.compact)
            }

            Text("SELECT ROUTE")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
                .padding(.horizontal, RediSpacing.screen)
                .padding(.bottom, RediSpacing.compact)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: RediSpacing.compact) {
                    ForEach(rankedRoutes) { ranked in
                        Button { selectRoute(ranked) } label: {
                            rankedRouteCard(ranked)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, RediSpacing.screen)
                .padding(.bottom, RediSpacing.section)
            }
            .frame(maxHeight: .infinity)

            // Back button
            VStack(spacing: RediSpacing.compact) {
                Button {
                    rankedRoutes = []
                    selectedDestination = nil
                } label: {
                    Label("CHOOSE DIFFERENT DESTINATION", systemImage: "arrow.uturn.backward")
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

    private func rankedRouteCard(_ ranked: OfflineRoutingService.RankedRoute) -> some View {
        VStack(alignment: .leading, spacing: RediSpacing.compact) {
            // Header: rank badge + label
            HStack(spacing: RediSpacing.tight) {
                Text("ROUTE \(ranked.rank)")
                    .font(RediTypography.data)
                    .foregroundStyle(ranked.rank == 1 ? ColorTheme.accent : ColorTheme.textSecondary)

                Text("·")
                    .foregroundStyle(ColorTheme.textTertiary)

                Text(ranked.label)
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(routeLabelColor(ranked.label))

                Spacer()

                if ranked.rank == 1 {
                    Text("RECOMMENDED")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.ready)
                }
            }

            // Key metrics
            HStack(spacing: RediSpacing.section) {
                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text("DISTANCE")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text(formatDistance(ranked.route.distanceMetres))
                        .font(RediTypography.dataLarge)
                        .foregroundStyle(ColorTheme.text)
                }

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text("EST. TIME")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text(formatDuration(ranked.route.durationSeconds))
                        .font(RediTypography.dataLarge)
                        .foregroundStyle(ColorTheme.text)
                }

                Spacer()

                // Hazard indicator
                if ranked.hazardExposure > 0 {
                    VStack(alignment: .trailing, spacing: RediSpacing.micro) {
                        Text("HAZARD")
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)
                        HStack(spacing: RediSpacing.micro) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text(hazardLevel(ranked.hazardExposure))
                                .font(RediTypography.data)
                        }
                        .foregroundStyle(hazardColor(ranked.hazardExposure))
                    }
                }
            }

            // Corridor summary if available
            if let analysis = ranked.corridorAnalysis {
                Divider().background(ColorTheme.dividerSubtle)

                HStack(spacing: RediSpacing.section) {
                    HStack(spacing: RediSpacing.micro) {
                        Image(systemName: "drop")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ColorTheme.accent)
                        Text("\(analysis.waterSources.count) WATER")
                            .font(RediTypography.caption)
                            .foregroundStyle(analysis.hasWaterAccess ? ColorTheme.text : ColorTheme.warning)
                    }

                    HStack(spacing: RediSpacing.micro) {
                        Image(systemName: "house")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ColorTheme.accent)
                        Text("\(analysis.shelters.count) SHELTER")
                            .font(RediTypography.caption)
                            .foregroundStyle(analysis.hasShelterAccess ? ColorTheme.text : ColorTheme.warning)
                    }

                    HStack(spacing: RediSpacing.micro) {
                        Image(systemName: "building.2")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ColorTheme.accent)
                        Text("\(analysis.towns.count) TOWN")
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.text)
                    }
                }
            }
        }
        .padding(RediSpacing.content)
        .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
        )
    }

    private func routeLabelColor(_ label: String) -> Color {
        switch label {
        case "FASTEST": ColorTheme.accent
        case "SAFEST": ColorTheme.ready
        case "LEAST HAZARD": ColorTheme.ready
        default: ColorTheme.textSecondary
        }
    }

    private func hazardLevel(_ exposure: Double) -> String {
        switch exposure {
        case 0 ..< 2: "LOW"
        case 2 ..< 10: "MODERATE"
        case 10 ..< 50: "HIGH"
        default: "EXTREME"
        }
    }

    private func hazardColor(_ exposure: Double) -> Color {
        switch exposure {
        case 0 ..< 2: ColorTheme.ready
        case 2 ..< 10: ColorTheme.warning
        default: ColorTheme.danger
        }
    }

    // MARK: - Corridor Result

    private func corridorResultView(_ analysis: RouteCorridor.CorridorAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab bar
            corridorTabBar
                .padding(.horizontal, RediSpacing.screen)
                .padding(.vertical, RediSpacing.compact)

            Divider().background(ColorTheme.divider)

            ScrollView {
                switch selectedTab {
                case .summary:
                    summaryTab(analysis)
                case .water:
                    resourceListTab(analysis.waterSources, emptyMessage: "No water sources within corridor")
                case .shelters:
                    resourceListTab(analysis.shelters + analysis.towns, emptyMessage: "No shelters or towns within corridor")
                case .steps:
                    stepsTab(analysis.route)
                }
            }
            .frame(maxHeight: .infinity)

            // Bottom actions
            VStack(spacing: RediSpacing.compact) {
                Button {
                    corridorAnalysis = nil
                    selectedDestination = nil
                    routeError = nil
                    rankedRoutes = []
                    selectedRouteID = nil
                } label: {
                    Label("NEW PLAN", systemImage: "arrow.triangle.turn.up.right.diamond")
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

    private var corridorTabBar: some View {
        HStack(spacing: RediSpacing.compact) {
            ForEach(CorridorTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(
                            selectedTab == tab ? ColorTheme.accent : ColorTheme.textTertiary
                        )
                        .padding(.horizontal, RediSpacing.content)
                        .padding(.vertical, RediSpacing.compact)
                        .background(
                            selectedTab == tab
                                ? ColorTheme.accent.opacity(0.1)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Summary Tab

    private func summaryTab(_ analysis: RouteCorridor.CorridorAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Destination header
            if let dest = selectedDestination {
                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text("EVACUATING TO")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text(dest.name.uppercased())
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)
                }
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.content)
            }

            // Key metrics
            VStack(spacing: RediSpacing.compact) {
                HStack(spacing: RediSpacing.section) {
                    metricBlock(label: "DISTANCE", value: formatDistance(analysis.route.distanceMetres))
                    metricBlock(label: "EST. TIME", value: formatDuration(analysis.route.durationSeconds))
                    metricBlock(label: "MODE", value: analysis.route.profile.title.uppercased())
                }

                Divider().background(ColorTheme.dividerSubtle)

                HStack(spacing: RediSpacing.section) {
                    metricBlock(
                        label: "WATER SOURCES",
                        value: "\(analysis.waterSources.count)",
                        status: analysis.hasWaterAccess ? .ready : .warning
                    )
                    metricBlock(
                        label: "SHELTERS",
                        value: "\(analysis.shelters.count)",
                        status: analysis.hasShelterAccess ? .ready : .warning
                    )
                    metricBlock(
                        label: "TOWNS",
                        value: "\(analysis.towns.count)"
                    )
                }

                Divider().background(ColorTheme.dividerSubtle)

                // Water gap warning
                HStack(spacing: RediSpacing.tight) {
                    let gapKM = analysis.longestWaterGapMetres / 1000
                    Image(systemName: gapKM > 50 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(gapKM > 50 ? ColorTheme.warning : ColorTheme.ready)
                    Text("LONGEST WATER GAP")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Spacer()
                    Text(analysis.longestWaterGapText)
                        .font(RediTypography.data)
                        .foregroundStyle(gapKM > 50 ? ColorTheme.warning : ColorTheme.text)
                }

                // Corridor width
                HStack(spacing: RediSpacing.tight) {
                    Image(systemName: "scope")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTheme.accent)
                    Text("CORRIDOR WIDTH")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Spacer()
                    Text("\(Int(analysis.corridorWidthMetres)) M")
                        .font(RediTypography.data)
                        .foregroundStyle(ColorTheme.text)
                }
            }
            .padding(RediSpacing.content)
            .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .stroke(ColorTheme.divider, lineWidth: 0.5)
            )
            .padding(.horizontal, RediSpacing.screen)
            .padding(.top, RediSpacing.content)

            // Resource prediction (next water/shelter/town ahead)
            resourcePredictionPanel(analysis)

            // Terrain profile (if elevation data loaded)
            terrainProfilePanel(analysis)

            // Computed offline badge + mesh share
            HStack {
                HStack(spacing: RediSpacing.tight) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ColorTheme.ready)
                    Text("COMPUTED OFFLINE")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.ready)
                }

                Spacer()

                // Mesh share button (Pro only — sending requires Pro)
                if !appState.meshService.connectedPeers.isEmpty {
                    Button {
                        if ProFeatureGate.allowsMeshSend(isProUser: isProUser) {
                            shareRouteViaMesh(analysis)
                        } else {
                            isShowingProPaywall = true
                        }
                    } label: {
                        HStack(spacing: RediSpacing.micro) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 11, weight: .medium))
                            Text(isProUser ? "SHARE" : "SHARE (PRO)")
                                .font(RediTypography.label)
                                .tracking(1.2)
                        }
                        .foregroundStyle(isProUser ? ColorTheme.accent : ColorTheme.textTertiary)
                        .padding(.horizontal, RediSpacing.compact)
                        .padding(.vertical, RediSpacing.tight)
                        .background(
                            (isProUser ? ColorTheme.accent : ColorTheme.textTertiary).opacity(0.1),
                            in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, RediSpacing.screen)
            .padding(.top, RediSpacing.content)

            // Corridor resources timeline
            if !analysis.allResources.isEmpty {
                Text("CORRIDOR RESOURCES")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)
                    .padding(.horizontal, RediSpacing.screen)
                    .padding(.top, RediSpacing.section)
                    .padding(.bottom, RediSpacing.compact)

                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(analysis.allResources.enumerated()), id: \.offset) { _, resource in
                        corridorResourceRow(resource)
                        Divider()
                            .background(ColorTheme.dividerSubtle)
                            .padding(.leading, RediSpacing.screen)
                    }
                }
            }
        }
    }

    // MARK: - Resource List Tab

    private func resourceListTab(_ resources: [RouteCorridor.CorridorResource], emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if resources.isEmpty {
                VStack(spacing: RediSpacing.content) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text(emptyMessage.uppercased())
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(resources.enumerated()), id: \.offset) { _, resource in
                        corridorResourceRow(resource)
                        Divider()
                            .background(ColorTheme.dividerSubtle)
                            .padding(.leading, RediSpacing.screen)
                    }
                }
            }
        }
    }

    // MARK: - Steps Tab

    private func stepsTab(_ route: OfflineRoutingService.Route) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
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
                }
                .padding(.horizontal, RediSpacing.screen)
                .padding(.vertical, RediSpacing.content)

                if index < route.steps.count - 1 {
                    Divider()
                        .background(ColorTheme.dividerSubtle)
                        .padding(.leading, RediSpacing.screen)
                }
            }
        }
    }

    // MARK: - Shared Components

    private func corridorResourceRow(_ resource: RouteCorridor.CorridorResource) -> some View {
        HStack(alignment: .top, spacing: RediSpacing.content) {
            Image(systemName: categoryIcon(resource.category))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTheme.accent)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: RediSpacing.micro) {
                Text(resource.name.uppercased())
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                    .lineLimit(1)

                Text(resource.subtitle)
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: RediSpacing.micro) {
                Text(resource.distanceAlongText)
                    .font(RediTypography.data)
                    .foregroundStyle(ColorTheme.text)
                Text(resource.offsetText)
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textTertiary)
            }
        }
        .padding(.horizontal, RediSpacing.screen)
        .padding(.vertical, RediSpacing.content)
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

            Text(result.distanceText)
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.text)
        }
        .padding(.horizontal, RediSpacing.screen)
        .padding(.vertical, RediSpacing.content)
        .contentShape(Rectangle())
    }

    private func metricBlock(label: String, value: String, status: SemanticStatus? = nil) -> some View {
        VStack(alignment: .leading, spacing: RediSpacing.micro) {
            Text(label)
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
            Text(value)
                .font(RediTypography.dataLarge)
                .foregroundStyle(statusColor(status))
        }
    }

    private enum SemanticStatus {
        case ready, warning, danger
    }

    private func statusColor(_ status: SemanticStatus?) -> Color {
        switch status {
        case .ready: ColorTheme.ready
        case .warning: ColorTheme.warning
        case .danger: ColorTheme.danger
        case nil: ColorTheme.text
        }
    }

    // MARK: - States

    private var computingState: some View {
        VStack(spacing: RediSpacing.content) {
            Spacer()
            ProgressView()
                .tint(ColorTheme.accent)
            Text("COMPUTING EVACUATION PLAN")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
            Text("Routing + corridor analysis + resource scanning...")
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
            Text("EVACUATION PLAN FAILED")
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

    private var emptyDestinationsState: some View {
        VStack(spacing: RediSpacing.content) {
            Image(systemName: "building.2")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(ColorTheme.textTertiary)
            Text("NO EVACUATION DESTINATIONS")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
            Text("No shelters or towns found in offline data.")
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
        // Combine shelters and towns as evacuation destinations
        let shelters = nearestService.nearest(.shelter, to: location.coordinate, installedPackIDs: installedPackIDs, limit: 5)
        let towns = nearestService.nearest(.town, to: location.coordinate, installedPackIDs: installedPackIDs, limit: 5)
        destinations = (shelters + towns).sorted { $0.distanceMetres < $1.distanceMetres }
    }

    private func computeEvacuation(to destination: NearestResourceService.NearestResult) {
        guard let location = currentLocation else {
            routeError = "Location unavailable."
            return
        }

        selectedDestination = destination
        isComputing = true
        routeError = nil
        corridorAnalysis = nil
        rankedRoutes = []
        selectedRouteID = nil

        let installedPackIDs = appState.mapDataService.loadInstalledPackIDs()
        let installedPacks = appState.mapDataService.packs(withIDs: installedPackIDs)

        do {
            // Load routing graph
            try appState.offlineRoutingService.loadBestGraph(
                near: location.coordinate,
                installedPacks: installedPacks
            )

            if ProFeatureGate.allowsAdvancedRoutingIntelligence(isProUser: isProUser) {
                // Pro: full multi-route comparison with corridor analysis
                let corridor = RouteCorridor(
                    nearestService: nearestService,
                    installedPackIDs: installedPackIDs
                )

                rankedRoutes = try appState.offlineRoutingService.routeAlternatives(
                    from: location.coordinate,
                    to: destination.coordinate,
                    profile: selectedProfile,
                    corridor: corridor
                )

                // If only one route found, go straight to result
                if rankedRoutes.count == 1, let only = rankedRoutes.first {
                    corridorAnalysis = only.corridorAnalysis
                        ?? corridor.analyze(route: only.route, corridorWidthMetres: 200)
                    rankedRoutes = []
                }
            } else {
                // Free: basic single route, no corridor analysis or hazard ranking
                let route = try appState.offlineRoutingService.route(
                    from: location.coordinate,
                    to: destination.coordinate,
                    profile: selectedProfile
                )
                // Present a minimal corridor analysis with just the route basics
                let corridor = RouteCorridor(
                    nearestService: nearestService,
                    installedPackIDs: installedPackIDs
                )
                corridorAnalysis = corridor.analyze(route: route, corridorWidthMetres: 200)
            }

        } catch {
            routeError = error.localizedDescription
        }

        isComputing = false
    }

    private func selectRoute(_ ranked: OfflineRoutingService.RankedRoute) {
        selectedRouteID = ranked.id
        if let analysis = ranked.corridorAnalysis {
            corridorAnalysis = analysis
        } else {
            let installedPackIDs = appState.mapDataService.loadInstalledPackIDs()
            let corridor = RouteCorridor(
                nearestService: nearestService,
                installedPackIDs: installedPackIDs
            )
            corridorAnalysis = corridor.analyze(route: ranked.route, corridorWidthMetres: 200)
        }
        rankedRoutes = [] // Clear to show result view
    }

    // MARK: - Resource Prediction Panel

    private func resourcePredictionPanel(_ analysis: RouteCorridor.CorridorAnalysis) -> some View {
        let installedPackIDs = appState.mapDataService.loadInstalledPackIDs()
        let corridor = RouteCorridor(
            nearestService: nearestService,
            installedPackIDs: installedPackIDs
        )

        // Estimate current position (start of route if no live location)
        let positionAlong: CLLocationDistance
        if let loc = currentLocation {
            positionAlong = corridor.estimatePositionAlongRoute(
                currentLocation: loc.coordinate,
                route: analysis.route
            )
        } else {
            positionAlong = 0
        }

        let prediction = corridor.predictNextResources(
            analysis: analysis,
            currentPositionAlongRoute: positionAlong
        )

        return VStack(alignment: .leading, spacing: RediSpacing.compact) {
            Text("NEXT RESOURCES AHEAD")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)

            HStack(spacing: RediSpacing.section) {
                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    HStack(spacing: RediSpacing.micro) {
                        Image(systemName: "drop")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ColorTheme.accent)
                        Text("WATER")
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                    Text(prediction.nextWaterText)
                        .font(RediTypography.dataLarge)
                        .foregroundStyle(
                            prediction.nextWater != nil ? ColorTheme.text : ColorTheme.warning
                        )
                }

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    HStack(spacing: RediSpacing.micro) {
                        Image(systemName: "house")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ColorTheme.accent)
                        Text("SHELTER")
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                    Text(prediction.nextShelterText)
                        .font(RediTypography.dataLarge)
                        .foregroundStyle(
                            prediction.nextShelter != nil ? ColorTheme.text : ColorTheme.warning
                        )
                }

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    HStack(spacing: RediSpacing.micro) {
                        Image(systemName: "building.2")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ColorTheme.accent)
                        Text("TOWN")
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                    Text(prediction.nextTownText)
                        .font(RediTypography.dataLarge)
                        .foregroundStyle(
                            prediction.nextTown != nil ? ColorTheme.text : ColorTheme.textSecondary
                        )
                }
            }

            if let waterName = prediction.nextWater?.name {
                Text(waterName)
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(RediSpacing.content)
        .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
        )
        .padding(.horizontal, RediSpacing.screen)
        .padding(.top, RediSpacing.content)
    }

    // MARK: - Terrain Profile Panel

    private func terrainProfilePanel(_ analysis: RouteCorridor.CorridorAnalysis) -> some View {
        Group {
            if let profile = ElevationService().profile(for: analysis.route.coordinates) {
                VStack(alignment: .leading, spacing: RediSpacing.compact) {
                    Text("TERRAIN PROFILE")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)

                    HStack(spacing: RediSpacing.section) {
                        VStack(alignment: .leading, spacing: RediSpacing.micro) {
                            Text("ASCENT")
                                .font(RediTypography.label)
                                .tracking(1.2)
                                .foregroundStyle(ColorTheme.textTertiary)
                            Text(profile.ascentText)
                                .font(RediTypography.data)
                                .foregroundStyle(ColorTheme.text)
                        }

                        VStack(alignment: .leading, spacing: RediSpacing.micro) {
                            Text("DESCENT")
                                .font(RediTypography.label)
                                .tracking(1.2)
                                .foregroundStyle(ColorTheme.textTertiary)
                            Text(profile.descentText)
                                .font(RediTypography.data)
                                .foregroundStyle(ColorTheme.text)
                        }

                        VStack(alignment: .leading, spacing: RediSpacing.micro) {
                            Text("ELEVATION")
                                .font(RediTypography.label)
                                .tracking(1.2)
                                .foregroundStyle(ColorTheme.textTertiary)
                            Text("\(profile.minElevation)–\(profile.maxElevation) M")
                                .font(RediTypography.data)
                                .foregroundStyle(ColorTheme.text)
                        }
                    }

                    if profile.floodRiskSegments > 0 {
                        HStack(spacing: RediSpacing.tight) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(ColorTheme.warning)
                            Text("FLOOD RISK SEGMENTS: \(profile.floodRiskSegments)")
                                .font(RediTypography.caption)
                                .foregroundStyle(ColorTheme.warning)
                        }
                    }
                }
                .padding(RediSpacing.content)
                .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                        .stroke(ColorTheme.divider, lineWidth: 0.5)
                )
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.compact)
            }
        }
    }

    // MARK: - Evacuation Advisory

    private func computeAdvisory() -> HazardIntelligenceService.EvacuationAdvisory? {
        return appState.hazardIntelligenceService.evaluateRoutes(rankedRoutes, currentLocation: currentLocation?.coordinate)
    }

    private func advisoryPanel(_ advisory: HazardIntelligenceService.EvacuationAdvisory) -> some View {
        VStack(alignment: .leading, spacing: RediSpacing.compact) {
            HStack(spacing: RediSpacing.tight) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTheme.accent)
                Text("EVACUATION INTELLIGENCE")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.accent)
                Spacer()
                Text("CONFIDENCE: \(advisory.confidence.title)")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(advisoryConfidenceColor(advisory.confidence))
            }

            HStack(spacing: RediSpacing.tight) {
                Text("RECOMMENDED:")
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textTertiary)
                Text("ROUTE \(advisory.recommendedRouteIndex + 1)")
                    .font(RediTypography.dataLarge)
                    .foregroundStyle(ColorTheme.ready)
            }

            ForEach(advisory.reasons, id: \.self) { reason in
                HStack(alignment: .top, spacing: RediSpacing.tight) {
                    Text("•")
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
                    Text(reason)
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                }
            }

            Text(advisory.hazardSummary.uppercased())
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)

            // Route rejection reasons (transparency)
            if !advisory.rejections.isEmpty {
                Divider().background(ColorTheme.divider)

                Text("REJECTED ROUTES")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.danger)

                ForEach(advisory.rejections) { rejection in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rejection.routeLabel)
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.textSecondary)
                        ForEach(rejection.reasons, id: \.self) { reason in
                            HStack(alignment: .top, spacing: RediSpacing.tight) {
                                Text("✕")
                                    .font(RediTypography.caption)
                                    .foregroundStyle(ColorTheme.danger)
                                Text(reason)
                                    .font(RediTypography.caption)
                                    .foregroundStyle(ColorTheme.textTertiary)
                            }
                        }
                    }
                }
            }

            // Collapse detection
            if let collapse = computeCollapseAssessment(), collapse.level > .stable {
                Divider().background(ColorTheme.divider)

                HStack(spacing: RediSpacing.tight) {
                    Image(systemName: collapse.level == .collapsed ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(collapseColor(collapse.level))
                    Text("SITUATION: \(collapse.level.rawValue.uppercased())")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(collapseColor(collapse.level))
                }

                ForEach(collapse.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: RediSpacing.tight) {
                        Text("⚠")
                            .font(RediTypography.caption)
                            .foregroundStyle(collapseColor(collapse.level))
                        Text(warning)
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }
            }
        }
        .padding(RediSpacing.content)
        .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                .stroke(ColorTheme.accent.opacity(0.3), lineWidth: 0.5)
        )
    }

    private func advisoryConfidenceColor(_ confidence: HazardIntelligenceService.HazardConfidence) -> Color {
        switch confidence {
        case .verified: ColorTheme.ready
        case .high: ColorTheme.ready
        case .medium: ColorTheme.warning
        case .low: ColorTheme.textTertiary
        }
    }

    private func computeCollapseAssessment() -> HazardIntelligenceService.CollapseAssessment? {
        let destCoord: CLLocationCoordinate2D? = selectedDestination?.coordinate
        return appState.hazardIntelligenceService.assessCollapse(
            rankedRoutes: rankedRoutes,
            destination: destCoord
        )
    }

    private func collapseColor(_ level: HazardIntelligenceService.CollapseLevel) -> Color {
        switch level {
        case .stable: ColorTheme.ready
        case .degrading: ColorTheme.warning
        case .critical: ColorTheme.danger
        case .collapsed: ColorTheme.danger
        }
    }

    // MARK: - Mesh Sharing

    private func shareRouteViaMesh(_ analysis: RouteCorridor.CorridorAnalysis) {
        guard let dest = selectedDestination else { return }

        appState.meshService.shareEvacuationRoute(
            destination: dest.name,
            route: analysis.route,
            corridorAnalysis: analysis,
            hazardExposure: 0
        )
    }

    // MARK: - Formatting

    private func formatDistance(_ metres: CLLocationDistance) -> String {
        if metres >= 1000 {
            return String(format: "%.1f KM", metres / 1000)
        }
        return "\(Int(metres.rounded())) M"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)H \(minutes)M" }
        return "\(minutes) MIN"
    }

    private func categoryIcon(_ category: NearestResourceService.ResourceCategory) -> String {
        switch category {
        case .water: "drop"
        case .shelter: "house"
        case .road: "road.lanes"
        case .town: "building.2"
        }
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
}
