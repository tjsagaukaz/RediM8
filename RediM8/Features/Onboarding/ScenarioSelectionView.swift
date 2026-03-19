import SwiftUI

struct ScenarioSelectionView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var viewModel: OnboardingViewModel

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible(), spacing: 12)]
        } else {
            [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
        }
    }

    private var selectedScenarioNames: [String] {
        viewModel.selectedScenarioModels.map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModeHeroCard(
                eyebrow: "Operational Context",
                title: "Select the situations you need to be ready for.",
                subtitle: "Choose all that apply. RediM8 will configure guidance, targets, maps, and emergency shortcuts accordingly.",
                iconName: "situation",
                accent: ColorTheme.textTertiary,
                backgroundAssetName: "community_storm_town",
                backgroundImageOffset: CGSize(width: 10, height: 0)
            ) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Multi-select", tone: .verified),
                    TrustPillItem(title: "Baseline retained", tone: .neutral),
                    TrustPillItem(title: "Editable later", tone: .info)
                ])
            }

            PanelCard(
                title: "Current Baseline",
                subtitle: selectedScenarioNames.isEmpty ? "General emergency readiness remains active." : "Selected contexts are now driving the initial system profile."
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

            Text("If you are unsure, keep it broad. Refine the system later from Home.")
                .font(.caption)
                .foregroundStyle(ColorTheme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
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
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(ColorTheme.background)
                    }
                }

                Text(scenario.name)
                    .font(.headline)
                    .foregroundStyle(isSelected ? Color.black : ColorTheme.text)

                Text(scenario.description)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? Color.black.opacity(0.75) : ColorTheme.textMuted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("PRIMARY FOCUS")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(isSelected ? Color.black.opacity(0.65) : ColorTheme.textTertiary)

                    Text(scenarioFooter(for: scenario.kind))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.black.opacity(0.8) : tint)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
            .frame(
                maxWidth: .infinity,
                minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 136,
                alignment: .leading
            )
            .background(
                isSelected ? tint : ColorTheme.panelRaised,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.clear : tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(scenario.name). \(scenario.description)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("\(scenarioFooter(for: scenario.kind)). Double-tap to \(isSelected ? "remove" : "add") this scenario.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func scenarioBadge(for scenario: ScenarioKind) -> some View {
        HStack(spacing: 6) {
            Image(systemName: scenarioSymbol(for: scenario))
                .font(.footnote.weight(.semibold))
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
            "CRITICAL"
        case .generalEmergencies:
            "BASELINE"
        default:
            "CONTEXT"
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
            "Immediate movement and route execution"
        case .floods:
            "Movement away from water and shelter access"
        case .powerOutages:
            "Power reserve, lighting, and blackout continuity"
        case .remoteTravel:
            "Vehicle movement, fuel, water, and extraction options"
        case .generalEmergencies:
            "Core household readiness and fallback actions"
        default:
            "Guides, targets, and shortcut priorities"
        }
    }
}
