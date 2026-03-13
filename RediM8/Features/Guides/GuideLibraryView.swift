import SwiftUI

struct GuideLibraryView: View {
    let appState: AppState
    var highlightedCategory: GuideCategory?

    @State private var selectedGuide: Guide?
    @State private var searchText = ""
    @State private var selectedCategory: GuideCategory?

    private var isFocusedEmergencySheet: Bool {
        highlightedCategory != nil
    }

    private var effectiveCategory: GuideCategory? {
        highlightedCategory ?? selectedCategory
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayedGuides: [Guide] {
        if !trimmedSearchText.isEmpty {
            return appState.guideService.searchGuides(query: trimmedSearchText, category: effectiveCategory)
        }

        if let effectiveCategory {
            return appState.guideService.guides(in: effectiveCategory)
        }

        return appState.guideService.allGuides()
    }

    private var groupedGuides: [(GuideCategory, [Guide])] {
        let grouped = Dictionary(grouping: displayedGuides, by: \.category)
        return GuideCategory.allCases.compactMap { category in
            guard let guides = grouped[category], !guides.isEmpty else {
                return nil
            }
            return (category, guides.sorted { $0.title < $1.title })
        }
    }

    private var libraryTitle: String {
        if let highlightedCategory {
            return highlightedCategory.title
        }
        return "Library"
    }

    private var featuredCollections: [GuideCollection] {
        guard highlightedCategory == nil, trimmedSearchText.isEmpty else {
            return []
        }

        return GuideCollection.allCases
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                libraryStatusRail
                searchCard

                if !featuredCollections.isEmpty {
                    featuredCollectionsSection
                }

                if !isFocusedEmergencySheet {
                    categoryFilterSection
                }

                if displayedGuides.isEmpty {
                    emptyStateCard
                } else if effectiveCategory == nil && trimmedSearchText.isEmpty {
                    browseSections
                } else {
                    resultsSection
                }
            }
            .padding(.horizontal, RediSpacing.screen)
            .padding(.top, RediSpacing.screen)
            .padding(.bottom, RediLayout.commandDockContentInset)
        }
        .background(Color.clear)
        .navigationTitle(libraryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedGuide) { guide in
            NavigationStack {
                GuideDetailView(guide: guide)
            }
            .rediSheetPresentation(style: .library, accent: accent(for: guide.category))
        }
    }

    private var headerCard: some View {
        ModeHeroCard(
            eyebrow: isFocusedEmergencySheet ? "Emergency Guide Sheet" : "Offline Library",
            title: isFocusedEmergencySheet ? "\(libraryTitle) Reference" : "Field Library",
            subtitle: isFocusedEmergencySheet
                ? "Fast offline guidance for the category you opened from emergency mode."
                : "Search, browse, and keep illustrated field guides ready offline. Safety content stays source-labeled instead of pretending every answer is authoritative.",
            iconName: highlightedCategory?.systemImage ?? "documents",
            accent: highlightedCategory.map(accent(for:)) ?? ColorTheme.archive,
            backgroundAssetName: "marketing_coast_storm",
            backgroundImageOffset: CGSize(width: 12, height: 0)
        ) {
            LazyVGrid(columns: libraryMetricColumns, spacing: 12) {
                libraryMetric(
                    title: "Guides",
                    value: "\(totalGuideCount)",
                    detail: "Bundled offline",
                    iconName: "documents",
                    tint: ColorTheme.archive
                )
                libraryMetric(
                    title: "Illustrated",
                    value: "\(illustratedGuideCount)",
                    detail: "Diagram-led references",
                    iconName: "photo.on.rectangle.angled",
                    tint: ColorTheme.info
                )
                libraryMetric(
                    title: "Official",
                    value: "\(officialGuideCount)",
                    detail: "Source-backed guides",
                    iconName: "checkmark.shield.fill",
                    tint: ColorTheme.ready
                )
                libraryMetric(
                    title: "Coverage",
                    value: "\(GuideCategory.allCases.count)",
                    detail: "Core categories",
                    iconName: "square.grid.2x2.fill",
                    tint: ColorTheme.accent
                )
            }

            Text(TrustLayer.librarySourceTransparencyNotice)
                .font(.caption)
                .foregroundStyle(ColorTheme.textFaint)
        }
    }

    private var libraryStatusRail: some View {
        SystemStatusRail(items: libraryStatusItems, accent: ColorTheme.archive)
    }

    private var searchCard: some View {
        PanelCard(
            title: "Search Library",
            subtitle: trimmedSearchText.isEmpty
                ? "Find bleeding control, knots, water purification, damper, raised beds, and more."
                : "\(displayedGuides.count) offline matches update instantly on device."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(trimmedSearchText.isEmpty ? ColorTheme.textFaint : ColorTheme.archive)

                    TextField("Search offline guides", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundStyle(ColorTheme.text)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(ColorTheme.textFaint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    PremiumSurfaceBackground(
                        cornerRadius: RediRadius.field,
                        backgroundAssetName: nil,
                        backgroundImageOffset: .zero,
                        atmosphere: (effectiveCategory.map(accent(for:)) ?? ColorTheme.archive).opacity(trimmedSearchText.isEmpty ? 0.08 : 0.16)
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: RediRadius.field, style: .continuous))
                .modifier(
                    PremiumSurfaceChrome(
                        cornerRadius: RediRadius.field,
                        edgeColor: (effectiveCategory.map(accent(for:)) ?? ColorTheme.archive).opacity(trimmedSearchText.isEmpty ? 0.12 : 0.18),
                        shadowColor: ColorTheme.archive.opacity(0.04)
                    )
                )

                TrustPillGroup(items: searchContextItems)
            }
        }
    }

    private var featuredCollectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Collections")
                    .font(RediTypography.sectionTitle)
                    .foregroundStyle(ColorTheme.text)
                Text("Curated bundles for high-stress reference, field skills, and offline learning.")
                    .font(RediTypography.bodyCompact)
                    .foregroundStyle(ColorTheme.textMuted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(featuredCollections) { collection in
                        collectionCard(collection)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var categoryFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Categories")
                        .font(RediTypography.sectionTitle)
                        .foregroundStyle(ColorTheme.text)
                    Text("Narrow the library by operational topic without losing offline access.")
                        .font(RediTypography.bodyCompact)
                        .foregroundStyle(ColorTheme.textMuted)
                }

                Spacer()

                if selectedCategory != nil {
                    Button("Show All") {
                        selectedCategory = nil
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTheme.info)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(GuideCategory.allCases) { category in
                        Button {
                            selectedCategory = selectedCategory == category ? nil : category
                        } label: {
                            HStack(spacing: 8) {
                                RediIcon(category.systemImage)
                                    .font(.caption.weight(.bold))
                                Text(category.title)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(selectedCategory == category ? ColorTheme.background : ColorTheme.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                selectedCategory == category ? accent(for: category) : ColorTheme.panelRaised,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(accent(for: category).opacity(selectedCategory == category ? 0.0 : 0.26), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var browseSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(groupedGuides, id: \.0.rawValue) { category, guides in
                PanelCard(title: category.title, subtitle: categorySummary(for: category)) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(guides) { guide in
                            guideRow(guide)
                        }
                    }
                }
            }
        }
    }

    private var resultsSection: some View {
        PanelCard(
            title: trimmedSearchText.isEmpty ? (effectiveCategory?.title ?? "Results") : "Search Results",
            subtitle: trimmedSearchText.isEmpty
                ? "Offline guides ready to open."
                : "\(displayedGuides.count) matches for \"\(trimmedSearchText)\"."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(displayedGuides) { guide in
                    guideRow(guide)
                }
            }
        }
    }

    private var emptyStateCard: some View {
        PanelCard(title: "No Matches", subtitle: "Try a shorter search or switch back to all categories.") {
            VStack(alignment: .leading, spacing: 10) {
                Text("RediM8 keeps the full library offline, but the current query did not match any bundled guide.")
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textMuted)

                TrustPillGroup(items: [
                    TrustPillItem(title: "Offline indexed", tone: .verified),
                    TrustPillItem(title: "Search terms matter", tone: .neutral),
                    TrustPillItem(title: effectiveCategory?.title ?? "All categories", tone: .info)
                ])
            }
        }
    }

    private var totalGuideCount: Int {
        appState.guideService.allGuides().count
    }

    private var illustratedGuideCount: Int {
        appState.guideService.illustratedGuides().count
    }

    private var officialGuideCount: Int {
        appState.guideService.allGuides().filter { guide in
            guide.sources.contains(where: { $0.kind == .official })
        }.count
    }

    private var libraryMetricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var libraryStatusItems: [OperationalStatusItem] {
        [
            OperationalStatusItem(
                iconName: "books.vertical.fill",
                label: "Library",
                value: "Offline Ready",
                tone: .ready
            ),
            OperationalStatusItem(
                iconName: "magnifyingglass",
                label: "Search",
                value: trimmedSearchText.isEmpty ? "Indexed Offline" : "\(displayedGuides.count) Results",
                tone: trimmedSearchText.isEmpty ? .info : .ready
            ),
            OperationalStatusItem(
                iconName: effectiveCategory?.systemImage ?? "square.grid.2x2.fill",
                label: "Focus",
                value: effectiveCategory?.title ?? "All Topics",
                tone: effectiveCategory == nil ? .neutral : .info
            ),
            OperationalStatusItem(
                iconName: "checkmark.shield.fill",
                label: "Sources",
                value: "\(officialGuideCount) Official-Labeled",
                tone: .info
            )
        ]
    }

    private var searchContextItems: [TrustPillItem] {
        var items = [TrustPillItem(title: "Offline indexed", tone: .verified)]

        if trimmedSearchText.isEmpty {
            items.append(TrustPillItem(title: "Browse all", tone: .neutral))
        } else {
            items.append(TrustPillItem(title: "\(displayedGuides.count) matches", tone: .info))
        }

        if let effectiveCategory {
            items.append(TrustPillItem(title: effectiveCategory.title, tone: .info))
        }

        if highlightedCategory != nil {
            items.append(TrustPillItem(title: "Emergency sheet", tone: .caution))
        }

        return items
    }

    private func collectionCard(_ collection: GuideCollection) -> some View {
        let guides = appState.guideService.featuredCollection(collection)
        let previewGuides = Array(guides.prefix(2))
        let tint = collectionAccent(for: collection)

        return Button {
            activateCollection(collection)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    Text(collection.title.uppercased())
                        .font(RediTypography.metadata)
                        .foregroundStyle(tint)

                    Spacer(minLength: 0)

                    Text("\(guides.count) guides")
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textFaint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ColorTheme.panel.opacity(0.8), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(collection.title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text(collection.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textMuted)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(previewGuides) { guide in
                        HStack(alignment: .center, spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(tint.opacity(0.14))
                                    .frame(width: 28, height: 28)

                                RediIcon(guide.heroIconName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(tint)
                                    .frame(width: 14, height: 14)
                            }

                            Text(guide.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ColorTheme.text)
                                .lineLimit(2)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text(collection == .emergency ? "High-stress first" : "Curated offline bundle")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textFaint)

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                }
            }
            .frame(width: 244, alignment: .leading)
            .padding(18)
            .background(
                PremiumSurfaceBackground(
                    cornerRadius: 24,
                    backgroundAssetName: nil,
                    backgroundImageOffset: .zero,
                    atmosphere: tint.opacity(0.12)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .modifier(PremiumSurfaceChrome(cornerRadius: 24, edgeColor: tint.opacity(0.16), shadowColor: tint.opacity(0.06)))
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func guideRow(_ guide: Guide) -> some View {
        let tint = accent(for: guide.category)

        return Button {
            selectedGuide = guide
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tint.opacity(0.16))
                            .frame(width: 48, height: 48)

                        RediIcon(guide.heroIconName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(tint)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(guide.category.title.uppercased())
                            .font(RediTypography.metadata)
                            .foregroundStyle(tint)

                        Text(guide.title)
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)

                        Text(guide.summary)
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textMuted)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)
                }

                TrustPillGroup(items: trustItems(for: guide))

                HStack(spacing: 12) {
                    Text("Reviewed \(guide.lastReviewed)")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textFaint)

                    if !guide.sources.isEmpty {
                        Text("\(guide.sources.count) sources")
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textFaint)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ColorTheme.textFaint)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PremiumSurfaceBackground(
                    cornerRadius: 18,
                    backgroundAssetName: nil,
                    backgroundImageOffset: .zero,
                    atmosphere: tint.opacity(0.08)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .modifier(PremiumSurfaceChrome(cornerRadius: 18, edgeColor: tint.opacity(0.12), shadowColor: tint.opacity(0.04)))
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func activateCollection(_ collection: GuideCollection) {
        switch collection {
        case .emergency:
            selectedCategory = .firstAid
        case .illustrated:
            searchText = "diagram"
        case .bushcraft:
            selectedCategory = .bushcraft
        case .food:
            selectedCategory = .foodCooking
        case .growing:
            selectedCategory = .foodGrowing
        }
    }

    private func trustItems(for guide: Guide) -> [TrustPillItem] {
        var items = [
            TrustPillItem(title: guide.category.title, tone: .info),
            TrustPillItem(title: guide.readingTimeText, tone: .neutral),
            TrustPillItem(title: guide.difficulty.title, tone: .neutral),
            TrustPillItem(title: guide.regionScope.title, tone: .neutral)
        ]

        if guide.isIllustrated {
            items.append(TrustPillItem(title: "Illustrated", tone: .verified))
        }

        if guide.sources.contains(where: { $0.kind == .official }) {
            items.append(TrustPillItem(title: "Official sources", tone: .verified))
        } else if !guide.sources.isEmpty {
            items.append(TrustPillItem(title: "Source-labeled", tone: .info))
        }

        return items
    }

    private func categorySummary(for category: GuideCategory) -> String {
        switch category {
        case .firstAid:
            "Immediate response steps for bleeding, burns, bites, fractures, and collapse."
        case .disasterResponse:
            "Leave-now, warning monitoring, utility safety, and shelter decisions."
        case .bushcraft:
            "Shelter setup, knots, signalling, food hygiene, and campcraft."
        case .navigation:
            "Map, compass, rally points, and moving safely when GPS is unreliable."
        case .waterSafety:
            "Water collection, storage, purification, and floodwater avoidance."
        case .fireSafety:
            "Bushfire, campfire, ember, and home fire safety."
        case .medical:
            "General medical guidance that supports emergency decision-making."
        case .heatSafety:
            "Heat exhaustion, heatstroke, hydration, and cooling strategies."
        case .stormSafety:
            "Storm-room setup, cleanup, outages, and electrical risk."
        case .floodSafety:
            "Flood evacuation timing, re-entry, cleanup, and sandbag basics."
        case .foodCooking:
            "Pantry bread, damper, scones, blackout cooking, and field meal basics."
        case .foodGrowing:
            "Fast crops, raised beds, bag growing, seed starts, and water-smart gardens."
        }
    }

    private func libraryMetric(
        title: String,
        value: String,
        detail: String,
        iconName: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 34, height: 34)

                    RediIcon(iconName)
                        .foregroundStyle(tint)
                        .frame(width: 16, height: 16)
                }

                Spacer(minLength: 0)
            }

            Text(title.uppercased())
                .font(RediTypography.metadata)
                .foregroundStyle(ColorTheme.textFaint)
            Text(value)
                .font(RediTypography.metricCompact)
                .foregroundStyle(ColorTheme.text)
                .contentTransition(.numericText())
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
                atmosphere: tint.opacity(0.1)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 20, edgeColor: tint.opacity(0.14), shadowColor: tint.opacity(0.05)))
    }

    private func accent(for category: GuideCategory) -> Color {
        switch category {
        case .firstAid, .medical:
            ColorTheme.danger
        case .disasterResponse, .fireSafety, .stormSafety, .floodSafety:
            ColorTheme.warning
        case .bushcraft, .foodCooking, .foodGrowing:
            ColorTheme.accent
        case .navigation, .waterSafety:
            ColorTheme.info
        case .heatSafety:
            ColorTheme.warning
        }
    }

    private func collectionAccent(for collection: GuideCollection) -> Color {
        switch collection {
        case .emergency:
            ColorTheme.danger
        case .illustrated:
            ColorTheme.info
        case .bushcraft:
            ColorTheme.accent
        case .food:
            ColorTheme.warning
        case .growing:
            ColorTheme.ready
        }
    }
}

struct GuideDetailView: View {
    let guide: Guide

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ModeHeroCard(
                    eyebrow: guide.category.title,
                    title: guide.title,
                    subtitle: guide.summary,
                    iconName: guide.heroIconName,
                    accent: accent
                ) {
                    TrustPillGroup(items: trustItems)
                }

                if !guide.notes.isEmpty {
                    PanelCard(title: "Important", subtitle: "Keep this limitation or caution in mind while using the guide.") {
                        Text(guide.notes)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ColorTheme.warning)
                    }
                }

                if guide.isIllustrated {
                    PanelCard(title: "Diagrams", subtitle: "Original offline diagrams to make field steps easier to scan.") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(guide.diagrams) { diagram in
                                    GuideDiagramPanel(diagram: diagram, accent: accent)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }

                PanelCard(title: "Guide Steps", subtitle: "Structured to stay readable when you are tired, rushed, or offline.") {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(guide.contentSections) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(section.title)
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)

                                if let summary = section.summary, !summary.isEmpty {
                                    Text(summary)
                                        .font(.subheadline)
                                        .foregroundStyle(ColorTheme.textMuted)
                                }

                                ForEach(Array(section.steps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(index + 1).")
                                            .font(.headline)
                                            .foregroundStyle(accent)
                                        Text(step)
                                            .font(.body)
                                            .foregroundStyle(ColorTheme.text)
                                    }
                                }
                            }
                        }
                    }
                }

                if !guide.sources.isEmpty {
                    PanelCard(title: "Sources", subtitle: "Traceability matters. RediM8 shows where this guide was reviewed against.") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(guide.sources) { source in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(source.kind.title)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(accent)
                                        Text(source.publisher)
                                            .font(.caption)
                                            .foregroundStyle(ColorTheme.textFaint)
                                    }

                                    Text(source.title)
                                        .font(.headline)
                                        .foregroundStyle(ColorTheme.text)

                                    Text(source.url)
                                        .font(.caption)
                                        .foregroundStyle(ColorTheme.info)
                                        .textSelection(.enabled)

                                    if let license = source.license, !license.isEmpty {
                                        Text(license)
                                            .font(.caption)
                                            .foregroundStyle(ColorTheme.textFaint)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }

                            Text(TrustLayer.guideEndorsementNotice)
                                .font(.caption)
                                .foregroundStyle(ColorTheme.textFaint)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle("Guide")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var accent: Color {
        switch guide.category {
        case .firstAid, .medical:
            ColorTheme.danger
        case .disasterResponse, .fireSafety, .heatSafety, .stormSafety, .floodSafety:
            ColorTheme.warning
        case .bushcraft, .foodCooking, .foodGrowing:
            ColorTheme.accent
        case .navigation, .waterSafety:
            ColorTheme.info
        }
    }

    private var trustItems: [TrustPillItem] {
        var items = [
            TrustPillItem(title: guide.confidenceTitle, tone: .info),
            TrustPillItem(title: guide.readingTimeText, tone: .neutral),
            TrustPillItem(title: guide.difficulty.title, tone: .neutral),
            TrustPillItem(title: guide.regionScope.title, tone: .neutral),
            TrustPillItem(title: "Reviewed \(guide.lastReviewed)", tone: .neutral)
        ]

        if guide.isIllustrated {
            items.append(TrustPillItem(title: "Illustrated", tone: .verified))
        }

        if guide.sources.contains(where: { $0.kind == .official }) {
            items.append(TrustPillItem(title: "Official sources", tone: .verified))
        }

        return items
    }
}

private struct GuideDiagramPanel: View {
    let diagram: GuideDiagram
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GuideDiagramArtwork(diagram: diagram, accent: accent)
                .frame(width: 248, height: 160)
                .background(
                    LinearGradient(
                        colors: [ColorTheme.panelRaised, accent.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(accent.opacity(0.24), lineWidth: 1)
                )

            Text(diagram.title)
                .font(.headline)
                .foregroundStyle(ColorTheme.text)

            Text(diagram.caption)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textMuted)
        }
        .frame(width: 248, alignment: .leading)
    }
}

private struct GuideDiagramArtwork: View {
    let diagram: GuideDiagram
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch diagram.kind {
                case .pressureBandage:
                    pressureBandageArt(in: proxy.size)
                case .recoveryPosition:
                    recoveryPositionArt(in: proxy.size)
                case .bowline:
                    bowlineArt(in: proxy.size)
                case .cloveHitch:
                    cloveHitchArt(in: proxy.size)
                case .reefKnot:
                    reefKnotArt(in: proxy.size)
                case .tarpRidgeline:
                    tarpRidgelineArt(in: proxy.size)
                case .compassBearing:
                    compassBearingArt(in: proxy.size)
                case .damperMethod:
                    damperMethodArt(in: proxy.size)
                case .skilletBread:
                    skilletBreadArt(in: proxy.size)
                case .sconeMethod:
                    sconeMethodArt(in: proxy.size)
                case .raisedBedLayout:
                    raisedBedArt(in: proxy.size)
                case .seedTray:
                    seedTrayArt(in: proxy.size)
                case .potatoBag:
                    potatoBagArt(in: proxy.size)
                case .waterFilter:
                    waterFilterArt(in: proxy.size)
                }
            }
            .padding(18)
        }
    }

    private func pressureBandageArt(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(width: size.width * 0.72, height: 52)

            Circle()
                .fill(ColorTheme.danger)
                .frame(width: 18, height: 18)
                .offset(x: -size.width * 0.10)

            ForEach(0..<6, id: \.self) { index in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(accent.opacity(0.86))
                    .frame(width: size.width * 0.12, height: 56)
                    .rotationEffect(.degrees(26))
                    .offset(x: CGFloat(index - 2) * 26)
            }

            Text("Firm bandage")
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .offset(y: 44)
        }
    }

    private func recoveryPositionArt(in size: CGSize) -> some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.06))
                .frame(width: size.width * 0.50, height: 32)
                .rotationEffect(.degrees(18))
                .offset(x: -12, y: -8)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 30, height: 30)
                .offset(x: size.width * 0.18, y: -30)

            Path { path in
                path.move(to: CGPoint(x: size.width * 0.38, y: size.height * 0.58))
                path.addLine(to: CGPoint(x: size.width * 0.54, y: size.height * 0.46))
                path.addLine(to: CGPoint(x: size.width * 0.65, y: size.height * 0.62))
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))

            Text("Side position")
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .offset(y: 44)
        }
    }

    private func bowlineArt(in size: CGSize) -> some View {
        ZStack {
            Circle()
                .stroke(ColorTheme.info, lineWidth: 10)
                .frame(width: size.width * 0.34, height: size.width * 0.34)
                .offset(x: -34, y: -4)

            Path { path in
                path.move(to: CGPoint(x: size.width * 0.56, y: size.height * 0.26))
                path.addCurve(
                    to: CGPoint(x: size.width * 0.52, y: size.height * 0.74),
                    control1: CGPoint(x: size.width * 0.62, y: size.height * 0.40),
                    control2: CGPoint(x: size.width * 0.60, y: size.height * 0.62)
                )
                path.addCurve(
                    to: CGPoint(x: size.width * 0.34, y: size.height * 0.54),
                    control1: CGPoint(x: size.width * 0.46, y: size.height * 0.70),
                    control2: CGPoint(x: size.width * 0.38, y: size.height * 0.64)
                )
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))

            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.title2)
                .foregroundStyle(ColorTheme.warning)
                .offset(x: 52, y: -34)
        }
    }

    private func cloveHitchArt(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: 28, height: size.height * 0.68)

            ForEach([-18.0, 18.0], id: \.self) { offset in
                Circle()
                    .stroke(accent, lineWidth: 10)
                    .frame(width: 68, height: 68)
                    .offset(x: offset)
            }

            Image(systemName: "arrow.left.and.right.circle.fill")
                .font(.title2)
                .foregroundStyle(ColorTheme.warning)
                .offset(y: 44)
        }
    }

    private func reefKnotArt(in size: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.18, y: size.height * 0.38))
                path.addCurve(
                    to: CGPoint(x: size.width * 0.50, y: size.height * 0.52),
                    control1: CGPoint(x: size.width * 0.32, y: size.height * 0.34),
                    control2: CGPoint(x: size.width * 0.38, y: size.height * 0.60)
                )
                path.addCurve(
                    to: CGPoint(x: size.width * 0.82, y: size.height * 0.36),
                    control1: CGPoint(x: size.width * 0.62, y: size.height * 0.44),
                    control2: CGPoint(x: size.width * 0.68, y: size.height * 0.30)
                )
            }
            .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))

            Path { path in
                path.move(to: CGPoint(x: size.width * 0.18, y: size.height * 0.62))
                path.addCurve(
                    to: CGPoint(x: size.width * 0.50, y: size.height * 0.46),
                    control1: CGPoint(x: size.width * 0.30, y: size.height * 0.70),
                    control2: CGPoint(x: size.width * 0.40, y: size.height * 0.36)
                )
                path.addCurve(
                    to: CGPoint(x: size.width * 0.82, y: size.height * 0.64),
                    control1: CGPoint(x: size.width * 0.60, y: size.height * 0.58),
                    control2: CGPoint(x: size.width * 0.72, y: size.height * 0.72)
                )
            }
            .stroke(ColorTheme.info, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
        }
    }

    private func tarpRidgelineArt(in size: CGSize) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: size.width * 0.68, height: 4)
                .offset(y: -24)

            Triangle()
                .fill(accent.opacity(0.84))
                .frame(width: size.width * 0.66, height: size.height * 0.38)
                .offset(y: -2)

            ForEach([-68.0, 68.0], id: \.self) { offset in
                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.50 + offset, y: size.height * 0.46))
                    path.addLine(to: CGPoint(x: size.width * 0.50 + offset, y: size.height * 0.76))
                }
                .stroke(ColorTheme.info, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
        }
    }

    private func compassBearingArt(in size: CGSize) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 5)
                .frame(width: size.height * 0.64, height: size.height * 0.64)

            Image(systemName: "location.north.line.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(accent)
                .rotationEffect(.degrees(-32))

            Text("Bearing")
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .offset(y: 48)
        }
    }

    private func damperMethodArt(in size: CGSize) -> some View {
        ingredientRatioArt(
            title: "Flour",
            middle: "Water",
            end: "Pinch salt",
            leftColor: accent,
            middleColor: ColorTheme.info,
            endColor: ColorTheme.warning
        )
    }

    private func skilletBreadArt(in size: CGSize) -> some View {
        ZStack {
            ingredientRatioArt(
                title: "Flour",
                middle: "Yeast",
                end: "Water",
                leftColor: accent,
                middleColor: ColorTheme.warning,
                endColor: ColorTheme.info
            )

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ColorTheme.textFaint, lineWidth: 4)
                .frame(width: size.width * 0.28, height: size.height * 0.16)
                .offset(y: 42)
        }
    }

    private func sconeMethodArt(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accent.opacity(0.22))
                .frame(width: size.width * 0.62, height: size.height * 0.32)

            ForEach([-40.0, 0.0, 40.0], id: \.self) { offset in
                Circle()
                    .fill(ColorTheme.warning.opacity(0.88))
                    .frame(width: 30, height: 30)
                    .offset(x: offset, y: 4)
            }

            Text("Cut • Bake")
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .offset(y: 46)
        }
    }

    private func raisedBedArt(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent, lineWidth: 4)
                .frame(width: size.width * 0.70, height: size.height * 0.48)

            ForEach(0..<3, id: \.self) { row in
                ForEach(0..<4, id: \.self) { column in
                    Circle()
                        .fill(ColorTheme.ready)
                        .frame(width: 12, height: 12)
                        .offset(
                            x: CGFloat(column - 1) * 34 - 16,
                            y: CGFloat(row - 1) * 26
                        )
                }
            }
        }
    }

    private func seedTrayArt(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ColorTheme.info, lineWidth: 4)
                .frame(width: size.width * 0.66, height: size.height * 0.42)

            ForEach(0..<3, id: \.self) { row in
                ForEach(0..<4, id: \.self) { column in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accent.opacity(0.22))
                        .frame(width: 30, height: 24)
                        .offset(x: CGFloat(column - 1) * 34 - 16, y: CGFloat(row - 1) * 22)
                }
            }

            Image(systemName: "leaf.fill")
                .font(.title2)
                .foregroundStyle(ColorTheme.ready)
                .offset(y: -42)
        }
    }

    private func potatoBagArt(in size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: size.width * 0.34, height: size.height * 0.56)

            ForEach([-12.0, 12.0], id: \.self) { offset in
                Circle()
                    .fill(ColorTheme.warning)
                    .frame(width: 24, height: 24)
                    .offset(x: offset, y: 18)
            }

            Image(systemName: "leaf.fill")
                .font(.title)
                .foregroundStyle(accent)
                .offset(y: -34)
        }
    }

    private func waterFilterArt(in size: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.36, y: size.height * 0.20))
                path.addLine(to: CGPoint(x: size.width * 0.64, y: size.height * 0.20))
                path.addLine(to: CGPoint(x: size.width * 0.54, y: size.height * 0.72))
                path.addLine(to: CGPoint(x: size.width * 0.46, y: size.height * 0.72))
                path.closeSubpath()
            }
            .fill(accent.opacity(0.18))
            .overlay {
                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.36, y: size.height * 0.20))
                    path.addLine(to: CGPoint(x: size.width * 0.64, y: size.height * 0.20))
                    path.addLine(to: CGPoint(x: size.width * 0.54, y: size.height * 0.72))
                    path.addLine(to: CGPoint(x: size.width * 0.46, y: size.height * 0.72))
                    path.closeSubpath()
                }
                .stroke(accent, lineWidth: 4)
            }

            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ColorTheme.warning)
                    .frame(width: 52, height: 10)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ColorTheme.textFaint)
                    .frame(width: 52, height: 10)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ColorTheme.info)
                    .frame(width: 52, height: 10)
            }
        }
    }

    private func ingredientRatioArt(
        title: String,
        middle: String,
        end: String,
        leftColor: Color,
        middleColor: Color,
        endColor: Color
    ) -> some View {
        HStack(spacing: 12) {
            ratioBubble(title: title, color: leftColor)
            ratioBubble(title: middle, color: middleColor)
            ratioBubble(title: end, color: endColor)
        }
    }

    private func ratioBubble(title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(color.opacity(0.22))
                .frame(width: 42, height: 42)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.34), lineWidth: 1)
                )
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .multilineTextAlignment(.center)
                .frame(width: 58)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
