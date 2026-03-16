import SwiftUI

struct GoBagView: View {
    @ObservedObject var viewModel: GoBagViewModel
    @State private var isShowingEvacuationCheck = false
    @State private var selectedCategoryID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CinematicBanner("gobag_loadout", height: 160)

                PanelCard(
                    title: "Evacuation Bag Readiness",
                    subtitle: "Pack the essentials before you need to leave",
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

                        Text("\(viewModel.plan.readiness.completedCount) / \(viewModel.plan.readiness.totalCount) items packed")
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

                        if !viewModel.plan.nextActions.isEmpty {
                            checklistPreviewCard(
                                title: "Next 3 items",
                                items: viewModel.plan.nextActions,
                                tint: ColorTheme.warning
                            )
                        }

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

                        Button("Start Evacuation Check") {
                            isShowingEvacuationCheck = true
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }
                }

                SystemStatusRail(items: goBagStatusItems, accent: ColorTheme.textTertiary)

                if immediateMissingItems.isEmpty {
                    PanelCard(title: "Departure Ready", subtitle: "The bag is covered. Use the evacuation check when it is time to move.") {
                        Text("All tracked go-bag items are marked complete. Run the evacuation check for a fast final confirmation.")
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                } else {
                    PanelCard(title: "Missing Now", subtitle: "Pack these blockers first before browsing the full bag by section.") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(immediateMissingItems) { item in
                                goBagItemButton(item, emphasizeMissing: true)
                            }
                        }
                    }
                }

                PanelCard(title: "Bag Sections", subtitle: "Open one section at a time so the bag reads like a staged loadout instead of a single long list.") {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(viewModel.plan.categories) { category in
                            categoryButton(category)
                        }
                    }
                }

                if let selectedCategory {
                    PanelCard(
                        title: selectedCategory.title,
                        subtitle: categoryMissingCount(selectedCategory) == 0
                            ? "This section is packed."
                            : "\(categoryMissingCount(selectedCategory)) item\(categoryMissingCount(selectedCategory) == 1 ? "" : "s") still open in this section."
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(selectedCategory.items) { item in
                                goBagItemButton(item, emphasizeMissing: !viewModel.isItemComplete(item.id))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Go Bag")
        .background(ColorTheme.background.ignoresSafeArea())
        .onAppear {
            selectDefaultCategoryIfNeeded()
        }
        .onChange(of: viewModel.plan.readiness.completedCount) { _, _ in
            selectDefaultCategoryIfNeeded()
        }
        .sheet(isPresented: $isShowingEvacuationCheck) {
            NavigationStack {
                GoBagEvacuationView(plan: viewModel.plan, isBlackoutMode: false)
            }
            .rediSheetPresentation()
        }
    }

    private var goBagStatusItems: [OperationalStatusItem] {
        [
            OperationalStatusItem(
                iconName: "go_bag",
                label: "Ready",
                value: viewModel.plan.readiness.percentage.percentageText,
                tone: viewModel.plan.readiness.percentage >= 67 ? .ready : .caution
            ),
            OperationalStatusItem(
                iconName: "warning",
                label: "Missing",
                value: "\(immediateMissingItems.count == missingItems.count ? missingItems.count : immediateMissingItems.count)+",
                tone: missingItems.isEmpty ? .ready : .caution
            ),
            OperationalStatusItem(
                iconName: "signal",
                label: "Scenario Items",
                value: "\(scenarioSpecificMissingCount)",
                tone: scenarioSpecificMissingCount == 0 ? .neutral : .info
            )
        ]
    }

    private var missingItems: [GoBagItem] {
        viewModel.plan.categories
            .flatMap(\.items)
            .filter { !viewModel.isItemComplete($0.id) }
    }

    private var immediateMissingItems: [GoBagItem] {
        Array(missingItems.prefix(4))
    }

    private var scenarioSpecificMissingCount: Int {
        missingItems.filter(\.isScenarioSpecific).count
    }

    private var selectedCategory: GoBagCategory? {
        if let selectedCategoryID,
           let category = viewModel.plan.categories.first(where: { $0.id == selectedCategoryID }) {
            return category
        }

        return viewModel.plan.categories.first
    }

    private func selectDefaultCategoryIfNeeded() {
        guard !viewModel.plan.categories.isEmpty else {
            selectedCategoryID = nil
            return
        }

        if let selectedCategoryID,
           viewModel.plan.categories.contains(where: { $0.id == selectedCategoryID }) {
            return
        }

        selectedCategoryID = viewModel.plan.categories
            .sorted { lhs, rhs in
                let lhsMissing = categoryMissingCount(lhs)
                let rhsMissing = categoryMissingCount(rhs)
                if lhsMissing != rhsMissing {
                    return lhsMissing > rhsMissing
                }
                return lhs.title < rhs.title
            }
            .first?
            .id
    }

    private func categoryMissingCount(_ category: GoBagCategory) -> Int {
        category.items.filter { !viewModel.isItemComplete($0.id) }.count
    }

    private func categoryButton(_ category: GoBagCategory) -> some View {
        let isSelected = category.id == selectedCategoryID
        let missingCount = categoryMissingCount(category)
        let completedCount = category.items.count - missingCount
        let completionPercentage = category.items.isEmpty ? 0 : Int((Double(completedCount) / Double(category.items.count) * 100).rounded())

        return Button {
            selectedCategoryID = category.id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(category.title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Text(missingCount == 0 ? "100% complete" : "\(completedCount)/\(category.items.count) complete")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(missingCount == 0 ? ColorTheme.ready : ColorTheme.warning)
                }

                ReadinessMeter(
                    value: category.items.isEmpty ? 0 : Double(category.items.count - missingCount) / Double(category.items.count),
                    tint: missingCount == 0 ? ColorTheme.ready : ColorTheme.warning,
                    height: 8
                )

                Text("\(completionPercentage)% ready")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .background(
                (isSelected ? ColorTheme.accent.opacity(0.16) : Color.black.opacity(0.22)),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke((isSelected ? ColorTheme.accent : ColorTheme.dividerStrong).opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func goBagItemButton(_ item: GoBagItem, emphasizeMissing: Bool) -> some View {
        let isComplete = viewModel.isItemComplete(item.id)

        return Button {
            viewModel.setItemComplete(item.id, isComplete: !isComplete)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isComplete ? ColorTheme.ready : (emphasizeMissing ? ColorTheme.warning : ColorTheme.divider))

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)
                        if item.isScenarioSpecific {
                            Text("Scenario")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ColorTheme.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ColorTheme.textTertiary.opacity(0.14), in: Capsule())
                        }
                    }

                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let supportingText = item.supportingText {
                        Text(supportingText)
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (isComplete ? ColorTheme.ready.opacity(0.08) : (emphasizeMissing ? ColorTheme.warning.opacity(0.08) : Color.black.opacity(0.2))),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke((isComplete ? ColorTheme.ready : (emphasizeMissing ? ColorTheme.warning : ColorTheme.divider)).opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func checklistPreviewCard(title: String, items: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(tint)

            ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { _, item in
                HStack(spacing: 10) {
                    Image(systemName: "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)

                    Text(item)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTheme.text)

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }

    @ViewBuilder
    private func tagWrap(items: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTheme.textTertiary.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                            .foregroundStyle(ColorTheme.textTertiary)

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
                    .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
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
                    .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                            .stroke(ColorTheme.divider, lineWidth: 1)
                    )

                    Spacer(minLength: 0)

                    VStack(spacing: 14) {
                        largeActionButton(title: "Run Again", background: ColorTheme.accent) {
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
                .background(background, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        }
        .buttonStyle(CardPressButtonStyle())
    }

}
