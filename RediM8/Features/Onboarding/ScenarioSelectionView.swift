import SwiftUI

struct ScenarioSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var selectedScenarioNames: [String] {
        viewModel.selectedScenarioModels.map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModeHeroCard(
                eyebrow: "Risks",
                title: "Pick the situations you actually plan for.",
                subtitle: "Choose all that apply. RediM8 will use this to tune targets, guides, and emergency shortcuts.",
                iconName: "situation",
                accent: ColorTheme.textTertiary,
                backgroundAssetName: "community_storm_town",
                backgroundImageOffset: CGSize(width: 10, height: 0)
            ) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "All that apply", tone: .verified),
                    TrustPillItem(title: "General fallback", tone: .neutral),
                    TrustPillItem(title: "Editable later", tone: .info)
                ])
            }

            PanelCard(
                title: "Selected",
                subtitle: selectedScenarioNames.isEmpty ? "General emergencies will stay as the baseline." : "Your current setup focus."
            ) {
                if selectedScenarioNames.isEmpty {
                    Text("General emergencies")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTheme.text)
                } else {
                    TrustPillGroup(items: selectedScenarioNames.map { TrustPillItem(title: $0, tone: .info) })
                }

                if let highlighted = viewModel.highlightedPrioritySituation {
                    Text("\(highlighted.title) will be pushed closer to the front in emergency flows.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textMuted)
                        .padding(.top, 6)
                }
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.availableScenarios) { scenario in
                    scenarioCard(scenario)
                }
            }

            Text("Leave it broad if you are unsure. You can tune this again later.")
                .font(.caption)
                .foregroundStyle(ColorTheme.textFaint)
        }
    }

    private func scenarioCard(_ scenario: PrepScenario) -> some View {
        let isSelected = viewModel.selectedScenarios.contains(scenario.kind)
        let tint = scenarioAccent(for: scenario.kind)

        return Button {
            viewModel.toggle(scenario.kind)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    scenarioBadge(for: scenario.kind)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(ColorTheme.background)
                    }
                }

                Text(scenario.name)
                    .font(.headline)
                    .foregroundStyle(isSelected ? Color.black : ColorTheme.text)

                Text(scenario.description)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.black.opacity(0.75) : ColorTheme.textMuted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Text(scenarioFooter(for: scenario.kind))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.78) : tint)
                    .lineLimit(2)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
            .background(
                isSelected ? tint : ColorTheme.panelRaised,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? Color.clear : tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func scenarioBadge(for scenario: ScenarioKind) -> some View {
        HStack(spacing: 6) {
            Image(systemName: scenarioSymbol(for: scenario))
                .font(.system(size: 13, weight: .semibold))
            Text(scenarioTag(for: scenario))
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(ColorTheme.background)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(scenarioAccent(for: scenario), in: Capsule())
    }

    private func scenarioSymbol(for scenario: ScenarioKind) -> String {
        switch scenario {
        case .bushfires:
            "flame.fill"
        case .floods:
            "drop.fill"
        case .cyclones:
            "wind"
        case .powerOutages, .extendedInfrastructureDisruption:
            "bolt.slash.fill"
        case .extremeHeat:
            "sun.max.fill"
        case .fuelShortages:
            "fuelpump.fill"
        case .remoteTravel:
            "car.fill"
        case .campingOffGrid:
            "tent.fill"
        case .severeStorm:
            "cloud.bolt.rain.fill"
        case .earthquake:
            "waveform.path.ecg.rectangle.fill"
        case .generalEmergencies:
            "shield.fill"
        }
    }

    private func scenarioTag(for scenario: ScenarioKind) -> String {
        switch scenario {
        case .bushfires, .floods, .powerOutages, .remoteTravel:
            "Priority"
        case .generalEmergencies:
            "Fallback"
        default:
            "Scenario"
        }
    }

    private func scenarioAccent(for scenario: ScenarioKind) -> Color {
        switch scenario {
        case .bushfires:
            ColorTheme.danger
        case .floods, .cyclones:
            ColorTheme.info
        case .powerOutages, .extendedInfrastructureDisruption:
            ColorTheme.warning
        case .remoteTravel, .campingOffGrid:
            Color(hex: "73D13D")
        case .generalEmergencies:
            ColorTheme.accent
        case .extremeHeat, .fuelShortages, .severeStorm, .earthquake:
            Color(hex: "B68CFF")
        }
    }

    private func scenarioFooter(for scenario: ScenarioKind) -> String {
        switch scenario {
        case .bushfires:
            "Leave now and route focus"
        case .floods:
            "Movement and shelter focus"
        case .powerOutages:
            "Battery and blackout focus"
        case .remoteTravel:
            "Vehicle, fuel, and water focus"
        case .generalEmergencies:
            "Safe default baseline"
        default:
            "Adjusts targets and guides"
        }
    }
}
