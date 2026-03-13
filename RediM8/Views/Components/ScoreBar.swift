import SwiftUI

struct ScoreBar: View {
    let score: CategoryScore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(score.category.title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                Spacer()
                Text(score.score.percentageText)
                    .font(RediTypography.caption)
                    .foregroundStyle(color)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(ColorTheme.panelElevated)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.84), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * CGFloat(score.score) / 100)
                }
            }
            .frame(height: 12)
        }
    }

    private var color: Color {
        switch score.score {
        case ..<34:
            ColorTheme.danger
        case 34..<67:
            ColorTheme.warning
        default:
            ColorTheme.ready
        }
    }
}
