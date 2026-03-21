import SwiftUI

enum MapTonePalette {
    static func color(for tone: OperationalStatusTone) -> Color {
        switch tone {
        case .ready:
            ColorTheme.ready
        case .info:
            ColorTheme.info
        case .caution:
            ColorTheme.warning
        case .danger:
            ColorTheme.danger
        case .neutral:
            ColorTheme.textFaint
        }
    }
}

struct MapSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(RediTypography.label)
            .tracking(1.2)
            .foregroundStyle(ColorTheme.textTertiary)
    }
}

struct MapSummaryCardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let value: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(RediTypography.caption)
                .foregroundStyle(accent)

            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textMuted)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(
            minWidth: dynamicTypeSize.isAccessibilitySize ? 220 : 184,
            maxWidth: dynamicTypeSize.isAccessibilitySize ? 280 : 220,
            alignment: .leading
        )
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityHint(detail)
    }
}

struct MapInlineCalloutView: View {
    let title: String
    let detail: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(accent)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorTheme.text)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }
}

struct MapStatusBannerView: View {
    let tone: Color
    let headline: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RediIcon("map_marker")
                .foregroundStyle(tone)
                .frame(width: 18, height: 18)
                .padding(10)
                .background(tone.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("MAP STATUS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tone)
                Text(headline)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ColorTheme.text)
                    .accessibilityIdentifier("map.statusHeadline")
                Text(detail)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ColorTheme.textMuted)
                    .accessibilityIdentifier("map.statusDetail")
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tone.opacity(0.18), lineWidth: 1)
        )
    }
}

struct MapModeBadgeView: View {
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MAP MODE")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(tint)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(ColorTheme.textMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
    }
}

struct MapHeadingBadgeView: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            RediIcon("compass")
                .foregroundStyle(ColorTheme.textTertiary)
                .frame(width: 16, height: 16)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.78), in: Capsule())
        .overlay(
            Capsule()
                .stroke(ColorTheme.textTertiary.opacity(0.28), lineWidth: 1)
        )
    }
}

struct MapCompactSummaryView: View {
    let tone: Color
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MAP CONFIDENCE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(ColorTheme.text)
                .lineLimit(1)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(ColorTheme.textMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct MapDistanceRingLegendView: View {
    let labels: [String]

    var body: some View {
        HStack(spacing: 8) {
            RediIcon("compass")
                .foregroundStyle(ColorTheme.textTertiary)
                .frame(width: 14, height: 14)

            Text(labels.joined(separator: " • "))
                .font(.caption.weight(.semibold))
                .foregroundStyle(ColorTheme.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.82), in: Capsule())
        .overlay(
            Capsule()
                .stroke(ColorTheme.textTertiary.opacity(0.2), lineWidth: 1)
        )
    }
}

struct MapReferenceChipView: View {
    let title: String
    let detail: String
    let iconName: String
    let accent: Color

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RediIcon(iconName)
                .foregroundStyle(accent)
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorTheme.textFaint)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.text)
            }

            Spacer(minLength: 0)
        }
    }
}

struct MapBriefMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(accent)

            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }
}

struct MapBulletLine: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(ColorTheme.textTertiary)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(.caption)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MapInspectorGroup<Content: View>: View {
    let title: String
    let subtitle: String
    let accent: Color
    let content: Content

    init(
        title: String,
        subtitle: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textMuted)
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }
}

struct TrustBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

struct ShelterCard: View {
    let shelter: ShelterLocation
    let distanceText: String
    let tint: Color
    let isSelected: Bool
    let trustItems: [TrustPillItem]
    let openNavigation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                MapAssetIcon(assetName: shelter.type.mapMarkerAssetName, fallbackSystemName: "shelter", size: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(shelter.name)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)

                    if isSelected {
                        Text("Selected on map")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }

                Spacer()

                TrustBadge(title: shelter.type.title, tint: tint)
            }

            TrustPillGroup(items: trustItems)

            Text("Capacity: \(shelter.capacityText)")
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            Text("Distance: \(distanceText)")
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            Text("Note: \(shelter.notes)")
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            Text(shelter.source)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Navigate") {
                openNavigation()
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MapPackRow: View {
    let pack: OfflineMapPack
    let isInstalled: Bool
    let trustItems: [TrustPillItem]
    let onInstall: () -> Void
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.name)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text(pack.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(isInstalled ? "Installed" : pack.kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isInstalled ? ColorTheme.ready : ColorTheme.info)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((isInstalled ? ColorTheme.ready : ColorTheme.info).opacity(0.14), in: Capsule())
            }

            MapPackCoveragePreview(pack: pack, isInstalled: isInstalled, accent: isInstalled ? ColorTheme.ready : ColorTheme.info)

            Text(pack.coverageSummary)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)

            TrustPillGroup(items: trustItems)

            HStack(spacing: 14) {
                Label("\(pack.sizeMB) MB", systemImage: "internaldrive.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(DateFormatter.rediM8MonthYear.string(from: pack.lastUpdated), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Layers: \(pack.supportedLayerSummary)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Coverage stops at this pack boundary. Outside it, RediM8 falls back to the basemap and any saved markers.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if isInstalled {
                    Button("Open") {
                        onOpen()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("map.pack.\(pack.id).open")

                    if !pack.isBundledByDefault {
                        Button("Remove") {
                            onRemove()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .accessibilityIdentifier("map.pack.\(pack.id).remove")
                    }
                } else {
                    Button("Install") {
                        onInstall()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("map.pack.\(pack.id).install")
                }
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("map.pack.\(pack.id).card")
    }
}
