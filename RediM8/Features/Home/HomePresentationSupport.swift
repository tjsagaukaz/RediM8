import SwiftUI

extension HomeView {
    var shouldShowOperationalInsights: Bool {
        !viewModel.forgottenItems.isEmpty || viewModel.shouldShowExpiryReminders || viewModel.shouldShowWaterSourceGuidance
    }

    func scoreValue(for category: PrepCategory) -> Int {
        viewModel.prepScore.categoryScores.first(where: { $0.category == category })?.score ?? viewModel.prepScore.overall
    }

    func readinessColor(for score: Int) -> Color {
        switch score {
        case ..<34:
            ColorTheme.danger
        case 34..<67:
            ColorTheme.warning
        default:
            ColorTheme.ready
        }
    }

    func bushfireToneColor(_ tone: BushfireStatusRow.Tone) -> Color {
        switch tone {
        case .ready:
            ColorTheme.ready
        case .warning:
            ColorTheme.warning
        }
    }

    func officialAlertToneColor(_ tone: OfficialAlertStatusTone) -> Color {
        switch tone {
        case .ready:
            ColorTheme.ready
        case .info:
            ColorTheme.accent
        case .caution:
            ColorTheme.warning
        case .danger:
            ColorTheme.danger
        }
    }

    func operationalTone(for tone: OfficialAlertStatusTone) -> OperationalStatusTone {
        switch tone {
        case .ready:
            .ready
        case .info:
            .info
        case .caution:
            .caution
        case .danger:
            .danger
        }
    }

    func metricStatus(for color: Color) -> MetricStatus {
        if color == ColorTheme.ready { return .ready }
        if color == ColorTheme.warning { return .warning }
        if color == ColorTheme.danger { return .danger }
        return .normal
    }

    func alertMetricStatus(_ tone: OfficialAlertStatusTone) -> MetricStatus {
        switch tone {
        case .ready: .ready
        case .info: .normal
        case .caution: .warning
        case .danger: .danger
        }
    }
}

private struct HomeInsetSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ColorTheme.graphite)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ColorTheme.divider, lineWidth: 0.5)
            )
    }
}

extension View {
    func homeInsetSurface(cornerRadius: CGFloat) -> some View {
        modifier(HomeInsetSurfaceModifier(cornerRadius: cornerRadius))
    }
}
