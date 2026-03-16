import SwiftUI

struct GuideLibraryView: View {
    let appState: AppState
    let scrollToTopRequestID: Int
    var highlightedCategory: GuideCategory?

    @State private var selectedGuide: Guide?
    @State private var searchText = ""
    @State private var selectedCategory: GuideCategory?
    @State private var isShowingFullLibrary = false
    @State private var assistantContext: AssistantLaunchContext?

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
        guard highlightedCategory == nil, selectedCategory == nil, trimmedSearchText.isEmpty else {
            return []
        }

        return GuideCollection.allCases
    }

    private var isBrowsingFullLibrary: Bool {
        effectiveCategory == nil && trimmedSearchText.isEmpty
    }

    private var criticalNowGuides: [Guide] {
        guard highlightedCategory == nil, selectedCategory == nil, trimmedSearchText.isEmpty else {
            return []
        }

        return Array(appState.guideService.allEmergencyCards().prefix(4))
    }

    private var savedGuides: [Guide] {
        guard isBrowsingFullLibrary, !isFocusedEmergencySheet else {
            return []
        }

        return appState.guideService.guides(ids: appState.profile.savedGuideIDs)
    }

    private var recentlyViewedGuides: [Guide] {
        guard isBrowsingFullLibrary, !isFocusedEmergencySheet else {
            return []
        }

        let savedIDs = Set(savedGuides.map(\.id))
        return appState.guideService.guides(ids: appState.profile.recentGuideIDs)
            .filter { !savedIDs.contains($0.id) }
    }

    private var illustratedSpotlightGuides: [Guide] {
        guard isBrowsingFullLibrary else {
            return []
        }

        return Array(appState.guideService.illustratedGuides().prefix(4))
    }

    private var categoryDirectory: [(category: GuideCategory, guides: [Guide])] {
        GuideCategory.allCases.compactMap { category in
            let guides = appState.guideService.guides(in: category)
            guard !guides.isEmpty else {
                return nil
            }

            return (category, guides)
        }
    }

    init(appState: AppState, highlightedCategory: GuideCategory? = nil, scrollToTopRequestID: Int = 0) {
        self.appState = appState
        self.highlightedCategory = highlightedCategory
        self.scrollToTopRequestID = scrollToTopRequestID
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear
                        .frame(height: 0)
                        .id(LibraryScrollAnchor.top)

                    headerCard
                    libraryStatusRail
                    searchCard

                    if !savedGuides.isEmpty {
                        savedGuidesSection
                    }

                    if !recentlyViewedGuides.isEmpty {
                        recentlyViewedSection
                    }

                    if !criticalNowGuides.isEmpty {
                        criticalNowSection
                    }

                    if !featuredCollections.isEmpty {
                        featuredCollectionsSection
                    }

                    if !isFocusedEmergencySheet && trimmedSearchText.isEmpty {
                        topicDirectorySection
                    }

                    if displayedGuides.isEmpty {
                        emptyStateCard
                    } else if isBrowsingFullLibrary {
                        if !illustratedSpotlightGuides.isEmpty {
                            illustratedSpotlightSection
                        }

                        fullLibrarySection
                    } else {
                        resultsSection
                    }
                }
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.screen)
                .padding(.bottom, RediLayout.commandDockContentInset)
            }
            .onChange(of: scrollToTopRequestID) { _, _ in
                DispatchQueue.main.async {
                    withAnimation(RediMotion.selection) {
                        proxy.scrollTo(LibraryScrollAnchor.top, anchor: .top)
                    }
                }
            }
        }
        .background(Color.clear)
        .navigationTitle(libraryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedGuide) { guide in
            NavigationStack {
                GuideDetailView(
                    guide: guide,
                    isSaved: isGuideSaved(guide.id),
                    onToggleSaved: { toggleSavedGuide(guide.id) }
                )
            }
            .rediSheetPresentation()
        }
        .sheet(item: $assistantContext) { context in
            NavigationStack {
                AssistantView(
                    appState: appState,
                    initialQuery: context.initialQuery,
                    sourceLabel: context.sourceLabel
                )
            }
            .rediSheetPresentation()
        }
    }

    private enum LibraryScrollAnchor {
        static let top = "library-scroll-top"
    }

    private var headerCard: some View {
        ModeHeroCard(
            eyebrow: isFocusedEmergencySheet ? "Emergency Guide Sheet" : "Offline Library",
            title: isFocusedEmergencySheet ? "\(libraryTitle) Reference" : "Field Library",
            subtitle: isFocusedEmergencySheet
                ? "Fast offline guidance for the category you opened from emergency mode."
                : "Search, browse, and keep illustrated field guides ready offline. Safety content stays source-labeled instead of pretending every answer is authoritative.",
            iconName: highlightedCategory?.systemImage ?? "documents",
            accent: highlightedCategory.map(accent(for:)) ?? ColorTheme.textTertiary
        ) {
            LazyVGrid(columns: libraryMetricColumns, spacing: 12) {
                libraryMetric(
                    title: "Critical",
                    value: "\(emergencyGuideCount)",
                    detail: "Open-first cards",
                    iconName: "cross.case.fill",
                    tint: ColorTheme.textTertiary
                )
                libraryMetric(
                    title: "Illustrated",
                    value: "\(illustratedGuideCount)",
                    detail: "Diagram-led references",
                    iconName: "photo.on.rectangle.angled",
                    tint: ColorTheme.textTertiary
                )
                libraryMetric(
                    title: "Official",
                    value: "\(officialGuideCount)",
                    detail: "Source-backed guides",
                    iconName: "checkmark.shield.fill",
                    tint: ColorTheme.textTertiary
                )
                libraryMetric(
                    title: "Coverage",
                    value: "\(GuideCategory.allCases.count)",
                    detail: "Core categories",
                    iconName: "square.grid.2x2.fill",
                    tint: ColorTheme.textTertiary
                )
            }

            Text(TrustLayer.librarySourceTransparencyNotice)
                .font(.caption)
                .foregroundStyle(ColorTheme.textTertiary)
        }
    }

    private var libraryStatusRail: some View {
        SystemStatusRail(items: libraryStatusItems, accent: ColorTheme.textTertiary)
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
                        .foregroundStyle(trimmedSearchText.isEmpty ? ColorTheme.textTertiary : ColorTheme.textTertiary)

                    TextField("Search offline guides", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .foregroundStyle(ColorTheme.text)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(ColorTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.field, style: .continuous))

                TrustPillGroup(items: searchContextItems)

                if trimmedSearchText.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(searchSuggestions, id: \.query) { suggestion in
                                Button {
                                    searchText = suggestion.query
                                } label: {
                                    Text(suggestion.label)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(ColorTheme.text)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(ColorTheme.panelRaised, in: Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(ColorTheme.textTertiary.opacity(0.18), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                } else {
                    Button {
                        assistantContext = AssistantLaunchContext(
                            initialQuery: trimmedSearchText,
                            sourceLabel: "Library search"
                        )
                    } label: {
                        RediCommandCard(
                            title: "Ask RediM8",
                            detail: displayedGuides.isEmpty
                                ? "Route this search to the offline assistant instead of guessing."
                                : "Use the assistant to turn this search into a guide-linked answer.",
                            systemImage: "bubble.left.and.text.bubble.right.fill",
                            tint: effectiveCategory.map(accent(for:)) ?? ColorTheme.textTertiary,
                            badge: displayedGuides.isEmpty ? "Fallback" : "Assist",
                            prominence: .accented,
                            layout: .rail
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())
                }
            }
        }
    }

    private var criticalNowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Critical Now")
                    .font(RediTypography.heading)
                    .foregroundStyle(ColorTheme.text)
                Text("High-stress guides surfaced first so the fastest actions are always within one tap.")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(criticalNowGuides) { guide in
                        spotlightGuideCard(
                            guide,
                            eyebrow: "Open First",
                            detail: guide.readingTimeText,
                            tint: accent(for: guide.category)
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var savedGuidesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Saved Guides")
                    .font(RediTypography.heading)
                    .foregroundStyle(ColorTheme.text)
                Text("Bookmarked references stay one tap away for repeat practice and fast recall.")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(savedGuides.prefix(6))) { guide in
                        spotlightGuideCard(
                            guide,
                            eyebrow: "Saved",
                            detail: guide.skillTimeText,
                            tint: accent(for: guide.category)
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var recentlyViewedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recently Viewed")
                    .font(RediTypography.heading)
                    .foregroundStyle(ColorTheme.text)
                Text("Reopen the same guide fast when you are checking steps more than once.")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(recentlyViewedGuides.prefix(6))) { guide in
                        spotlightGuideCard(
                            guide,
                            eyebrow: "Recent",
                            detail: guide.readingTimeText,
                            tint: accent(for: guide.category)
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var featuredCollectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Collections")
                    .font(RediTypography.heading)
                    .foregroundStyle(ColorTheme.text)
                Text("Curated bundles for high-stress reference, field skills, and offline learning.")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.textSecondary)
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

    private var topicDirectorySection: some View {
        PanelCard(
            title: "Topic Directory",
            subtitle: selectedCategory == nil
                ? "Browse by topic when you know the lane but not the exact guide title."
                : "Switch focus without losing your offline shelf."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: directoryColumns, spacing: 12) {
                    ForEach(categoryDirectory, id: \.category.rawValue) { entry in
                        categoryDirectoryCard(category: entry.category, guides: entry.guides)
                    }
                }

                if selectedCategory != nil {
                    Button {
                        selectedCategory = nil
                    } label: {
                        RediCommandCard(
                            title: "Show All Topics",
                            detail: "Clear the focused topic and return to the full offline directory.",
                            systemImage: "square.grid.2x2.fill",
                            tint: ColorTheme.textTertiary,
                            badge: "Reset",
                            prominence: .neutral,
                            layout: .rail
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())
                }
            }
        }
    }

    private var illustratedSpotlightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Illustrated Field Guides")
                    .font(RediTypography.heading)
                    .foregroundStyle(ColorTheme.text)
                Text("Diagram-led references stay close to the top for quick scanning in the field.")
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(illustratedSpotlightGuides) { guide in
                        spotlightGuideCard(
                            guide,
                            eyebrow: "Diagram-Led",
                            detail: "\(guide.diagrams.count) diagrams",
                            tint: accent(for: guide.category)
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var fullLibrarySection: some View {
        CollapsiblePanelCard(
            title: "All Topics",
            subtitle: "Open the full offline shelf when you want to browse beyond fast lanes and collections.",
            accent: ColorTheme.textTertiary,
            isExpanded: $isShowingFullLibrary
        ) {
            browseSections
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
                    .foregroundStyle(ColorTheme.textSecondary)

                TrustPillGroup(items: [
                    TrustPillItem(title: "Offline indexed", tone: .verified),
                    TrustPillItem(title: "Search terms matter", tone: .neutral),
                    TrustPillItem(title: effectiveCategory?.title ?? "All categories", tone: .info)
                ])

                if !trimmedSearchText.isEmpty {
                    Button {
                        assistantContext = AssistantLaunchContext(
                            initialQuery: trimmedSearchText,
                            sourceLabel: "Library fallback"
                        )
                    } label: {
                        RediCommandCard(
                            title: "Ask RediM8 Instead",
                            detail: "Open the offline assistant with this search so it can route the closest safe guides.",
                            systemImage: "bubble.left.and.text.bubble.right.fill",
                            tint: ColorTheme.textTertiary,
                            badge: "Offline",
                            prominence: .accented,
                            layout: .rail
                        )
                    }
                    .buttonStyle(CardPressButtonStyle())
                }
            }
        }
    }

    private var totalGuideCount: Int {
        appState.guideService.allGuides().count
    }

    private var emergencyGuideCount: Int {
        appState.guideService.allEmergencyCards().count
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

    private var directoryColumns: [GridItem] {
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
        var items = [TrustPillItem(title: "Offline indexed", tone: .neutral)]

        if trimmedSearchText.isEmpty {
            items.append(TrustPillItem(title: "Browse all", tone: .neutral))
        } else {
            items.append(TrustPillItem(title: "\(displayedGuides.count) matches", tone: .neutral))
        }

        if let effectiveCategory {
            items.append(TrustPillItem(title: effectiveCategory.title, tone: .neutral))
        }

        if highlightedCategory != nil {
            items.append(TrustPillItem(title: "Emergency sheet", tone: .caution))
        }

        return items
    }

    private var searchSuggestions: [(label: String, query: String)] {
        [
            ("Bleeding Control", "bleeding"),
            ("CPR", "cpr"),
            ("Water Purification", "water purification"),
            ("Compass Bearing", "compass"),
            ("Damper", "damper"),
            ("Raised Beds", "raised beds")
        ]
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
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)

                    Spacer(minLength: 0)

                    Text("\(guides.count) guides")
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
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
                        .foregroundStyle(ColorTheme.textSecondary)
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
                        .foregroundStyle(ColorTheme.textTertiary)

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                }
            }
            .frame(width: 244, alignment: .leading)
            .padding(18)
            .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous))
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func guideRow(_ guide: Guide) -> some View {
        let tint = accent(for: guide.category)

        return ZStack(alignment: .topTrailing) {
            Button {
                openGuide(guide)
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
                                .font(RediTypography.caption)
                                .foregroundStyle(ColorTheme.textTertiary)

                            Text(guide.title)
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)

                            Text(guide.summary)
                                .font(.subheadline)
                                .foregroundStyle(ColorTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)
                    }

                    TrustPillGroup(items: trustItems(for: guide))

                    HStack(spacing: 12) {
                        Label("Stored offline", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textTertiary)

                        Text("Reviewed \(guide.lastReviewed)")
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textTertiary)

                        if !guide.sources.isEmpty {
                            Text("\(guide.sources.count) sources")
                                .font(.caption)
                                .foregroundStyle(ColorTheme.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            }
            .buttonStyle(CardPressButtonStyle())

            guideSaveButton(for: guide)
                .padding(12)
        }
    }

    private func spotlightGuideCard(
        _ guide: Guide,
        eyebrow: String,
        detail: String,
        tint: Color
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                openGuide(guide)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(eyebrow.uppercased())
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.textTertiary)

                        Spacer(minLength: 0)

                        Text(detail)
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.textTertiary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(ColorTheme.panel.opacity(0.84), in: Capsule())
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tint.opacity(0.15))
                            .frame(width: 46, height: 46)

                        RediIcon(guide.heroIconName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(tint)
                            .frame(width: 18, height: 18)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(guide.title)
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)
                            .lineLimit(2)

                        Text(guide.summary)
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textSecondary)
                            .lineLimit(3)
                    }

                    TrustPillGroup(items: Array(trustItems(for: guide).prefix(3)))

                    HStack(spacing: 8) {
                        Label("Stored offline", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textTertiary)

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 252, alignment: .leading)
                .padding(18)
                .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous))
            }
            .buttonStyle(CardPressButtonStyle())

            guideSaveButton(for: guide)
                .padding(12)
        }
    }

    private func categoryDirectoryCard(category: GuideCategory, guides: [Guide]) -> some View {
        let tint = accent(for: category)
        let isSelected = selectedCategory == category
        let officialCount = guides.filter { guide in
            guide.sources.contains(where: { $0.kind == .official })
        }.count

        return Button {
            selectedCategory = isSelected ? nil : category
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill((isSelected ? ColorTheme.background : tint).opacity(isSelected ? 0.14 : 0.14))
                            .frame(width: 40, height: 40)

                        RediIcon(category.systemImage)
                            .foregroundStyle(isSelected ? ColorTheme.background : tint)
                            .frame(width: 18, height: 18)
                    }

                    Spacer(minLength: 0)

                    Text("\(guides.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? ColorTheme.background : ColorTheme.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((isSelected ? Color.white.opacity(0.16) : ColorTheme.panelRaised), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(category.title)
                        .font(.headline)
                        .foregroundStyle(isSelected ? ColorTheme.background : ColorTheme.text)

                    Text(categorySummary(for: category))
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? ColorTheme.background.opacity(0.82) : ColorTheme.textSecondary)
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    Text(officialCount == 0 ? "Offline shelf" : "\(officialCount) official")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? ColorTheme.background.opacity(0.92) : tint)

                    Spacer(minLength: 0)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? ColorTheme.background : tint)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 188, alignment: .leading)
            .padding(16)
            .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.16) : ColorTheme.dividerStrong, lineWidth: 1)
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func guideSaveButton(for guide: Guide) -> some View {
        Button {
            _ = toggleSavedGuide(guide.id)
        } label: {
            Image(systemName: isGuideSaved(guide.id) ? "bookmark.fill" : "bookmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isGuideSaved(guide.id) ? ColorTheme.accent : ColorTheme.textTertiary)
                .frame(width: 34, height: 34)
                .background(ColorTheme.panel.opacity(0.92), in: Circle())
                .overlay(
                    Circle()
                        .stroke(ColorTheme.dividerStrong, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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

    private func isGuideSaved(_ guideID: String) -> Bool {
        appState.profile.savedGuideIDs.contains(guideID)
    }

    @discardableResult
    private func toggleSavedGuide(_ guideID: String) -> Bool {
        var isSaved = false

        appState.mutateProfile { profile in
            if let existingIndex = profile.savedGuideIDs.firstIndex(of: guideID) {
                profile.savedGuideIDs.remove(at: existingIndex)
                isSaved = false
            } else {
                profile.savedGuideIDs.removeAll { $0 == guideID }
                profile.savedGuideIDs.insert(guideID, at: 0)
                profile.savedGuideIDs = Array(profile.savedGuideIDs.prefix(16))
                isSaved = true
            }
        }

        RediHaptics.selection()
        return isSaved
    }

    private func recordGuideView(_ guideID: String) {
        appState.mutateProfile { profile in
            profile.recentGuideIDs.removeAll { $0 == guideID }
            profile.recentGuideIDs.insert(guideID, at: 0)
            profile.recentGuideIDs = Array(profile.recentGuideIDs.prefix(12))
        }
    }

    private func openGuide(_ guide: Guide) {
        recordGuideView(guide.id)
        selectedGuide = guide
    }

    private func trustItems(for guide: Guide) -> [TrustPillItem] {
        var items = [
            TrustPillItem(title: "Stored offline", tone: .neutral),
            TrustPillItem(title: guide.difficulty.skillLevelTitle, tone: .neutral),
            TrustPillItem(title: guide.isIllustrated ? guide.skillTimeText : guide.readingTimeText, tone: .neutral)
        ]

        if guide.isIllustrated {
            items.append(TrustPillItem(title: "Illustrated", tone: .neutral))
        }

        if guide.sources.contains(where: { $0.kind == .official }) {
            items.append(TrustPillItem(title: "Official sources", tone: .verified))
        } else if !guide.sources.isEmpty {
            items.append(TrustPillItem(title: "Source-labeled", tone: .neutral))
        }

        if guide.regionScope == .regional {
            items.append(TrustPillItem(title: guide.regionScope.title, tone: .neutral))
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
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)
            Text(value)
                .font(RediTypography.dataLarge)
                .foregroundStyle(ColorTheme.text)
                .contentTransition(.numericText())
            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(16)
        .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
    }

    private func accent(for category: GuideCategory) -> Color {
        switch category {
        case .firstAid, .medical:
            ColorTheme.textTertiary
        case .disasterResponse, .fireSafety, .stormSafety, .floodSafety:
            ColorTheme.textTertiary
        case .bushcraft, .foodCooking, .foodGrowing:
            ColorTheme.textTertiary
        case .navigation, .waterSafety:
            ColorTheme.textTertiary
        case .heatSafety:
            ColorTheme.textTertiary
        }
    }

    private func collectionAccent(for collection: GuideCollection) -> Color {
        switch collection {
        case .emergency:
            ColorTheme.textTertiary
        case .illustrated:
            ColorTheme.textTertiary
        case .bushcraft:
            ColorTheme.textTertiary
        case .food:
            ColorTheme.textTertiary
        case .growing:
            ColorTheme.textTertiary
        }
    }
}

private enum GuideReadingMode: String, Hashable {
    case field
    case reference
}

struct GuideDetailView: View {
    let guide: Guide
    let onToggleSaved: (() -> Bool)?
    @State private var readingMode: GuideReadingMode
    @State private var selectedSectionID: String?
    @State private var isShowingReferenceSections = true
    @State private var isShowingIllustrations: Bool
    @State private var isShowingSources = false
    @State private var isSaved: Bool

    init(guide: Guide, isSaved: Bool = false, onToggleSaved: (() -> Bool)? = nil) {
        self.guide = guide
        self.onToggleSaved = onToggleSaved
        _readingMode = State(initialValue: .field)
        _selectedSectionID = State(initialValue: guide.contentSections.first?.id)
        _isShowingIllustrations = State(initialValue: guide.isIllustrated)
        _isSaved = State(initialValue: isSaved)
    }

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

                SystemStatusRail(items: detailStatusItems, accent: accent)

                PanelCard(
                    title: "Reading Mode",
                    subtitle: "Field mode keeps one action lane open at a time. Reference mode surfaces diagrams, section summaries, and source traceability."
                ) {
                    PremiumSegmentedControl(items: readingModeOptions, selection: $readingMode)
                }

                if !guide.notes.isEmpty {
                    PanelCard(title: "Important", subtitle: "Keep this limitation or caution in mind while using the guide.") {
                        Text(guide.notes)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ColorTheme.warning)
                    }
                }

                if readingMode == .field {
                    fieldModeContent
                } else {
                    referenceModeContent
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle("Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let onToggleSaved {
                        isSaved = onToggleSaved()
                    } else {
                        isSaved.toggle()
                    }
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isSaved ? ColorTheme.warning : ColorTheme.text)
                }
            }
        }
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
            ColorTheme.accent
        }
    }

    private var readingModeOptions: [PremiumSegmentedControlOption<GuideReadingMode>] {
        [
            PremiumSegmentedControlOption(
                segmentID: .field,
                title: "Field",
                detail: "One lane at a time",
                iconName: "bolt.fill",
                accent: accent
            ),
            PremiumSegmentedControlOption(
                segmentID: .reference,
                title: "Reference",
                detail: "Full supporting context",
                iconName: "book.pages.fill",
                accent: accent
            )
        ]
    }

    private var detailStatusItems: [OperationalStatusItem] {
        [
            OperationalStatusItem(
                iconName: readingMode == .field ? "bolt.fill" : "book.pages.fill",
                label: "Mode",
                value: readingMode == .field ? "Field Steps" : "Reference View",
                tone: .info
            ),
            OperationalStatusItem(
                iconName: "list.number",
                label: "Sections",
                value: guide.contentSections.count == 1 ? "1 Section" : "\(guide.contentSections.count) Sections",
                tone: .neutral
            ),
            OperationalStatusItem(
                iconName: "figure.walk.motion",
                label: "Focus",
                value: selectedSection?.title ?? "Guide Steps",
                tone: .ready
            ),
            OperationalStatusItem(
                iconName: "checkmark.shield.fill",
                label: "Sources",
                value: guide.sources.isEmpty ? "Bundled Guide" : "\(guide.sources.count) Linked",
                tone: guide.sources.isEmpty ? .neutral : .info
            )
        ]
    }

    private var selectedSection: GuideSection? {
        if let selectedSectionID,
           let section = guide.contentSections.first(where: { $0.id == selectedSectionID }) {
            return section
        }

        return guide.contentSections.first
    }

    private var totalStepCount: Int {
        guide.contentSections.reduce(0) { $0 + $1.steps.count }
    }

    private var fieldModeContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if guide.contentSections.count > 1 {
                PanelCard(
                    title: "Section Navigator",
                    subtitle: "Keep one action lane open at a time so the next move stays obvious."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(guide.contentSections) { section in
                                fieldSectionButton(section)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }

            if guide.isIllustrated {
                PanelCard(title: "Scan First", subtitle: "Illustrations stay up front in field mode for quick visual checks.") {
                    diagramStrip
                }
            }

            if let selectedSection {
                PanelCard(
                    title: selectedSection.title,
                    subtitle: selectedSection.summary ?? "Work this lane from top to bottom before moving on."
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(selectedSection.steps.enumerated()), id: \.offset) { index, step in
                            fieldStepCard(number: index + 1, step: step)
                        }
                    }
                }
            }
        }
    }

    private var referenceModeContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelCard(title: "Reference Overview", subtitle: "A fuller briefing for planning, reviewing, or training before the next incident.") {
                LazyVGrid(columns: detailMetricColumns, spacing: 12) {
                    detailMetricTile(
                        title: "Steps",
                        value: "\(totalStepCount)",
                        detail: "Action items",
                        iconName: "list.number"
                    )
                    detailMetricTile(
                        title: "Diagrams",
                        value: guide.isIllustrated ? "\(guide.diagrams.count)" : "0",
                        detail: guide.isIllustrated ? "Visual aids" : "Text-only guide",
                        iconName: "photo.on.rectangle.angled"
                    )
                    detailMetricTile(
                        title: "Sources",
                        value: guide.sources.isEmpty ? "0" : "\(guide.sources.count)",
                        detail: guide.sources.isEmpty ? "Bundled only" : "Traceable links",
                        iconName: "checkmark.shield.fill"
                    )
                    detailMetricTile(
                        title: "Review",
                        value: guide.readingTimeText,
                        detail: guide.lastReviewed,
                        iconName: "clock.fill"
                    )
                }
            }

            if guide.isIllustrated {
                CollapsiblePanelCard(
                    title: "Diagrams",
                    subtitle: "Original offline diagrams that support the guide steps.",
                    accent: accent,
                    isExpanded: $isShowingIllustrations
                ) {
                    diagramStrip
                }
            }

            CollapsiblePanelCard(
                title: "Guide Sections",
                subtitle: "Jump between sections or read them end to end when you have more time.",
                accent: accent,
                isExpanded: $isShowingReferenceSections
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(guide.contentSections) { section in
                        referenceSectionCard(section)
                    }
                }
            }

            if !guide.sources.isEmpty {
                CollapsiblePanelCard(
                    title: "Sources",
                    subtitle: "Traceability matters. RediM8 shows where this guide was reviewed against.",
                    accent: accent,
                    isExpanded: $isShowingSources
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(guide.sources) { source in
                            sourceCard(source)
                        }

                        Text(TrustLayer.guideEndorsementNotice)
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                }
            }
        }
    }

    private var detailMetricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var diagramStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(guide.diagrams) { diagram in
                    GuideDiagramPanel(diagram: diagram, accent: accent)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func fieldSectionButton(_ section: GuideSection) -> some View {
        let isSelected = selectedSection?.id == section.id

        return Button {
            selectedSectionID = section.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(section.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSelected ? ColorTheme.background : ColorTheme.text)
                    .lineLimit(2)

                Text(section.steps.count == 1 ? "1 step" : "\(section.steps.count) steps")
                    .font(RediTypography.caption)
                    .foregroundStyle(isSelected ? ColorTheme.background.opacity(0.82) : accent)
            }
            .frame(width: 168, alignment: .leading)
            .padding(14)
            .background(
                PremiumSurfaceBackground(
                    cornerRadius: 20,
                    backgroundAssetName: nil,
                    backgroundImageOffset: .zero,
                    atmosphere: isSelected ? accent.opacity(0.34) : accent.opacity(0.1)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.0) : accent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func fieldStepCard(number: Int, step: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.18))
                    .frame(width: 42, height: 42)

                Text("\(number)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(accent)
            }

            Text(step)
                .font(.body.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func referenceSectionCard(_ section: GuideSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(section.title)
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)

                Spacer(minLength: 0)

                Text(section.steps.count == 1 ? "1 step" : "\(section.steps.count) steps")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.14), in: Capsule())
            }

            if let summary = section.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(section.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(accent)

                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.text)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func detailMetricTile(
        title: String,
        value: String,
        detail: String,
        iconName: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .frame(width: 34, height: 34)

                RediIcon(iconName)
                    .foregroundStyle(accent)
                    .frame(width: 16, height: 16)
            }

            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            Text(value)
                .font(RediTypography.dataLarge)
                .foregroundStyle(ColorTheme.text)
                .lineLimit(1)

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(16)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 20,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: accent.opacity(0.1)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 20, edgeColor: accent.opacity(0.14), shadowColor: accent.opacity(0.05)))
    }

    private func sourceCard(_ source: GuideSource) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(source.kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                Text(source.publisher)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textTertiary)
            }

            Text(source.title)
                .font(.headline)
                .foregroundStyle(ColorTheme.text)

            Text(source.url)
                .font(.caption)
                .foregroundStyle(ColorTheme.accent)
                .textSelection(.enabled)

            if let license = source.license, !license.isEmpty {
                Text(license)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var trustItems: [TrustPillItem] {
        var items = [
            TrustPillItem(title: "Stored offline", tone: .neutral),
            TrustPillItem(title: guide.confidenceTitle, tone: .neutral),
            TrustPillItem(title: guide.readingTimeText, tone: .neutral),
            TrustPillItem(title: guide.difficulty.skillLevelTitle, tone: .neutral),
            TrustPillItem(title: guide.regionScope.title, tone: .neutral),
            TrustPillItem(title: "Reviewed \(guide.lastReviewed)", tone: .neutral)
        ]

        if guide.isIllustrated {
            items.append(TrustPillItem(title: guide.skillTimeText, tone: .neutral))
            items.append(TrustPillItem(title: "Illustrated", tone: .neutral))
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
                .foregroundStyle(ColorTheme.textSecondary)
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
                .stroke(ColorTheme.accent, lineWidth: 10)
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
            .stroke(ColorTheme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
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
                .stroke(ColorTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
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
            middleColor: ColorTheme.accent,
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
                endColor: ColorTheme.accent
            )

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ColorTheme.textTertiary, lineWidth: 4)
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
                .stroke(ColorTheme.accent, lineWidth: 4)
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
                    .fill(ColorTheme.textTertiary)
                    .frame(width: 52, height: 10)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ColorTheme.accent)
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
