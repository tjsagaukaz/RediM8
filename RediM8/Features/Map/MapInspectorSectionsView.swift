import SwiftUI

struct MapInspectorSectionsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: MapViewModel
    let mapFailureRows: [(title: String, detail: String)]
    let openEvacuationRoutes: () -> Void
    @Binding var isShowingMapBrief: Bool
    @Binding var isShowingRouteInspector: Bool
    @Binding var selectedOfficialAlertScope: MapOfficialAlertScope
    @Binding var selectedOfficialAlertJurisdiction: AustralianJurisdiction?

    private let briefMetricColumns = [
        GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 12)
    ]

    var body: some View {
        Group {
            criticalNearbyPanel

            CollapsiblePanelCard(
                title: "Field Brief",
                subtitle: "Surface, coverage, and fallback detail for the current map mode.",
                accent: ColorTheme.textTertiary,
                isExpanded: $isShowingMapBrief
            ) {
                mapBriefContent
            }

            CollapsiblePanelCard(
                title: "Routes & Alerts",
                subtitle: "Saved routes, official warnings, and known map failures.",
                accent: officialAlertColor,
                isExpanded: $isShowingRouteInspector
            ) {
                routeInspectorContent
            }
        }
    }

    private var effectiveOfficialAlertJurisdiction: AustralianJurisdiction? {
        selectedOfficialAlertJurisdiction
            ?? viewModel.defaultOfficialAlertJurisdiction
            ?? viewModel.availableOfficialAlertJurisdictions.first
    }

    private var selectedOfficialAlertSummary: MapOfficialAlertSummary {
        viewModel.officialAlertSummary(
            for: selectedOfficialAlertScope,
            jurisdiction: effectiveOfficialAlertJurisdiction
        )
    }

    private var selectedOfficialAlerts: [OfficialAlert] {
        viewModel.officialAlerts(
            for: selectedOfficialAlertScope,
            jurisdiction: effectiveOfficialAlertJurisdiction
        )
    }

    private var officialAlertScopeOptions: [PremiumSegmentedControlOption<MapOfficialAlertScope>] {
        MapOfficialAlertScope.allCases.map { scope in
            PremiumSegmentedControlOption(
                segmentID: scope,
                title: scope.title,
                detail: scope.detail,
                iconName: scope.iconName,
                accent: officialAlertColor
            )
        }
    }

    private var officialAlertLayerSubtitle: String {
        switch selectedOfficialAlertScope {
        case .local:
            "Mirrored public warnings matched to this map area and installed coverage."
        case .state:
            "Check a state or territory feed for family, travel, or wider operational context."
        case .australia:
            "Scan the national warning picture across cached official feeds."
        }
    }

    private var officialAlertColor: Color {
        MapTonePalette.color(for: viewModel.officialAlertTone)
    }

    private var mapBriefContent: some View {
        VStack(spacing: 14) {
            MapInspectorGroup(
                title: "Confidence",
                subtitle: "Fast scan of what the map can rely on right now.",
                accent: ColorTheme.textTertiary
            ) {
                TrustPillGroup(items: viewModel.mapTrustItems)
                LazyVGrid(columns: briefMetricColumns, spacing: 12) {
                    MapBriefMetricCard(
                        title: "Confidence",
                        value: viewModel.mapConfidenceValue,
                        detail: viewModel.mapConfidenceOverlayDetail,
                        accent: MapTonePalette.color(for: viewModel.mapConfidenceTone)
                    )
                    MapBriefMetricCard(
                        title: "Basemap",
                        value: viewModel.mapStatusHeadline,
                        detail: viewModel.mapModeOverlayDetail,
                        accent: viewModel.surfaceTint
                    )
                    MapBriefMetricCard(
                        title: "Coverage",
                        value: viewModel.coverageLimitHeadline,
                        detail: viewModel.installedPacks.isEmpty ? "Offline layers limited" : "Offline pack boundary active",
                        accent: viewModel.installedPacks.isEmpty ? ColorTheme.warning : ColorTheme.info
                    )
                    MapBriefMetricCard(
                        title: "Position",
                        value: viewModel.currentLocation == nil ? "No live position" : "Live position",
                        detail: viewModel.currentLocation == nil ? "Waiting for GPS" : viewModel.headingText,
                        accent: viewModel.currentLocation == nil ? ColorTheme.warning : ColorTheme.ready
                    )
                    MapBriefMetricCard(
                        title: "Hazards",
                        value: viewModel.hazardFeedStatusValue,
                        detail: viewModel.hazardFeedHeadline,
                        accent: MapTonePalette.color(for: viewModel.hazardFeedTone)
                    )
                    MapBriefMetricCard(
                        title: "Rings",
                        value: viewModel.showsDistanceRings ? "1 km / 5 km / 10 km" : "Hidden",
                        detail: viewModel.showsDistanceRings ? "Distance guides active" : "Distance guides disabled",
                        accent: viewModel.showsDistanceRings ? ColorTheme.info : ColorTheme.textTertiary
                    )
                }
            }

            MapInspectorGroup(
                title: "Coverage Limits",
                subtitle: "What drops away outside your installed boundary.",
                accent: viewModel.installedPacks.isEmpty ? ColorTheme.warning : ColorTheme.info
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("OFFLINE PACK")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textFaint)

                    Text(viewModel.coverageLimitHeadline)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.coverageLimitBullets, id: \.self) { bullet in
                        MapBulletLine(text: bullet)
                    }
                }

                if let surfaceAvailabilityNote = viewModel.surfaceAvailabilityNote {
                    Text(surfaceAvailabilityNote)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textMuted)
                }

                MapInstalledCoveragePreview(viewModel: viewModel)

                Text("Offline layers last updated: \(viewModel.lastUpdatedText)")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.text)

                DataFreshnessIndicator(
                    freshness: viewModel.mapDataService.dataFreshness,
                    lastUpdated: viewModel.mapDataService.lastUpdated,
                    impactMessage: viewModel.mapDataService.freshnessImpactMessage
                )

                Text(TrustLayer.mapFreshnessNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(TrustLayer.mapCoverageNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let bushfireMapSummary = viewModel.bushfireMapSummary {
                MapInspectorGroup(
                    title: "Scenario Priority",
                    subtitle: "Mode-specific routing focus now in effect.",
                    accent: ColorTheme.textTertiary
                ) {
                    Text(bushfireMapSummary)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.text)
                }
            }

            if viewModel.isLayerEnabled(.fireTrails) || viewModel.isLayerEnabled(.evacuationPoints) || viewModel.isStealthModeEnabled {
                MapInspectorGroup(
                    title: "Operating Notes",
                    subtitle: "Extra cautions based on active layers and device mode.",
                    accent: ColorTheme.textTertiary
                ) {
                    if viewModel.isLayerEnabled(.fireTrails) {
                        Text(TrustLayer.fireTrailSafetyReminder)
                            .font(.caption)
                            .foregroundStyle(ColorTheme.warning)
                    }

                    if viewModel.isLayerEnabled(.evacuationPoints) {
                        Text(TrustLayer.shelterAvailabilityReminder)
                            .font(.caption)
                            .foregroundStyle(ColorTheme.warning)
                    }

                    if viewModel.isStealthModeEnabled {
                        Text("Stealth Mode reduces location accuracy and map motion to conserve battery while keeping offline maps readable.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var routeInspectorContent: some View {
        VStack(spacing: 14) {
            savedRoutesInspector
            officialAlertsInspector

            if !mapFailureRows.isEmpty {
                failureModesInspector
            }
        }
    }

    private var savedRoutesInspector: some View {
        MapInspectorGroup(
            title: "Saved Evacuation Routes",
            subtitle: "Offline route notes from your plan.",
            accent: routeInspectorAccent
        ) {
            if let warning = viewModel.routeCompromisedWarning {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.danger)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ROUTE COMPROMISED")
                            .font(RediTypography.label)
                            .tracking(1.0)
                            .foregroundStyle(ColorTheme.danger)
                        Text(warning)
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }
                .padding(RediSpacing.content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTheme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            }

            Text(viewModel.savedRouteSummary)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            TrustPillGroup(items: viewModel.savedRouteTrustItems)

            if viewModel.savedRoutes.isEmpty {
                Button {
                    openEvacuationRoutes()
                } label: {
                    Label("Create Evacuation Route", systemImage: "route")
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Text("No route has been saved on this device yet.")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.warning)
            } else {
                Button {
                    openEvacuationRoutes()
                } label: {
                    Label("Edit Routes", systemImage: "square.and.pencil")
                }
                .buttonStyle(SecondaryActionButtonStyle())

                ForEach(Array(viewModel.savedRoutes.prefix(3).enumerated()), id: \.offset) { index, route in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(index == 0 ? "Primary route" : "Backup route \(index)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ColorTheme.textFaint)
                        Text(route)
                            .font(RediTypography.bodyStrong)
                            .foregroundStyle(ColorTheme.text)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private var routeInspectorAccent: Color {
        if viewModel.routeCompromisedWarning != nil {
            return ColorTheme.danger
        }
        return viewModel.savedRoutes.isEmpty ? ColorTheme.warning : ColorTheme.ready
    }

    private var officialAlertsInspector: some View {
        MapInspectorGroup(
            title: "Official Alerts",
            subtitle: officialAlertLayerSubtitle,
            accent: MapTonePalette.color(for: selectedOfficialAlertSummary.tone)
        ) {
            Text("Switch between local, state, and Australia-wide warning views without leaving the map.")
                .font(.caption)
                .foregroundStyle(.secondary)

            MapOfficialAlertsContentView(
                viewModel: viewModel,
                selectedScope: $selectedOfficialAlertScope,
                selectedJurisdiction: $selectedOfficialAlertJurisdiction,
                scopeOptions: officialAlertScopeOptions,
                selectedSummary: selectedOfficialAlertSummary,
                selectedAlerts: selectedOfficialAlerts,
                effectiveJurisdiction: effectiveOfficialAlertJurisdiction
            )
        }
    }

    private var failureModesInspector: some View {
        MapInspectorGroup(
            title: "Failure Modes",
            subtitle: "What still works when a dependency drops out.",
            accent: ColorTheme.textTertiary
        ) {
            ForEach(Array(mapFailureRows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                    Text(row.detail)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textMuted)
                }
            }
        }
    }

    private var criticalNearbyPanel: some View {
        PanelCard(
            title: "Nearest Resources",
            subtitle: "Water first, then shelter and evacuation options",
            backgroundAssetName: "community_shelter_hub",
            backgroundImageOffset: CGSize(width: 0, height: 0)
        ) {
            VStack(spacing: 12) {
                if viewModel.featuredShelters.isEmpty, viewModel.featuredWaterPoints.isEmpty {
                    Text(viewModel.currentLocation == nil
                        ? "No nearby shelters or water points are available from the current offline coverage. Install a regional pack or use saved routes and landmarks as fallback references."
                        : "No nearby shelters or water points are available from installed offline coverage or live nearby data right now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let point = viewModel.featuredWaterPoints.first {
                    MapWaterPriorityCard(point: point, viewModel: viewModel)
                }

                if let shelter = viewModel.featuredShelters.first {
                    MapNearbySummaryCard(
                        title: shelter.name,
                        subtitle: "Evacuation point • \(viewModel.shelterDistanceText(for: shelter))",
                        detail: shelter.notes,
                        iconName: shelter.type.mapMarkerAssetName,
                        accent: viewModel.shelterTint(for: shelter.type),
                        trustItems: viewModel.shelterTrustItems(for: shelter),
                        actionTitle: "Navigate",
                        action: {
                            guard let url = viewModel.shelterNavigationURL(for: shelter) else {
                                return
                            }
                            openURL(url)
                        }
                    )
                }
            }
        }
    }
}
