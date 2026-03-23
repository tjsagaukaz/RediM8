import SwiftUI

// MARK: - Communicate Workspace (Send + Reports)

struct SignalCommunicateWorkspaceView: View {
    @ObservedObject var viewModel: SignalViewModel
    let signalStatusColor: Color
    let quickMessageTemplates: [String]
    var assistantContextAction: (AssistantLaunchContext) -> Void

    var body: some View {
        sendWorkspaceContent
        reportsWorkspaceContent
    }

    // MARK: - Send Panel

    private var sendWorkspaceContent: some View {
        VStack(spacing: 16) {
            sendUpdatePanel
        }
    }

    private var sendUpdatePanel: some View {
        PanelCard(title: "Send Signal", subtitle: "Short transmission only. Optimised for low signal.") {
            VStack(alignment: .leading, spacing: 14) {
                signalCommandStatusGrid

                Button {
                    assistantContextAction(AssistantLaunchContext(
                        initialQuery: signalAssistantQuery,
                        sourceLabel: "Signal context"
                    ))
                } label: {
                    RediCommandCard(
                        title: "Ask RediM8",
                        detail: signalAssistantDetail,
                        systemImage: "bubble.left.and.text.bubble.right.fill",
                        tint: signalStatusColor,
                        badge: "Context",
                        prominence: .accented,
                        layout: .rail
                    )
                }
                .buttonStyle(CardPressButtonStyle())

                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Starts")
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(quickMessageTemplates, id: \.self) { template in
                                messageTemplateButton(template)
                            }
                        }
                    }
                }

                TextField("What do others need to know?", text: $viewModel.draftMessage, axis: .vertical)
                    .lineLimit(4...8)
                    .textFieldStyle(TacticalTextFieldStyle())
                    .frame(minHeight: 108, alignment: .topLeading)
                    .disabled(!viewModel.canBroadcastOutboundSignals)

                Text("Use short text such as NEED WATER or FIRE NEARBY.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let composeAvailabilityMessage = viewModel.composeAvailabilityMessage {
                    Text(composeAvailabilityMessage)
                        .font(.caption)
                        .foregroundStyle(viewModel.canBroadcastOutboundSignals ? .secondary : ColorTheme.warning)
                }

                SignalViewHelpers.signalInsetCard(tint: ColorTheme.danger) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WHEN TO USE BROADCAST")
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.danger)

                        SignalViewHelpers.signalGuidanceLine("No signal or network")
                        SignalViewHelpers.signalGuidanceLine("Urgent situation nearby")
                        SignalViewHelpers.signalGuidanceLine("Need help or need to warn others")
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(ColorTheme.accent)
                    Text("Session activity stays in memory only on this phone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Reports Panel

    private var reportsWorkspaceContent: some View {
        VStack(spacing: 16) {
            communitySituationReportsPanel
        }
    }

    private var communitySituationReportsPanel: some View {
        PanelCard(title: "Community Reports", subtitle: "Broadcast short local reports that can carry while they stay fresh") {
            VStack(alignment: .leading, spacing: 16) {
                Text(TrustLayer.beaconVerificationReminder)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TrustPillGroup(items: viewModel.draftBeaconTrustItems)

                if let activeBeacon = viewModel.activeBeacon {
                    activeBeaconCard(activeBeacon)
                }

                if !urgentSituationReportTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Urgent")
                            .font(RediTypography.heading)
                            .foregroundStyle(ColorTheme.text)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(urgentSituationReportTypes) { type in
                                SignalViewHelpers.situationReportButton(type, isSelected: viewModel.selectedBeaconType == type) {
                                    viewModel.selectSituationReport(type)
                                }
                            }
                        }
                    }
                }

                if !importantSituationReportTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Important")
                            .font(RediTypography.heading)
                            .foregroundStyle(ColorTheme.text)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(importantSituationReportTypes) { type in
                                SignalViewHelpers.situationReportButton(type, isSelected: viewModel.selectedBeaconType == type) {
                                    viewModel.selectSituationReport(type)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Starts")
                        .font(RediTypography.heading)
                        .foregroundStyle(ColorTheme.text)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(quickMessageTemplates, id: \.self) { template in
                                reportQuickTemplateButton(template)
                            }
                        }
                    }
                }

                if !viewModel.secondaryBeaconTypes.isEmpty {
                    Picker("Other report types", selection: $viewModel.selectedBeaconType) {
                        ForEach(viewModel.secondaryBeaconTypes) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Text(viewModel.selectedReportLifetimeSummary)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textSecondary)

                TextField(viewModel.selectedReportLocationPrompt, text: $viewModel.beaconLocationName)
                    .textFieldStyle(TacticalTextFieldStyle())

                TextField(viewModel.selectedReportMessagePrompt, text: $viewModel.beaconMessage, axis: .vertical)
                    .textFieldStyle(TacticalTextFieldStyle())

                signalIntelligenceEditor

                if viewModel.selectedBeaconType.supportsEmergencyMedicalDisclosure {
                    SignalViewHelpers.signalInsetCard(tint: viewModel.includesEmergencyMedicalInfo ? ColorTheme.danger : ColorTheme.accent) {
                        Toggle("Include emergency medical info", isOn: $viewModel.includesEmergencyMedicalInfo)
                            .toggleStyle(.switch)
                            .foregroundStyle(ColorTheme.text)
                            .disabled(!viewModel.canAttachEmergencyMedicalInfo)

                        if let emergencyMedicalInfoStatusMessage = viewModel.emergencyMedicalInfoStatusMessage {
                            Text(emergencyMedicalInfoStatusMessage)
                                .font(.caption)
                                .foregroundStyle(viewModel.hasEmergencyMedicalInfo ? ColorTheme.textSecondary : ColorTheme.warning)
                        }

                        if let emergencyMedicalBroadcastPreview = viewModel.emergencyMedicalBroadcastPreview {
                            SignalViewHelpers.sharedMedicalInfoBlock(emergencyMedicalBroadcastPreview)
                        }
                    }
                }

                Toggle("Show optional display name", isOn: $viewModel.showsName)
                    .toggleStyle(.switch)
                    .foregroundStyle(ColorTheme.text)
                    .disabled(!viewModel.isDisplayNameControlEnabled)

                if !viewModel.isDisplayNameControlEnabled {
                    Text("Show Device Name is off in Settings, so nearby users will only see your node ID.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if viewModel.showsName {
                    TextField("Display name", text: $viewModel.displayName)
                        .textFieldStyle(TacticalTextFieldStyle())
                }

                if !orderedSelectedResources.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Linked tags")
                            .font(RediTypography.heading)
                            .foregroundStyle(ColorTheme.text)
                        BeaconResourceWrap(resources: orderedSelectedResources) { resource in
                            BeaconResourcePill(resource: resource, isSelected: true, action: {})
                        }
                    }
                }

                if let beaconAvailabilityMessage = viewModel.beaconAvailabilityMessage {
                    Text(beaconAvailabilityMessage)
                        .font(.caption)
                        .foregroundStyle(viewModel.canUseBeaconMode ? ColorTheme.danger : ColorTheme.warning)
                }

                Button {
                    viewModel.activateBeacon()
                } label: {
                    Label(viewModel.beaconActionTitle, systemImage: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(viewModel.beaconAvailabilityMessage != nil && viewModel.activeBeacon == nil)
            }
        }
    }

    // MARK: - Active Beacon Card

    private func activeBeaconCard(_ activeBeacon: CommunityBeacon) -> some View {
        SignalViewHelpers.signalInsetCard(tint: SignalViewHelpers.beaconAccentColor(for: activeBeacon.type)) {
            HStack(alignment: .top) {
                BeaconTypeBadge(type: activeBeacon.type)
                Spacer()
                Text("Broadcasting")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.ready)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ColorTheme.ready.opacity(0.14), in: Capsule())
            }

            Text(activeBeacon.type.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(ColorTheme.text)

            TrustPillGroup(items: viewModel.activeBeaconTrustItems(for: activeBeacon))

            Text(activeBeacon.displayLabel)
                .font(RediTypography.body)
                .foregroundStyle(.secondary)

            if let message = activeBeacon.message.nilIfBlank {
                Text(message)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.text)
            }

            if !activeBeacon.signalHighlights.isEmpty {
                SignalViewHelpers.signalHighlightsBlock(activeBeacon.signalHighlights, accent: SignalViewHelpers.beaconAccentColor(for: activeBeacon.type))
            }

            if let sharedEmergencyMedicalSummary = activeBeacon.sharedEmergencyMedicalSummary {
                SignalViewHelpers.sharedMedicalInfoBlock(sharedEmergencyMedicalSummary)
            }

            Text(activeBeacon.locationName)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.accent)

            if !activeBeacon.resources.isEmpty {
                BeaconResourceWrap(resources: activeBeacon.resources) { resource in
                    BeaconResourcePill(resource: resource, isSelected: true, action: {})
                }
            }

            Text("Expires \(activeBeacon.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let staleWarning = viewModel.beaconStaleWarning(for: activeBeacon) {
                Text(staleWarning)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.warning)
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.refreshBeacon()
                } label: {
                    Label("Refresh Broadcast", systemImage: "arrow.clockwise")
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button {
                    viewModel.deactivateBeacon()
                } label: {
                    Label("Stop Broadcast", systemImage: "xmark.circle")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }

    // MARK: - Intelligence Editor

    private var signalIntelligenceEditor: some View {
        SignalViewHelpers.signalInsetCard(tint: SignalViewHelpers.beaconAccentColor(for: viewModel.selectedBeaconType)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Report Details")
                    .font(RediTypography.heading)
                    .foregroundStyle(ColorTheme.text)

                HStack(spacing: 10) {
                    SignalViewHelpers.signalMetadataPicker(
                        title: "Severity",
                        selectionText: viewModel.selectedSeverity.title
                    ) {
                        Picker("Severity", selection: $viewModel.selectedSeverity) {
                            ForEach(BeaconSeverity.allCases) { severity in
                                Text(severity.title).tag(severity)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    SignalViewHelpers.signalMetadataPicker(
                        title: "Confidence",
                        selectionText: viewModel.selectedConfidence.title
                    ) {
                        Picker("Confidence", selection: $viewModel.selectedConfidence) {
                            ForEach(BeaconConfidence.allCases) { confidence in
                                Text(confidence.title).tag(confidence)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if viewModel.selectedBeaconType.supportsDirectionHint,
                   let detailPrompt = viewModel.selectedBeaconType.detailPrompt {
                    TextField(detailPrompt, text: $viewModel.directionHint)
                        .textFieldStyle(TacticalTextFieldStyle())
                }

                if viewModel.selectedBeaconType.supportsRouteCondition {
                    SignalViewHelpers.signalMetadataPicker(
                        title: "Route",
                        selectionText: viewModel.selectedRouteCondition.title
                    ) {
                        Picker("Route", selection: $viewModel.selectedRouteCondition) {
                            ForEach(BeaconRouteCondition.allCases) { routeCondition in
                                Text(routeCondition.title).tag(routeCondition)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if viewModel.selectedBeaconType.supportsWaterSafety {
                    SignalViewHelpers.signalMetadataPicker(
                        title: "Water Safety",
                        selectionText: viewModel.selectedWaterSafety.title
                    ) {
                        Picker("Water Safety", selection: $viewModel.selectedWaterSafety) {
                            ForEach(BeaconWaterSafety.allCases) { waterSafety in
                                Text(waterSafety.title).tag(waterSafety)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if viewModel.selectedBeaconType.supportsShelterStatus {
                    SignalViewHelpers.signalMetadataPicker(
                        title: "Shelter Status",
                        selectionText: viewModel.selectedShelterStatus.title
                    ) {
                        Picker("Shelter Status", selection: $viewModel.selectedShelterStatus) {
                            ForEach(BeaconShelterStatus.allCases) { shelterStatus in
                                Text(shelterStatus.title).tag(shelterStatus)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if viewModel.selectedBeaconType.supportsShelterCapacityNote {
                    TextField("Capacity or access note", text: $viewModel.shelterCapacityNote)
                        .textFieldStyle(TacticalTextFieldStyle())
                }

                if viewModel.selectedBeaconType.supportsBatteryLevel {
                    TextField("Battery % (optional)", text: $viewModel.batteryLevelText)
                        .textFieldStyle(TacticalTextFieldStyle())
                        .keyboardType(.numberPad)
                }

                SignalViewHelpers.signalHighlightsBlock(viewModel.selectedSignalHighlights, accent: SignalViewHelpers.beaconAccentColor(for: viewModel.selectedBeaconType))
            }
        }
    }

    // MARK: - Command Status Grid

    private var signalCommandColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 108, maximum: 170), spacing: 10)
        ]
    }

    private var signalCommandStatusGrid: some View {
        LazyVGrid(columns: signalCommandColumns, spacing: 10) {
            SignalViewHelpers.commandStatusTile(
                title: "Broadcast Alert",
                value: broadcastDockStatus,
                detail: "Emergency message to nearby devices",
                iconName: "exclamationmark.triangle.fill",
                tint: canTriggerBroadcast ? ColorTheme.danger : ColorTheme.warning
            )
            SignalViewHelpers.commandStatusTile(
                title: "Share Location",
                value: shareDockStatus,
                detail: canShareCurrentLocation ? "Current position ready" : shareDockDetail,
                iconName: "location.fill",
                tint: canShareCurrentLocation ? ColorTheme.accent : ColorTheme.warning
            )
            SignalViewHelpers.commandStatusTile(
                title: "Send Report",
                value: reportDockStatus,
                detail: viewModel.activeBeacon == nil ? (canManageReport ? "Short local report" : "Enable reports + GPS") : "Live report broadcasting",
                iconName: "dot.radiowaves.left.and.right",
                tint: reportDockTint
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Template Buttons

    private func messageTemplateButton(_ template: String) -> some View {
        let tint = SignalViewHelpers.quickTemplateTint(for: template)

        return Button(template) {
            viewModel.draftMessage = template
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.26), lineWidth: 1)
        )
        .buttonStyle(CardPressButtonStyle())
    }

    private func reportQuickTemplateButton(_ template: String) -> some View {
        let tint = SignalViewHelpers.quickTemplateTint(for: template)

        return Button(template) {
            viewModel.applyStructuredQuickSignal(template)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.26), lineWidth: 1)
        )
        .buttonStyle(CardPressButtonStyle())
    }

    // MARK: - Computed Helpers

    private var trimmedDraftMessage: String {
        viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasDraftMessage: Bool {
        !trimmedDraftMessage.isEmpty
    }

    private var canTriggerBroadcast: Bool {
        viewModel.canBroadcastOutboundSignals && hasDraftMessage
    }

    private var canShareCurrentLocation: Bool {
        viewModel.canShareLocation && viewModel.currentLocation != nil
    }

    private var canManageReport: Bool {
        viewModel.activeBeacon != nil || viewModel.beaconAvailabilityMessage == nil
    }

    private var broadcastDockStatus: String {
        if !viewModel.canBroadcastOutboundSignals {
            return "Receive-only"
        }
        return hasDraftMessage ? "Ready" : "Need Text"
    }

    private var shareDockStatus: String {
        if !viewModel.canShareLocation {
            return "Location Off"
        }
        return viewModel.currentLocation == nil ? "Need GPS" : "Ready"
    }

    private var reportDockStatus: String {
        if viewModel.activeBeacon != nil {
            return "Live"
        }
        return canManageReport ? "Ready" : "Need GPS"
    }

    private var shareDockDetail: String {
        if !viewModel.canShareLocation {
            return "Location sharing off"
        }
        return "GPS lock pending"
    }

    private var reportDockTint: Color {
        if let activeBeacon = viewModel.activeBeacon {
            return SignalViewHelpers.beaconAccentColor(for: activeBeacon.type)
        }

        if canManageReport {
            return SignalViewHelpers.beaconAccentColor(for: viewModel.selectedBeaconType)
        }

        return ColorTheme.warning
    }

    private var signalAssistantQuery: String? {
        if let activeBeacon = viewModel.activeBeacon {
            return "What should I do about \(activeBeacon.type.title.lowercased()) nearby?"
        }

        if !trimmedDraftMessage.isEmpty {
            return trimmedDraftMessage
        }

        return "What should I do about \(viewModel.selectedBeaconType.title.lowercased()) nearby?"
    }

    private var signalAssistantDetail: String {
        if let activeBeacon = viewModel.activeBeacon {
            return "Get next steps using the live \(activeBeacon.type.title.lowercased()) context before you transmit."
        }

        if !trimmedDraftMessage.isEmpty {
            return "Turn this draft into clear next steps before you send it."
        }

        return "Get next steps based on your current signal and report context."
    }

    private var urgentSituationReportTypes: [BeaconType] {
        let urgentOrder: [BeaconType] = [.fireSpotted, .medicalHelp, .floodedRoad]
        return urgentOrder.filter(viewModel.situationReportTypes.contains)
    }

    private var importantSituationReportTypes: [BeaconType] {
        viewModel.situationReportTypes.filter { !urgentSituationReportTypes.contains($0) }
    }

    private var orderedSelectedResources: [BeaconResource] {
        viewModel.selectedResources.sorted { $0.title < $1.title }
    }
}
