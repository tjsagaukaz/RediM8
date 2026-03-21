import SwiftUI

struct MapOfficialAlertsContentView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: MapViewModel
    @Binding var selectedScope: MapOfficialAlertScope
    @Binding var selectedJurisdiction: AustralianJurisdiction?
    let scopeOptions: [PremiumSegmentedControlOption<MapOfficialAlertScope>]
    let selectedSummary: MapOfficialAlertSummary
    let selectedAlerts: [OfficialAlert]
    let effectiveJurisdiction: AustralianJurisdiction?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PremiumSegmentedControl(items: scopeOptions, selection: $selectedScope)

            if selectedScope == .state {
                officialAlertJurisdictionPicker
            }

            HStack(alignment: .top, spacing: 12) {
                RediIcon(selectedAlerts.first?.kind.systemImage ?? "warning")
                    .foregroundStyle(MapTonePalette.color(for: selectedSummary.tone))
                    .frame(width: 18, height: 18)
                    .padding(10)
                    .background(
                        MapTonePalette.color(for: selectedSummary.tone).opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("OFFICIAL ALERTS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MapTonePalette.color(for: selectedSummary.tone))
                    Text(selectedSummary.title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text(selectedSummary.detail)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textMuted)
                }

                Spacer(minLength: 0)
            }

            TrustPillGroup(items: viewModel.scopedOfficialAlertTrustItems(for: selectedScope, jurisdiction: effectiveJurisdiction))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    officialAlertMetaCard(
                        title: "Official Feed",
                        value: selectedAlerts.first?.issuer ?? "Cached mirror"
                    )
                    officialAlertMetaCard(
                        title: "Scope",
                        value: selectedScope == .state
                            ? (effectiveJurisdiction?.title ?? "Select a state")
                            : selectedScope.title
                    )
                }

                VStack(spacing: 12) {
                    officialAlertMetaCard(
                        title: "Official Feed",
                        value: selectedAlerts.first?.issuer ?? "Cached mirror"
                    )
                    officialAlertMetaCard(
                        title: "Scope",
                        value: selectedScope == .state
                            ? (effectiveJurisdiction?.title ?? "Select a state")
                            : selectedScope.title
                    )
                }
            }

            if let countSummary = viewModel.officialAlertCountSummary(for: selectedScope, jurisdiction: effectiveJurisdiction) {
                Text(countSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if selectedAlerts.isEmpty {
                Text("No active alerts are currently listed for this scope.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(Array(selectedAlerts.prefix(4))) { alert in
                    MapOfficialAlertRow(
                        alert: alert,
                        scope: selectedScope,
                        tone: MapTonePalette.color(for: selectedSummary.tone),
                        viewModel: viewModel,
                        openURL: openURL.callAsFunction
                    )
                }
            }

            if selectedAlerts.count > 4 {
                Text("Showing the first 4 of \(selectedAlerts.count) alerts in this scope.")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)
            }

            Text("Official source labels remain separate from RediM8's readable summary so you can judge the warning against the issuing agency.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if selectedScope == .local {
                Text("Switch to State or Australia when you need a wider family or travel view.")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var officialAlertJurisdictionPicker: some View {
        Menu {
            ForEach(viewModel.availableOfficialAlertJurisdictions) { jurisdiction in
                Button {
                    selectedJurisdiction = jurisdiction
                } label: {
                    if jurisdiction == effectiveJurisdiction {
                        Label(jurisdiction.title, systemImage: "checkmark")
                    } else {
                        Text(jurisdiction.title)
                    }
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STATE FEED")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ColorTheme.textMuted)
                    Text(effectiveJurisdiction?.title ?? "Select a state or territory")
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.textMuted)
            }
            .padding(14)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func officialAlertMetaCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.textMuted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MapInstalledCoveragePreview: View {
    @ObservedObject var viewModel: MapViewModel

    var body: some View {
        Group {
            if let highlightedPack = viewModel.installedPacks.first ?? viewModel.availablePacks.first {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(viewModel.installedPacks.isEmpty ? "Coverage Preview" : "Installed Pack Boundary")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ColorTheme.textFaint)
                        Spacer()
                        Text(highlightedPack.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(viewModel.installedPacks.isEmpty ? ColorTheme.warning : ColorTheme.ready)
                    }

                    MapPackCoveragePreview(
                        pack: highlightedPack,
                        isInstalled: viewModel.installedPackIDs.contains(highlightedPack.id),
                        accent: viewModel.installedPackIDs.contains(highlightedPack.id) ? ColorTheme.ready : ColorTheme.info
                    )

                    Text(viewModel.installedPacks.isEmpty
                         ? "No regional pack is installed yet. This preview shows how pack boundaries limit offline water, shelter, and track coverage."
                         : "Coverage stops at this boundary. Outside it, RediM8 falls back to the basemap and saved markers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

struct MapNearbySummaryCard: View {
    let title: String
    let subtitle: String
    let detail: String
    let iconName: String
    let accent: Color
    let trustItems: [TrustPillItem]
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        subtitle: String,
        detail: String,
        iconName: String,
        accent: Color,
        trustItems: [TrustPillItem],
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.iconName = iconName
        self.accent = accent
        self.trustItems = trustItems
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                MapAssetIcon(assetName: iconName, size: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
            }

            TrustPillGroup(items: trustItems)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }
}

struct MapWaterPriorityCard: View {
    let point: WaterPoint
    @ObservedObject var viewModel: MapViewModel

    var body: some View {
        MapNearbySummaryCard(
            title: point.name,
            subtitle: "\(point.kind.title) • \(viewModel.waterDistanceText(for: point))",
            detail: point.notes,
            iconName: point.kind.mapMarkerAssetName,
            accent: point.quality == .drinkingWater ? ColorTheme.water : (point.quality == .nonPotable ? ColorTheme.warning : ColorTheme.info),
            trustItems: viewModel.waterTrustItems(for: point)
        )
    }
}

struct MapWaterPointRow: View {
    let point: WaterPoint
    @ObservedObject var viewModel: MapViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                MapAssetIcon(assetName: point.kind.mapMarkerAssetName, size: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(point.name)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text("\(point.kind.title) • \(viewModel.waterDistanceText(for: point))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                WaterQualityPill(
                    title: point.quality.title,
                    tint: point.quality == .drinkingWater ? ColorTheme.water : (point.quality == .nonPotable ? ColorTheme.warning : ColorTheme.info)
                )
            }

            TrustPillGroup(items: viewModel.waterTrustItems(for: point))

            Text(point.notes)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            Text(point.source)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MapTrackRow: View {
    let track: TrackSegment
    @ObservedObject var viewModel: MapViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                MapAssetIcon(assetName: track.kind.mapMarkerAssetName, size: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.name)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text("\(track.kind.title) • \(viewModel.distanceText(to: track.midpoint))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if track.kind == .fireTrail {
                Text("Surface: \(track.surface.title)")
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)
                Text("Vehicle: \(track.vehicleAdvice?.title ?? "Check locally")")
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)
                Text("Purpose: \(track.purpose?.title ?? "Emergency Access")")
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)
            } else {
                Text("Surface: \(track.surface.title) • Vehicle: \(track.vehicleAdvice?.title ?? "Check locally")")
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.text)
            }

            TrustPillGroup(items: viewModel.trackTrustItems(for: track))

            if !track.safetyLabels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(track.safetyLabels) { label in
                            TrustBadge(
                                title: label.title,
                                tint: viewModel.trackSafetyColor(for: label)
                            )
                        }
                    }
                }
            }

            Text(track.notes)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            Text(track.source)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MapBeaconRow: View {
    let beacon: CommunityBeacon
    @ObservedObject var viewModel: MapViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MapAssetIcon(
                assetName: beacon.type.mapMarkerAssetName,
                fallbackSystemName: beacon.type.symbolName,
                size: 24
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(beacon.type.title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    if beacon.id == viewModel.activeBeacon?.id {
                        Text("This device")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ColorTheme.ready)
                    }
                    if beacon.type.isPriorityReport {
                        Text("Priority")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ColorTheme.danger)
                    }
                }
                Text("\(beacon.displayLabel) • \(viewModel.beaconDistanceText(for: beacon))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TrustPillGroup(items: viewModel.beaconTrustItems(for: beacon))

                Text(beacon.statusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ColorTheme.text)

                if !beacon.signalHighlights.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(beacon.signalHighlights.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 8) {
                                Text(item.label)
                                    .font(RediTypography.caption)
                                    .foregroundStyle(ColorTheme.textFaint)
                                    .frame(width: 72, alignment: .leading)
                                Text(item.value)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(ColorTheme.text)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                Text(beacon.locationName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.textSecondary)
                if let message = beacon.message.nilIfBlank {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let sharedEmergencyMedicalSummary = beacon.sharedEmergencyMedicalSummary {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MEDICAL NOTE SHARED")
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.danger)
                        Text(sharedEmergencyMedicalSummary)
                            .font(.caption)
                            .foregroundStyle(ColorTheme.text)
                    }
                    .padding(.top, 2)
                }
                Text("Expires \(beacon.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let staleWarning = viewModel.beaconStaleWarning(for: beacon) {
                    Text(staleWarning)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                } else if let relayDelayNotice = beacon.relayDelayNotice {
                    Text(relayDelayNotice)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.warning)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MapOfficialAlertRow: View {
    let alert: OfficialAlert
    let scope: MapOfficialAlertScope
    let tone: Color
    @ObservedObject var viewModel: MapViewModel
    let openURL: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                MapAssetIcon(
                    assetName: alert.kind.mapMarkerAssetName,
                    fallbackSystemName: alert.kind.systemImage,
                    size: 24
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text("\(alert.severity.title) • \(viewModel.officialAlertScopeLine(for: alert, scope: scope))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                TrustBadge(title: alert.kind.title, tint: tone)
            }

            TrustPillGroup(items: viewModel.officialAlertTrustItems(for: alert))

            Text(alert.regionScope)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ColorTheme.text)

            Text(alert.message)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            if let instruction = alert.instruction {
                Text(instruction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(viewModel.officialAlertUpdatedLine(for: alert))
                .font(.caption)
                .foregroundStyle(ColorTheme.textMuted)

            Text(viewModel.officialAlertSafetyNote(for: alert))
                .font(.caption)
                .foregroundStyle(tone)

            if let sourceURL = alert.sourceURL {
                Button("Open Official Source") {
                    openURL(sourceURL)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
