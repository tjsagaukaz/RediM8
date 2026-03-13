import SwiftUI

struct PanelCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let backgroundAssetName: String?
    let backgroundImageOffset: CGSize
    private let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        backgroundAssetName: String? = nil,
        backgroundImageOffset: CGSize = .zero,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.backgroundAssetName = backgroundAssetName
        self.backgroundImageOffset = backgroundImageOffset
        self.content = content()
    }

    var body: some View {
        let cornerRadius = RediRadius.card

        return VStack(alignment: .leading, spacing: RediSpacing.content) {
            if let title {
                VStack(alignment: .leading, spacing: RediSpacing.micro) {
                    Text(title)
                        .font(RediTypography.sectionTitle)
                        .foregroundStyle(ColorTheme.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(RediTypography.bodyCompact)
                            .foregroundStyle(ColorTheme.textMuted)
                    }
                }
            }

            content
        }
        .padding(RediSpacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: cornerRadius,
                backgroundAssetName: backgroundAssetName,
                backgroundImageOffset: backgroundImageOffset,
                atmosphere: backgroundAssetName == nil ? ColorTheme.accent.opacity(0.08) : ColorTheme.premium.opacity(0.1)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: cornerRadius))
    }
}

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
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false
    @State private var shimmerPhase: CGFloat = -0.24

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
        self.content = content()
    }

    var body: some View {
        let cornerRadius = RediRadius.hero

        return VStack(alignment: .leading, spacing: RediSpacing.section) {
            HStack(alignment: .top, spacing: RediSpacing.content) {
                if let iconName {
                    ZStack {
                        RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        ColorTheme.panelElevated.opacity(0.96),
                                        accent.opacity(0.14)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)

                        RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                            .stroke(accent.opacity(0.3), lineWidth: 1)
                            .frame(width: 64, height: 64)

                        RediIcon(iconName)
                            .foregroundStyle(accent)
                            .frame(width: 28, height: 28)
                    }
                }

                VStack(alignment: .leading, spacing: RediSpacing.tight) {
                    if let eyebrow {
                        Text(eyebrow.uppercased())
                            .font(RediTypography.sectionEyebrow)
                            .foregroundStyle(accent)
                    }

                    Text(title)
                        .font(RediTypography.heroTitle)
                        .foregroundStyle(ColorTheme.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(RediTypography.heroSubtitle)
                        .foregroundStyle(ColorTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(RediSpacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: cornerRadius,
                backgroundAssetName: backgroundAssetName,
                backgroundImageOffset: backgroundImageOffset,
                atmosphere: atmosphere ?? accent.opacity(backgroundAssetName == nil ? 0.24 : 0.16),
                imageTopShadeOpacity: 0.32,
                imageBottomShadeOpacity: 0.8,
                brightness: -0.03,
                glowScale: reduceMotion || !showsBreathing ? 1 : (isBreathing ? 1.04 : 0.98),
                glowOpacity: reduceMotion || !showsBreathing ? 0.94 : (isBreathing ? 0.96 : 0.84),
                shimmerColor: shimmerColor,
                shimmerPhase: shimmerPhase
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: cornerRadius, edgeColor: accent.opacity(0.16), shadowColor: accent.opacity(0.1)))
        .onAppear(perform: startHeroMotion)
        .onChange(of: showsBreathing) { _, _ in
            startHeroMotion()
        }
        .onChange(of: shimmerColor != nil) { _, _ in
            startHeroMotion()
        }
    }

    private func startHeroMotion() {
        if showsBreathing && !reduceMotion {
            withAnimation(RediMotion.breathe) {
                isBreathing = true
            }
        } else {
            isBreathing = false
        }

        guard shimmerColor != nil else { return }

        if reduceMotion {
            shimmerPhase = -0.2
            return
        }

        shimmerPhase = -1.05
        withAnimation(RediMotion.shimmer) {
            shimmerPhase = 1.1
        }
    }
}

struct PremiumSurfaceBackground: View {
    let cornerRadius: CGFloat
    let backgroundAssetName: String?
    let backgroundImageOffset: CGSize
    let atmosphere: Color
    var imageTopShadeOpacity: Double = 0.28
    var imageBottomShadeOpacity: Double = 0.76
    var brightness: Double = -0.04
    var glowScale: CGFloat = 1
    var glowOpacity: Double = 0.92
    var shimmerColor: Color? = nil
    var shimmerPhase: CGFloat = -0.2

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ColorTheme.panelElevated.opacity(0.96),
                            ColorTheme.panelRaised.opacity(0.94),
                            ColorTheme.panel.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let backgroundAssetName {
                GeometryReader { proxy in
                    Image(backgroundAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(1.05)
                        .offset(backgroundImageOffset)
                        .saturation(0.92)
                        .contrast(1.04)
                        .brightness(brightness)
                        .overlay {
                            ZStack {
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(imageTopShadeOpacity),
                                        Color.black.opacity(0.52),
                                        Color.black.opacity(imageBottomShadeOpacity)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )

                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.52),
                                        Color.clear,
                                        Color.black.opacity(0.34)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )

                                RadialGradient(
                                    colors: [
                                        Color.clear,
                                        Color.black.opacity(0.12),
                                        Color.black.opacity(0.34)
                                    ],
                                    center: .center,
                                    startRadius: 36,
                                    endRadius: max(proxy.size.width, proxy.size.height)
                                )
                            }
                        }
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }

            Circle()
                .fill(atmosphere)
                .blur(radius: 48)
                .frame(width: 220, height: 220)
                .offset(x: 88, y: -90)
                .scaleEffect(glowScale)
                .opacity(glowOpacity)

            if let shimmerColor {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [
                            .clear,
                            shimmerColor.opacity(0.02),
                            shimmerColor.opacity(0.28),
                            shimmerColor.opacity(0.02),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: proxy.size.width * 0.44, height: proxy.size.height * 1.8)
                    .rotationEffect(.degrees(-18))
                    .blur(radius: 5)
                    .offset(
                        x: proxy.size.width * shimmerPhase,
                        y: -proxy.size.height * 0.12
                    )
                    .blendMode(.screen)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ColorTheme.glassHighlight,
                            Color.clear,
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}

struct PremiumSurfaceChrome: ViewModifier {
    let cornerRadius: CGFloat
    var edgeColor: Color = ColorTheme.dividerStrong
    var shadowColor: Color = ColorTheme.shadow

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(edgeColor, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ColorTheme.hairline, lineWidth: 1)
                    .blur(radius: 0.6)
            )
            .shadow(color: shadowColor, radius: 24, y: 12)
            .shadow(color: ColorTheme.deepShadow.opacity(0.36), radius: 48, y: 24)
    }
}

private struct PremiumModalBackdrop: View {
    let style: AmbientBackgroundStyle
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLit = false

    var body: some View {
        ZStack {
            AmbientBackground(style: style)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.03),
                    .clear,
                    Color.black.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(accent.opacity(isLit ? 0.14 : 0.08))
                .blur(radius: isLit ? 64 : 44)
                .frame(width: 260, height: 260)
                .offset(x: 0, y: -170)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(ColorTheme.glassHighlight.opacity(0.7))
                    .frame(height: 1)
                Spacer()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else {
                isLit = false
                return
            }

            withAnimation(RediMotion.breathe) {
                isLit = true
            }
        }
    }
}

private struct PremiumSheetPresentationModifier: ViewModifier {
    let style: AmbientBackgroundStyle
    let accent: Color

    func body(content: Content) -> some View {
        content
            .background {
                PremiumModalBackdrop(style: style, accent: accent)
            }
            .presentationBackground(.clear)
            .presentationCornerRadius(RediRadius.hero)
            .presentationDragIndicator(.visible)
    }
}

extension View {
    func rediSheetPresentation(style: AmbientBackgroundStyle, accent: Color) -> some View {
        modifier(PremiumSheetPresentationModifier(style: style, accent: accent))
    }
}
