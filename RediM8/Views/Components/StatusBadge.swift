import SwiftUI

// MARK: - Status Badge

struct StatusBadge: View {
    let tier: PrepTier

    var body: some View {
        Text(tier.displayTitle.uppercased())
            .font(RediTypography.label)
            .tracking(1.2)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(foreground.opacity(0.10), in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                    .stroke(foreground.opacity(0.16), lineWidth: 0.5)
            )
            .accessibilityLabel("Readiness tier: \(tier.displayTitle)")
    }

    private var foreground: Color {
        switch tier {
        case .notReady: ColorTheme.danger
        case .improving: ColorTheme.warning
        case .prepared, .highlyPrepared: ColorTheme.ready
        }
    }
}

// MARK: - Trust Pills

enum TrustPillTone: String, Equatable, Hashable {
    case verified, neutral, info, caution, danger
}

struct TrustPillItem: Identifiable, Equatable, Hashable {
    let title: String
    let tone: TrustPillTone
    var id: String { "\(tone.rawValue)-\(title)" }
}

struct TrustPillGroup: View {
    let items: [TrustPillItem]

    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RediSpacing.tight) {
                    ForEach(items) { item in
                        TrustPill(item: item)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }
}

private struct TrustPill: View {
    let item: TrustPillItem

    var body: some View {
        Text(item.title)
            .font(RediTypography.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ColorTheme.graphite, in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                    .stroke(ColorTheme.divider, lineWidth: 0.5)
            )
    }

    private var foreground: Color {
        switch item.tone {
        case .verified: ColorTheme.ready
        case .neutral: ColorTheme.textTertiary
        case .info: ColorTheme.accent
        case .caution: ColorTheme.warning
        case .danger: ColorTheme.danger
        }
    }
}

// MARK: - Operational Status

enum OperationalStatusTone: Equatable {
    case ready, info, caution, danger, neutral
}

struct OperationalStatusItem: Identifiable, Equatable {
    let iconName: String
    let label: String
    let value: String
    let tone: OperationalStatusTone
    var id: String { "\(label)-\(value)" }
}

struct OperationalStatusRail: View {
    let items: [OperationalStatusItem]
    let accent: Color

    var body: some View {
        if !items.isEmpty {
            SystemStatusRail(items: items, accent: accent)
                .background(ColorTheme.background)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(ColorTheme.divider)
                        .frame(height: 0.5)
                }
        }
    }
}

struct SystemStatusRail: View {
    let items: [OperationalStatusItem]
    let accent: Color

    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RediSpacing.compact) {
                    ForEach(items) { item in
                        SystemStatusChip(item: item)
                    }
                }
                .padding(.horizontal, RediSpacing.screen)
                .padding(.vertical, RediSpacing.compact)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct SystemStatusChip: View {
    let item: OperationalStatusItem

    var body: some View {
        let toneColor = color(for: item.tone)

        HStack(alignment: .center, spacing: RediSpacing.compact) {
            ZStack {
                RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                    .fill(ColorTheme.gunmetal)
                    .frame(width: 28, height: 28)

                RediIcon(item.iconName)
                    .foregroundStyle(toneColor)
                    .frame(width: 14, height: 14)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.label.uppercased())
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)
                    .lineLimit(1)
                Text(item.value)
                    .font(RediTypography.data)
                    .foregroundStyle(ColorTheme.text)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(ColorTheme.graphite)
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.label)
        .accessibilityValue(item.value)
    }

    private func color(for tone: OperationalStatusTone) -> Color {
        switch tone {
        case .ready: ColorTheme.ready
        case .info: ColorTheme.accent
        case .caution: ColorTheme.warning
        case .danger: ColorTheme.danger
        case .neutral: ColorTheme.textTertiary
        }
    }
}

// MARK: - Readiness Meter

struct ReadinessMeter: View {
    let value: Double
    let tint: Color
    var height: CGFloat = 6
    var backgroundTint: Color = ColorTheme.gunmetal

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedValue: Double = 0

    private var clampedValue: Double { min(max(value, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            let fillWidth = proxy.size.width * displayedValue

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(backgroundTint)

                RoundedRectangle(cornerRadius: 3)
                    .fill(tint)
                    .frame(width: max(fillWidth, displayedValue > 0.02 ? height : 0))
            }
        }
        .frame(height: height)
        .onAppear { updateDisplayedValue(initial: true) }
        .onChange(of: clampedValue) { _, _ in updateDisplayedValue(initial: false) }
    }

    private func updateDisplayedValue(initial: Bool) {
        guard !reduceMotion else {
            displayedValue = clampedValue
            return
        }
        if initial {
            displayedValue = 0
            DispatchQueue.main.async {
                withAnimation(RediMotion.meter) { displayedValue = clampedValue }
            }
        } else {
            withAnimation(RediMotion.meter) { displayedValue = clampedValue }
        }
    }
}

// MARK: - Readiness Ring

struct ReadinessRing: View {
    let value: Double
    let tint: Color
    let title: String
    let subtitle: String
    var size: CGFloat = 112
    var lineWidth: CGFloat = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedValue: Double = 0

    private var clampedValue: Double { min(max(value, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ColorTheme.iron, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: displayedValue)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text(title)
                    .font(RediTypography.dataLarge)
                    .foregroundStyle(ColorTheme.text)
                    .contentTransition(.numericText())

                Text(subtitle.uppercased())
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .onAppear { updateDisplayedValue(initial: true) }
        .onChange(of: clampedValue) { _, _ in updateDisplayedValue(initial: false) }
    }

    private func updateDisplayedValue(initial: Bool) {
        guard !reduceMotion else {
            displayedValue = clampedValue
            return
        }
        if initial {
            displayedValue = 0
            DispatchQueue.main.async {
                withAnimation(RediMotion.meter) { displayedValue = clampedValue }
            }
        } else {
            withAnimation(RediMotion.meter) { displayedValue = clampedValue }
        }
    }
}

// MARK: - Segmented Control

struct PremiumSegmentedControlOption<ID: Hashable>: Identifiable {
    let segmentID: ID
    let title: String
    let detail: String?
    let iconName: String?
    let accent: Color
    var id: ID { segmentID }
}

struct PremiumSegmentedControl<ID: Hashable>: View {
    let items: [PremiumSegmentedControlOption<ID>]
    @Binding var selection: ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: RediSpacing.tight) {
            ForEach(items) { item in
                let isSelected = item.segmentID == selection

                Button {
                    guard selection != item.segmentID else { return }
                    if reduceMotion {
                        selection = item.segmentID
                    } else {
                        withAnimation(RediMotion.selection) { selection = item.segmentID }
                    }
                } label: {
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                                .fill(ColorTheme.gunmetal)
                                .overlay(
                                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                                        .stroke(ColorTheme.accent.opacity(0.3), lineWidth: 0.5)
                                )
                                .matchedGeometryEffect(id: "premiumSegmentSelection", in: selectionNamespace)
                        }

                        HStack(alignment: .center, spacing: RediSpacing.compact) {
                            if let iconName = item.iconName {
                                ZStack {
                                    RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                                        .fill(ColorTheme.gunmetal)
                                        .frame(width: 28, height: 28)

                                    RediIcon(iconName)
                                        .foregroundStyle(isSelected ? ColorTheme.accent : ColorTheme.textTertiary)
                                        .frame(width: 14, height: 14)
                                }
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(RediTypography.bodyStrong)
                                    .foregroundStyle(isSelected ? ColorTheme.text : ColorTheme.textSecondary)
                                    .lineLimit(1)

                                if let detail = item.detail {
                                    Text(detail)
                                        .font(RediTypography.caption)
                                        .foregroundStyle(isSelected ? ColorTheme.accent : ColorTheme.textTertiary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(RediSpacing.tight)
        .background(ColorTheme.charcoal)
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.section, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.section, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
        )
        .animation(reduceMotion ? nil : RediMotion.selection, value: selection)
    }
}

// MARK: - Mode Hero Card

struct ModeHeroCard<Content: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String
    let iconName: String
    let accent: Color
    let showsBreathing: Bool?
    let shimmerColor: Color?
    let backgroundAssetName: String?
    let backgroundImageOffset: CGSize
    private let content: Content

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String,
        iconName: String,
        accent: Color,
        showsBreathing: Bool? = nil,
        shimmerColor: Color? = nil,
        backgroundAssetName: String? = nil,
        backgroundImageOffset: CGSize = .zero,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.accent = accent
        self.showsBreathing = showsBreathing
        self.shimmerColor = shimmerColor
        self.backgroundAssetName = backgroundAssetName
        self.backgroundImageOffset = backgroundImageOffset
        self.content = content()
    }

    var body: some View {
        HeroPanel(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            iconName: iconName,
            accent: accent,
            showsBreathing: false,
            backgroundAssetName: backgroundAssetName,
            backgroundImageOffset: backgroundImageOffset
        ) {
            content
        }
    }
}

// MARK: - Collapsible Panel

struct CollapsiblePanelCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let accent: Color
    let surfaceAtmosphere: Color?
    let surfaceEdgeColor: Color?
    let surfaceShadowColor: Color?
    @Binding var isExpanded: Bool
    private let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        accent: Color = ColorTheme.accent,
        surfaceAtmosphere: Color? = nil,
        surfaceEdgeColor: Color? = nil,
        surfaceShadowColor: Color? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.surfaceAtmosphere = surfaceAtmosphere
        self.surfaceEdgeColor = surfaceEdgeColor
        self.surfaceShadowColor = surfaceShadowColor
        _isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(RediMotion.reveal) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .center, spacing: RediSpacing.content) {
                    VStack(alignment: .leading, spacing: RediSpacing.micro) {
                        Text(title)
                            .font(RediTypography.heading)
                            .foregroundStyle(ColorTheme.text)

                        if let subtitle {
                            Text(subtitle)
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ColorTheme.textTertiary)
                }
                .padding(RediSpacing.card)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Rectangle()
                    .fill(ColorTheme.divider)
                    .frame(height: 0.5)
                    .padding(.horizontal, RediSpacing.card)

                VStack(alignment: .leading, spacing: RediSpacing.content) {
                    content
                }
                .padding(RediSpacing.card)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(ColorTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.section, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.section, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
        )
    }
}

// MARK: - Thumb Action Dock

struct ThumbActionDock<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(ColorTheme.divider)
                .frame(height: 0.5)

            content
                .padding(.horizontal, RediSpacing.compact)
                .padding(.vertical, RediSpacing.tight)
                .background(ColorTheme.panel)
        }
    }
}

// MARK: - Command Dock (Tab Bar)

struct CommandDockItemModel<ID: Hashable>: Identifiable {
    let dockID: ID
    let title: String
    let systemImage: String
    let accent: Color
    var id: ID { dockID }
}

struct CommandDock<ID: Hashable>: View {
    let items: [CommandDockItemModel<ID>]
    let selectedID: ID
    let action: (ID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = item.dockID == selectedID

                Button {
                    action(item.dockID)
                } label: {
                    VStack(spacing: 2) {
                        // Accent underline indicator
                        Rectangle()
                            .fill(isSelected ? ColorTheme.accent : Color.clear)
                            .frame(height: 2)

                        Spacer(minLength: 4)

                        Image(systemName: item.systemImage)
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 18, weight: .semibold))

                        Text(item.title)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(isSelected ? ColorTheme.accent : ColorTheme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(CommandDockButtonStyle())
                .accessibilityLabel(item.title)
            }
        }
        .background(
            VStack(spacing: 0) {
                Rectangle()
                    .fill(ColorTheme.divider)
                    .frame(height: 0.5)
                ColorTheme.charcoal
            }
        )
        .animation(reduceMotion ? nil : RediMotion.selection, value: selectedID)
        .dynamicTypeSize(.xSmall ... .large)
    }
}

private struct CommandDockButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Staggered Reveal (simplified — instant appear)

private struct StaggeredRevealModifier: ViewModifier {
    let index: Int
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .animation(RediMotion.reveal, value: isVisible)
    }
}

extension View {
    func rediStaggeredReveal(index: Int, isVisible: Bool) -> some View {
        modifier(StaggeredRevealModifier(index: index, isVisible: isVisible))
    }
}

// MARK: - Map Pack Coverage Preview

struct MapPackCoveragePreview: View {
    let pack: OfflineMapPack
    let isInstalled: Bool
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.size
            let widthRatio = normalizedRatio(
                value: pack.longitudeDelta,
                maxValue: pack.kind == .state ? 16 : 6.5
            )
            let heightRatio = normalizedRatio(
                value: pack.latitudeDelta,
                maxValue: pack.kind == .state ? 16 : 6.5
            )

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .fill(ColorTheme.graphite)

                gridOverlay(in: frame)

                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .fill(accent.opacity(isInstalled ? 0.20 : 0.10))
                    .frame(width: frame.width * CGFloat(widthRatio), height: frame.height * CGFloat(heightRatio))
                    .overlay(
                        RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                            .stroke(accent.opacity(0.3), lineWidth: 0.5)
                    )
                    .position(x: frame.width / 2, y: frame.height / 2)

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text(pack.kind.title.uppercased())
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)

                    Text(isInstalled ? "Coverage ready" : "Coverage optional")
                        .font(RediTypography.caption)
                        .foregroundStyle(isInstalled ? ColorTheme.ready : ColorTheme.textSecondary)
                }
                .padding(RediSpacing.content)
            }
        }
        .frame(height: 80)
    }

    private func normalizedRatio(value: Double, maxValue: Double) -> Double {
        (value / maxValue).clamped(to: 0.34...0.92)
    }

    @ViewBuilder
    private func gridOverlay(in size: CGSize) -> some View {
        Path { path in
            let verticalStep = size.width / 4
            let horizontalStep = size.height / 4
            for index in 1..<4 {
                let vertical = verticalStep * CGFloat(index)
                let horizontal = horizontalStep * CGFloat(index)
                path.move(to: CGPoint(x: vertical, y: 0))
                path.addLine(to: CGPoint(x: vertical, y: size.height))
                path.move(to: CGPoint(x: 0, y: horizontal))
                path.addLine(to: CGPoint(x: size.width, y: horizontal))
            }
        }
        .stroke(ColorTheme.dividerSubtle, lineWidth: 0.5)
    }
}
