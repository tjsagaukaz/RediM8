import SwiftUI

struct StatusBadge: View {
    let tier: PrepTier

    var body: some View {
        Text(tier.displayTitle.uppercased())
            .font(RediTypography.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [background, foreground.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(foreground.opacity(0.34), lineWidth: 1)
            )
    }

    private var foreground: Color {
        switch tier {
        case .notReady:
            ColorTheme.danger
        case .improving:
            ColorTheme.warning
        case .prepared:
            ColorTheme.ready
        case .highlyPrepared:
            ColorTheme.ready
        }
    }

    private var background: Color {
        foreground.opacity(tier == .highlyPrepared ? 0.18 : 0.14)
    }
}

enum TrustPillTone: String, Equatable, Hashable {
    case verified
    case neutral
    case info
    case caution
    case danger
}

struct TrustPillItem: Identifiable, Equatable, Hashable {
    let title: String
    let tone: TrustPillTone

    var id: String {
        "\(tone.rawValue)-\(title)"
    }
}

struct TrustPillGroup: View {
    let items: [TrustPillItem]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasRevealed = false

    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        TrustPill(item: item)
                            .rediStaggeredReveal(index: index, isVisible: hasRevealed)
                    }
                }
                .padding(.vertical, 1)
            }
            .onAppear(perform: triggerReveal)
            .onChange(of: items.map(\.id)) { _, _ in
                triggerReveal()
            }
        }
    }

    private func triggerReveal() {
        guard !reduceMotion else {
            hasRevealed = true
            return
        }

        hasRevealed = false
        DispatchQueue.main.async {
            hasRevealed = true
        }
    }
}

private struct TrustPill: View {
    let item: TrustPillItem

    var body: some View {
        Text(item.title)
            .font(RediTypography.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                LinearGradient(
                    colors: [ColorTheme.panelElevated, ColorTheme.panelRaised],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(ColorTheme.dividerStrong, lineWidth: 1)
            )
    }

    private var foreground: Color {
        switch item.tone {
        case .verified:
            ColorTheme.ready
        case .neutral:
            ColorTheme.textFaint
        case .info:
            ColorTheme.info
        case .caution:
            ColorTheme.warning
        case .danger:
            ColorTheme.danger
        }
    }
}

enum OperationalStatusTone: Equatable {
    case ready
    case info
    case caution
    case danger
    case neutral
}

struct OperationalStatusItem: Identifiable, Equatable {
    let iconName: String
    let label: String
    let value: String
    let tone: OperationalStatusTone

    var id: String {
        "\(label)-\(value)"
    }
}

struct OperationalStatusRail: View {
    let items: [OperationalStatusItem]
    let accent: Color

    var body: some View {
        if !items.isEmpty {
            SystemStatusRail(items: items, accent: accent)
            .background(
                LinearGradient(
                    colors: [
                        ColorTheme.background.opacity(0.9),
                        ColorTheme.background.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(ColorTheme.hairline)
                            .frame(height: 1)
                    }
            )
        }
    }
}

struct SystemStatusRail: View {
    let items: [OperationalStatusItem]
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasRevealed = false

    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RediSpacing.compact) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        SystemStatusChip(item: item, accent: accent)
                            .rediStaggeredReveal(index: index, isVisible: hasRevealed)
                    }
                }
                .padding(.horizontal, RediSpacing.screen)
                .padding(.vertical, RediSpacing.compact)
            }
            .scrollIndicators(.hidden)
            .onAppear(perform: triggerReveal)
            .onChange(of: items.map(\.id)) { _, _ in
                triggerReveal()
            }
        }
    }

    private func triggerReveal() {
        guard !reduceMotion else {
            hasRevealed = true
            return
        }

        hasRevealed = false
        DispatchQueue.main.async {
            hasRevealed = true
        }
    }
}

private struct SystemStatusChip: View {
    let item: OperationalStatusItem
    let accent: Color

    var body: some View {
        let toneColor = color(for: item.tone)
        let atmosphere = item.tone == .neutral ? accent.opacity(0.12) : toneColor.opacity(0.16)

        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(toneColor.opacity(0.14))
                    .frame(width: 34, height: 34)

                RediIcon(item.iconName)
                    .foregroundStyle(toneColor)
                    .frame(width: 16, height: 16)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.label.uppercased())
                    .font(RediTypography.metadata)
                    .foregroundStyle(ColorTheme.textFaint)
                    .lineLimit(1)
                Text(item.value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTheme.text)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
            .background(
            PremiumSurfaceBackground(
                cornerRadius: 20,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: atmosphere
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .modifier(
            PremiumSurfaceChrome(
                cornerRadius: 20,
                edgeColor: toneColor.opacity(0.18),
                shadowColor: toneColor.opacity(0.08)
            )
        )
    }

    private func color(for tone: OperationalStatusTone) -> Color {
        switch tone {
        case .ready:
            ColorTheme.ready
        case .info:
            ColorTheme.statusInfo
        case .caution:
            ColorTheme.statusWarning
        case .danger:
            ColorTheme.statusDanger
        case .neutral:
            ColorTheme.textFaint
        }
    }
}

struct ReadinessMeter: View {
    let value: Double
    let tint: Color
    var height: CGFloat = 10
    var backgroundTint: Color = ColorTheme.dividerStrong

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedValue: Double = 0

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let fillWidth = proxy.size.width * displayedValue

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(backgroundTint.opacity(0.72))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.78),
                                tint,
                                tint.opacity(0.84)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(fillWidth, displayedValue > 0.02 ? height : 0), alignment: .leading)
                    .overlay(alignment: .trailing) {
                        if displayedValue > 0 {
                            Circle()
                                .fill(tint.opacity(0.34))
                                .frame(width: height * 2.4, height: height * 2.4)
                                .blur(radius: height)
                                .offset(x: height * 0.24)
                        }
                    }

                Capsule()
                    .fill(ColorTheme.glassHighlight.opacity(0.4))
                    .frame(height: max(1, height * 0.34))
                    .padding(.horizontal, 1)
                    .padding(.top, 1)
                    .blendMode(.screen)
                    .opacity(0.75)
            }
        }
        .frame(height: height)
        .onAppear {
            updateDisplayedValue(initial: true)
        }
        .onChange(of: clampedValue) { _, _ in
            updateDisplayedValue(initial: false)
        }
    }

    private func updateDisplayedValue(initial: Bool) {
        guard !reduceMotion else {
            displayedValue = clampedValue
            return
        }

        if initial {
            displayedValue = 0
            DispatchQueue.main.async {
                withAnimation(RediMotion.meter) {
                    displayedValue = clampedValue
                }
            }
        } else {
            withAnimation(RediMotion.meter) {
                displayedValue = clampedValue
            }
        }
    }
}

struct ReadinessRing: View {
    let value: Double
    let tint: Color
    let title: String
    let subtitle: String
    var size: CGFloat = 112
    var lineWidth: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedValue: Double = 0

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ColorTheme.dividerStrong.opacity(0.62), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: displayedValue)
                .stroke(
                    AngularGradient(
                        colors: [
                            tint.opacity(0.35),
                            tint,
                            tint.opacity(0.84)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.24), radius: 10, y: 4)

            Circle()
                .fill(tint.opacity(0.12))
                .padding(lineWidth + 8)

            VStack(spacing: 4) {
                Text(title)
                    .font(RediTypography.metricCompact)
                    .foregroundStyle(ColorTheme.text)
                    .contentTransition(.numericText())

                Text(subtitle.uppercased())
                    .font(RediTypography.metadata)
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            updateDisplayedValue(initial: true)
        }
        .onChange(of: clampedValue) { _, _ in
            updateDisplayedValue(initial: false)
        }
    }

    private func updateDisplayedValue(initial: Bool) {
        guard !reduceMotion else {
            displayedValue = clampedValue
            return
        }

        if initial {
            displayedValue = 0
            DispatchQueue.main.async {
                withAnimation(RediMotion.meter) {
                    displayedValue = clampedValue
                }
            }
        } else {
            withAnimation(RediMotion.meter) {
                displayedValue = clampedValue
            }
        }
    }
}

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
        let selectedAccent = items.first(where: { $0.segmentID == selection })?.accent ?? ColorTheme.accent

        HStack(spacing: 10) {
            ForEach(items) { item in
                let isSelected = item.segmentID == selection

                Button {
                    guard selection != item.segmentID else { return }

                    if reduceMotion {
                        selection = item.segmentID
                    } else {
                        withAnimation(RediMotion.selection) {
                            selection = item.segmentID
                        }
                    }
                } label: {
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            item.accent.opacity(0.22),
                                            item.accent.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(item.accent.opacity(0.24), lineWidth: 1)
                                )
                                .matchedGeometryEffect(id: "premiumSegmentSelection", in: selectionNamespace)
                        }

                        HStack(alignment: .center, spacing: 10) {
                            if let iconName = item.iconName {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill((isSelected ? item.accent : ColorTheme.panelRaised).opacity(isSelected ? 0.18 : 0.8))
                                        .frame(width: 34, height: 34)

                                    RediIcon(iconName)
                                        .foregroundStyle(isSelected ? item.accent : ColorTheme.textFaint)
                                        .frame(width: 16, height: 16)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(isSelected ? ColorTheme.text : ColorTheme.textMuted)
                                    .lineLimit(1)

                                if let detail = item.detail {
                                    Text(detail)
                                        .font(RediTypography.metadata)
                                        .foregroundStyle(isSelected ? item.accent : ColorTheme.textFaint)
                                        .lineLimit(1)
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.section,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: selectedAccent.opacity(0.14)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.section, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.section, edgeColor: selectedAccent.opacity(0.12), shadowColor: selectedAccent.opacity(0.06)))
        .animation(reduceMotion ? nil : RediMotion.selection, value: selection)
    }
}

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
            atmosphere: accent.opacity(backgroundAssetName == nil ? 0.24 : 0.16),
            showsBreathing: showsBreathing ?? (backgroundAssetName != nil),
            shimmerColor: shimmerColor,
            backgroundAssetName: backgroundAssetName,
            backgroundImageOffset: backgroundImageOffset
        ) {
            content
        }
    }
}

struct CollapsiblePanelCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let accent: Color
    @Binding var isExpanded: Bool
    private let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        accent: Color = ColorTheme.accent,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        _isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(RediMotion.reveal) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(RediTypography.sectionTitle)
                            .foregroundStyle(ColorTheme.text)

                        if let subtitle {
                            Text(subtitle)
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.textMuted)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .padding(20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .background(ColorTheme.divider)
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .padding(20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.section,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: accent.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.section, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.section))
    }
}

struct ThumbActionDock<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(ColorTheme.hairline)

            content
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [
                            ColorTheme.panel.opacity(0.94),
                            ColorTheme.background.opacity(0.98)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}

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
    @ScaledMetric(relativeTo: .caption2) private var iconSize: CGFloat = 14
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 10.5
    @ScaledMetric(relativeTo: .caption2) private var itemVerticalPadding: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var dockHeight: CGFloat = 62
    @Namespace private var selectionNamespace
    @State private var dockGlowScale: CGFloat = 1
    @State private var dockGlowOpacity: Double = 0.16

    var body: some View {
        let selectedAccent = items.first(where: { $0.dockID == selectedID })?.accent ?? ColorTheme.accent

        return HStack(spacing: items.count > 5 ? 4 : 6) {
            ForEach(items) { item in
                let isSelected = item.dockID == selectedID

                Button {
                    action(item.dockID)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(isSelected ? 0 : 0.018))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(ColorTheme.hairline.opacity(isSelected ? 0 : 0.5), lineWidth: 0.75)
                            )

                        if isSelected {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            item.accent.opacity(0.2),
                                            item.accent.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: item.accent.opacity(0.18), radius: 16, y: 8)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(item.accent.opacity(0.12))
                                        .blur(radius: 16)
                                        .scaleEffect(reduceMotion ? 1 : dockGlowScale)
                                        .opacity(reduceMotion ? 0.14 : dockGlowOpacity)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(item.accent.opacity(0.28), lineWidth: 1)
                                )
                                .matchedGeometryEffect(id: "selectedDockItem", in: selectionNamespace)
                        }

                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(item.accent.opacity(isSelected ? (reduceMotion ? 0.14 : dockGlowOpacity) : 0))
                                    .frame(width: 28, height: 28)
                                    .blur(radius: 9)
                                    .scaleEffect(isSelected ? (reduceMotion ? 1 : 0.92 + ((dockGlowScale - 0.92) * 0.42)) : 0.9)

                                Image(systemName: item.systemImage)
                                    .font(.system(size: iconSize, weight: isSelected ? .bold : .semibold))
                                    .shadow(color: item.accent.opacity(isSelected ? 0.18 : 0), radius: 8, y: 2)
                            }

                            Text(item.title)
                                .font(.system(size: labelSize, weight: isSelected ? .bold : .semibold, design: .rounded))
                                .minimumScaleFactor(0.78)
                                .allowsTightening(true)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                        }
                        .foregroundStyle(isSelected ? ColorTheme.text : ColorTheme.text.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: dockHeight - 16, alignment: .center)
                        .padding(.vertical, itemVerticalPadding)
                        .padding(.horizontal, 4)
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(isSelected ? item.accent : Color.clear)
                                .frame(width: 24, height: 3)
                                .padding(.top, 6)
                        }
                    }
                }
                .buttonStyle(CommandDockButtonStyle())
                .accessibilityLabel(item.title)
            }
        }
        .frame(height: dockHeight, alignment: .center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, items.count > 5 ? 10 : 12)
        .padding(.vertical, RediLayout.commandDockOuterVerticalPadding)
        .background {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: RediRadius.dock, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                ColorTheme.panel.opacity(0.985),
                                ColorTheme.panelRaised.opacity(0.95),
                                ColorTheme.background.opacity(0.98)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Circle()
                    .fill(selectedAccent.opacity(reduceMotion ? 0.16 : dockGlowOpacity))
                    .blur(radius: reduceMotion ? 34 : 40)
                    .frame(width: 180, height: 180)
                    .scaleEffect(reduceMotion ? 1 : dockGlowScale)
                    .offset(y: 36)

                Rectangle()
                    .fill(ColorTheme.glassHighlight.opacity(0.7))
                    .frame(height: 1)

                RoundedRectangle(cornerRadius: RediRadius.dock, style: .continuous)
                    .stroke(ColorTheme.dividerStrong.opacity(1.15), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: RediRadius.dock, style: .continuous))
            .padding(.horizontal, 8)
            .shadow(color: ColorTheme.shadow, radius: 20, y: 12)
            .shadow(color: selectedAccent.opacity(0.08), radius: 28, y: 16)
        }
        .animation(reduceMotion ? nil : RediMotion.selection, value: selectedID)
        .onAppear(perform: triggerGlowPulse)
        .onChange(of: selectedID) { _, _ in
            triggerGlowPulse()
        }
        .dynamicTypeSize(.xSmall ... .large)
    }

    private func triggerGlowPulse() {
        guard !reduceMotion else {
            dockGlowScale = 1
            dockGlowOpacity = 0.16
            return
        }

        dockGlowScale = 0.92
        dockGlowOpacity = 0.08

        withAnimation(.easeOut(duration: 0.42)) {
            dockGlowScale = 1.16
            dockGlowOpacity = 0.22
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            withAnimation(.easeOut(duration: 0.28)) {
                dockGlowScale = 1
                dockGlowOpacity = 0.16
            }
        }
    }
}

private struct CommandDockButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : 1))
            .offset(y: reduceMotion ? 0 : (configuration.isPressed ? 1 : 0))
            .animation(reduceMotion ? nil : RediMotion.press, value: configuration.isPressed)
    }
}

private struct StaggeredRevealModifier: ViewModifier {
    let index: Int
    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || isVisible ? 1 : 0)
            .offset(y: reduceMotion || isVisible ? 0 : 6)
            .scaleEffect(reduceMotion || isVisible ? 1 : 0.985)
            .animation(reduceMotion ? nil : RediMotion.reveal.delay(Double(index) * 0.035), value: isVisible)
    }
}

private extension View {
    func rediStaggeredReveal(index: Int, isVisible: Bool) -> some View {
        modifier(StaggeredRevealModifier(index: index, isVisible: isVisible))
    }
}

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
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.24))

                gridOverlay(in: frame)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(isInstalled ? 0.26 : 0.14))
                    .frame(width: frame.width * CGFloat(widthRatio), height: frame.height * CGFloat(heightRatio))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(accent.opacity(0.42), lineWidth: 1)
                    )
                    .position(x: frame.width / 2, y: frame.height / 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(pack.kind.title.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ColorTheme.textFaint)

                    Text(isInstalled ? "Coverage ready" : "Coverage optional")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isInstalled ? ColorTheme.ready : ColorTheme.textMuted)
                }
                .padding(12)
            }
        }
        .frame(height: 92)
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
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }
}
