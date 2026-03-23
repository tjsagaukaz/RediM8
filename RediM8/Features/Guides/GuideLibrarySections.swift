import SwiftUI

// MARK: - Library Content Sections

extension GuideLibraryView {

    var headerCard: some View {
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

    var libraryStatusRail: some View {
        SystemStatusRail(items: libraryStatusItems, accent: ColorTheme.textTertiary)
    }

    var searchCard: some View {
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

    var criticalNowSection: some View {
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

    var savedGuidesSection: some View {
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

    var recentlyViewedSection: some View {
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

    var featuredCollectionsSection: some View {
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

    var topicDirectorySection: some View {
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

    var illustratedSpotlightSection: some View {
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

    var fullLibrarySection: some View {
        CollapsiblePanelCard(
            title: "All Topics",
            subtitle: "Open the full offline shelf when you want to browse beyond fast lanes and collections.",
            accent: ColorTheme.textTertiary,
            isExpanded: $isShowingFullLibrary
        ) {
            browseSections
        }
    }

    var browseSections: some View {
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

    var resultsSection: some View {
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

    var emptyStateCard: some View {
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
}
