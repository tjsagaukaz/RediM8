import SwiftUI

enum GuideReadingMode: String, Hashable {
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
    @State private var isShowingProcedural = true
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

                Picker("Reading Mode", selection: $readingMode) {
                    Text("Field").tag(GuideReadingMode.field)
                    Text("Reference").tag(GuideReadingMode.reference)
                }
                .pickerStyle(.segmented)

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

    // MARK: - Accent

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
        case .wildlife, .trapping, .toolcraft, .fieldComms, .sanitation,
             .psychology, .security, .vehicleSurvival, .waterSourcing,
             .shelterBuilding, .firecraft, .navigationAdvanced:
            ColorTheme.accent
        }
    }

    // MARK: - Reading Mode Options

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

    // MARK: - Status Items

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

    // MARK: - Computed Properties

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

    private var proceduralStepCount: Int {
        ProceduralDiagramRegistry.steps(for: guide.id)?.count ?? 0
    }

    // MARK: - Field Mode

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

            if ProceduralDiagramRegistry.hasDiagrams(for: guide.id) {
                PanelCard(title: "Visual Steps", subtitle: "Step-by-step procedural diagrams. Each panel = one action.") {
                    ProceduralDiagramStrip(guideID: guide.id, accent: accent)
                }
            } else if guide.isIllustrated {
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
                            InlineStepDiagram(guideID: guide.id, stepIndex: index, accent: accent)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reference Mode

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
                        value: proceduralStepCount > 0 ? "\(proceduralStepCount)" : (guide.isIllustrated ? "\(guide.diagrams.count)" : "0"),
                        detail: proceduralStepCount > 0 ? "Procedural steps" : (guide.isIllustrated ? "Visual aids" : "Text-only guide"),
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

            if ProceduralDiagramRegistry.hasDiagrams(for: guide.id) {
                CollapsiblePanelCard(
                    title: "Procedural Diagrams",
                    subtitle: "Step-by-step visual instructions. Each panel shows one physical action.",
                    accent: accent,
                    isExpanded: $isShowingProcedural
                ) {
                    ProceduralDiagramStrip(guideID: guide.id, accent: accent)
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

    // MARK: - Layout

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

    // MARK: - Sub-Components

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

    // MARK: - Trust Items

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
