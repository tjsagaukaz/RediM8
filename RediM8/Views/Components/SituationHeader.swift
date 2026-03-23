import SwiftUI

/// Persistent 32px global status strip — command systems show state at all times.
/// Pinned at top of every screen, below safe area.
struct SituationHeader: View {
    @ObservedObject var appState: AppState
    let isEmergencyActive: Bool

    @State private var isShowingSystemDetail = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RediSpacing.content) {
                systemConfidenceItem

                headerDivider

                headerItem(label: "STATUS", value: statusValue, color: statusColor)

                headerDivider

                headerItem(label: "THREAT", value: threatValue, color: threatColor)

                headerDivider

                headerItem(label: "WATER", value: waterValue)

                headerDivider

                headerItem(label: "POWER", value: powerValue)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.isEmpty ? label : "\(label): \(value)")
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

    // MARK: - System Confidence

    private var systemConfidenceResult: SystemConfidenceResult {
        SystemConfidenceResult.evaluate(appState: appState)
    }

    private var systemConfidenceColor: Color {
        switch systemConfidenceResult.confidence {
        case .high: ColorTheme.ready
        case .limited: ColorTheme.warning
        case .degraded: ColorTheme.danger
        }
    }

    private var systemConfidenceItem: some View {
        Button {
            if systemConfidenceResult.confidence != .high {
                isShowingSystemDetail.toggle()
            }
        } label: {
            HStack(spacing: RediSpacing.micro) {
                Text("SYS")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(ColorTheme.textTertiary)

                Text(systemConfidenceResult.confidence.label.uppercased())
                    .font(RediTypography.data)
                    .foregroundStyle(systemConfidenceColor)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("System confidence: \(systemConfidenceResult.confidence.label)")
        .accessibilityHint(systemConfidenceResult.confidence != .high ? "Tap for details" : "")
        .popover(isPresented: $isShowingSystemDetail, arrowEdge: .top) {
            systemConfidencePopover
        }
    }

    private var systemConfidencePopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(systemConfidenceColor)
                    .frame(width: 8, height: 8)
                Text("System \(systemConfidenceResult.confidence.label)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ColorTheme.text)
            }

            ForEach(systemConfidenceResult.reasons, id: \.self) { reason in
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(systemConfidenceColor)
                    Text(reason)
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .frame(minWidth: 180)
        .background(ColorTheme.charcoal)
        .presentationCompactAdaptation(.popover)
    }
}

// MARK: - System Confidence Model

/// App-wide trust indicator derived from subsystem health.
/// HIGH = all critical systems operational.
/// LIMITED = some degradation (no GPS, stale data, no mesh).
/// DEGRADED = multiple critical systems unavailable.
enum SystemConfidence {
    case high
    case limited
    case degraded

    var label: String {
        switch self {
        case .high: "High"
        case .limited: "Limited"
        case .degraded: "Degraded"
        }
    }
}

/// Result of evaluating system confidence — includes the level AND specific reasons.
struct SystemConfidenceResult {
    let confidence: SystemConfidence
    let reasons: [String]

    var summary: String {
        if reasons.isEmpty { return "All systems operational" }
        return reasons.joined(separator: " · ")
    }

    /// Evaluates current system health from AppState subsystems.
    @MainActor static func evaluate(appState: AppState) -> SystemConfidenceResult {
        var reasons: [String] = []

        // GPS availability
        if appState.signal.locationService.currentLocation == nil {
            reasons.append("GPS unavailable")
        }

        // Battery critical
        if let level = appState.batteryStatus.level, level < 0.1 {
            reasons.append("Battery critical")
        }

        // Mesh connectivity
        if appState.signal.meshService.connectedPeers.isEmpty {
            reasons.append("No mesh peers")
        }

        let confidence: SystemConfidence = switch reasons.count {
        case 0: .high
        case 1: .limited
        default: .degraded
        }

        return SystemConfidenceResult(confidence: confidence, reasons: reasons)
    }
}
