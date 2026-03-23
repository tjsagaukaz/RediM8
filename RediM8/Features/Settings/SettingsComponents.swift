import SwiftUI

struct SettingsRowLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(RediTypography.heading)
                .foregroundStyle(ColorTheme.text)
            Text(subtitle)
                .font(RediTypography.body)
                .foregroundStyle(.secondary)
        }
    }
}

struct SettingsCallout: View {
    let title: String
    let detail: String
    let tone: OperationalStatusTone
    let iconName: String

    private var tint: Color {
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let badge: String?
    let badgeTint: Color
    let footnote: String?
    @Binding var isOn: Bool

    init(
        title: String,
        subtitle: String,
        badge: String? = nil,
        badgeTint: Color = ColorTheme.textTertiary,
        footnote: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.badgeTint = badgeTint
        self.footnote = footnote
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    SettingsRowLabel(title: title, subtitle: subtitle)

                    if let badge {
                        Spacer(minLength: 0)
                        Text(badge.uppercased())
                            .font(RediTypography.caption)
                            .foregroundStyle(badgeTint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(badgeTint.opacity(0.14), in: Capsule())
                    }
                }

                if let footnote {
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(ColorTheme.accent)
    }
}

struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SettingsRowLabel(title: title, subtitle: subtitle)
            Spacer()
            HStack(alignment: .center, spacing: 8) {
                Text(value)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.textTertiary)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .font(RediTypography.label)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityValue(value)
        .accessibilityHint("Opens \(title).")
    }
}

struct SettingsActionRow: View {
    let title: String
    let subtitle: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SettingsRowLabel(title: title, subtitle: subtitle)
            Spacer()
            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(tint)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityValue(value)
    }
}

struct SettingsInfoRow: View {
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SettingsRowLabel(title: title, subtitle: subtitle)
            Spacer()
            Text(value)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.textTertiary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityValue(value)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .overlay(ColorTheme.divider)
    }
}

struct SettingsTextDetailView: View {
    let title: String
    let subtitle: String
    let lines: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PanelCard(title: title, subtitle: subtitle) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(RediTypography.body)
                                .foregroundStyle(ColorTheme.text)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
