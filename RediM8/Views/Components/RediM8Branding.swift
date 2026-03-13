import SwiftUI

struct RediM8BrandMark: View {
    let size: CGFloat
    var monochrome: Bool = true

    var body: some View {
        Image("brand_mark")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .saturation(monochrome ? 0 : 1)
            .brightness(monochrome ? 0.08 : 0)
            .contrast(monochrome ? 1.08 : 1)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                    .stroke(ColorTheme.dividerStrong, lineWidth: 1)
            )
            .shadow(color: ColorTheme.shadow, radius: 16, y: 8)
            .accessibilityHidden(true)
    }
}

struct RediM8Wordmark: View {
    let iconSize: CGFloat
    let titleFont: Font
    var titleColor: Color = ColorTheme.text
    var subtitle: String? = nil
    var subtitleColor: Color = ColorTheme.textMuted
    var monochromeMark: Bool = true

    var body: some View {
        let accessibilityText = subtitle.map { "RediM8, \($0)" } ?? "RediM8"

        HStack(spacing: 10) {
            RediM8BrandMark(size: iconSize, monochrome: monochromeMark)

            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text("RediM8")
                    .font(titleFont)
                    .foregroundStyle(titleColor)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(subtitleColor)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}
