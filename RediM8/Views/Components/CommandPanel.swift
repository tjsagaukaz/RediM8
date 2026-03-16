import SwiftUI

/// Command panel — structured module with eyebrow, data, and inline actions.
/// Replaces card-based layouts. The panel IS the control module.
///
/// Structure:
/// 1. Section eyebrow (label — 11pt uppercase tracked)
/// 2. Hairline divider
/// 3. Data content (data values, metrics)
/// 4. Inline action buttons (optional)
struct CommandPanel<Content: View, Actions: View>: View {
    let eyebrow: String
    private let content: Content
    private let actions: Actions

    init(
        eyebrow: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.eyebrow = eyebrow
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow
            Text(eyebrow.uppercased())
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
                .padding(.horizontal, RediSpacing.card)
                .padding(.top, RediSpacing.card)
                .padding(.bottom, RediSpacing.compact)

            // Hairline
            Rectangle()
                .fill(ColorTheme.divider)
                .frame(height: 0.5)
                .padding(.horizontal, RediSpacing.card)

            // Data content
            VStack(alignment: .leading, spacing: RediSpacing.compact) {
                content
            }
            .padding(RediSpacing.card)

            // Actions
            actions
                .padding(.horizontal, RediSpacing.card)
                .padding(.bottom, RediSpacing.card)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous)
                .stroke(ColorTheme.divider, lineWidth: 0.5)
        )
    }
}

extension CommandPanel where Actions == EmptyView {
    init(
        eyebrow: String,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.content = content()
        self.actions = EmptyView()
    }
}

/// Compact inline action button for use inside CommandPanel.
struct InlineActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.accent)
                .padding(.horizontal, RediSpacing.content)
                .padding(.vertical, RediSpacing.compact)
                .background(ColorTheme.gunmetal)
                .clipShape(RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                        .stroke(ColorTheme.dividerStrong, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
