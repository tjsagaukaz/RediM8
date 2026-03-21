import SwiftUI

struct PlanCapsuleBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title.uppercased())
            .font(RediTypography.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

struct PlanReadinessSummary<Badge: View>: View {
    let value: Double
    let tint: Color
    let title: String
    let subtitle: String
    let summaryTitle: String
    let summaryDetail: String
    let supportingLine: String
    private let badge: Badge

    init(
        value: Double,
        tint: Color,
        title: String,
        subtitle: String,
        summaryTitle: String,
        summaryDetail: String,
        supportingLine: String,
        @ViewBuilder badge: () -> Badge
    ) {
        self.value = value
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.summaryTitle = summaryTitle
        self.summaryDetail = summaryDetail
        self.supportingLine = supportingLine
        self.badge = badge()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                ring(size: 116, lineWidth: 12)
                summaryTextBlock
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    ring(size: 104, lineWidth: 11)
                    summaryTextBlock
                }
            }
        }
    }

    private func ring(size: CGFloat, lineWidth: CGFloat) -> some View {
        ReadinessRing(
            value: value,
            tint: tint,
            title: title,
            subtitle: subtitle,
            size: size,
            lineWidth: lineWidth
        )
    }

    private var summaryTextBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            badge

            Text(summaryTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(ColorTheme.text)

            Text(summaryDetail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textSecondary)

            ReadinessMeter(value: value, tint: tint, height: 12)

            Text(supportingLine)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PlanFocusCard: View {
    let eyebrow: String
    let iconName: String
    let title: String
    let detail: String
    let emphasis: String
    let secondaryEmphasis: String?
    let supporting: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 48, height: 48)

                    RediIcon(iconName)
                        .foregroundStyle(tint)
                        .frame(width: 20, height: 20)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow.uppercased())
                        .font(RediTypography.caption)
                        .foregroundStyle(tint)

                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(ColorTheme.text)
                }

                Spacer(minLength: 0)

                PlanCapsuleBadge(title: emphasis, tint: tint)
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textSecondary)

            HStack(spacing: 8) {
                PlanCapsuleBadge(title: emphasis, tint: tint)
                if let secondaryEmphasis {
                    PlanCapsuleBadge(title: secondaryEmphasis, tint: ColorTheme.textTertiary)
                }
            }

            Text(supporting)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.textTertiary)
        }
        .padding(16)
        .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous))
    }
}

struct PlanHeroMetricTile: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .lineLimit(1)

            Text(detail)
                .font(.caption)
                .foregroundStyle(tint)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(14)
        .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
    }
}

struct PlanReadinessBreakdownRow: View {
    let categoryScore: CategoryScore
    let tint: Color
    let severity: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 40, height: 40)

                RediIcon(categoryScore.category.systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 18, height: 18)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(categoryScore.category.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ColorTheme.text)

                    PlanCapsuleBadge(title: severity, tint: tint)

                    Spacer(minLength: 0)

                    Text("\(categoryScore.score)%")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint)
                }

                ReadinessMeter(
                    value: Double(categoryScore.score) / 100,
                    tint: tint,
                    height: 8
                )
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
    }
}
