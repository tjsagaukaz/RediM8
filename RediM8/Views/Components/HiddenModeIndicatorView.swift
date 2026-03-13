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
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.slash.fill")
                .foregroundStyle(SettingsPalette.accent)
            Text("Hidden Mode Active")
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)
            Spacer()
            Text("Not Broadcasting")
                .font(RediTypography.caption)
                .foregroundStyle(SettingsPalette.accent)
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
