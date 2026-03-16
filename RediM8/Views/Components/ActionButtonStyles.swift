import SwiftUI

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RediTypography.button)
            .tracking(0.3)
            .foregroundStyle(ColorTheme.chalk)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, RediSpacing.card)
            .background(
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .fill(ColorTheme.accent)
            )
            .clipShape(RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RediTypography.bodyStrong)
            .foregroundStyle(ColorTheme.text)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, RediSpacing.card)
            .background(
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .fill(ColorTheme.gunmetal)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .stroke(ColorTheme.dividerStrong, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct EmergencyActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RediTypography.button)
            .tracking(0.3)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, RediSpacing.card)
            .background(
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .fill(ColorTheme.danger)
            )
            .clipShape(RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CardPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct TacticalTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(RediTypography.body)
            .foregroundStyle(ColorTheme.text)
            .padding(.horizontal, RediSpacing.content)
            .padding(.vertical, RediSpacing.content)
            .background(
                ColorTheme.fieldBackground,
                in: RoundedRectangle(cornerRadius: RediRadius.field, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.field, style: .continuous)
                    .stroke(ColorTheme.dividerStrong, lineWidth: 0.5)
            )
            .tint(ColorTheme.accent)
    }
}
