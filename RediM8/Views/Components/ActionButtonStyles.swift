import SwiftUI

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RediTypography.button)
            .foregroundStyle(ColorTheme.text)
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 18)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(ColorTheme.panelElevated)
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: configuration.isPressed
                                    ? [ColorTheme.accent.opacity(0.38), ColorTheme.accentDeep.opacity(0.28)]
                                    : [ColorTheme.accent.opacity(0.26), ColorTheme.accentDeep.opacity(0.16)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ColorTheme.glassHighlight, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .stroke(configuration.isPressed ? ColorTheme.accentSoft : ColorTheme.accent.opacity(0.52), lineWidth: 1.2)
            )
            .shadow(color: ColorTheme.glowAmber.opacity(configuration.isPressed ? 0.18 : 0.26), radius: 20, y: 10)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1))
            .offset(y: reduceMotion ? 0 : (configuration.isPressed ? 1 : 0))
            .animation(reduceMotion ? nil : RediMotion.press, value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RediTypography.bodyStrong)
            .foregroundStyle(configuration.isPressed ? ColorTheme.accentSoft : ColorTheme.text)
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 18)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ColorTheme.panelElevated.opacity(configuration.isPressed ? 1 : 0.98),
                                    ColorTheme.panelRaised.opacity(configuration.isPressed ? 1 : 0.92)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(ColorTheme.accent.opacity(configuration.isPressed ? 0.1 : 0.02))
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ColorTheme.glassHighlight.opacity(0.8), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .stroke(configuration.isPressed ? ColorTheme.accent.opacity(0.52) : ColorTheme.dividerStrong, lineWidth: 1.2)
            )
            .shadow(color: ColorTheme.shadow.opacity(configuration.isPressed ? 0.16 : 0.08), radius: configuration.isPressed ? 14 : 8, y: configuration.isPressed ? 8 : 4)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.988 : 1))
            .offset(y: reduceMotion ? 0 : (configuration.isPressed ? 1 : 0))
            .animation(reduceMotion ? nil : RediMotion.press, value: configuration.isPressed)
    }
}

struct EmergencyActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RediTypography.button)
            .foregroundStyle(ColorTheme.text)
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 18)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(ColorTheme.panelElevated)
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: configuration.isPressed
                                    ? [ColorTheme.danger.opacity(0.42), ColorTheme.danger.opacity(0.3)]
                                    : [ColorTheme.danger.opacity(0.3), ColorTheme.danger.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ColorTheme.glassHighlight.opacity(0.72), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .stroke(configuration.isPressed ? ColorTheme.danger : ColorTheme.danger.opacity(0.54), lineWidth: 1.2)
            )
            .shadow(color: ColorTheme.glowRed.opacity(configuration.isPressed ? 0.18 : 0.26), radius: 24, y: 12)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1))
            .offset(y: reduceMotion ? 0 : (configuration.isPressed ? 1 : 0))
            .animation(reduceMotion ? nil : RediMotion.press, value: configuration.isPressed)
    }
}

struct CardPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.988 : 1))
            .offset(y: reduceMotion ? 0 : (configuration.isPressed ? 1 : 0))
            .shadow(
                color: ColorTheme.shadow.opacity(reduceMotion ? 0 : (configuration.isPressed ? 0.18 : 0.06)),
                radius: configuration.isPressed ? 14 : 6,
                y: configuration.isPressed ? 8 : 3
            )
            .animation(reduceMotion ? nil : RediMotion.press, value: configuration.isPressed)
    }
}

struct TacticalTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(RediTypography.body)
            .foregroundStyle(ColorTheme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [ColorTheme.fieldBackground, ColorTheme.panel],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: RediRadius.field, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.field, style: .continuous)
                    .stroke(ColorTheme.dividerStrong, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.field, style: .continuous)
                    .stroke(ColorTheme.hairline, lineWidth: 1)
                    .blur(radius: 0.4)
            )
            .tint(ColorTheme.accent)
    }
}
