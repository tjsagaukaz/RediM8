import SwiftUI

// MARK: - Procedural Diagram Strip

/// Displays the procedural step diagrams for a guide.
/// Each step gets its own visual panel with title, focus label, and rendered diagram.
struct ProceduralDiagramStrip: View {
    let guideID: String
    let accent: Color

    var body: some View {
        if let steps = ProceduralDiagramRegistry.steps(for: guideID) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(steps) { step in
                    StepDiagramContainer(
                        stepNumber: step.stepIndex + 1,
                        title: step.title,
                        focusLabel: step.focusLabel,
                        accent: accent
                    ) {
                        diagramContent(for: step)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func diagramContent(for step: ProceduralDiagramStep) -> some View {
        switch guideID {
        case "bow_drill_fire":
            BowDrillDiagrams.view(for: step, accent: accent)
        case "debris_hut_shelter":
            DebrisHutDiagrams.view(for: step, accent: accent)
        case "solar_still_construction":
            SolarStillDiagrams.view(for: step, accent: accent)
        case "basic_snares_small_game":
            SnareDiagrams.view(for: step, accent: accent)
        case "waste_disposal_distance_rules":
            WasteDisposalDiagrams.view(for: step, accent: accent)
        default:
            EmptyView()
        }
    }
}

// MARK: - Inline Step Diagram

/// Shows a single procedural diagram inline with a specific step.
/// Used in field mode when viewing individual steps.
struct InlineStepDiagram: View {
    let guideID: String
    let stepIndex: Int
    let accent: Color

    var body: some View {
        if let steps = ProceduralDiagramRegistry.steps(for: guideID),
           let step = steps.first(where: { $0.stepIndex == stepIndex }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(accent.opacity(0.6))

                    Text(step.title.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(accent.opacity(0.6))

                    Spacer(minLength: 0)

                    Text(step.focusLabel)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ColorTheme.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(accent.opacity(0.06))

                diagramContent(for: step)
                    .frame(height: 180)
                    .padding(6)
            }
            .background(ColorTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(accent.opacity(0.12), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private func diagramContent(for step: ProceduralDiagramStep) -> some View {
        switch guideID {
        case "bow_drill_fire":
            BowDrillDiagrams.view(for: step, accent: accent)
        case "debris_hut_shelter":
            DebrisHutDiagrams.view(for: step, accent: accent)
        case "solar_still_construction":
            SolarStillDiagrams.view(for: step, accent: accent)
        case "basic_snares_small_game":
            SnareDiagrams.view(for: step, accent: accent)
        case "waste_disposal_distance_rules":
            WasteDisposalDiagrams.view(for: step, accent: accent)
        default:
            EmptyView()
        }
    }
}
