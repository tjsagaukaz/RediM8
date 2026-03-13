import SwiftUI

struct ScenarioSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModeHeroCard(
                eyebrow: "Risk Profile",
                title: "Tell RediM8 what to prioritize.",
                subtitle: "Choose the situations you’re actually likely to face. RediM8 will use them to tune targets, Priority Mode, map emphasis, and the kinds of gaps it surfaces first.",
                iconName: "situation",
                accent: ColorTheme.warning
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    TrustPillGroup(items: [
                        TrustPillItem(title: "All that apply", tone: .verified),
                        TrustPillItem(title: "General fallback", tone: .neutral),
                        TrustPillItem(title: "Priority tuned", tone: .info)
                    ])

                    if let highlighted = viewModel.highlightedPrioritySituation {
                        HStack(alignment: .top, spacing: 12) {
                            RediIcon(highlighted.systemImage)
                                .foregroundStyle(ColorTheme.warning)
                                .frame(width: 22, height: 22)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(highlighted.title) will be surfaced first")
                                    .font(RediTypography.bodyStrong)
                                    .foregroundStyle(ColorTheme.text)
                                Text(priorityCopy(for: highlighted))
                                    .font(.subheadline)
                                    .foregroundStyle(ColorTheme.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } else {
                        Text("If you’re unsure, keep a general emergency baseline and you can refine it later.")
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textMuted)
                    }
                }
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.availableScenarios) { scenario in
                    Button {
                        viewModel.toggle(scenario.kind)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                scenarioBadge(for: scenario.kind)
                                Spacer()
                                if viewModel.selectedScenarios.contains(scenario.kind) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(ColorTheme.background)
                                }
                            }

                            Text(scenario.name)
                                .font(.headline)
                                .foregroundStyle(viewModel.selectedScenarios.contains(scenario.kind) ? Color.black : ColorTheme.text)

                            Text(scenario.description)
                                .font(.caption)
                                .foregroundStyle(viewModel.selectedScenarios.contains(scenario.kind) ? Color.black.opacity(0.75) : ColorTheme.textMuted)
                                .multilineTextAlignment(.leading)

                            Text(scenarioFooter(for: scenario.kind))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(viewModel.selectedScenarios.contains(scenario.kind) ? Color.black.opacity(0.78) : ColorTheme.info)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 152, alignment: .leading)
                        .background(
                            viewModel.selectedScenarios.contains(scenario.kind)
                                ? scenarioAccent(for: scenario.kind)
                                : ColorTheme.panelRaised,
                            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(viewModel.selectedScenarios.contains(scenario.kind) ? Color.clear : scenarioAccent(for: scenario.kind).opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            PanelCard(title: "How Selection Works", subtitle: "Calm defaults when you’re not sure") {
                VStack(alignment: .leading, spacing: 10) {
                    infoLine("You can select more than one situation if your risks overlap.")
                    infoLine("General Emergency stays as the fallback when nothing else is selected.")
                    infoLine("You can rerun onboarding later from Home if seasons or travel plans change.")
                }
            }
        }
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
            "Priority Mode"
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
            "Faster Leave Now, shelters, and route emphasis"
        case .floods:
            "Higher-ground movement and shelter emphasis"
        case .powerOutages:
            "Battery, low-draw, and blackout emphasis"
        case .remoteTravel:
            "Vehicle kit, fuel, and water emphasis"
        case .generalEmergencies:
            "Safe default if you’re not sure yet"
        default:
            "Adjusts targets, tasks, and guides"
        }
    }

    private func priorityCopy(for situation: PrioritySituation) -> String {
        switch situation {
        case .bushfire:
            "Leave Now, evacuation routes, shelters, and grab-folder prompts will move closer to the front."
        case .flood:
            "Movement, shelter context, and route checking will be emphasized earlier."
        case .blackout:
            "Battery preservation, torch access, and reduced-motion tools will matter more."
        case .remoteTravel:
            "Vehicle readiness, water, fuel, and offline navigation will carry more weight."
        }
    }

    private func infoLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ColorTheme.ready)
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 2)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)
        }
    }
}
