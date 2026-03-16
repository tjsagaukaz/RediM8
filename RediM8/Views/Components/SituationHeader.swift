import SwiftUI

/// Persistent 32px global status strip — command systems show state at all times.
/// Pinned at top of every screen, below safe area.
struct SituationHeader: View {
    @ObservedObject var appState: AppState
    let isEmergencyActive: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RediSpacing.content) {
                headerItem(label: "REDIM8", value: "")
                    .foregroundStyle(ColorTheme.accent)

                headerDivider

                headerItem(label: "STATUS", value: statusValue, color: statusColor)

                headerDivider

                headerItem(label: "WATER", value: waterValue)

                headerDivider

                headerItem(label: "POWER", value: powerValue)

                headerDivider

                headerItem(label: "THREAT", value: threatValue, color: threatColor)
            }
            .padding(.horizontal, RediSpacing.screen)
        }
        .scrollIndicators(.hidden)
        .frame(height: RediLayout.situationHeaderHeight)
        .background(ColorTheme.charcoal)
        .background(isEmergencyActive ? ColorTheme.danger.opacity(0.06) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isEmergencyActive ? ColorTheme.danger.opacity(0.3) : ColorTheme.divider)
                .frame(height: 0.5)
        }
    }

    private func headerItem(label: String, value: String, color: Color = ColorTheme.text) -> some View {
        HStack(spacing: RediSpacing.micro) {
            Text(label)
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)

            if !value.isEmpty {
                Text(value)
                    .font(RediTypography.data)
                    .foregroundStyle(color)
            }
        }
    }

    private var headerDivider: some View {
        Rectangle()
            .fill(ColorTheme.divider)
            .frame(width: 0.5, height: 16)
    }

    // MARK: - Computed Values

    private var statusValue: String {
        isEmergencyActive ? "EMERGENCY" : "READY"
    }

    private var statusColor: Color {
        isEmergencyActive ? ColorTheme.danger : ColorTheme.ready
    }

    private var waterValue: String {
        let estimate = appState.waterRuntimeService.estimate(
            for: appState.profile,
            scenarios: appState.scenarioEngine.selectedScenarios(for: appState.profile.selectedScenarios)
        )
        let days = Int(estimate.estimatedDays)
        return days > 0 ? "\(days)D" : "--"
    }

    private var powerValue: String {
        appState.batteryStatus.percentageText
    }

    private var threatValue: String {
        if isEmergencyActive { return "CRITICAL" }
        let alertCount = appState.officialAlertService.library.alerts.count
        if alertCount > 0 { return "WARNING" }
        return "LOW"
    }

    private var threatColor: Color {
        if isEmergencyActive { return ColorTheme.danger }
        let alertCount = appState.officialAlertService.library.alerts.count
        if alertCount > 0 { return ColorTheme.warning }
        return ColorTheme.ready
    }
}
