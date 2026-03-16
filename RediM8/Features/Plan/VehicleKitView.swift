import SwiftUI

struct VehicleKitView: View {
    @ObservedObject var viewModel: VehicleKitViewModel
    var showsSummaryCard: Bool = true
    var customTasks: [PlanCustomTask] = []
    @Binding var laneNotes: String
    var addCustomTask: (String, String) -> Void = { _, _ in }
    var toggleCustomTask: (UUID) -> Void = { _ in }
    var deleteCustomTask: (UUID) -> Void = { _ in }
    var updateCustomTaskTitle: (UUID, String) -> Void = { _, _ in }
    var updateCustomTaskNote: (UUID, String) -> Void = { _, _ in }

    init(
        viewModel: VehicleKitViewModel,
        showsSummaryCard: Bool = true,
        customTasks: [PlanCustomTask] = [],
        laneNotes: Binding<String> = .constant(""),
        addCustomTask: @escaping (String, String) -> Void = { _, _ in },
        toggleCustomTask: @escaping (UUID) -> Void = { _ in },
        deleteCustomTask: @escaping (UUID) -> Void = { _ in },
        updateCustomTaskTitle: @escaping (UUID, String) -> Void = { _, _ in },
        updateCustomTaskNote: @escaping (UUID, String) -> Void = { _, _ in }
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.showsSummaryCard = showsSummaryCard
        self.customTasks = customTasks
        _laneNotes = laneNotes
        self.addCustomTask = addCustomTask
        self.toggleCustomTask = toggleCustomTask
        self.deleteCustomTask = deleteCustomTask
        self.updateCustomTaskTitle = updateCustomTaskTitle
        self.updateCustomTaskNote = updateCustomTaskNote
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CinematicBanner("evacuation_vehicle_load", height: 160)

            if showsSummaryCard {
                PanelCard(
                    title: "Vehicle Readiness Mode",
                    subtitle: "For 4WDs, tradies, campers, rural travel, and long-distance driving",
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .bottom, spacing: 12) {
                                vehicleReadinessHeadline
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                vehicleReadinessHeadline
                            }
                        }

                        Text("\(viewModel.plan.readiness.completedCount) / \(viewModel.plan.readiness.totalCount) vehicle essentials checked")
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)

                        ReadinessMeter(
                            value: viewModel.plan.readiness.progress,
                            tint: viewModel.plan.readiness.percentage >= 67 ? ColorTheme.ready : ColorTheme.warning,
                            height: 11
                        )

                        ForEach(viewModel.plan.contextLines, id: \.self) { line in
                            Text(line)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if !viewModel.plan.nextActions.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Pack next")
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)
                                ForEach(viewModel.plan.nextActions, id: \.self) { action in
                                    Text(action)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            SystemStatusRail(items: vehicleStatusItems, accent: ColorTheme.accent)

            if let nextAction = viewModel.plan.nextActions.first {
                PanelCard(title: "Move First", subtitle: "Finish the highest-impact vehicle task before you drill into the rest of the kit.") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(nextAction)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(ColorTheme.text)

                        Text(viewModel.plan.contextLines.last ?? "Keep long-range movement simple: fuel, maps, recovery, and breakdown essentials first.")
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }
            }

            vehicleSectionCard(
                title: "Must Have Now",
                subtitle: "Core movement and breakdown coverage. These items should be in the vehicle before almost any trip.",
                tint: ColorTheme.warning,
                items: mustHaveNowItems
            )

            if !terrainSpecificItems.isEmpty {
                vehicleSectionCard(
                    title: "Weather + Terrain",
                    subtitle: "Bring these forward when the current hazards or route demand extra self-recovery.",
                    tint: ColorTheme.accent,
                    items: terrainSpecificItems
                )
            }

            if !supportItems.isEmpty {
                vehicleSectionCard(
                    title: "Support + Backup",
                    subtitle: "Helpful secondary coverage once the must-have items are already handled.",
                    tint: ColorTheme.accent,
                    items: supportItems
                )
            }

            PlanningCustomTasksCard(
                title: "Custom Tasks",
                subtitle: "Your own checklist items and notes for vehicle readiness.",
                accent: ColorTheme.accent,
                tasks: customTasks,
                notes: $laneNotes,
                addTask: addCustomTask,
                toggleTask: toggleCustomTask,
                deleteTask: deleteCustomTask,
                updateTaskTitle: updateCustomTaskTitle,
                updateTaskNote: updateCustomTaskNote
            )
        }
    }

    private var vehicleStatusItems: [OperationalStatusItem] {
        [
            OperationalStatusItem(
                iconName: "vehicle",
                label: "Ready",
                value: viewModel.plan.readiness.percentage.percentageText,
                tone: viewModel.plan.readiness.percentage >= 67 ? .ready : .caution
            ),
            OperationalStatusItem(
                iconName: "warning",
                label: "Must Have Open",
                value: "\(mustHaveNowItems.filter { !viewModel.isItemComplete($0.id) }.count)",
                tone: mustHaveNowItems.allSatisfy { viewModel.isItemComplete($0.id) } ? .ready : .caution
            ),
            OperationalStatusItem(
                iconName: "map_marker",
                label: "Scenarios",
                value: viewModel.plan.scenarioTitles.isEmpty ? "General travel" : "\(viewModel.plan.scenarioTitles.count) active",
                tone: .info
            )
        ]
    }

    private var mustHaveNowItems: [VehicleKitItem] {
        sectionItems(for: [
            "vehicle_first_aid",
            "vehicle_spare_tyre",
            "vehicle_maps",
            "vehicle_fuel",
            "vehicle_water"
        ])
    }

    private var terrainSpecificItems: [VehicleKitItem] {
        sectionItems(for: [
            "vehicle_recovery_gear",
            "vehicle_compressor",
            "vehicle_jump_starter"
        ])
    }

    private var supportItems: [VehicleKitItem] {
        viewModel.plan.items.filter { item in
            !mustHaveNowItems.contains(item) && !terrainSpecificItems.contains(item)
        }
    }

    private func sectionItems(for ids: [String]) -> [VehicleKitItem] {
        let idSet = Set(ids)
        return viewModel.plan.items.filter { idSet.contains($0.id) }
    }

    private func vehicleSectionCard(
        title: String,
        subtitle: String,
        tint: Color,
        items: [VehicleKitItem]
    ) -> some View {
        PanelCard(title: title, subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(items) { item in
                    vehicleItemButton(item, tint: tint)
                }
            }
        }
    }

    private func vehicleItemButton(_ item: VehicleKitItem, tint: Color) -> some View {
        let isComplete = viewModel.isItemComplete(item.id)

        return Button {
            viewModel.setItemComplete(item.id, isComplete: !isComplete)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                RediIcon(item.systemImage)
                    .foregroundStyle(isComplete ? ColorTheme.ready : tint)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)
                        if item.isCritical {
                            Text("Priority")
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
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(isComplete ? ColorTheme.ready : ColorTheme.divider)
                    .frame(width: 38, height: 38)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (isComplete ? ColorTheme.ready.opacity(0.08) : Color.black.opacity(0.26)),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke((isComplete ? ColorTheme.ready : tint).opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private var vehicleReadinessHeadline: some View {
        Group {
            Text(viewModel.plan.readiness.percentage.percentageText)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(ColorTheme.text)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text("Vehicle Ready")
                .font(.headline.weight(.semibold))
                .foregroundStyle(viewModel.plan.readiness.percentage >= 67 ? ColorTheme.ready : ColorTheme.warning)
        }
    }
}

struct PlanningCustomTasksCard: View {
    let title: String
    let subtitle: String
    let accent: Color
    let tasks: [PlanCustomTask]
    @Binding var notes: String
    let addTask: (String, String) -> Void
    let toggleTask: (UUID) -> Void
    let deleteTask: (UUID) -> Void
    let updateTaskTitle: (UUID, String) -> Void
    let updateTaskNote: (UUID, String) -> Void

    @State private var draftTaskTitle = ""
    @State private var draftTaskNote = ""

    private var openTasks: [PlanCustomTask] {
        tasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [PlanCustomTask] {
        tasks.filter(\.isCompleted)
    }

    private var trimmedDraftTaskTitle: String {
        draftTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        PanelCard(title: title, subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 16) {
                addTaskComposer

                if tasks.isEmpty {
                    emptyState
                } else {
                    if !openTasks.isEmpty {
                        taskSection(title: "Open", tasks: openTasks, tint: accent)
                    }

                    if !completedTasks.isEmpty {
                        if !openTasks.isEmpty {
                            Divider()
                                .background(ColorTheme.divider)
                        }

                        taskSection(title: "Done", tasks: completedTasks, tint: ColorTheme.ready)
                    }
                }

                Divider()
                    .background(ColorTheme.divider)

                notesSection
            }
        }
    }

    private var addTaskComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Custom Task")
                .font(.headline)
                .foregroundStyle(ColorTheme.text)

            TextField("Task title", text: $draftTaskTitle)
                .textFieldStyle(TacticalTextFieldStyle())

            TextField("Optional note", text: $draftTaskNote, axis: .vertical)
                .textFieldStyle(TacticalTextFieldStyle())

            Button("Add Task") {
                let note = draftTaskNote.trimmingCharacters(in: .whitespacesAndNewlines)
                addTask(trimmedDraftTaskTitle, note)
                draftTaskTitle = ""
                draftTaskNote = ""
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(trimmedDraftTaskTitle.isEmpty)
            .opacity(trimmedDraftTaskTitle.isEmpty ? 0.6 : 1)
        }
    }

    private var emptyState: some View {
        Text("Add your own household-specific jobs here, then tick them off as they get done.")
            .font(.subheadline)
            .foregroundStyle(ColorTheme.textSecondary)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.headline)
                .foregroundStyle(ColorTheme.text)

            TextField("Add anything specific for this lane", text: $notes, axis: .vertical)
                .textFieldStyle(TacticalTextFieldStyle())
        }
    }

    private func taskSection(title: String, tasks: [PlanCustomTask], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(tint)

            ForEach(tasks) { task in
                taskRow(task, tint: tint)
            }
        }
    }

    private func taskRow(_ task: PlanCustomTask, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    toggleTask(task.id)
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(task.isCompleted ? ColorTheme.ready : tint)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    TextField(
                        "Task",
                        text: Binding(
                            get: { task.title },
                            set: { updateTaskTitle(task.id, $0) }
                        )
                    )
                    .textFieldStyle(TacticalTextFieldStyle())
                    .strikethrough(task.isCompleted, color: ColorTheme.textTertiary)

                    TextField(
                        "Optional note",
                        text: Binding(
                            get: { task.note },
                            set: { updateTaskNote(task.id, $0) }
                        ),
                        axis: .vertical
                    )
                    .textFieldStyle(TacticalTextFieldStyle())
                }

                Button {
                    deleteTask(task.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ColorTheme.textTertiary)
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.22), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(task.isCompleted ? 0.76 : 1)
        .padding(14)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke((task.isCompleted ? ColorTheme.ready : tint).opacity(0.12), lineWidth: 1)
        )
    }
}
