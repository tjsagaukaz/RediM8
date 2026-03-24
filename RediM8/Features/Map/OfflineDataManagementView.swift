import SwiftUI

private enum OfflinePackWorkspace: String, Hashable {
    case recommended
    case regional
    case state

    var title: String {
        switch self {
        case .recommended:
            "Recommended"
        case .regional:
            "Regional"
        case .state:
            "State"
        }
    }

    var detail: String {
        switch self {
        case .recommended:
            "Default coverage"
        case .regional:
            "Compact local packs"
        case .state:
            "Large-area coverage"
        }
    }

    var iconName: String {
        switch self {
        case .recommended:
            "checkmark.shield.fill"
        case .regional:
            "map.fill"
        case .state:
            "globe.americas.fill"
        }
    }

    var accent: Color {
        switch self {
        case .recommended:
            ColorTheme.textTertiary
        case .regional:
            ColorTheme.textTertiary
        case .state:
            ColorTheme.textTertiary
        }
    }
}

struct OfflineDataManagementView: View {
    let appState: AppState

    @ObservedObject private var basemapService: OfflineBasemapService
    @State private var installedPackIDs: Set<String>
    @State private var selectedWorkspace: OfflinePackWorkspace = .recommended
    @State private var isShowingInstalledPacks = true
    @State private var isShowingAvailablePacks = true
    @State private var isShowingCuratedBasemaps = true
    @State private var isShowingInstalledBasemaps = true
    @State private var isShowingBasemapDownloader = false
    @State private var basemapManifestURL = ""
    @State private var basemapInputError: String?
    @State private var isShowingProPaywall = false

    private var isProUser: Bool { appState.isProUser }

    /// Non-bundled packs that the user actively installed.
    private var userInstalledPackCount: Int {
        allPacks.filter { installedPackIDs.contains($0.id) && !$0.isBundledByDefault }.count
    }

    private var canInstallMorePacks: Bool {
        ProFeatureGate.allowsAdditionalMapPacks(isProUser: isProUser, currentPackCount: userInstalledPackCount)
    }

    init(appState: AppState) {
        self.appState = appState
        _basemapService = ObservedObject(wrappedValue: appState.offlineBasemapService)
        _installedPackIDs = State(initialValue: appState.mapDataService.loadInstalledPackIDs())
    }

    private var allPacks: [OfflineMapPack] {
        appState.mapDataService.availablePacks
    }

    private var installedPacks: [OfflineMapPack] {
        allPacks.filter { installedPackIDs.contains($0.id) }
    }

    private var installedBasemapPackages: [OfflineBasemapService.InstalledPackage] {
        basemapService.installedPackages
    }

    private var catalogBasemapPackages: [OfflineBasemapCatalogPackage] {
        basemapService.catalogPackages
    }

    private var activeBasemapPackage: OfflineBasemapService.InstalledPackage? {
        installedBasemapPackages.first(where: { $0.isActive })
    }

    private var installableCatalogBasemapCount: Int {
        catalogBasemapPackages.filter(\.isInstallable).count
    }

    private var installedSizeMB: Int {
        installedPacks.reduce(0) { $0 + $1.sizeMB }
    }

    private var installedSizeSummary: String {
        installedSizeMB == 1 ? "1 MB stored locally" : "\(installedSizeMB) MB stored locally"
    }

    private var basemapStorageSummary: String {
        let totalBytes = installedBasemapPackages.reduce(Int64(0)) { $0 + $1.sizeBytes }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    private var totalCatalogSizeMB: Int {
        allPacks.reduce(0) { $0 + $1.sizeMB }
    }

    private var storageUsageRatio: Double {
        guard totalCatalogSizeMB > 0 else {
            return 0
        }

        return Double(installedSizeMB) / Double(totalCatalogSizeMB)
    }

    private var freshestPackLabel: String {
        let newestDate = allPacks.map(\.lastUpdated).max() ?? .distantPast
        return DateFormatter.rediM8MonthYear.string(from: newestDate)
    }

    private var workspacePacks: [OfflineMapPack] {
        switch selectedWorkspace {
        case .recommended:
            return allPacks.filter(\.isBundledByDefault)
        case .regional:
            return allPacks.filter { $0.kind == .regional }
        case .state:
            return allPacks.filter { $0.kind == .state }
        }
    }

    private var installedWorkspacePacks: [OfflineMapPack] {
        workspacePacks.filter { installedPackIDs.contains($0.id) }
    }

    private var availableWorkspacePacks: [OfflineMapPack] {
        workspacePacks.filter { !installedPackIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CinematicBanner("map_forest_route", height: 160)

                heroCard
                SystemStatusRail(items: statusItems, accent: selectedWorkspace.accent)
                basemapOverviewCard
                basemapInstallerFeedback

                if !catalogBasemapPackages.isEmpty {
                    CollapsiblePanelCard(
                        title: "Curated Basemap Catalog",
                        subtitle: "Choose a RediM8 basemap package from the trusted catalog first.",
                        accent: ColorTheme.textTertiary,
                        isExpanded: $isShowingCuratedBasemaps
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(catalogBasemapPackages) { package in
                                basemapCatalogCard(package)
                            }
                        }
                    }
                }

                if !installedBasemapPackages.isEmpty {
                    CollapsiblePanelCard(
                        title: "Installed Basemaps",
                        subtitle: "Switch between downloaded basemap packages or remove ones you no longer need.",
                        accent: activeBasemapPackage == nil ? ColorTheme.warning : ColorTheme.ready,
                        isExpanded: $isShowingInstalledBasemaps
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(installedBasemapPackages) { package in
                                basemapCard(package)
                            }
                        }
                    }
                }

#if DEBUG
                CollapsiblePanelCard(
                    title: "Advanced Install",
                    subtitle: "Internal testing only. Paste a trusted RediM8 HTTPS basemap manifest URL when validating hosted packages before release.",
                    accent: ColorTheme.accent,
                    isExpanded: $isShowingBasemapDownloader
                ) {
                    basemapDownloadCard
                }
#endif

                comparisonOverviewCard
                workspaceCard

                if !installedWorkspacePacks.isEmpty {
                    CollapsiblePanelCard(
                        title: "Ready on Device",
                        subtitle: "Coverage in this lane is already stored locally and available when coverage drops.",
                        accent: ColorTheme.textTertiary,
                        isExpanded: $isShowingInstalledPacks
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(installedWorkspacePacks) { pack in
                                packCard(pack)
                            }
                        }
                    }
                }

                CollapsiblePanelCard(
                    title: availableWorkspacePacks.isEmpty ? "No More Packs in This Lane" : "Available to Add",
                    subtitle: availableWorkspacePacks.isEmpty
                        ? "Everything in this comparison lane is already installed."
                        : "Compare footprint, freshness, and supported layers before you add more coverage.",
                    accent: selectedWorkspace.accent,
                    isExpanded: $isShowingAvailablePacks
                ) {
                    if availableWorkspacePacks.isEmpty {
                        Text("Switch to another lane to compare additional pack sizes and coverage footprints.")
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textMuted)
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(availableWorkspacePacks) { pack in
                                packCard(pack)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle("Offline Data")
        .navigationBarTitleDisplayMode(.inline)
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

    private var heroCard: some View {
        ModeHeroCard(
            eyebrow: "Offline Map Storage",
            title: "Offline Data",
            subtitle: "Manage both regional data packs and full offline basemap packages so RediM8 stays useful when live map tiles disappear.",
            iconName: "map_marker",
            accent: ColorTheme.textTertiary,
            backgroundAssetName: "map_remote_track"
        ) {
            LazyVGrid(columns: metricColumns, spacing: 12) {
                metricTile(
                    title: "Installed",
                    value: "\(installedPacks.count)",
                    detail: "Ready offline",
                    iconName: "internaldrive.fill"
                )
                metricTile(
                    title: "Storage",
                    value: "\(installedSizeMB) MB",
                    detail: "Current footprint",
                    iconName: "externaldrive.fill.badge.checkmark"
                )
                metricTile(
                    title: "Catalog",
                    value: "\(allPacks.count)",
                    detail: "\(installedBasemapPackages.count) basemaps saved",
                    iconName: "square.stack.3d.up.fill"
                )
                metricTile(
                    title: "Freshness",
                    value: freshestPackLabel,
                    detail: "Newest pack date",
                    iconName: "clock.fill"
                )
            }

            DataFreshnessIndicator(
                freshness: appState.mapDataService.dataFreshness,
                lastUpdated: appState.mapDataService.lastUpdated,
                impactMessage: appState.mapDataService.freshnessImpactMessage
            )

            Text(TrustLayer.mapFreshnessNotice)
                .font(.caption)
                .foregroundStyle(ColorTheme.textFaint)
        }
    }

    private var comparisonOverviewCard: some View {
        PanelCard(
            title: "Coverage Comparison",
            subtitle: "Use the lane selector to compare pack scale, included layers, and storage impact before installing."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: metricColumns, spacing: 12) {
                    comparisonMetric(
                        title: "Lane Ready",
                        value: "\(installedWorkspacePacks.count)",
                        detail: selectedWorkspace == .recommended ? "Default packs installed" : "\(selectedWorkspace.title) packs installed"
                    )
                    comparisonMetric(
                        title: "Lane Optional",
                        value: "\(availableWorkspacePacks.count)",
                        detail: availableWorkspacePacks.isEmpty ? "No pending installs" : "Still available to add"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Storage used")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ColorTheme.text)

                        Spacer()

                        Text(installedSizeSummary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ColorTheme.textFaint)
                    }

                    ReadinessMeter(value: storageUsageRatio, tint: ColorTheme.textTertiary, height: 10)

                    Text("Coverage stops at each pack boundary, so the preview below helps compare how much map area each install actually buys you.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textMuted)
                }
            }
        }
    }

    private var basemapOverviewCard: some View {
        PanelCard(
            title: "Offline Basemap",
            subtitle: "Basemap packages provide real local cartography for Tactical mode, separate from your shelter, water, and trail data packs."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: metricColumns, spacing: 12) {
                    comparisonMetric(
                        title: "Mode",
                        value: basemapService.configuration.isPremiumActive ? "Local" : "Fallback",
                        detail: activeBasemapPackage?.name ?? "Tactical fallback only"
                    )
                    comparisonMetric(
                        title: "Catalog",
                        value: "\(catalogBasemapPackages.count)",
                        detail: installableCatalogBasemapCount == 0 ? "Hosted packs pending" : "\(installableCatalogBasemapCount) ready to download"
                    )
                    comparisonMetric(
                        title: "Storage",
                        value: basemapStorageSummary,
                        detail: "Basemap footprint"
                    )
                    comparisonMetric(
                        title: "Installed",
                        value: "\(installedBasemapPackages.count)",
                        detail: activeBasemapPackage?.installedAt.formatted(date: .abbreviated, time: .omitted) ?? "Using fallback"
                    )
                }

                Text(basemapService.configuration.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)

                Text("Start with the curated catalog below. Install only trusted RediM8-hosted HTTPS basemap packages in production.")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)
            }
        }
    }

    @ViewBuilder
    private var basemapInstallerFeedback: some View {
        if let installErrorText = basemapService.installErrorText {
            feedbackLine(
                title: "Download failed",
                detail: installErrorText,
                tone: .danger
            )
        } else if let installStatusText = basemapService.installStatusText {
            feedbackLine(
                title: basemapService.isInstalling ? "Installing basemap" : "Basemap updated",
                detail: installStatusText,
                tone: basemapService.isInstalling ? .info : .ready
            )
        }
    }

    private var basemapDownloadCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Manifest URL")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ColorTheme.textFaint)

                TextField("https://example.com/redim8-basemap-manifest.json", text: $basemapManifestURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ColorTheme.dividerStrong, lineWidth: 1)
                    )
            }

            if let basemapInputError {
                feedbackLine(
                    title: "Manifest URL required",
                    detail: basemapInputError,
                    tone: .danger
                )
            }

            Button {
                startBasemapInstall()
            } label: {
                if basemapService.isInstalling {
                    Label("Installing...", systemImage: "arrow.down.circle.fill")
                } else {
                    Label("Download Basemap", systemImage: "arrow.down.circle.fill")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(basemapService.isInstalling)

            Text("Manifest packages must include a root-level style.json plus any local tile, glyph, sprite, or asset files referenced by that style.")
                .font(.caption)
                .foregroundStyle(ColorTheme.textMuted)
        }
    }

    private func basemapCatalogCard(_ package: OfflineBasemapCatalogPackage) -> some View {
        let installedPackage = installedBasemapPackages.first(where: { $0.id == package.id })
        let isInstalled = installedPackage != nil
        let isActive = installedPackage?.isActive == true
        let accent: Color = {
            if isActive {
                return ColorTheme.ready
            }
            if package.isInstallable {
                return ColorTheme.info
            }
            return ColorTheme.warning
        }()

        return PanelCard(
            title: package.name,
            subtitle: package.subtitle,
            backgroundAssetName: package.backgroundAssetName,
            surfaceImageOpacity: 0.34,
            surfaceImageBrightness: -0.08,
            surfaceAtmosphere: accent.opacity(0.12),
            surfaceEdgeColor: accent.opacity(0.18),
            surfaceShadowColor: accent.opacity(0.06)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text(isActive ? "Active" : package.availability.displayTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isActive ? ColorTheme.ready : accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((isActive ? ColorTheme.ready : accent).opacity(0.14), in: Capsule())

                    Spacer()

                    Text("\(package.sizeMB) MB")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTheme.text)
                }

                Text(package.summary)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)

                Text(package.coverageSummary)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                TrustPillGroup(items: basemapCatalogTrustItems(for: package, installedPackage: installedPackage))

                HStack(spacing: 12) {
                    if isInstalled {
                        if isActive {
                            Text("Active in Tactical mode.")
                                .font(.caption)
                                .foregroundStyle(ColorTheme.textFaint)
                        } else {
                            Button("Use Basemap") {
                                basemapService.activatePackage(package.id)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                        }
                    } else if package.isInstallable {
                        Button {
                            Task {
                                await basemapService.installCatalogPackage(package)
                            }
                        } label: {
                            if basemapService.isInstalling {
                                Label("Installing...", systemImage: "arrow.down.circle.fill")
                            } else {
                                Label("Download Package", systemImage: "arrow.down.circle.fill")
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(basemapService.isInstalling)
                    } else {
                        Text("Hosted package not live yet.")
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textFaint)
                    }
                }
            }
        }
    }

    private var workspaceCard: some View {
        PanelCard(title: "Pack Lanes", subtitle: "Recommended gives the default baseline. Regional and state let you compare broader footprints.") {
            PremiumSegmentedControl(items: workspaceOptions, selection: $selectedWorkspace)
        }
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var statusItems: [OperationalStatusItem] {
        [
            OperationalStatusItem(
                iconName: "internaldrive.fill",
                label: "Installed",
                value: "\(installedPacks.count) Packs",
                tone: installedPacks.isEmpty ? .caution : .ready
            ),
            OperationalStatusItem(
                iconName: selectedWorkspace.iconName,
                label: "Lane",
                value: selectedWorkspace.title,
                tone: .info
            ),
            OperationalStatusItem(
                iconName: "externaldrive.fill.badge.checkmark",
                label: "Storage",
                value: installedSizeSummary,
                tone: .neutral
            ),
            OperationalStatusItem(
                iconName: "map_marker",
                label: "Basemap",
                value: basemapService.configuration.isPremiumActive ? "Local" : "Fallback",
                tone: basemapService.configuration.isPremiumActive ? .ready : .caution
            ),
            OperationalStatusItem(
                iconName: "clock.fill",
                label: "Freshness",
                value: freshestPackLabel,
                tone: .info
            )
        ]
    }

    private var workspaceOptions: [PremiumSegmentedControlOption<OfflinePackWorkspace>] {
        [
            PremiumSegmentedControlOption(
                segmentID: .recommended,
                title: OfflinePackWorkspace.recommended.title,
                detail: OfflinePackWorkspace.recommended.detail,
                iconName: OfflinePackWorkspace.recommended.iconName,
                accent: OfflinePackWorkspace.recommended.accent
            ),
            PremiumSegmentedControlOption(
                segmentID: .regional,
                title: OfflinePackWorkspace.regional.title,
                detail: OfflinePackWorkspace.regional.detail,
                iconName: OfflinePackWorkspace.regional.iconName,
                accent: OfflinePackWorkspace.regional.accent
            ),
            PremiumSegmentedControlOption(
                segmentID: .state,
                title: OfflinePackWorkspace.state.title,
                detail: OfflinePackWorkspace.state.detail,
                iconName: OfflinePackWorkspace.state.iconName,
                accent: OfflinePackWorkspace.state.accent
            )
        ]
    }

    private func metricTile(
        title: String,
        value: String,
        detail: String,
        iconName: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ColorTheme.textTertiary.opacity(0.14))
                    .frame(width: 34, height: 34)

                RediIcon(iconName)
                    .foregroundStyle(ColorTheme.textTertiary)
                    .frame(width: 16, height: 16)
            }

            Text(title.uppercased())
                .font(RediTypography.metadata)
                .foregroundStyle(ColorTheme.textFaint)

            Text(value)
                .font(RediTypography.metricCompact)
                .foregroundStyle(ColorTheme.text)
                .lineLimit(1)

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(16)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 20,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: ColorTheme.textTertiary.opacity(0.1)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 20, edgeColor: ColorTheme.textTertiary.opacity(0.14), shadowColor: ColorTheme.textTertiary.opacity(0.05)))
    }

    private func comparisonMetric(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(RediTypography.metadata)
                .foregroundStyle(ColorTheme.textFaint)
            Text(value)
                .font(RediTypography.metricCompact)
                .foregroundStyle(ColorTheme.text)
            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .padding(16)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func packCard(_ pack: OfflineMapPack) -> some View {
        let isInstalled = installedPackIDs.contains(pack.id)
        let accent = isInstalled ? ColorTheme.ready : selectedWorkspace.accent

        return PanelCard(title: pack.name, subtitle: pack.subtitle) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text(isInstalled ? "Installed" : (pack.isBundledByDefault ? "Recommended" : pack.kind.title))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isInstalled ? ColorTheme.ready : accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((isInstalled ? ColorTheme.ready : accent).opacity(0.14), in: Capsule())

                    Spacer()

                    Text("\(pack.sizeMB) MB")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTheme.text)
                }

                MapPackCoveragePreview(pack: pack, isInstalled: isInstalled, accent: accent)

                Text(pack.coverageSummary)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)

                TrustPillGroup(items: packTrustItems(for: pack, isInstalled: isInstalled))

                Text("Layers: \(pack.supportedLayerSummary)")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)

                HStack(spacing: 12) {
                    if isInstalled, !pack.isBundledByDefault {
                        Button("Remove Pack") {
                            togglePack(pack.id)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    } else if !isInstalled {
                        if canInstallMorePacks {
                            Button("Install Pack") {
                                togglePack(pack.id)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                        } else {
                            Button(ProFeatureGate.paywallTitle(for: .mapPacks)) {
                                isShowingProPaywall = true
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                        }
                    } else {
                        Text("Bundled as part of your default offline baseline.")
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textFaint)
                    }
                }
            }
        }
    }

    private func basemapCard(_ package: OfflineBasemapService.InstalledPackage) -> some View {
        PanelCard(title: package.name, subtitle: package.summary) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text(package.isActive ? "Active" : "Downloaded")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(package.isActive ? ColorTheme.ready : ColorTheme.info)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((package.isActive ? ColorTheme.ready : ColorTheme.info).opacity(0.14), in: Capsule())

                    Spacer()

                    Text(package.sizeText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTheme.text)
                }

                TrustPillGroup(items: [
                    TrustPillItem(title: package.isActive ? "Driving Tactical mode" : "Stored locally", tone: package.isActive ? .verified : .info),
                    TrustPillItem(title: "Version \(package.version)", tone: .neutral),
                    TrustPillItem(title: package.installedAt.formatted(date: .abbreviated, time: .omitted), tone: .neutral)
                ])

                if let sourceManifestURL = package.sourceManifestURL {
                    Text(sourceManifestURL.absoluteString)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textMuted)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    if !package.isActive {
                        Button("Use Basemap") {
                            basemapService.activatePackage(package.id)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }

                    Button(package.isActive ? "Remove Basemap" : "Delete Package") {
                        basemapService.removePackage(package.id)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }

    private func feedbackLine(title: String, detail: String, tone: OperationalStatusTone) -> some View {
        let accent: Color
        switch tone {
        case .ready:
            accent = ColorTheme.ready
        case .info:
            accent = ColorTheme.info
        case .caution:
            accent = ColorTheme.warning
        case .danger:
            accent = ColorTheme.danger
        case .neutral:
            accent = ColorTheme.textFaint
        }

        return HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(accent)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }

    private func packTrustItems(for pack: OfflineMapPack, isInstalled: Bool) -> [TrustPillItem] {
        [
            TrustPillItem(title: pack.kind.title, tone: .info),
            TrustPillItem(title: isInstalled ? "Ready offline" : "Installable", tone: isInstalled ? .verified : .neutral),
            TrustPillItem(title: DateFormatter.rediM8MonthYear.string(from: pack.lastUpdated), tone: .neutral),
            TrustPillItem(title: "\(pack.supportedLayers.count) layers", tone: .neutral)
        ]
    }

    private func basemapCatalogTrustItems(
        for package: OfflineBasemapCatalogPackage,
        installedPackage: OfflineBasemapService.InstalledPackage?
    ) -> [TrustPillItem] {
        var items: [TrustPillItem] = [
            TrustPillItem(title: package.region, tone: .info),
            TrustPillItem(title: "Version \(package.version)", tone: .neutral),
            TrustPillItem(title: package.availability.displayTitle, tone: package.isInstallable ? .verified : .caution)
        ]

        if let installedPackage {
            items.append(TrustPillItem(title: installedPackage.isActive ? "Active on device" : "Stored locally", tone: installedPackage.isActive ? .verified : .neutral))
        }

        items.append(contentsOf: package.highlights.prefix(2).map { TrustPillItem(title: $0, tone: .neutral) })
        return items
    }

    private func togglePack(_ packID: String) {
        if installedPackIDs.contains(packID) {
            installedPackIDs = appState.mapDataService.removePack(packID, from: installedPackIDs)
        } else {
            installedPackIDs = appState.mapDataService.installPack(packID, into: installedPackIDs)
        }
    }

    private func startBasemapInstall() {
        basemapInputError = nil
        basemapService.clearInstallFeedback()

        let trimmedURL = basemapManifestURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            basemapInputError = "Paste a manifest URL first."
            return
        }

        guard let manifestURL = URL(string: trimmedURL),
              let scheme = manifestURL.scheme?.lowercased(),
              scheme == "https" else {
            basemapInputError = "Use a valid `https://` manifest URL."
            return
        }

        Task {
            await basemapService.installPackage(from: manifestURL)
        }
    }
}
