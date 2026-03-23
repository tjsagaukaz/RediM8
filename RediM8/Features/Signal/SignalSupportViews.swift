import SwiftUI

// MARK: - Shared Types

enum SignalWorkspace: String, CaseIterable, Identifiable {
    case communicate
    case network
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .communicate: "Messages"
        case .network: "Peers"
        case .system: "Status"
        }
    }

    var subtitle: String {
        switch self {
        case .communicate: "Broadcasts, direct signals, and field reports"
        case .network: "Nearby devices, roll call, and relayed reports"
        case .system: "Scanner, limits, and session activity"
        }
    }
}

enum SignalScrollSpace {
    static let name = "signal-scroll"
}

struct SignalScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

enum SignalDockButtonProminence {
    case critical
    case accented
    case standard
}

struct SignalFailureRowModel: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let iconName: String
    let tint: Color
}

// MARK: - Beacon Components

struct BeaconTypeBadge: View {
    let type: BeaconType

    var body: some View {
        RediIcon(type.symbolName)
            .foregroundStyle(foreground)
            .frame(width: 18, height: 18)
            .padding(10)
            .background(background, in: Circle())
    }

    private var foreground: Color {
        ColorTheme.textTertiary
    }

    private var background: Color {
        foreground.opacity(0.16)
    }
}

struct BeaconResourceWrap<Content: View>: View {
    let resources: [BeaconResource]
    @ViewBuilder let content: (BeaconResource) -> Content

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(resources) { resource in
                content(resource)
            }
        }
    }
}

struct BeaconResourcePill: View {
    let resource: BeaconResource
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(RediTypography.label)
                Text(resource.title)
                    .font(RediTypography.bodyStrong)
            }
            .foregroundStyle(isSelected ? ColorTheme.text : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PremiumSurfaceBackground(
                    cornerRadius: RediRadius.button,

                    atmosphere: (isSelected ? ColorTheme.accent : ColorTheme.textSecondary).opacity(isSelected ? 0.14 : 0.04)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
            .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.button, edgeColor: (isSelected ? ColorTheme.accent : ColorTheme.dividerStrong).opacity(0.16), shadowColor: ColorTheme.accent.opacity(0.03)))
        }
        .buttonStyle(CardPressButtonStyle())
    }
}

// MARK: - MeshMessage Extension

extension MeshMessage {
    var kindLabel: String {
        switch kind {
        case .direct:
            "Direct"
        case .broadcastAlert:
            "Alert"
        case .locationShare:
            "Location"
        case .accountabilityStatus:
            "Roll Call"
        case .routeShare:
            "Route"
        case .hazardReport:
            "Hazard"
        }
    }
}

// MARK: - Shared Signal View Helpers

/// Reusable view-building functions used across multiple Signal workspace views.
enum SignalViewHelpers {

    static func signalInsetCard<Content: View>(
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.card,

                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.card, edgeColor: tint.opacity(0.12), shadowColor: tint.opacity(0.04)))
    }

    static func signalMetricTile(
        title: String,
        value: String,
        detail: String,
        iconName: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 34, height: 34)

                    RediIcon(iconName)
                        .foregroundStyle(tint)
                        .frame(width: 16, height: 16)
                }

                Spacer(minLength: 0)
            }

            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(14)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.card,

                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.card, edgeColor: tint.opacity(0.12), shadowColor: tint.opacity(0.04)))
    }

    static func commandStatusTile(
        title: String,
        value: String,
        detail: String,
        iconName: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)

                RediIcon(iconName)
                    .foregroundStyle(tint)
                    .frame(width: 16, height: 16)
            }

            Text(title)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)

            Text(value.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(tint)

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .padding(12)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.card,

                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.card, edgeColor: tint.opacity(0.14), shadowColor: tint.opacity(0.04)))
    }

    static func meshBannerStat(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.button,

                atmosphere: tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.button, edgeColor: tint.opacity(0.1), shadowColor: tint.opacity(0.03)))
    }

    static func signalFailureRow(_ row: SignalFailureRowModel) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                    .fill(row.tint.opacity(0.14))
                    .frame(width: 38, height: 38)

                RediIcon(row.iconName)
                    .foregroundStyle(row.tint)
                    .frame(width: 16, height: 16)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                Text(row.detail)
                    .font(RediTypography.body)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.card,

                atmosphere: row.tint.opacity(0.08)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.card, edgeColor: row.tint.opacity(0.12), shadowColor: row.tint.opacity(0.04)))
    }

    static func signalHighlightsBlock(_ highlights: [(label: String, value: String)], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signal Details")
                .font(RediTypography.caption)
                .foregroundStyle(accent)

            ForEach(Array(highlights.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 10) {
                    Text(item.label.uppercased())
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
                        .frame(width: 76, alignment: .leading)

                    Text(item.value)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        )
    }

    static func sharedMedicalInfoBlock(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MEDICAL NOTE SHARED")
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.danger)
            Text(summary)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            PremiumSurfaceBackground(
                cornerRadius: RediRadius.button,

                atmosphere: ColorTheme.danger.opacity(0.12)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
        .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.button, edgeColor: ColorTheme.danger.opacity(0.16), shadowColor: ColorTheme.danger.opacity(0.04)))
    }

    static func beaconAccentColor(for _: BeaconType) -> Color {
        ColorTheme.textTertiary
    }

    static func beaconTypeStrip(for type: BeaconType) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(beaconAccentColor(for: type))
            .frame(height: 3)
            .frame(maxWidth: .infinity)
    }

    static func signalLimitLine(iconName: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RediIcon(iconName)
                .foregroundStyle(ColorTheme.textTertiary)
                .frame(width: 16, height: 16)
                .padding(.top, 2)

            Text(text)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    static func signalGuidanceLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(ColorTheme.danger)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(RediTypography.body)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    static func meshDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)
                .frame(width: 92, alignment: .leading)

            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    static func signalMetadataPicker<Content: View>(
        title: String,
        selectionText: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            Menu {
                content()
            } label: {
                HStack(spacing: 8) {
                    Text(selectionText)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ColorTheme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .stroke(ColorTheme.dividerStrong.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func quickTemplateTint(for template: String) -> Color {
        if template.contains("FIRE") {
            return ColorTheme.danger
        }
        if template.contains("SAFE") {
            return ColorTheme.ready
        }
        if template.contains("WATER") {
            return ColorTheme.accent
        }
        return ColorTheme.warning
    }

    static func color(for tone: OperationalStatusTone) -> Color {
        switch tone {
        case .ready:
            ColorTheme.ready
        case .info:
            ColorTheme.accent
        case .caution:
            ColorTheme.warning
        case .danger:
            ColorTheme.danger
        case .neutral:
            ColorTheme.textTertiary
        }
    }

    static func situationReportButton(_ type: BeaconType, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let tint = beaconAccentColor(for: type)

        return Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    BeaconTypeBadge(type: type)
                    Spacer(minLength: 0)
                }

                Text(type.buttonTitle.uppercased())
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)

                Text(type.expiryBadgeTitle)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PremiumSurfaceBackground(
                    cornerRadius: RediRadius.card,

                    atmosphere: (isSelected ? tint : ColorTheme.textSecondary).opacity(isSelected ? 0.14 : 0.05)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            .modifier(PremiumSurfaceChrome(cornerRadius: RediRadius.card, edgeColor: (isSelected ? tint : ColorTheme.dividerStrong).opacity(0.18), shadowColor: tint.opacity(0.04)))
        }
        .buttonStyle(CardPressButtonStyle())
    }

    static func scannerAlertRow(_ alert: SituationalScannerAlert) -> some View {
        let tint = color(for: alert.tone)

        return signalInsetCard(tint: tint) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 34, height: 34)

                    Image(systemName: alert.iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)

                    Text(alert.detail)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }
        }
    }

    static func signalDockButton(
        title: String,
        detail: String,
        status: String,
        systemImage: String,
        tint: Color,
        prominence: SignalDockButtonProminence,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isEnabled ? tint : ColorTheme.textTertiary)
                    .frame(width: 18, height: 18)
                    .padding(8)
                    .background((isEnabled ? tint : ColorTheme.textTertiary).opacity(0.14), in: RoundedRectangle(cornerRadius: RediRadius.button, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isEnabled ? ColorTheme.text : ColorTheme.textSecondary)
                        .lineLimit(2)

                    Text(status.uppercased())
                        .font(.caption2.weight(.black))
                        .foregroundStyle(isEnabled ? tint : ColorTheme.textTertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                Color.black.opacity(backgroundOpacity(for: prominence, isEnabled: isEnabled)),
                in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                    .stroke((isEnabled ? tint : ColorTheme.dividerStrong).opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel("\(title), \(status). \(detail)")
    }

    static func backgroundOpacity(for prominence: SignalDockButtonProminence, isEnabled: Bool) -> Double {
        guard isEnabled else { return 0.16 }

        switch prominence {
        case .critical:
            return 0.24
        case .accented:
            return 0.2
        case .standard:
            return 0.16
        }
    }
}
