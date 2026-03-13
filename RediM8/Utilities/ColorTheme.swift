import SwiftUI
import UIKit

enum ColorTheme {
    static let obsidian = Color(hex: "07090C")
    static let graphite = Color(hex: "111418")
    static let slate = Color(hex: "171C21")
    static let steel = Color(hex: "20262D")
    static let smoke = Color(hex: "2C343D")
    static let ember = Color(hex: "F6A623")
    static let emberSoft = Color(hex: "FFBF5F")
    static let emberDeep = Color(hex: "C87516")
    static let comms = Color(hex: "73D6FF")
    static let commsDeep = Color(hex: "0F86C7")
    static let archive = Color(hex: "93B7C7")
    static let terrain = Color(hex: "7DA49A")
    static let secure = Color(hex: "D6A45B")
    static let premium = Color(hex: "C2CFDA")
    static let background = obsidian
    static let panel = graphite
    static let panelRaised = slate
    static let panelElevated = steel
    static let fieldBackground = Color(hex: "0D1014")
    static let divider = Color.white.opacity(0.08)
    static let dividerStrong = Color.white.opacity(0.14)
    static let text = Color(hex: "F7F8FA")
    static let textMuted = Color(hex: "AEB6C0")
    static let textFaint = Color(hex: "77818D")
    static let accent = ember
    static let accentSoft = emberSoft
    static let accentDeep = emberDeep
    static let ready = Color(hex: "58D775")
    static let warning = Color(hex: "FFD15C")
    static let danger = Color(hex: "FF5D52")
    static let info = comms
    static let water = Color(hex: "49A9FF")
    static let statusWarning = warning
    static let statusInfo = info
    static let statusDanger = danger
    static let hairline = Color.white.opacity(0.06)
    static let chromeGlow = Color.white.opacity(0.05)
    static let shadow = Color.black.opacity(0.5)
    static let deepShadow = Color.black.opacity(0.68)
    static let glowAmber = accent.opacity(0.3)
    static let glowCyan = info.opacity(0.28)
    static let glowRed = danger.opacity(0.24)
    static let glassHighlight = Color.white.opacity(0.1)
    static let glassFill = Color.white.opacity(0.04)
}

enum RediTypography {
    static let screenTitle = Font.system(size: 32, weight: .black, design: .rounded)
    static let screenSubtitle = Font.system(size: 17, weight: .semibold)
    static let sectionTitle = Font.system(size: 20, weight: .semibold)
    static let sectionEyebrow = Font.system(size: 12, weight: .bold, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular)
    static let bodyStrong = Font.system(size: 16, weight: .medium)
    static let bodyCompact = Font.system(size: 15, weight: .medium)
    static let button = Font.system(size: 22, weight: .bold)
    static let heroTitle = Font.system(size: 32, weight: .black, design: .rounded)
    static let heroSubtitle = Font.system(size: 16, weight: .medium)
    static let emergencyValue = Font.system(size: 30, weight: .bold)
    static let metric = Font.system(size: 56, weight: .black, design: .rounded)
    static let metricHero = Font.system(size: 64, weight: .black, design: .rounded)
    static let metricCompact = Font.system(size: 34, weight: .bold)
    static let caption = Font.system(size: 13, weight: .semibold, design: .rounded)
    static let metadata = Font.system(size: 12, weight: .semibold, design: .rounded)
}

enum RediSpacing {
    static let screen: CGFloat = 20
    static let section: CGFloat = 18
    static let card: CGFloat = 22
    static let content: CGFloat = 16
    static let compact: CGFloat = 12
    static let tight: CGFloat = 8
    static let micro: CGFloat = 6
}

enum RediRadius {
    static let hero: CGFloat = 30
    static let card: CGFloat = 28
    static let section: CGFloat = 24
    static let dock: CGFloat = 30
    static let button: CGFloat = 20
    static let chip: CGFloat = 16
    static let field: CGFloat = 18
}

enum RediLayout {
    static let commandDockContentInset: CGFloat = 120
    static let commandDockOuterVerticalPadding: CGFloat = 8
}

enum RediMotion {
    static let press = Animation.spring(response: 0.24, dampingFraction: 0.82)
    static let selection = Animation.spring(response: 0.34, dampingFraction: 0.84)
    static let reveal = Animation.easeInOut(duration: 0.22)
    static let meter = Animation.spring(response: 0.72, dampingFraction: 0.9)
    static let breathe = Animation.easeInOut(duration: 4.8).repeatForever(autoreverses: true)
    static let pulse = Animation.easeInOut(duration: 2.6).repeatForever(autoreverses: true)
    static let shimmer = Animation.linear(duration: 2.8).repeatForever(autoreverses: false)
    static let ambient = Animation.easeInOut(duration: 22).repeatForever(autoreverses: true)
}

enum RediHaptics {
    static func selection(enabled: Bool = true) {
        trigger(enabled: enabled) {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
    }

    static func softImpact(enabled: Bool = true) {
        trigger(enabled: enabled) {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: 0.78)
        }
    }

    static func success(enabled: Bool = true) {
        trigger(enabled: enabled) {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }

    static func warning(enabled: Bool = true) {
        trigger(enabled: enabled) {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
        }
    }

    static func emergency(enabled: Bool = true) {
        trigger(enabled: enabled) {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            generator.impactOccurred(intensity: 0.92)
        }
    }

    private static func trigger(enabled: Bool, _ action: @escaping @MainActor () -> Void) {
        guard enabled, !ProcessInfo.processInfo.isiOSAppOnMac else { return }

        Task { @MainActor in
            action()
        }
    }
}

enum AmbientBackgroundStyle {
    case home
    case plan
    case vault
    case library
    case map
    case signal
    case pro
    case neutral
}

struct AmbientBackground: View {
    let style: AmbientBackgroundStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatePrimary = false
    @State private var animateSecondary = false

    var body: some View {
        GeometryReader { proxy in
            let palette = palette(for: style)

            ZStack {
                LinearGradient(
                    colors: palette.base,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LinearGradient(
                    colors: [
                        palette.edge.opacity(0.26),
                        .clear,
                        Color.black.opacity(0.32)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.02),
                                .clear,
                                palette.texture.opacity(0.12),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)

                ambientBloom(
                    color: palette.primaryBloom,
                    size: CGSize(width: proxy.size.width * 0.9, height: proxy.size.width * 0.9),
                    alignment: .topLeading,
                    restOffset: CGSize(width: -proxy.size.width * 0.18, height: -120),
                    animatedOffset: CGSize(width: -proxy.size.width * 0.06, height: -40),
                    blurRadius: 120,
                    isAnimating: animatePrimary
                )

                ambientBloom(
                    color: palette.secondaryBloom,
                    size: CGSize(width: proxy.size.width * 0.75, height: proxy.size.width * 0.75),
                    alignment: .bottomTrailing,
                    restOffset: CGSize(width: proxy.size.width * 0.18, height: 130),
                    animatedOffset: CGSize(width: proxy.size.width * 0.04, height: 40),
                    blurRadius: 130,
                    isAnimating: animateSecondary
                )

                RadialGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(0.12),
                        Color.black.opacity(0.34)
                    ],
                    center: .center,
                    startRadius: 80,
                    endRadius: max(proxy.size.width, proxy.size.height)
                )
            }
            .ignoresSafeArea()
        }
        .onAppear {
            guard !reduceMotion else { return }

            withAnimation(RediMotion.ambient) {
                animatePrimary.toggle()
            }

            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                animateSecondary.toggle()
            }
        }
    }

    @ViewBuilder
    private func ambientBloom(
        color: Color,
        size: CGSize,
        alignment: Alignment,
        restOffset: CGSize,
        animatedOffset: CGSize,
        blurRadius: CGFloat,
        isAnimating: Bool
    ) -> some View {
        Circle()
            .fill(color)
            .frame(width: size.width, height: size.height)
            .blur(radius: blurRadius)
            .opacity(0.92)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .offset(
                x: reduceMotion ? restOffset.width : (isAnimating ? animatedOffset.width : restOffset.width),
                y: reduceMotion ? restOffset.height : (isAnimating ? animatedOffset.height : restOffset.height)
            )
    }

    private func palette(for style: AmbientBackgroundStyle) -> (
        base: [Color],
        primaryBloom: Color,
        secondaryBloom: Color,
        texture: Color,
        edge: Color
    ) {
        switch style {
        case .home:
            (
                [ColorTheme.obsidian, ColorTheme.graphite, Color(hex: "14100B")],
                ColorTheme.accent.opacity(0.26),
                ColorTheme.warning.opacity(0.16),
                ColorTheme.accentSoft,
                ColorTheme.accent
            )
        case .plan:
            (
                [ColorTheme.obsidian, ColorTheme.graphite, Color(hex: "121314")],
                ColorTheme.accent.opacity(0.14),
                Color.white.opacity(0.06),
                ColorTheme.premium,
                ColorTheme.smoke
            )
        case .vault:
            (
                [ColorTheme.obsidian, Color(hex: "101114"), Color(hex: "17120D")],
                ColorTheme.secure.opacity(0.18),
                ColorTheme.accent.opacity(0.12),
                ColorTheme.secure,
                ColorTheme.secure
            )
        case .library:
            (
                [ColorTheme.obsidian, Color(hex: "0E1418"), Color(hex: "151B20")],
                ColorTheme.archive.opacity(0.18),
                ColorTheme.info.opacity(0.12),
                ColorTheme.archive,
                ColorTheme.archive
            )
        case .map:
            (
                [ColorTheme.obsidian, Color(hex: "0C1414"), Color(hex: "121713")],
                ColorTheme.terrain.opacity(0.16),
                ColorTheme.info.opacity(0.1),
                ColorTheme.terrain,
                ColorTheme.terrain
            )
        case .signal:
            (
                [ColorTheme.obsidian, Color(hex: "081216"), Color(hex: "11171B")],
                ColorTheme.comms.opacity(0.2),
                ColorTheme.commsDeep.opacity(0.12),
                ColorTheme.comms,
                ColorTheme.comms
            )
        case .pro:
            (
                [ColorTheme.obsidian, Color(hex: "141112"), Color(hex: "1A120B")],
                ColorTheme.warning.opacity(0.22),
                ColorTheme.danger.opacity(0.16),
                ColorTheme.warning,
                ColorTheme.danger
            )
        case .neutral:
            (
                [ColorTheme.obsidian, ColorTheme.graphite, ColorTheme.slate],
                Color.white.opacity(0.08),
                ColorTheme.premium.opacity(0.08),
                ColorTheme.premium,
                ColorTheme.smoke
            )
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
