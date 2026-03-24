import SwiftUI

/// Displays a freshness indicator for bundled offline data.
/// Shows nothing when data is current. Shows increasingly prominent
/// warnings as data ages past its expected update cycle.
struct DataFreshnessIndicator: View {
    let freshness: DataFreshness
    let lastUpdated: Date
    var impactMessage: String?

    var body: some View {
        if freshness.shouldWarn {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: freshness == .outdated ? "exclamationmark.triangle.fill" : "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(iconColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(freshness.label.uppercased())
                        .font(RediTypography.label)
                        .tracking(1.0)
                        .foregroundStyle(iconColor)

                    if let impact = impactMessage, freshness.shouldWarn {
                        Text(impact)
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.textSecondary)
                    } else if let warning = freshness.warningText {
                        Text(warning)
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }

                    Text("Last updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
            }
            .padding(RediSpacing.content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(iconColor.opacity(0.08), in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        }
    }

    private var iconColor: Color {
        switch freshness {
        case .current, .aging: ColorTheme.textTertiary
        case .stale: ColorTheme.warning
        case .outdated: ColorTheme.danger
        }
    }
}

/// Compact inline freshness badge for list rows.
struct DataFreshnessBadge: View {
    let freshness: DataFreshness

    var body: some View {
        if freshness.shouldWarn {
            Text(freshness.label.uppercased())
                .font(RediTypography.label)
                .tracking(1.0)
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(badgeColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private var badgeColor: Color {
        freshness == .outdated ? ColorTheme.danger : ColorTheme.warning
    }
}
