import SwiftUI

extension View {
    func tacticalSurface(
        tint: Color = ColorTheme.divider,
        cornerRadius: CGFloat = RediRadius.card,
        fillOpacity: Double = 1,
        strokeOpacity: Double = 1,
        strokeWidth: CGFloat = 0.5
    ) -> some View {
        self
            .background(
                ColorTheme.panel,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ColorTheme.divider, lineWidth: strokeWidth)
            )
    }

    func tacticalHazardSurface(
        tint: Color = ColorTheme.danger,
        cornerRadius: CGFloat = RediRadius.chip,
        isHazard: Bool = false
    ) -> some View {
        self
            .background(
                ColorTheme.panel,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isHazard ? ColorTheme.danger.opacity(0.3) : ColorTheme.divider,
                        lineWidth: isHazard ? 1 : 0.5
                    )
            )
    }
}
