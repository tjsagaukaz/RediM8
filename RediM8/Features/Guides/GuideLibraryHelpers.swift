import SwiftUI

// MARK: - Helper Functions, Data, and Computed Properties

extension GuideLibraryView {

    // MARK: - Guide Counts

    var totalGuideCount: Int {
        appState.guideService.allGuides().count
    }

    var emergencyGuideCount: Int {
        appState.guideService.allEmergencyCards().count
    }

    var illustratedGuideCount: Int {
        appState.guideService.illustratedGuides().count
    }

    var officialGuideCount: Int {
        appState.guideService.allGuides().filter { guide in
            guide.sources.contains(where: { $0.kind == .official })
        }.count
    }

    // MARK: - Grid Columns

    var libraryMetricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    var directoryColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    // MARK: - Status Items

    var libraryStatusItems: [OperationalStatusItem] {
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

    var searchContextItems: [TrustPillItem] {
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

    var searchSuggestions: [(label: String, query: String)] {
        [
            ("Bleeding Control", "bleeding"),
            ("CPR", "cpr"),
            ("Water Purification", "water purification"),
            ("Compass Bearing", "compass"),
            ("Damper", "damper"),
            ("Raised Beds", "raised beds")
        ]
    }

    // MARK: - Actions

    func activateCollection(_ collection: GuideCollection) {
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
        case .survivalWater:
            selectedCategory = .waterSourcing
        case .survivalFire:
            selectedCategory = .firecraft
        case .survivalShelter:
            selectedCategory = .shelterBuilding
        case .survivalFood:
            selectedCategory = .trapping
        case .survivalField:
            selectedCategory = .fieldComms
        }
    }

    func isGuideSaved(_ guideID: String) -> Bool {
        appState.profile.savedGuideIDs.contains(guideID)
    }

    @discardableResult
    func toggleSavedGuide(_ guideID: String) -> Bool {
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

    func recordGuideView(_ guideID: String) {
        appState.mutateProfile { profile in
            profile.recentGuideIDs.removeAll { $0 == guideID }
            profile.recentGuideIDs.insert(guideID, at: 0)
            profile.recentGuideIDs = Array(profile.recentGuideIDs.prefix(12))
        }
    }

    func openGuide(_ guide: Guide) {
        recordGuideView(guide.id)
        selectedGuide = guide
    }

    // MARK: - Trust Items

    func trustItems(for guide: Guide) -> [TrustPillItem] {
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

    // MARK: - Category Summary

    func categorySummary(for category: GuideCategory) -> String {
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
        case .wildlife:
            "Dangerous wildlife identification, avoidance, and encounter response."
        case .trapping:
            "Snares, fish traps, insect protein, and emergency foraging rules."
        case .toolcraft:
            "Improvised tools, cordage, cutting edges, and field repairs."
        case .fieldComms:
            "Signal fires, ground signals, UHF/CB radio, and improvised antennas."
        case .sanitation:
            "Waste disposal, water contamination prevention, and hygiene without supplies."
        case .psychology:
            "Routine building, panic control, decision fatigue, and isolation coping."
        case .security:
            "Camp concealment, perimeter awareness, and personal safety protocols."
        case .vehicleSurvival:
            "Vehicle shelter, battery survival, signalling, and stay-vs-leave decisions."
        case .waterSourcing:
            "Finding water from terrain, solar stills, condensation, and rationing."
        case .shelterBuilding:
            "Debris huts, lean-tos, ground insulation, and heat retention."
        case .firecraft:
            "Bow drill, hand drill, wet-weather fire, and long-term fire maintenance."
        case .navigationAdvanced:
            "Sun and star navigation, terrain reading, and don't-get-lost protocols."
        }
    }

    // MARK: - Library Metric

    func libraryMetric(
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

    // MARK: - Accent Colors

    func accent(for category: GuideCategory) -> Color {
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
        case .wildlife, .trapping, .toolcraft, .fieldComms, .sanitation,
             .psychology, .security, .vehicleSurvival, .waterSourcing,
             .shelterBuilding, .firecraft, .navigationAdvanced:
            ColorTheme.textTertiary
        }
    }

    func collectionAccent(for collection: GuideCollection) -> Color {
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
        case .survivalWater, .survivalFire, .survivalShelter, .survivalFood, .survivalField:
            ColorTheme.textTertiary
        }
    }
}
