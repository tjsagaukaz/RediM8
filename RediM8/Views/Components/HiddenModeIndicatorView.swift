import SwiftUI

struct StealthModeIndicatorView: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(ColorTheme.warning)
                .frame(width: 8, height: 8)
            Text("Stealth Mode")
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)
            Spacer()
            Text("Receive-Only Active")
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.warning)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(ColorTheme.panelElevated, in: Capsule())
        .overlay(
            Capsule()
                .stroke(ColorTheme.dividerStrong, lineWidth: 1)
        )
    }
}

struct HiddenModeIndicatorView: View {
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.slash.fill")
                .foregroundStyle(SettingsPalette.accent)
            Text("Hidden Mode Active")
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(RediTypography.caption)
                    .foregroundStyle(SettingsPalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(SettingsPalette.mutedAccent, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(SettingsPalette.accent.opacity(0.22), lineWidth: 1)
                    )
                    .buttonStyle(.plain)
            } else {
                Text("Not Broadcasting")
                    .font(RediTypography.caption)
                    .foregroundStyle(SettingsPalette.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(ColorTheme.panelElevated, in: Capsule())
        .overlay(
            Capsule()
                .stroke(ColorTheme.dividerStrong, lineWidth: 1)
        )
    }
}

enum SettingsPalette {
    static let accent = ColorTheme.accentSoft
    static let mutedAccent = accent.opacity(0.18)
}
