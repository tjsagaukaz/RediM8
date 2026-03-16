import SwiftUI
import UIKit

// MARK: - Color Palette

enum ColorTheme {
    // Monochrome scale (dark → light)
    static let nero = Color(hex: "08090A")
    static let charcoal = Color(hex: "111214")
    static let graphite = Color(hex: "1A1C1F")
    static let gunmetal = Color(hex: "252729")
    static let iron = Color(hex: "363839")
    static let pewter = Color(hex: "6B6E72")
    static let silver = Color(hex: "A0A3A8")
    static let chalk = Color(hex: "E8E9EB")

    // Accent: dark cobalt
    static let accent = Color(hex: "2563EB")
    static let accentMuted = accent.opacity(0.4)
    static let focusRing = accent.opacity(0.6)

    // Semantic (status only)
    static let ready = Color(hex: "46A758")
    static let warning = Color(hex: "F5A623")
    static let danger = Color(hex: "E5484D")

    // Derived surface tokens
    static let background = nero
    static let panel = charcoal
    static let panelRaised = graphite
    static let panelElevated = gunmetal
    static let fieldBackground = Color(hex: "0D0E10")

    // Text
    static let text = chalk
    static let textSecondary = silver
    static let textTertiary = pewter

    // Borders
    static let dividerSubtle = Color.white.opacity(0.03)
    static let hairline = Color.white.opacity(0.04)
    static let divider = Color.white.opacity(0.06)
    static let dividerStrong = Color.white.opacity(0.10)

    // Shadow
    static let shadow = Color.black.opacity(0.4)

    // MARK: - Legacy Aliases (migration support)
    // These map old token names to new values so feature views compile
    // during incremental migration. Remove once all views are updated.

    static let obsidian = nero
    static let slate = graphite
    static let steel = gunmetal
    static let smoke = iron
    static let ember = accent
    static let emberSoft = accent
    static let emberDeep = accent
    static let comms = accent
    static let commsDeep = accent
    static let archive = textTertiary
    static let terrain = textTertiary
    static let secure = textTertiary
    static let premium = textSecondary
    static let water = accent
    static let info = accent
    static let accentSoft = accent
    static let accentDeep = accent
    static let textMuted = textSecondary
    static let textFaint = textTertiary
    static let statusWarning = warning
    static let statusInfo = accent
    static let statusDanger = danger
    static let chromeGlow = Color.clear
    static let deepShadow = shadow
    static let glowAmber = Color.clear
    static let glowCyan = Color.clear
    static let glowRed = Color.clear
    static let glassHighlight = Color.clear
    static let glassFill = Color.clear
}

// MARK: - Typography

enum RediTypography {
    // Display & Headings (SF Pro)
    static let display = Font.system(size: 28, weight: .semibold)
    static let heading = Font.system(size: 18, weight: .semibold)
    static let subheading = Font.system(size: 15, weight: .medium)

    // Body (SF Pro)
    static let body = Font.system(size: 15, weight: .regular)
    static let bodyStrong = Font.system(size: 15, weight: .medium)

    // Labels & Captions (SF Pro)
    static let label = Font.system(size: 11, weight: .semibold)
    static let caption = Font.system(size: 12, weight: .medium)

    // Data values (SF Mono)
    static let data = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let dataLarge = Font.system(size: 22, weight: .semibold, design: .monospaced)
    static let dataHero = Font.system(size: 36, weight: .bold, design: .monospaced)

    // Button (SF Pro)
    static let button = Font.system(size: 15, weight: .semibold)

    // MARK: - Legacy Aliases
    static let screenTitle = display
    static let screenSubtitle = Font.system(size: 17, weight: .semibold)
    static let sectionTitle = heading
    static let sectionEyebrow = label
    static let bodyCompact = bodyStrong
    static let heroTitle = display
    static let heroSubtitle = body
    static let emergencyValue = dataLarge
    static let metric = dataHero
    static let metricHero = dataHero
    static let metricCompact = dataLarge
    static let metadata = caption
}

// MARK: - Spacing

enum RediSpacing {
    static let screen: CGFloat = 16
    static let section: CGFloat = 14
    static let card: CGFloat = 14
    static let content: CGFloat = 12
    static let compact: CGFloat = 8
    static let tight: CGFloat = 6
    static let micro: CGFloat = 4
}

// MARK: - Radius

enum RediRadius {
    static let hero: CGFloat = 10
    static let card: CGFloat = 8
    static let section: CGFloat = 8
    static let dock: CGFloat = 0
    static let button: CGFloat = 6
    static let chip: CGFloat = 4
    static let field: CGFloat = 6
}

// MARK: - Layout

enum RediLayout {
    static let commandDockContentInset: CGFloat = 72
    static let commandDockOuterVerticalPadding: CGFloat = 0
    static let situationHeaderHeight: CGFloat = 32
}

// MARK: - Motion (functional only)

enum RediMotion {
    static let press = Animation.easeOut(duration: 0.1)
    static let selection = Animation.easeInOut(duration: 0.15)
    static let reveal = Animation.easeIn(duration: 0.12)
    static let meter = Animation.easeOut(duration: 0.4)

    // Legacy aliases (no-op — these should not animate)
    static let breathe = Animation.easeInOut(duration: 0)
    static let pulse = Animation.easeInOut(duration: 0)
    static let shimmer = Animation.linear(duration: 0)
    static let ambient = Animation.easeInOut(duration: 0)
}

// MARK: - Haptics

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

// MARK: - Ambient Background (stripped — flat color only)

enum AmbientBackgroundStyle {
    case home, ask, plan, vault, library, map, signal, more, pro, neutral
}

struct AmbientBackground: View {
    let style: AmbientBackgroundStyle

    var body: some View {
        ColorTheme.background
            .ignoresSafeArea()
    }
}

// MARK: - Color Hex Init

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
