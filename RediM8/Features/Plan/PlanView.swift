import SwiftUI

struct PlanView: View {
    @ObservedObject private var appState: AppState
    @StateObject private var viewModel: PlanViewModel
    @StateObject private var goBagViewModel: GoBagViewModel
    @StateObject private var vehicleKitViewModel: VehicleKitViewModel
    @Binding private var requestedFocus: PlanFocus?
    private let scrollToTopRequestID: Int
    private let disablesAutomaticLocationPrompts: Bool
    @State private var isShowingGoBag = false
    @State private var selectedPreparednessGearRecommendation: PreparednessGearRecommendation?
    @State private var selectedPrepareGuide: Guide?
    @State private var selectedPrepareDestination: PrepareDestination?
    @State private var selectedSection: PlanSection = .household
    @State private var selectedHouseholdWorkspace: HouseholdWorkspace = .prepare

    init(
        appState: AppState,
        requestedFocus: Binding<PlanFocus?>,
        scrollToTopRequestID: Int,
        disablesAutomaticLocationPrompts: Bool = false
    ) {
        _appState = ObservedObject(wrappedValue: appState)
        _viewModel = StateObject(wrappedValue: PlanViewModel(appState: appState))
        _goBagViewModel = StateObject(wrappedValue: GoBagViewModel(appState: appState))
        _vehicleKitViewModel = StateObject(wrappedValue: VehicleKitViewModel(appState: appState))
        _requestedFocus = requestedFocus
        self.scrollToTopRequestID = scrollToTopRequestID
        self.disablesAutomaticLocationPrompts = disablesAutomaticLocationPrompts
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear
                        .frame(height: 0)
                        .id(PlanScrollAnchor.top)

                    PremiumSegmentedControl(items: planSectionOptions, selection: $selectedSection)

                    if selectedSection == .household {
                        if selectedHouseholdWorkspace == .prepare {
                            prepareHubContent
                                .id(PlanFocus.householdOverview)
                                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .leading)), removal: .opacity))
                        } else {
                            CinematicBanner("marketing_command_table", height: 160)

                            planOverviewHero
                                .id(PlanFocus.householdOverview)

                            householdWorkspaceDeck
                            householdReadinessBreakdownCard
                            householdPlanContent
                                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .leading)), removal: .opacity))
                        }
                    } else {
                        CinematicBanner("marketing_command_table", height: 160)

                        planOverviewHero
                            .id(PlanFocus.vehicleKit)

                        VehicleKitView(
                            viewModel: vehicleKitViewModel,
                            showsSummaryCard: false,
                            customTasks: customPlanningTasks(for: .vehicle),
                            laneNotes: customPlanningNotesBinding(for: .vehicle),
                            addCustomTask: { title, note in
                                addCustomPlanningTask(title: title, note: note, to: .vehicle)
                            },
                            toggleCustomTask: { taskID in
                                toggleCustomPlanningTask(taskID, in: .vehicle)
                            },
                            deleteCustomTask: { taskID in
                                deleteCustomPlanningTask(taskID, from: .vehicle)
                            },
                            updateCustomTaskTitle: { taskID, title in
                                updateCustomPlanningTask(taskID, in: .vehicle) { $0.title = title }
                            },
                            updateCustomTaskNote: { taskID, note in
                                updateCustomPlanningTask(taskID, in: .vehicle) { $0.note = note }
                            }
                        )
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                    }
                }
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.screen)
                .padding(.bottom, RediLayout.commandDockContentInset)
                .animation(RediMotion.selection, value: selectedSection)
            }
            .accessibilityIdentifier("plan.root")
            .onAppear {
                applyRequestedFocus(using: proxy)
            }
            .onChange(of: requestedFocus) { _, _ in
                applyRequestedFocus(using: proxy)
            }
            .onChange(of: scrollToTopRequestID) { _, _ in
                scrollToPlanTop(using: proxy)
            }
        }
        .navigationTitle("Prepare")
        .background(Color.clear)
        .onAppear { viewModel.onAppear(requestLocationAccess: !disablesAutomaticLocationPrompts) }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $isShowingGoBag) {
            NavigationStack {
                GoBagView(viewModel: goBagViewModel)
            }
            .rediSheetPresentation()
        }
        .sheet(item: $selectedPreparednessGearRecommendation) { recommendation in
            NavigationStack {
                PreparednessGearRecommendationSheet(recommendation: recommendation)
            }
            .rediSheetPresentation()
        }
        .sheet(item: $selectedPrepareDestination) { destination in
            NavigationStack {
                switch destination {
                case let .scenario(scenario):
                    PrepareScenarioDetailView(
                        scenario: scenario,
                        recommendations: viewModel.prepareRecommendations(
                            for: scenario.gearTypes,
                            scenarioOverrides: scenario.scenarioOverrides,
                            includeBundle: true
                        ),
                        relatedGuides: viewModel.guides(ids: scenario.guideIDs),
                        areGearRecommendationsSuppressed: viewModel.isPreparednessGearSuppressed
                    )
                }
            }
            .rediSheetPresentation()
        }
        .sheet(item: $selectedPrepareGuide) { guide in
            NavigationStack {
                GuideDetailView(guide: guide)
            }
            .rediSheetPresentation()
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
            accent: ColorTheme.textTertiary
        ) {
            TrustPillGroup(items: [
                TrustPillItem(title: "OFFLINE READY", tone: .neutral),
                TrustPillItem(title: "CURRENT PRIORITY", tone: .neutral),
                TrustPillItem(title: "ACTION FIRST", tone: .neutral)
            ])

            PlanReadinessSummary(
                value: Double(overallScore) / 100,
                tint: accent,
                title: householdReadinessLabel,
                subtitle: "Preparedness",
                summaryTitle: householdPriorityLine,
                summaryDetail: householdTargetLine,
                supportingLine: householdTimeToReadyLine
            ) {
                PlanCapsuleBadge(title: "Current Priority", tint: accent)
            }
            .accessibilityIdentifier("plan.household.readinessSummary")

            if let suggestion = householdPrioritySuggestion {
                PlanFocusCard(
                    eyebrow: "Next Action",
                    iconName: suggestion.category.systemImage,
                    title: nextActionTitle(for: suggestion),
                    detail: suggestion.detail,
                    emphasis: "Impact +\(suggestion.impact)%",
                    secondaryEmphasis: nextActionTimeLabel(for: suggestion.category),
                    supporting: householdTargetLine,
                    tint: accent
                )
            }

            LazyVGrid(columns: planHeroMetricColumns, spacing: 10) {
                PlanHeroMetricTile(
                    title: "Go Bag",
                    value: goBagStatusLabel,
                    detail: goBagReadyToLeaveLine,
                    tint: readinessTint(for: goBagViewModel.evacuationPrepScore)
                )
                PlanHeroMetricTile(
                    title: "Water",
                    value: viewModel.waterRuntimeEstimate.estimatedDaysText,
                    detail: viewModel.waterRuntimeEstimate.statusTitle,
                    tint: waterStatusTint
                )
                PlanHeroMetricTile(
                    title: "Routes",
                    value: "\(savedRouteCount)",
                    detail: savedRouteCount == 1 ? "offline route saved" : "offline routes saved",
                    tint: ColorTheme.textTertiary
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
            accent: ColorTheme.textTertiary
        ) {
            TrustPillGroup(items: [
                TrustPillItem(title: "REMOTE READY", tone: .neutral),
                TrustPillItem(title: "PRIORITY FIRST", tone: .neutral),
                TrustPillItem(title: "OFFLINE ROUTES", tone: .neutral)
            ])

            PlanReadinessSummary(
                value: readiness.progress,
                tint: tint,
                title: readinessOperationalLabel(for: readiness.percentage),
                subtitle: "Vehicle",
                summaryTitle: vehicleCriticalOutstandingCount == 0 ? "Vehicle movement baseline is covered." : "\(vehicleCriticalOutstandingCount) priority vehicle item\(vehicleCriticalOutstandingCount == 1 ? "" : "s") still open.",
                summaryDetail: "\(readiness.completedCount) of \(readiness.totalCount) vehicle essentials are checked and staged for movement.",
                supportingLine: vehicleTimeToReadyLine
            ) {
                PlanCapsuleBadge(
                    title: vehicleCriticalOutstandingCount == 0 ? "Move Ready" : "Current Priority",
                    tint: vehicleCriticalOutstandingCount == 0 ? ColorTheme.ready : ColorTheme.warning
                )
            }

            if let nextAction = vehicleKitViewModel.plan.nextActions.first {
                PlanFocusCard(
                    eyebrow: "Next Action",
                    iconName: "vehicle",
                    title: nextAction,
                    detail: vehicleKitViewModel.plan.contextLines.first ?? "Finish the highest-priority vehicle essentials before you move.",
                    emphasis: "Impact ~+\(estimatedLift(for: readiness))%",
                    secondaryEmphasis: vehicleTimeToReadyBadge,
                    supporting: vehicleScenarioSummary,
                    tint: ColorTheme.textTertiary
                )
            }

            LazyVGrid(columns: planHeroMetricColumns, spacing: 10) {
                PlanHeroMetricTile(
                    title: "Priority",
                    value: "\(vehicleCriticalOutstandingCount)",
                    detail: vehicleCriticalOutstandingCount == 1 ? "critical item open" : "critical items open",
                    tint: vehicleCriticalOutstandingCount == 0 ? ColorTheme.ready : ColorTheme.warning
                )
                PlanHeroMetricTile(
                    title: "Fuel",
                    value: "\(viewModel.draft.supplies.fuelLitres.roundedIntString)L",
                    detail: "tracked reserve",
                    tint: ColorTheme.textTertiary
                )
                PlanHeroMetricTile(
                    title: "Routes",
                    value: "\(savedRouteCount)",
                    detail: savedRouteCount == 1 ? "offline route saved" : "offline routes saved",
                    tint: ColorTheme.textTertiary
                )
            }
        }
    }

    private var householdWorkspaceDeck: some View {
        PanelCard(title: "Preparation Areas", subtitle: "Work one operational area at a time so routes, supplies, and people do not compete in one long scroll.") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(HouseholdWorkspace.allCases) { workspace in
                    householdWorkspaceButton(workspace)
                }
            }
        }
    }

    private var householdReadinessBreakdownCard: some View {
        PanelCard(
            title: "Weakest Areas",
                subtitle: "Start where the risk is highest so the next fix stays obvious."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(orderedCategoryScores) { categoryScore in
                    PlanReadinessBreakdownRow(
                        categoryScore: categoryScore,
                        tint: readinessTint(for: categoryScore.score),
                        severity: readinessSeverityLabel(for: categoryScore.score)
                    )
                }
            }
        }
    }

    private var prepareHubContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Prepare")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(ColorTheme.text)

                Text("Understand what to prepare for and how to be ready.")
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textSecondary)
            }

            PanelCard(title: "Scenario Essentials", subtitle: "Start with the situation you want to be ready for, then open the essentials that matter most.") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(PrepareScenario.allCases) { scenario in
                        prepareScenarioCard(scenario)
                    }
                }
            }

            if !viewModel.isPreparednessGearSuppressed {
                PanelCard(title: "Preparedness Kits", subtitle: "Fastest ways to cover multiple readiness gaps without turning the app into a store.") {
                    VStack(alignment: .leading, spacing: 12) {
                        prepareKitCard(
                            title: "Emergency Go-Bag",
                            detail: "Portable setup for evacuation or sudden disruption.",
                            iconName: "go_bag",
                            badge: "View Setup"
                        ) {
                            isShowingGoBag = true
                        }

                        prepareKitCard(
                            title: "Family Kit",
                            detail: "Covers household safety, contacts, and core supplies in one baseline setup.",
                            iconName: "family",
                            badge: "View Setup"
                        ) {
                            selectedPrepareDestination = .scenario(.household)
                        }

                        prepareKitCard(
                            title: "Vehicle Kit",
                            detail: "Essential items for being stranded, rerouting, or travelling through disruptions.",
                            iconName: "vehicle",
                            badge: "Open Vehicle"
                        ) {
                            withAnimation(RediMotion.selection) {
                                selectedSection = .vehicleKit
                            }
                        }
                    }
                }
            }

            PanelCard(title: "Learn The Basics", subtitle: "Offline references stay available when you want a fuller explanation behind the essentials.") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(prepareBasicsGuides) { guide in
                        Button {
                            selectedPrepareGuide = guide
                        } label: {
                            RediCommandCard(
                                title: guide.title,
                                detail: guide.summary,
                                iconName: guide.heroIconName,
                                tint: ColorTheme.textTertiary,
                                badge: "Guide",
                                prominence: .neutral,
                                layout: .rail,
                                minHeight: 78
                            )
                        }
                        .buttonStyle(CardPressButtonStyle())
                    }
                }
            }

            householdWorkspaceDeck
        }
    }

    private var prepareBasicsGuides: [Guide] {
        viewModel.guides(ids: [
            "boil_filter_disinfect_water",
            "shelter_in_place_steps",
            "household_evacuation_quick_start"
        ])
    }

    private func prepareScenarioCard(_ scenario: PrepareScenario) -> some View {
        Button {
            selectedPrepareDestination = .scenario(scenario)
        } label: {
            RediCommandCard(
                title: scenario.title,
                detail: scenario.subtitle,
                iconName: scenario.iconName,
                tint: ColorTheme.textTertiary,
                badge: prepareScenarioBadge(for: scenario),
                prominence: .neutral,
                layout: .rail,
                minHeight: 88
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func prepareKitCard(
        title: String,
        detail: String,
        iconName: String,
        badge: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RediCommandCard(
                title: title,
                detail: detail,
                iconName: iconName,
                tint: ColorTheme.textTertiary,
                badge: badge,
                prominence: .neutral,
                layout: .rail,
                minHeight: 84
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func prepareScenarioBadge(for scenario: PrepareScenario) -> String? {
        if scenario == .household {
            return "Baseline"
        }

        let selectedScenarios = Set(viewModel.draft.selectedScenarios)
        return selectedScenarios.isDisjoint(with: Set(scenario.scenarioOverrides)) ? nil : "Selected Risk"
    }

    @ViewBuilder
    private var householdPlanContent: some View {
        switch selectedHouseholdWorkspace {
        case .prepare:
            prepareHubContent
        case .basics:
            householdBasicsContent
            customPlanningWorkspaceCard(for: .basics)
        case .supplies:
            householdSuppliesContent
            customPlanningWorkspaceCard(for: .supplies)
        case .roles:
            householdRolesContent
            customPlanningWorkspaceCard(for: .roles)
        case .scenarios:
            householdScenariosContent
            customPlanningWorkspaceCard(for: .scenarios)
        }
    }

    private func householdWorkspaceButton(_ workspace: HouseholdWorkspace) -> some View {
        let isSelected = selectedHouseholdWorkspace == workspace

        return Button {
            withAnimation(RediMotion.selection) {
                selectedHouseholdWorkspace = workspace
            }
        } label: {
            RediCommandCard(
                title: workspace.title,
                detail: workspace.detail,
                iconName: workspace.iconName,
                tint: workspace.accent,
                badge: isSelected ? "Current" : nil,
                prominence: isSelected ? .accented : .neutral,
                minHeight: 108
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    @ViewBuilder
    private var householdBasicsContent: some View {
        PanelCard(
            title: "Go Bag Status",
            subtitle: goBagReadyToLeaveLine
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom, spacing: 12) {
                    Text(goBagStatusLabel)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(ColorTheme.text)
                    Text(goBagReadyToLeaveLine)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(goBagDepartureReady ? ColorTheme.ready : ColorTheme.warning)
                }

                Text("\(goBagViewModel.plan.readiness.completedCount) / \(goBagViewModel.plan.readiness.totalCount) items packed")
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)

                ReadinessMeter(
                    value: goBagViewModel.plan.readiness.progress,
                    tint: goBagViewModel.plan.readiness.percentage >= 67 ? ColorTheme.ready : ColorTheme.warning,
                    height: 11
                )

                Text(goBagTimeToReadyLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTheme.textSecondary)

                if goBagMissingCount > 0 {
                    Text("Missing critical items: \(goBagMissingCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ColorTheme.warning)
                }

                if !goBagViewModel.plan.nextActions.isEmpty {
                    checklistPreviewCard(
                        title: "Pack Next",
                        items: goBagViewModel.plan.nextActions,
                        tint: ColorTheme.warning
                    )
                }

                Button {
                    isShowingGoBag = true
                } label: {
                    RediCommandCard(
                        title: "Start Packing",
                        detail: "Open the detailed pack list, blockers, and section-by-section pack status.",
                        systemImage: "backpack.fill",
                        tint: ColorTheme.warning,
                        badge: goBagStatusLabel,
                        prominence: .accented,
                        layout: .rail
                    )
                }
                .buttonStyle(CardPressButtonStyle())
            }
        }

        PanelCard(title: "Emergency Kit Checklist", subtitle: "Core gear plus scenario prompts") {
            VStack(alignment: .leading, spacing: 18) {
                planningChecklistSection(
                    title: "Required First",
                    detail: "Cover these first before secondary lighting and backup gear.",
                    tint: ColorTheme.danger,
                    kinds: criticalChecklistKinds
                )

                Divider().background(ColorTheme.divider)

                planningChecklistSection(
                    title: "Secondary",
                    detail: "Add these once the medical and communications basics are already covered.",
                    tint: ColorTheme.warning,
                    kinds: importantChecklistKinds
                )
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
                            .tint(ColorTheme.accent)
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
                            .tint(ColorTheme.accent)
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

        PanelCard(
            title: "Evacuation Routes",
            subtitle: "Saved on device for blackout access"
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
    }

    @ViewBuilder
    private var householdSuppliesContent: some View {
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
                            .foregroundStyle(ColorTheme.textSecondary)
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

        Emergency72HourView(
            plan: viewModel.emergencyPlan,
            nearbyWaterSources: viewModel.nearbyWaterSources,
            waterSourceContext: viewModel.waterSourceContext,
            waterSourceStatusMessage: viewModel.waterSourceStatusMessage,
            isChecklistItemComplete: viewModel.isEmergencyChecklistItemComplete(_:),
            setChecklistItemComplete: viewModel.setEmergencyChecklistItem(_:isComplete:)
        )

        if !viewModel.preparednessGearRecommendations.isEmpty {
            PanelCard(title: "Missing Critical Items", subtitle: "Optional gear to close the biggest readiness gaps first") {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(viewModel.preparednessGearRecommendations) { recommendation in
                        preparednessGearRecommendationRow(recommendation)
                            .accessibilityIdentifier("plan.recommendation.\(recommendation.id)")
                    }

                    Text("Shown during planning only. Active emergency flows stay action-first.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
            }
            .accessibilityIdentifier("plan.recommendations.card")
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
    }

    @ViewBuilder
    private var householdRolesContent: some View {
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
                        .foregroundStyle(member.isPrimaryUser ? ColorTheme.accent : ColorTheme.text)

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
                            .foregroundStyle(ColorTheme.textTertiary)
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
    }

    @ViewBuilder
    private var householdScenariosContent: some View {
        PanelCard(title: "Scenario Tasks", subtitle: "Generated from selected hazards") {
            if viewModel.scenarioTasks.isEmpty {
                Text("Select local risks in onboarding or profile settings to generate scenario-specific planning tasks here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
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
                                .foregroundStyle(ColorTheme.textTertiary)
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

    private var householdReadinessLabel: String {
        readinessOperationalLabel(for: appState.prepScore.overall)
    }

    private var householdPriorityLine: String {
        guard let suggestion = householdPrioritySuggestion else {
            return "Current priority: Maintain routes, supplies, and household contacts."
        }

        switch suggestion.category {
        case .food:
            return "Current priority: Food supply below minimum threshold (\(viewModel.draft.supplies.foodDays.roundedIntString) days)"
        case .water:
            return "Current priority: Water reserve below target (\(viewModel.waterRuntimeEstimate.estimatedDaysText))"
        case .power:
            return "Current priority: Backup power is below baseline"
        case .communication:
            return "Current priority: Household communication plan is incomplete"
        case .medical:
            return "Current priority: Medical kit and critical records are incomplete"
        case .evacuation:
            return "Current priority: You are not ready to leave within 10 minutes"
        }
    }

    private var householdTargetLine: String {
        guard let suggestion = householdPrioritySuggestion else {
            return "Target: Keep your baseline current and review for seasonal risk changes."
        }

        switch suggestion.category {
        case .food:
            return "Target: 7-14 days of household food."
        case .water:
            return "Target: \(viewModel.waterRuntimeEstimate.recommendedReserveDays)-day household water reserve."
        case .power:
            return "Target: Lighting, charging, and battery backup staged."
        case .communication:
            return "Target: Local signal path and contact plan confirmed."
        case .medical:
            return "Target: Critical medications, first aid, and saved records."
        case .evacuation:
            return "Target: Route, meeting point, and go-time checks confirmed."
        }
    }

    private var householdTimeToReadyLine: String {
        let minutes = estimatedMinutesToBaseline
        guard minutes > 0 else {
            return "Estimated time to basic readiness: baseline covered."
        }

        return "Estimated time to basic readiness: \(formattedDuration(minutes: minutes))."
    }

    private var savedRouteCount: Int {
        viewModel.draft.evacuationRoutes.compactMap(\.nilIfBlank).count
    }

    private var orderedCategoryScores: [CategoryScore] {
        appState.prepScore.categoryScores.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score < rhs.score
            }
            return lhs.category.title < rhs.category.title
        }
    }

    private var criticalChecklistKinds: [ChecklistItemKind] {
        [.firstAidKit, .batteryRadio]
    }

    private var importantChecklistKinds: [ChecklistItemKind] {
        ChecklistItemKind.allCases.filter { !criticalChecklistKinds.contains($0) }
    }

    private var vehicleCriticalOutstandingCount: Int {
        vehicleKitViewModel.plan.items.filter { item in
            item.isCritical && !vehicleKitViewModel.isItemComplete(item.id)
        }.count
    }

    private var vehicleTimeToReadyLine: String {
        let minutes = max(vehicleCriticalOutstandingCount, 1) * 8
        return vehicleCriticalOutstandingCount == 0
            ? "Estimated time to move: baseline covered."
            : "Estimated time to move-ready: \(formattedDuration(minutes: minutes))."
    }

    private var vehicleTimeToReadyBadge: String? {
        vehicleCriticalOutstandingCount == 0 ? nil : "Time \(formattedDuration(minutes: max(vehicleCriticalOutstandingCount, 1) * 8))"
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

    private var goBagMissingCount: Int {
        goBagViewModel.plan.categories
            .flatMap(\.items)
            .filter { !goBagViewModel.isItemComplete($0.id) }
            .count
    }

    private var goBagDepartureReady: Bool {
        goBagViewModel.plan.nextActions.isEmpty
    }

    private var goBagStatusLabel: String {
        if goBagDepartureReady {
            return "READY"
        }
        if goBagViewModel.plan.readiness.percentage >= 67 {
            return "PARTIAL"
        }
        return "NOT READY"
    }

    private var goBagReadyToLeaveLine: String {
        "Ready to leave: \(goBagDepartureReady ? "YES" : "NO")"
    }

    private var goBagTimeToReadyLine: String {
        let blockers = max(min(goBagViewModel.plan.nextActions.count, 4), 1)
        return goBagDepartureReady
            ? "Estimated time to go-bag baseline: covered."
            : "Estimated time to go-bag baseline: \(formattedDuration(minutes: blockers * 6))."
    }

    private func readinessOperationalLabel(for score: Int) -> String {
        switch score {
        case ..<35:
            "LOW"
        case 35..<65:
            "GUARDED"
        case 65..<85:
            "STABLE"
        default:
            "READY"
        }
    }

    private func readinessSeverityLabel(for score: Int) -> String {
        switch score {
        case ..<20:
            "Critical"
        case 20..<45:
            "Low"
        case 45..<70:
            "Moderate"
        case 70..<100:
            "Stable"
        default:
            "Ready"
        }
    }

    private var estimatedMinutesToBaseline: Int {
        Array(appState.prepScore.suggestions.prefix(3)).reduce(0) { partialResult, suggestion in
            partialResult + estimatedMinutes(for: suggestion.category)
        }
    }

    private func estimatedMinutes(for category: PrepCategory) -> Int {
        switch category {
        case .water:
            10
        case .food:
            15
        case .medical:
            10
        case .power:
            15
        case .communication:
            5
        case .evacuation:
            12
        }
    }

    private func nextActionTitle(for suggestion: ImprovementSuggestion) -> String {
        switch suggestion.category {
        case .food:
            "Increase food supply to 7+ days"
        case .water:
            "Increase water reserve to target"
        case .medical:
            "Stage medical kit and critical records"
        case .power:
            "Stage backup power and lighting"
        case .communication:
            "Lock in household communication plan"
        case .evacuation:
            "Confirm route and departure plan"
        }
    }

    private func nextActionTimeLabel(for category: PrepCategory) -> String {
        "Time \(formattedDuration(minutes: estimatedMinutes(for: category)))"
    }

    private func formattedDuration(minutes: Int) -> String {
        guard minutes >= 60 else {
            return "~\(minutes) min"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if remainingMinutes == 0 {
            return "~\(hours) hr"
        }

        return "~\(hours) hr \(remainingMinutes) min"
    }

    private func customPlanningWorkspaceCard(for workspace: HouseholdWorkspace) -> some View {
        PlanningCustomTasksCard(
            title: "Custom Tasks",
            subtitle: "Your own checklist items and notes for the \(workspace.title.lowercased()) lane.",
            accent: workspace.accent,
            tasks: customPlanningTasks(for: workspace.planWorkspaceID),
            notes: customPlanningNotesBinding(for: workspace.planWorkspaceID),
            addTask: { title, note in
                addCustomPlanningTask(title: title, note: note, to: workspace.planWorkspaceID)
            },
            toggleTask: { taskID in
                toggleCustomPlanningTask(taskID, in: workspace.planWorkspaceID)
            },
            deleteTask: { taskID in
                deleteCustomPlanningTask(taskID, from: workspace.planWorkspaceID)
            },
            updateTaskTitle: { taskID, title in
                updateCustomPlanningTask(taskID, in: workspace.planWorkspaceID) { $0.title = title }
            },
            updateTaskNote: { taskID, note in
                updateCustomPlanningTask(taskID, in: workspace.planWorkspaceID) { $0.note = note }
            }
        )
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

    private func planningChecklistSection(
        title: String,
        detail: String,
        tint: Color,
        kinds: [ChecklistItemKind]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(RediTypography.caption)
                    .foregroundStyle(tint)

                Spacer(minLength: 0)

                Text("\(checklistCompletedCount(for: kinds)) / \(kinds.count)")
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textTertiary)
            }

            Text(detail)
                .font(.caption.weight(.medium))
                .foregroundStyle(ColorTheme.textSecondary)

            ForEach(kinds) { kind in
                Toggle(isOn: checklistBinding(for: kind)) {
                    Text(kind.title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                }
                .toggleStyle(.switch)
                .tint(tint)
                .accessibilityIdentifier("plan.checklist.\(kind.rawValue)")
                .padding(14)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }

    private func checklistCompletedCount(for kinds: [ChecklistItemKind]) -> Int {
        kinds.filter { checklistBinding(for: $0).wrappedValue }.count
    }

    private func checklistBinding(for kind: ChecklistItemKind) -> Binding<Bool> {
        Binding(
            get: {
                viewModel.draft.checklistItems.first(where: { $0.kind == kind })?.isChecked ?? false
            },
            set: { newValue in
                guard let index = viewModel.draft.checklistItems.firstIndex(where: { $0.kind == kind }) else {
                    return
                }
                viewModel.draft.checklistItems[index].isChecked = newValue
            }
        )
    }

    private func customPlanningTasks(for workspaceID: PlanWorkspaceID) -> [PlanCustomTask] {
        viewModel.draft.customPlanningWorkspace(workspaceID).tasks
    }

    private func customPlanningNotesBinding(for workspaceID: PlanWorkspaceID) -> Binding<String> {
        Binding(
            get: {
                viewModel.draft.customPlanningWorkspace(workspaceID).notes
            },
            set: { newValue in
                mutateCustomPlanningWorkspace(workspaceID) { workspace in
                    workspace.notes = newValue
                }
            }
        )
    }

    private func addCustomPlanningTask(title: String, note: String, to workspaceID: PlanWorkspaceID) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return
        }

        mutateCustomPlanningWorkspace(workspaceID) { workspace in
            workspace.tasks.append(
                PlanCustomTask(
                    title: trimmedTitle,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }
    }

    private func toggleCustomPlanningTask(_ taskID: UUID, in workspaceID: PlanWorkspaceID) {
        updateCustomPlanningTask(taskID, in: workspaceID) { task in
            task.isCompleted.toggle()
        }
    }

    private func deleteCustomPlanningTask(_ taskID: UUID, from workspaceID: PlanWorkspaceID) {
        mutateCustomPlanningWorkspace(workspaceID) { workspace in
            workspace.tasks.removeAll { $0.id == taskID }
        }
    }

    private func updateCustomPlanningTask(
        _ taskID: UUID,
        in workspaceID: PlanWorkspaceID,
        update: (inout PlanCustomTask) -> Void
    ) {
        mutateCustomPlanningWorkspace(workspaceID) { workspace in
            guard let index = workspace.tasks.firstIndex(where: { $0.id == taskID }) else {
                return
            }
            update(&workspace.tasks[index])
        }
    }

    private func mutateCustomPlanningWorkspace(
        _ workspaceID: PlanWorkspaceID,
        update: (inout PlanWorkspaceCustomData) -> Void
    ) {
        let index = customPlanningWorkspaceIndex(for: workspaceID)
        update(&viewModel.draft.customPlanningWorkspaces[index])
    }

    private func customPlanningWorkspaceIndex(for workspaceID: PlanWorkspaceID) -> Int {
        if let index = viewModel.draft.customPlanningWorkspaces.firstIndex(where: { $0.id == workspaceID }) {
            return index
        }

        viewModel.draft.customPlanningWorkspaces.append(PlanWorkspaceCustomData(id: workspaceID))
        return viewModel.draft.customPlanningWorkspaces.count - 1
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
                .tint(ColorTheme.textTertiary)
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
                .foregroundStyle(ColorTheme.textTertiary)
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

    private func preparednessGearRecommendationRow(_ recommendation: PreparednessGearRecommendation) -> some View {
        PreparednessGearRecommendationCard(recommendation: recommendation) {
            selectedPreparednessGearRecommendation = recommendation
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
                .foregroundStyle(ColorTheme.textTertiary)
                .frame(width: 24, height: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(task.memberName) - \(task.role)")
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
                Text(task.taskTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTheme.textSecondary)
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
        .foregroundStyle(selectedRole == role ? ColorTheme.accent : ColorTheme.text)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            selectedRole == role ? ColorTheme.accent.opacity(0.16) : Color.black.opacity(0.24),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    selectedRole == role ? ColorTheme.accent.opacity(0.35) : ColorTheme.dividerStrong,
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
                selectedHouseholdWorkspace = .prepare
            }
            DispatchQueue.main.async {
                proxy.scrollTo(PlanFocus.householdOverview, anchor: .top)
            }
        case .waterRuntime:
            withAnimation(RediMotion.selection) {
                selectedSection = .household
                selectedHouseholdWorkspace = .supplies
            }
            DispatchQueue.main.async {
                proxy.scrollTo(PlanFocus.waterRuntime, anchor: .top)
            }
        case .evacuationRoutes:
            withAnimation(RediMotion.selection) {
                selectedSection = .household
                selectedHouseholdWorkspace = .basics
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
        case .supplies:
            withAnimation(RediMotion.selection) {
                selectedSection = .household
                selectedHouseholdWorkspace = .supplies
            }
            DispatchQueue.main.async {
                proxy.scrollTo(PlanFocus.supplies, anchor: .top)
            }
        case .medicalProfile:
            withAnimation(RediMotion.selection) {
                selectedSection = .household
                selectedHouseholdWorkspace = .basics
            }
            DispatchQueue.main.async {
                proxy.scrollTo(PlanFocus.medicalProfile, anchor: .top)
            }
        case .gearChecklist:
            withAnimation(RediMotion.selection) {
                selectedSection = .household
                selectedHouseholdWorkspace = .basics
            }
            DispatchQueue.main.async {
                proxy.scrollTo(PlanFocus.gearChecklist, anchor: .top)
            }
        }

        DispatchQueue.main.async {
            self.requestedFocus = nil
        }
    }

    private enum PlanScrollAnchor {
        static let top = "plan-scroll-top"
    }

    private func scrollToPlanTop(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(RediMotion.selection) {
                proxy.scrollTo(PlanScrollAnchor.top, anchor: .top)
            }
        }
    }
}
