import SwiftUI

struct PlanView: View {
    private enum PlanSection: String, CaseIterable, Identifiable {
        case household
        case vehicleKit

        var id: String { rawValue }

        var title: String {
            switch self {
            case .household:
                "Household"
            case .vehicleKit:
                "Vehicle"
            }
        }

        var detail: String {
            switch self {
            case .household:
                "Go bag, water, family"
            case .vehicleKit:
                "Fuel, recovery, route"
            }
        }

        var iconName: String {
            switch self {
            case .household:
                "checklist"
            case .vehicleKit:
                "vehicle"
            }
        }

        var accent: Color {
            switch self {
            case .household:
                ColorTheme.warning
            case .vehicleKit:
                ColorTheme.terrain
            }
        }

        var heroAssetName: String {
            switch self {
            case .household:
                "preparedness_flatlay"
            case .vehicleKit:
                "evacuation_vehicle_load"
            }
        }

        var heroImageOffset: CGSize {
            switch self {
            case .household:
                CGSize(width: 8, height: 0)
            case .vehicleKit:
                CGSize(width: 18, height: 0)
            }
        }
    }

    @ObservedObject private var appState: AppState
    @StateObject private var viewModel: PlanViewModel
    @StateObject private var goBagViewModel: GoBagViewModel
    @StateObject private var vehicleKitViewModel: VehicleKitViewModel
    @Binding private var requestedFocus: PlanFocus?
    @State private var isShowingGoBag = false
    @State private var selectedSection: PlanSection = .household

    init(appState: AppState, requestedFocus: Binding<PlanFocus?>) {
        _appState = ObservedObject(wrappedValue: appState)
        _viewModel = StateObject(wrappedValue: PlanViewModel(appState: appState))
        _goBagViewModel = StateObject(wrappedValue: GoBagViewModel(appState: appState))
        _vehicleKitViewModel = StateObject(wrappedValue: VehicleKitViewModel(appState: appState))
        _requestedFocus = requestedFocus
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    planOverviewHero
                        .id(selectedSection == .household ? PlanFocus.householdOverview : PlanFocus.vehicleKit)

                    PremiumSegmentedControl(items: planSectionOptions, selection: $selectedSection)

                    if selectedSection == .household {
                        householdPlanContent
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .leading)), removal: .opacity))
                    } else {
                        VehicleKitView(viewModel: vehicleKitViewModel, showsSummaryCard: false)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                    }
                }
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.screen)
                .padding(.bottom, RediLayout.commandDockContentInset)
                .animation(RediMotion.selection, value: selectedSection)
            }
            .onAppear {
                applyRequestedFocus(using: proxy)
            }
            .onChange(of: requestedFocus) { _, _ in
                applyRequestedFocus(using: proxy)
            }
        }
        .navigationTitle("Plan")
        .background(Color.clear)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $isShowingGoBag) {
            NavigationStack {
                GoBagView(viewModel: goBagViewModel)
            }
            .rediSheetPresentation(style: .plan, accent: ColorTheme.warning)
        }
    }

    private var planSectionOptions: [PremiumSegmentedControlOption<PlanSection>] {
        PlanSection.allCases.map { section in
            PremiumSegmentedControlOption(
                segmentID: section,
                title: section.title,
                detail: section.detail,
                iconName: section.iconName,
                accent: section.accent
            )
        }
    }

    @ViewBuilder
    private var planOverviewHero: some View {
        switch selectedSection {
        case .household:
            householdOverviewHero
        case .vehicleKit:
            vehicleOverviewHero
        }
    }

    private var householdOverviewHero: some View {
        let overallScore = appState.prepScore.overall
        let accent = readinessTint(for: overallScore)

        return HeroPanel(
            eyebrow: "Planning Console",
            title: "Household Readiness",
            subtitle: "Keep the next best preparedness move visible while supplies, family details, and evacuation planning all stay editable offline.",
            iconName: selectedSection.iconName,
            accent: ColorTheme.warning,
            atmosphere: ColorTheme.accent.opacity(0.18),
            showsBreathing: true,
            backgroundAssetName: selectedSection.heroAssetName,
            backgroundImageOffset: selectedSection.heroImageOffset
        ) {
            TrustPillGroup(items: [
                TrustPillItem(title: "Offline planning", tone: .info),
                TrustPillItem(title: "72-hour targets", tone: .verified),
                TrustPillItem(title: "Action-first next step", tone: .caution)
            ])

            heroReadinessSummary(
                value: Double(overallScore) / 100,
                tint: accent,
                title: overallScore.percentageText,
                subtitle: "Ready",
                badge: StatusBadge(tier: appState.prepScore.tier),
                summaryTitle: "Overall readiness score",
                summaryDetail: "This score combines supplies, water runway, medical prep, power, communications, and evacuation planning.",
                supportingLine: appState.prepScore.milestoneCaption
            )

            if let suggestion = householdPrioritySuggestion {
                planFocusCard(
                    eyebrow: "Pack Next",
                    iconName: suggestion.category.systemImage,
                    title: suggestion.title,
                    detail: suggestion.detail,
                    emphasis: "+\(suggestion.impact)%",
                    supporting: suggestion.category.quickTaskEstimate,
                    tint: accent
                )
            }

            LazyVGrid(columns: planHeroMetricColumns, spacing: 10) {
                planHeroMetricTile(
                    title: "Go Bag",
                    value: goBagViewModel.plan.readiness.percentage.percentageText,
                    detail: "\(goBagViewModel.plan.readiness.completedCount) / \(goBagViewModel.plan.readiness.totalCount) packed",
                    tint: readinessTint(for: goBagViewModel.evacuationPrepScore)
                )
                planHeroMetricTile(
                    title: "Water",
                    value: viewModel.waterRuntimeEstimate.estimatedDaysText,
                    detail: viewModel.waterRuntimeEstimate.statusTitle,
                    tint: waterStatusTint
                )
                planHeroMetricTile(
                    title: "Routes",
                    value: "\(savedRouteCount)",
                    detail: savedRouteCount == 1 ? "offline route saved" : "offline routes saved",
                    tint: ColorTheme.info
                )
            }
        }
    }

    private var vehicleOverviewHero: some View {
        let readiness = vehicleKitViewModel.plan.readiness
        let tint = readinessTint(for: readiness.percentage)

        return HeroPanel(
            eyebrow: "Vehicle Console",
            title: "Vehicle Readiness",
            subtitle: "Keep long-range movement, fuel, recovery gear, and route confidence readable before you commit the vehicle.",
            iconName: selectedSection.iconName,
            accent: ColorTheme.terrain,
            atmosphere: ColorTheme.terrain.opacity(0.18),
            showsBreathing: true,
            backgroundAssetName: selectedSection.heroAssetName,
            backgroundImageOffset: selectedSection.heroImageOffset
        ) {
            TrustPillGroup(items: [
                TrustPillItem(title: "Remote travel aware", tone: .info),
                TrustPillItem(title: "Priority essentials", tone: .caution),
                TrustPillItem(title: "Offline routes kept local", tone: .verified)
            ])

            heroReadinessSummary(
                value: readiness.progress,
                tint: tint,
                title: readiness.percentage.percentageText,
                subtitle: "Ready",
                badge: Text(vehicleCriticalOutstandingCount == 0 ? "CRITICAL ITEMS COVERED" : "\(vehicleCriticalOutstandingCount) PRIORITY OPEN")
                    .font(RediTypography.metadata)
                    .foregroundStyle(vehicleCriticalOutstandingCount == 0 ? ColorTheme.ready : ColorTheme.warning)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        (vehicleCriticalOutstandingCount == 0 ? ColorTheme.ready : ColorTheme.warning).opacity(0.14),
                        in: Capsule()
                    ),
                summaryTitle: "Vehicle kit completion",
                summaryDetail: "\(readiness.completedCount) of \(readiness.totalCount) vehicle essentials are checked and staged for movement.",
                supportingLine: vehicleScenarioSummary
            )

            if let nextAction = vehicleKitViewModel.plan.nextActions.first {
                planFocusCard(
                    eyebrow: "Lift Readiness Fast",
                    iconName: "vehicle",
                    title: nextAction,
                    detail: vehicleKitViewModel.plan.contextLines.first ?? "Finish the highest-priority vehicle essentials before you move.",
                    emphasis: "~+\(estimatedLift(for: readiness))%",
                    supporting: vehicleScenarioSummary,
                    tint: ColorTheme.terrain
                )
            }

            LazyVGrid(columns: planHeroMetricColumns, spacing: 10) {
                planHeroMetricTile(
                    title: "Priority",
                    value: "\(vehicleCriticalOutstandingCount)",
                    detail: vehicleCriticalOutstandingCount == 1 ? "critical item open" : "critical items open",
                    tint: vehicleCriticalOutstandingCount == 0 ? ColorTheme.ready : ColorTheme.warning
                )
                planHeroMetricTile(
                    title: "Fuel",
                    value: "\(viewModel.draft.supplies.fuelLitres.roundedIntString)L",
                    detail: "tracked reserve",
                    tint: ColorTheme.warning
                )
                planHeroMetricTile(
                    title: "Routes",
                    value: "\(savedRouteCount)",
                    detail: savedRouteCount == 1 ? "offline route saved" : "offline routes saved",
                    tint: ColorTheme.info
                )
            }
        }
    }

    private var householdPlanContent: some View {
        Group {
            PanelCard(title: "Emergency Kit Checklist", subtitle: "Core gear plus scenario prompts") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach($viewModel.draft.checklistItems) { $item in
                        Toggle(isOn: $item.isChecked) {
                            Text(item.kind.title)
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)
                        }
                        .toggleStyle(.switch)
                    }
                }
            }

            if viewModel.isBushfireModeEnabled {
                PanelCard(title: "Bushfire Readiness Planner", subtitle: "Property preparation and seasonal checks for bushfire conditions") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Bushfire checklist")
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)

                            ForEach($viewModel.draft.bushfireReadiness.checklist) { $item in
                                Toggle(isOn: $item.isChecked) {
                                    Text(item.kind.title)
                                        .font(.headline)
                                        .foregroundStyle(ColorTheme.text)
                                }
                                .toggleStyle(.switch)
                                .tint(ColorTheme.warning)
                            }
                        }

                        Divider().background(ColorTheme.divider)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("House preparation")
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)

                            ForEach($viewModel.draft.bushfireReadiness.propertyItems) { $item in
                                Toggle(isOn: $item.isChecked) {
                                    Text(item.kind.title)
                                        .font(.headline)
                                        .foregroundStyle(ColorTheme.text)
                                }
                                .toggleStyle(.switch)
                                .tint(ColorTheme.warning)
                            }
                        }
                    }
                }

                PanelCard(title: "Bushfire Evacuation Planning", subtitle: "Integrates with the shared family plan and saved routes") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Primary evacuation route", text: bushfirePrimaryRouteBinding, axis: .vertical)
                        TextField("Secondary evacuation route", text: bushfireSecondaryRouteBinding, axis: .vertical)
                        TextField("Meeting point", text: bushfireMeetingPointBinding)
                        TextField("Pet evacuation plan", text: bushfirePetPlanBinding, axis: .vertical)
                    }
                    .textFieldStyle(TacticalTextFieldStyle())
                }
            }

            PanelCard(title: "Water Runtime Calculator", subtitle: "Adjust people, pets, and stored water to see how long your supply lasts") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.waterRuntimeEstimate.estimatedDaysText)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(ColorTheme.text)
                            Text("Estimated water duration")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(viewModel.waterRuntimeEstimate.recommendedTargetText)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(ColorTheme.water)
                            Text("Recommended target")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper("Household size: \(max(viewModel.draft.household.peopleCount, 1))", value: $viewModel.draft.household.peopleCount, in: 1...12)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)

                    Stepper("Pets: \(viewModel.draft.household.petCount)", value: $viewModel.draft.household.petCount, in: 0...12)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)

                    supplySlider(title: "Stored Water", value: $viewModel.draft.supplies.waterLitres, range: 0...200, suffix: "L")

                    Text(viewModel.waterRuntimeEstimate.statusTitle)
                        .font(.headline)
                        .foregroundStyle(viewModel.waterRuntimeEstimate.estimatedDays >= Double(viewModel.waterRuntimeEstimate.recommendedReserveDays) ? ColorTheme.ready : ColorTheme.warning)

                    Text(viewModel.waterRuntimeEstimate.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .id(PlanFocus.waterRuntime)

            PanelCard(title: "Supply Tracker", subtitle: "Stored locally for offline access") {
                VStack(spacing: 16) {
                    supplySlider(title: "Food", value: $viewModel.draft.supplies.foodDays, range: 0...21, suffix: "days")
                    supplySlider(title: "Fuel", value: $viewModel.draft.supplies.fuelLitres, range: 0...120, suffix: "L")
                    supplySlider(title: "Battery", value: $viewModel.draft.supplies.batteryCapacity, range: 0...100, suffix: "%")
                }
            }

            if !viewModel.forgottenItems.isEmpty {
                PanelCard(title: "Often Forgotten", subtitle: "Scenario-aware gaps RediM8 has inferred from your current setup") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.forgottenItems) { item in
                            forgottenItemRow(item)
                        }
                    }
                }
            }

            PanelCard(title: "Supply Expiry Tracking", subtitle: "Track medications, batteries, food, and water treatment before they quietly age out") {
                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.expiryReminders.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Upcoming reminders")
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)

                            ForEach(viewModel.expiryReminders) { reminder in
                                expiryReminderRow(reminder)
                            }
                        }

                        Divider().background(ColorTheme.divider)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick add")
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
                            ForEach(SupplyExpiryCategory.allCases) { category in
                                Button(category.defaultItemName) {
                                    viewModel.addSupplyExpiryItem(category: category)
                                }
                                .buttonStyle(SecondaryActionButtonStyle())
                            }
                        }
                    }

                    if viewModel.draft.supplies.trackedExpiryItems.isEmpty {
                        Text("Add expirable supplies to get reminders on the Home screen and keep the app useful between emergencies.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach($viewModel.draft.supplies.trackedExpiryItems) { $item in
                                entryCard {
                                    TextField("Item name", text: $item.name)

                                    Picker("Category", selection: $item.category) {
                                        ForEach(SupplyExpiryCategory.allCases) { category in
                                            Text(category.title).tag(category)
                                        }
                                    }
                                    .pickerStyle(.menu)

                                    TextField("Quantity / notes", text: $item.quantity)

                                    DatePicker("Expiry date", selection: $item.expiryDate, displayedComponents: .date)

                                    Stepper("Reminder lead: \(item.reminderLeadDays) days", value: $item.reminderLeadDays, in: 7...365, step: 7)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(ColorTheme.text)

                                    Button("Remove") {
                                        viewModel.removeSupplyExpiryItem(item.id)
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(ColorTheme.danger)
                                }
                            }
                        }
                    }
                }
            }

            Emergency72HourView(
                plan: viewModel.emergencyPlan,
                nearbyWaterSources: viewModel.nearbyWaterSources,
                waterSourceContext: viewModel.waterSourceContext,
                waterSourceStatusMessage: viewModel.waterSourceStatusMessage,
                isChecklistItemComplete: viewModel.isEmergencyChecklistItemComplete(_:),
                setChecklistItemComplete: viewModel.setEmergencyChecklistItem(_:isComplete:)
            )

            PanelCard(title: "Family Emergency Plan", subtitle: "Contacts, roles, medical notes and meeting points") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Family members")
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)

                    ForEach($viewModel.draft.familyMembers) { $member in
                        entryCard {
                            TextField("Name", text: $member.name)
                            TextField("Phone", text: $member.phone)
                                .keyboardType(.phonePad)
                            TextField("Medical notes", text: $member.medicalNotes, axis: .vertical)
                            TextField("Emergency role", text: $member.emergencyRole)

                            Button(member.isPrimaryUser ? "Using This Device" : "Mark as This Device User") {
                                viewModel.setPrimaryFamilyMember(member.id)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(member.isPrimaryUser ? ColorTheme.info : ColorTheme.text)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Quick roles")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                                    ForEach(emergencyRoleTemplates, id: \.self) { role in
                                        roleChip(role: role, memberID: member.id, selectedRole: member.emergencyRole)
                                    }
                                }
                            }

                            Button("Remove") {
                                viewModel.removeFamilyMember(member.id)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ColorTheme.danger)
                        }
                    }

                    Button("Add Family Member") {
                        viewModel.addFamilyMember()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Divider().background(ColorTheme.divider)

                    Text("Emergency contacts")
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)

                    ForEach($viewModel.draft.emergencyContacts) { $contact in
                        entryCard {
                            TextField("Contact name", text: $contact.name)
                            TextField("Phone", text: $contact.phone)
                                .keyboardType(.phonePad)
                            Button("Remove") {
                                viewModel.removeEmergencyContact(contact.id)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ColorTheme.danger)
                        }
                    }

                    Button("Add Emergency Contact") {
                        viewModel.addEmergencyContact()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Divider().background(ColorTheme.divider)

                    TextField("Household care notes", text: $viewModel.draft.medicalNotes, axis: .vertical)
                        .textFieldStyle(TacticalTextFieldStyle())

                    VStack(spacing: 12) {
                        TextField("Primary meeting point", text: $viewModel.draft.meetingPoints.primary)
                        TextField("Secondary meeting point", text: $viewModel.draft.meetingPoints.secondary)
                        TextField("Fallback meeting point", text: $viewModel.draft.meetingPoints.fallback)
                    }
                    .textFieldStyle(TacticalTextFieldStyle())
                }
            }

            PanelCard(title: "Family Roles", subtitle: "Emergency Mode surfaces the primary device user's task first") {
                if let primaryRoleTask {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Primary device user")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(ColorTheme.info)
                            Text("\(primaryRoleTask.memberName) - \(primaryRoleTask.role)")
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)
                            Text(primaryRoleTask.taskTitle)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(ColorTheme.text)
                            Text(primaryRoleTask.taskDetail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                        if !secondaryRoleTasks(excluding: primaryRoleTask.id).isEmpty {
                            Divider().background(ColorTheme.divider)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Role summary")
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)

                                ForEach(secondaryRoleTasks(excluding: primaryRoleTask.id)) { task in
                                    familyRoleRow(task)
                                }
                            }
                        }
                    }
                } else {
                    Text("Add family members and assign roles like Driver, First Aid, Pets, or Documents to get person-specific prompts in Emergency Mode.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            PanelCard(
                title: "Go Bag",
                subtitle: "Evacuation bag readiness and rapid departure checklist",
                backgroundAssetName: "gobag_loadout",
                backgroundImageOffset: CGSize(width: -26, height: 0)
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom, spacing: 12) {
                        Text(goBagViewModel.plan.readiness.percentage.percentageText)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(ColorTheme.text)
                        Text("Ready")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(goBagViewModel.plan.readiness.percentage >= 67 ? ColorTheme.ready : ColorTheme.warning)
                    }

                    Text("\(goBagViewModel.plan.readiness.completedCount) / \(goBagViewModel.plan.readiness.totalCount) items packed")
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)

                    ReadinessMeter(
                        value: goBagViewModel.plan.readiness.progress,
                        tint: goBagViewModel.plan.readiness.percentage >= 67 ? ColorTheme.ready : ColorTheme.warning,
                        height: 11
                    )

                    if !goBagViewModel.plan.scenarioTitles.isEmpty {
                        Text(goBagViewModel.plan.scenarioTitles.joined(separator: " • "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !goBagViewModel.plan.nextActions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pack next")
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)
                            ForEach(Array(goBagViewModel.plan.nextActions.enumerated()), id: \.offset) { _, action in
                                Text(action)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button("Open Go Bag Mode") {
                        isShowingGoBag = true
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }

            PanelCard(
                title: "Evacuation Routes",
                subtitle: "Saved on device for blackout access",
                backgroundAssetName: "evacuation_staging",
                backgroundImageOffset: CGSize(width: 14, height: 0)
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(viewModel.draft.evacuationRoutes.indices), id: \.self) { index in
                        entryCard {
                            TextField("Route \(index + 1)", text: $viewModel.draft.evacuationRoutes[index], axis: .vertical)
                            Button("Remove") {
                                viewModel.removeEvacuationRoute(at: index)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ColorTheme.danger)
                        }
                    }

                    Button("Add Route") {
                        viewModel.addEvacuationRoute()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
            .id(PlanFocus.evacuationRoutes)

            PanelCard(title: "Scenario Tasks", subtitle: "Generated from selected hazards") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.scenarioTasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)
                            Text(task.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(task.category.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ColorTheme.info)
                        }
                    }
                }
            }

            PanelCard(title: "Recommended Gear", subtitle: "Thin slice of scenario-linked recommendations") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.recommendedGear) { gear in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gear.name)
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)
                            Text(gear.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(gear.category.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ColorTheme.info)
                        }
                    }
                }
            }
        }
    }

    private let planHeroMetricColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var householdPrioritySuggestion: ImprovementSuggestion? {
        appState.prepScore.suggestions.first
    }

    private var savedRouteCount: Int {
        viewModel.draft.evacuationRoutes.compactMap(\.nilIfBlank).count
    }

    private var vehicleCriticalOutstandingCount: Int {
        vehicleKitViewModel.plan.items.filter { item in
            item.isCritical && !vehicleKitViewModel.isItemComplete(item.id)
        }.count
    }

    private var vehicleScenarioSummary: String {
        let titles = vehicleKitViewModel.plan.scenarioTitles
        if titles.isEmpty {
            return "General travel coverage with offline route fallback."
        }
        return "Prioritised for \(titles.joined(separator: ", "))."
    }

    private var waterStatusTint: Color {
        switch viewModel.waterRuntimeEstimate.statusTitle {
        case "On Target":
            ColorTheme.ready
        case "Below Target":
            ColorTheme.warning
        default:
            ColorTheme.danger
        }
    }

    private func heroReadinessSummary<Badge: View>(
        value: Double,
        tint: Color,
        title: String,
        subtitle: String,
        badge: Badge,
        summaryTitle: String,
        summaryDetail: String,
        supportingLine: String
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                ReadinessRing(
                    value: value,
                    tint: tint,
                    title: title,
                    subtitle: subtitle
                )

                readinessSummaryTextBlock(
                    value: value,
                    tint: tint,
                    badge: badge,
                    summaryTitle: summaryTitle,
                    summaryDetail: summaryDetail,
                    supportingLine: supportingLine
                )
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    ReadinessRing(
                        value: value,
                        tint: tint,
                        title: title,
                        subtitle: subtitle,
                        size: 104,
                        lineWidth: 11
                    )

                    readinessSummaryTextBlock(
                        value: value,
                        tint: tint,
                        badge: badge,
                        summaryTitle: summaryTitle,
                        summaryDetail: summaryDetail,
                        supportingLine: supportingLine
                    )
                }
            }
        }
    }

    private func readinessSummaryTextBlock<Badge: View>(
        value: Double,
        tint: Color,
        badge: Badge,
        summaryTitle: String,
        summaryDetail: String,
        supportingLine: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            badge

            Text(summaryTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(ColorTheme.text)

            Text(summaryDetail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textMuted)

            ReadinessMeter(value: value, tint: tint, height: 12)

            Text(supportingLine)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func planFocusCard(
        eyebrow: String,
        iconName: String,
        title: String,
        detail: String,
        emphasis: String,
        supporting: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 48, height: 48)

                    RediIcon(iconName)
                        .foregroundStyle(tint)
                        .frame(width: 20, height: 20)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow.uppercased())
                        .font(RediTypography.metadata)
                        .foregroundStyle(tint)

                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(ColorTheme.text)
                }

                Spacer(minLength: 0)

                Text(emphasis)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(tint.opacity(0.14), in: Capsule())
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textMuted)

            Text(supporting)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.textFaint)
        }
        .padding(16)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 22,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: tint.opacity(0.12)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 22, edgeColor: tint.opacity(0.14), shadowColor: tint.opacity(0.06)))
    }

    private func planHeroMetricTile(
        title: String,
        value: String,
        detail: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(RediTypography.metadata)
                .foregroundStyle(ColorTheme.textFaint)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .lineLimit(1)

            Text(detail)
                .font(.caption)
                .foregroundStyle(tint)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(14)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: 18,
                backgroundAssetName: nil,
                backgroundImageOffset: .zero,
                atmosphere: tint.opacity(0.1)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: 18, edgeColor: tint.opacity(0.1), shadowColor: tint.opacity(0.05)))
    }

    private func estimatedLift(for readiness: GoBagReadiness) -> Int {
        guard readiness.totalCount > 0 else {
            return 0
        }

        return min(max(Int((100 / Double(readiness.totalCount)).rounded()), 4), 14)
    }

    private func supplySlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
                Spacer()
                Text("\(value.wrappedValue.roundedIntString) \(suffix)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .tint(ColorTheme.info)
        }
    }

    private var emergencyRoleTemplates: [String] {
        ["Driver", "First Aid", "Pets", "Documents", "Go Bag", "Communications"]
    }

    private var primaryRoleTask: FamilyRoleTask? {
        viewModel.familyRoleTasks.first(where: \.isPrimaryUser) ?? viewModel.familyRoleTasks.first
    }

    private func secondaryRoleTasks(excluding id: UUID) -> [FamilyRoleTask] {
        viewModel.familyRoleTasks.filter { $0.id != id }
    }

    private func entryCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .textFieldStyle(TacticalTextFieldStyle())
    }

    private func forgottenItemRow(_ item: ForgottenItemInsight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RediIcon(item.systemImage)
                .foregroundStyle(ColorTheme.warning)
                .frame(width: 24, height: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func expiryReminderRow(_ reminder: SupplyExpiryReminder) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RediIcon(reminder.status == .overdue ? "warning" : "alert")
                .foregroundStyle(reminder.status == .overdue ? ColorTheme.danger : ColorTheme.warning)
                .frame(width: 24, height: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
                Text(reminder.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func familyRoleRow(_ task: FamilyRoleTask) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RediIcon(task.systemImage)
                .foregroundStyle(ColorTheme.info)
                .frame(width: 24, height: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(task.memberName) - \(task.role)")
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
                Text(task.taskTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTheme.info)
                Text(task.taskDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func roleChip(role: String, memberID: UUID, selectedRole: String) -> some View {
        Button(role) {
            viewModel.assignEmergencyRole(role, to: memberID)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(selectedRole == role ? ColorTheme.info : ColorTheme.text)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            selectedRole == role ? ColorTheme.info.opacity(0.16) : Color.black.opacity(0.24),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    selectedRole == role ? ColorTheme.info.opacity(0.35) : ColorTheme.dividerStrong,
                    lineWidth: 1
                )
        )
        .buttonStyle(CardPressButtonStyle())
    }

    private var bushfirePrimaryRouteBinding: Binding<String> {
        Binding(
            get: { viewModel.bushfireRoute(at: 0) },
            set: { viewModel.setBushfireRoute($0, at: 0) }
        )
    }

    private var bushfireSecondaryRouteBinding: Binding<String> {
        Binding(
            get: { viewModel.bushfireRoute(at: 1) },
            set: { viewModel.setBushfireRoute($0, at: 1) }
        )
    }

    private var bushfireMeetingPointBinding: Binding<String> {
        Binding(
            get: { viewModel.bushfireMeetingPoint() },
            set: { viewModel.setBushfireMeetingPoint($0) }
        )
    }

    private var bushfirePetPlanBinding: Binding<String> {
        Binding(
            get: { viewModel.bushfirePetPlan() },
            set: { viewModel.setBushfirePetPlan($0) }
        )
    }

    private func readinessTint(for score: Int) -> Color {
        switch score {
        case ..<50:
            ColorTheme.danger
        case 50..<75:
            ColorTheme.warning
        default:
            ColorTheme.ready
        }
    }

    private func applyRequestedFocus(using proxy: ScrollViewProxy) {
        guard let requestedFocus else {
            return
        }

        switch requestedFocus {
        case .householdOverview:
            withAnimation(RediMotion.selection) {
                selectedSection = .household
            }
            DispatchQueue.main.async {
                proxy.scrollTo(PlanFocus.householdOverview, anchor: .top)
            }
        case .waterRuntime:
            withAnimation(RediMotion.selection) {
                selectedSection = .household
            }
            DispatchQueue.main.async {
                proxy.scrollTo(PlanFocus.waterRuntime, anchor: .top)
            }
        case .evacuationRoutes:
            withAnimation(RediMotion.selection) {
                selectedSection = .household
            }
            DispatchQueue.main.async {
                proxy.scrollTo(PlanFocus.evacuationRoutes, anchor: .top)
            }
        case .vehicleKit:
            withAnimation(RediMotion.selection) {
                selectedSection = .vehicleKit
            }
            DispatchQueue.main.async {
                proxy.scrollTo(PlanFocus.vehicleKit, anchor: .top)
            }
        }

        DispatchQueue.main.async {
            self.requestedFocus = nil
        }
    }
}
