import SwiftUI

struct GuideLibraryView: View {
    let appState: AppState
    let scrollToTopRequestID: Int
    var highlightedCategory: GuideCategory?

    @State var selectedGuide: Guide?
    @State var searchText = ""
    @State var selectedCategory: GuideCategory?
    @State var isShowingFullLibrary = false
    @State var assistantContext: AssistantLaunchContext?

    var isFocusedEmergencySheet: Bool {
        highlightedCategory != nil
    }

    var effectiveCategory: GuideCategory? {
        highlightedCategory ?? selectedCategory
    }

    var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayedGuides: [Guide] {
        if !trimmedSearchText.isEmpty {
            return appState.guideService.searchGuides(query: trimmedSearchText, category: effectiveCategory)
        }

        if let effectiveCategory {
            return appState.guideService.guides(in: effectiveCategory)
        }

        return appState.guideService.allGuides()
    }

    var groupedGuides: [(GuideCategory, [Guide])] {
        let grouped = Dictionary(grouping: displayedGuides, by: \.category)
        return GuideCategory.allCases.compactMap { category in
            guard let guides = grouped[category], !guides.isEmpty else {
                return nil
            }
            return (category, guides.sorted { $0.title < $1.title })
        }
    }

    var libraryTitle: String {
        if let highlightedCategory {
            return highlightedCategory.title
        }
        return "Library"
    }

    var featuredCollections: [GuideCollection] {
        guard highlightedCategory == nil, selectedCategory == nil, trimmedSearchText.isEmpty else {
            return []
        }

        return GuideCollection.allCases
    }

    var isBrowsingFullLibrary: Bool {
        effectiveCategory == nil && trimmedSearchText.isEmpty
    }

    var criticalNowGuides: [Guide] {
        guard highlightedCategory == nil, selectedCategory == nil, trimmedSearchText.isEmpty else {
            return []
        }

        return Array(appState.guideService.allEmergencyCards().prefix(4))
    }

    var savedGuides: [Guide] {
        guard isBrowsingFullLibrary, !isFocusedEmergencySheet else {
            return []
        }

        return appState.guideService.guides(ids: appState.profile.savedGuideIDs)
    }

    var recentlyViewedGuides: [Guide] {
        guard isBrowsingFullLibrary, !isFocusedEmergencySheet else {
            return []
        }

        let savedIDs = Set(savedGuides.map(\.id))
        return appState.guideService.guides(ids: appState.profile.recentGuideIDs)
            .filter { !savedIDs.contains($0.id) }
    }

    var illustratedSpotlightGuides: [Guide] {
        guard isBrowsingFullLibrary else {
            return []
        }

        return Array(appState.guideService.illustratedGuides().prefix(4))
    }

    var categoryDirectory: [(category: GuideCategory, guides: [Guide])] {
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

                    if appState.isElevatedThreat {
                        // Elevated threat: critical guides first, search available, no browsing.
                        searchCard

                        if !criticalNowGuides.isEmpty {
                            criticalNowSection
                        }

                        if !savedGuides.isEmpty {
                            savedGuidesSection
                        }

                        if !trimmedSearchText.isEmpty {
                            resultsSection
                        }
                    } else {
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
}
