import SwiftUI

// MARK: - Command Card

enum RediCommandCardLayout {
    case block
    case rail
}

enum RediCommandCardProminence {
    case neutral
    case accented
    case critical

    func atmosphere(tint: Color, hasImage: Bool, isEnabled: Bool) -> Color { .clear }
    func edgeColor(tint: Color, isEnabled: Bool) -> Color { ColorTheme.divider }
    func shadowColor(tint: Color, isEnabled: Bool) -> Color { .clear }
}

private enum RediCommandCardIcon {
    case system(String)
    case redi(String)
}

struct RediCommandCard: View {
    let title: String
    let detail: String?
    let tint: Color
    let badge: String?
    let prominence: RediCommandCardProminence
    let layout: RediCommandCardLayout
    let isEnabled: Bool
    let backgroundAssetName: String?
    let backgroundImageOffset: CGSize
    let minHeight: CGFloat?

    private let icon: RediCommandCardIcon

    init(
        title: String,
        detail: String? = nil,
        systemImage: String,
        tint: Color,
        badge: String? = nil,
        prominence: RediCommandCardProminence = .neutral,
        layout: RediCommandCardLayout = .block,
        isEnabled: Bool = true,
        backgroundAssetName: String? = nil,
        backgroundImageOffset: CGSize = .zero,
        minHeight: CGFloat? = nil
    ) {
        self.title = title
        self.detail = detail
        self.tint = tint
        self.badge = badge
        self.prominence = prominence
        self.layout = layout
        self.isEnabled = isEnabled
        self.backgroundAssetName = backgroundAssetName
        self.backgroundImageOffset = backgroundImageOffset
        self.minHeight = minHeight
        icon = .system(systemImage)
    }

    init(
        title: String,
        detail: String? = nil,
        iconName: String,
        tint: Color,
        badge: String? = nil,
        prominence: RediCommandCardProminence = .neutral,
        layout: RediCommandCardLayout = .block,
        isEnabled: Bool = true,
        backgroundAssetName: String? = nil,
        backgroundImageOffset: CGSize = .zero,
        minHeight: CGFloat? = nil
    ) {
        self.title = title
        self.detail = detail
        self.tint = tint
        self.badge = badge
        self.prominence = prominence
        self.layout = layout
        self.isEnabled = isEnabled
        self.backgroundAssetName = backgroundAssetName
        self.backgroundImageOffset = backgroundImageOffset
        self.minHeight = minHeight
        icon = .redi(iconName)
    }

    var body: some View {
        let commandHeight = minHeight ?? (layout == .block ? 96 : 64)

        Group {
            switch layout {
            case .block: blockLayout
            case .rail: railLayout
            }
        }
        .padding(RediSpacing.card)
        .frame(maxWidth: .infinity, minHeight: commandHeight, alignment: .leading)
        .background(ColorTheme.graphite)
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(detail ?? "")
    }

    private var blockLayout: some View {
        VStack(alignment: .leading, spacing: RediSpacing.compact) {
            HStack(alignment: .top, spacing: RediSpacing.compact) {
                commandIcon
                Spacer(minLength: 0)
                if let badge, !badge.isEmpty {
                    commandBadge(badge)
                }
            }

            VStack(alignment: .leading, spacing: RediSpacing.micro) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var railLayout: some View {
        HStack(alignment: .center, spacing: RediSpacing.content) {
            commandIcon

            VStack(alignment: .leading, spacing: RediSpacing.micro) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                    .lineLimit(1)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: RediSpacing.compact)

            if let badge, !badge.isEmpty {
                commandBadge(badge)
            }
        }
    }

    private var commandIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                .fill(ColorTheme.gunmetal)
                .frame(width: 36, height: 36)

            RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
                .frame(width: 36, height: 36)

            Group {
                switch icon {
                case let .system(name):
                    Image(systemName: name)
                case let .redi(name):
                    RediIcon(name)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(effectiveTint)
            .frame(width: 16, height: 16)
        }
    }

    private func commandBadge(_ title: String) -> some View {
        Text(title.uppercased())
            .font(RediTypography.label)
            .tracking(1.2)
            .foregroundStyle(effectiveTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(effectiveTint.opacity(0.10), in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                    .stroke(effectiveTint.opacity(0.16), lineWidth: 0.5)
            )
    }

    private var effectiveTint: Color {
        isEnabled ? tint : ColorTheme.textTertiary
    }
}

// MARK: - Panel Card

struct PanelCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let backgroundAssetName: String?
    let backgroundImageOffset: CGSize
    let surfaceImageOpacity: Double
    let surfaceImageBrightness: Double
    let surfaceAtmosphere: Color?
    let surfaceEdgeColor: Color?
    let surfaceShadowColor: Color?
    private let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        backgroundAssetName: String? = nil,
        backgroundImageOffset: CGSize = .zero,
        surfaceImageOpacity: Double = 1,
        surfaceImageBrightness: Double = -0.04,
        surfaceAtmosphere: Color? = nil,
        surfaceEdgeColor: Color? = nil,
        surfaceShadowColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.backgroundAssetName = backgroundAssetName
        self.backgroundImageOffset = backgroundImageOffset
        self.surfaceImageOpacity = surfaceImageOpacity
        self.surfaceImageBrightness = surfaceImageBrightness
        self.surfaceAtmosphere = surfaceAtmosphere
        self.surfaceEdgeColor = surfaceEdgeColor
        self.surfaceShadowColor = surfaceShadowColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RediSpacing.content) {
            if let title {
                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text(title)
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(RediTypography.body)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }
            }

            content
        }
        .padding(RediSpacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
        )
    }
}

// MARK: - Hero Panel

struct HeroPanel<Content: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String
    let iconName: String?
    let accent: Color
    let atmosphere: Color?
    let showsBreathing: Bool
    let shimmerColor: Color?
    let backgroundAssetName: String?
    let backgroundImageOffset: CGSize
    let chromeEdgeColor: Color?
    let chromeShadowColor: Color?
    private let content: Content

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String,
        iconName: String? = nil,
        accent: Color,
        atmosphere: Color? = nil,
        showsBreathing: Bool = false,
        shimmerColor: Color? = nil,
        backgroundAssetName: String? = nil,
        backgroundImageOffset: CGSize = .zero,
        chromeEdgeColor: Color? = nil,
        chromeShadowColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.accent = accent
        self.atmosphere = atmosphere
        self.showsBreathing = showsBreathing
        self.shimmerColor = shimmerColor
        self.backgroundAssetName = backgroundAssetName
        self.backgroundImageOffset = backgroundImageOffset
        self.chromeEdgeColor = chromeEdgeColor
        self.chromeShadowColor = chromeShadowColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RediSpacing.section) {
            HStack(alignment: .top, spacing: RediSpacing.content) {
                if let iconName {
                    ZStack {
                        RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                            .fill(ColorTheme.gunmetal)
                            .frame(width: 48, height: 48)

                        RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                            .stroke(ColorTheme.divider, lineWidth: 0.5)
                            .frame(width: 48, height: 48)

                        RediIcon(iconName)
                            .foregroundStyle(ColorTheme.accent)
                            .frame(width: 20, height: 20)
                    }
                }

                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    if let eyebrow {
                        Text(eyebrow.uppercased())
                            .font(RediTypography.label)
                            .tracking(1.2)
                            .foregroundStyle(accent)
                    }

                    Text(title)
                        .font(RediTypography.display)
                        .foregroundStyle(ColorTheme.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(RediTypography.body)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(RediSpacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTheme.graphite)
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                .stroke(ColorTheme.dividerStrong, lineWidth: 0.5)
        )
    }
}

// MARK: - Legacy Surface Types (no-op for compilation)

struct PremiumSurfaceBackground: View {
    let cornerRadius: CGFloat
    var backgroundAssetName: String? = nil
    var backgroundImageOffset: CGSize = .zero
    var atmosphere: Color = .clear
    var imageOpacity: Double = 1
    var imageTopShadeOpacity: Double = 0
    var imageBottomShadeOpacity: Double = 0
    var brightness: Double = 0
    var glowScale: CGFloat = 1
    var glowOpacity: Double = 1
    var shimmerColor: Color? = nil
    var shimmerPhase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(ColorTheme.panel)
    }
}

struct PremiumSurfaceChrome: ViewModifier {
    let cornerRadius: CGFloat
    var edgeColor: Color = ColorTheme.divider
    var shadowColor: Color = .clear
    var interactionProgress: CGFloat = 0
    var highlightColor: Color = .clear

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ColorTheme.divider, lineWidth: 0.5)
            )
    }
}

// MARK: - Sheet Presentation

extension View {
    func rediSheetPresentation(style: AmbientBackgroundStyle = .neutral, accent: Color = ColorTheme.accent) -> some View {
        self
            .presentationBackground(ColorTheme.background)
            .presentationCornerRadius(RediRadius.hero)
            .presentationDragIndicator(.visible)
    }
}
