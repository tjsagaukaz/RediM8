import SwiftUI

struct GoBagView: View {
    @ObservedObject var viewModel: GoBagViewModel
    @State private var isShowingEvacuationCheck = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PanelCard(
                    title: "Evacuation Bag Readiness",
                    subtitle: "Pack the essentials before you need to leave",
                    backgroundAssetName: "gobag_loadout",
                    backgroundImageOffset: CGSize(width: -26, height: 0)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .bottom, spacing: 12) {
                                gobagReadinessHeadline
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                gobagReadinessHeadline
                            }
                        }

                        Text("\(viewModel.plan.readiness.completedCount) / \(viewModel.plan.readiness.totalCount) items complete")
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)

                        ReadinessMeter(
                            value: viewModel.plan.readiness.progress,
                            tint: viewModel.plan.readiness.percentage >= 67 ? ColorTheme.ready : ColorTheme.warning,
                            height: 11
                        )

                        Text("Evacuation prep score: \(viewModel.evacuationPrepScore)%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !viewModel.plan.scenarioTitles.isEmpty {
                            tagWrap(items: viewModel.plan.scenarioTitles)
                        }

                        if !viewModel.plan.contextLines.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(viewModel.plan.contextLines.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if !viewModel.plan.nextActions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Pack next")
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)

                                ForEach(Array(viewModel.plan.nextActions.enumerated()), id: \.offset) { _, action in
                                    Text(action)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Button("Start Evacuation Check") {
                            isShowingEvacuationCheck = true
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }
                }

                ForEach(viewModel.plan.categories) { category in
                    PanelCard(title: category.title) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(category.items) { item in
                                Button {
                                    viewModel.setItemComplete(item.id, isComplete: !viewModel.isItemComplete(item.id))
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: viewModel.isItemComplete(item.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(viewModel.isItemComplete(item.id) ? ColorTheme.ready : ColorTheme.divider)

                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack {
                                                Text(item.title)
                                                    .font(.headline)
                                                    .foregroundStyle(ColorTheme.text)
                                                if item.isScenarioSpecific {
                                                    Text("Scenario")
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundStyle(ColorTheme.warning)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(ColorTheme.warning.opacity(0.14), in: Capsule())
                                                }
                                            }

                                            Text(item.detail)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)

                                            if let supportingText = item.supportingText {
                                                Text(supportingText)
                                                    .font(.caption)
                                                    .foregroundStyle(ColorTheme.info)
                                            }
                                        }

                                        Spacer(minLength: 0)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(viewModel.isItemComplete(item.id) ? ColorTheme.ready.opacity(0.45) : ColorTheme.divider, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(CardPressButtonStyle())
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Go Bag")
        .background(ColorTheme.background.ignoresSafeArea())
        .sheet(isPresented: $isShowingEvacuationCheck) {
            NavigationStack {
                GoBagEvacuationView(plan: viewModel.plan, isBlackoutMode: false)
            }
            .rediSheetPresentation(style: .plan, accent: ColorTheme.warning)
        }
    }

    @ViewBuilder
    private func tagWrap(items: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.info)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTheme.info.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var gobagReadinessHeadline: some View {
        Group {
            Text(viewModel.plan.readiness.percentage.percentageText)
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(ColorTheme.text)
                .minimumScaleFactor(0.78)
                .lineLimit(1)

            Text("Ready")
                .font(.headline.weight(.semibold))
                .foregroundStyle(viewModel.plan.readiness.percentage >= 67 ? ColorTheme.ready : ColorTheme.warning)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    (viewModel.plan.readiness.percentage >= 67 ? ColorTheme.ready : ColorTheme.warning)
                        .opacity(0.16),
                    in: Capsule()
                )
        }
    }
}

struct GoBagEvacuationView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: GoBagPlan
    let isBlackoutMode: Bool

    @State private var currentStepIndex = 0
    @State private var completedStepIDs = Set<String>()

    private var steps: [GoBagEvacuationStep] {
        plan.evacuationChecklist
    }

    private var currentStep: GoBagEvacuationStep? {
        guard steps.indices.contains(currentStepIndex) else {
            return nil
        }

        return steps[currentStepIndex]
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isBlackoutMode ? "Blackout Go Bag" : "Evacuation Check")
                            .font(.system(size: isBlackoutMode ? 30 : 24, weight: .bold))
                            .foregroundStyle(ColorTheme.text)
                        Text("Pack status: \(plan.readiness.completedCount) / \(plan.readiness.totalCount) items ready")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .frame(width: 110)
                }

                if let currentStep {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Step \(currentStepIndex + 1) of \(steps.count)")
                            .font(.headline)
                            .foregroundStyle(ColorTheme.info)

                        Text(currentStep.title)
                            .font(.system(size: isBlackoutMode ? 34 : 28, weight: .bold))
                            .foregroundStyle(ColorTheme.text)

                        Text(currentStep.detail)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)

                        if !plan.nextActions.isEmpty && currentStepIndex == 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Still missing")
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)

                                ForEach(Array(plan.nextActions.enumerated()), id: \.offset) { _, action in
                                    Text(action)
                                        .font(.subheadline)
                                        .foregroundStyle(ColorTheme.warning)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(ColorTheme.divider, lineWidth: 1)
                    )

                    Spacer(minLength: 0)

                    VStack(spacing: 14) {
                        largeActionButton(title: "Done", background: ColorTheme.ready) {
                            completedStepIDs.insert(currentStep.id)
                            advanceStep()
                        }

                        largeActionButton(title: "Skip", background: ColorTheme.panel) {
                            advanceStep()
                        }
                    }
                } else {
                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Checklist Complete")
                            .font(.system(size: isBlackoutMode ? 34 : 28, weight: .bold))
                            .foregroundStyle(ColorTheme.text)
                        Text("\(completedStepIDs.count) of \(steps.count) steps checked off.")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)

                        if !plan.nextActions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Pack next when safe")
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)

                                ForEach(Array(plan.nextActions.enumerated()), id: \.offset) { _, action in
                                    Text(action)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(ColorTheme.divider, lineWidth: 1)
                    )

                    Spacer(minLength: 0)

                    VStack(spacing: 14) {
                        largeActionButton(title: "Run Again", background: ColorTheme.info) {
                            currentStepIndex = 0
                            completedStepIDs = []
                        }

                        largeActionButton(title: "Close", background: ColorTheme.panel) {
                            dismiss()
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ColorTheme.background)
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
    }

    private func advanceStep() {
        currentStepIndex += 1
    }

    private func largeActionButton(title: String, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: isBlackoutMode ? 24 : 20, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: isBlackoutMode ? 74 : 64)
                .foregroundStyle(ColorTheme.text)
                .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(CardPressButtonStyle())
    }

}
