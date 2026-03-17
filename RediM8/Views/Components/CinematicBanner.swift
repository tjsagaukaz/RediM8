import SwiftUI

/// Full-width cinematic hero image banner for command panels and sections.
/// Displays real-world photography with a dark bottom gradient so content reads cleanly below.
/// Per asset treatment rules: real-world photos keep natural color, slightly desaturated.
struct CinematicBanner: View {
    let assetName: String
    let height: CGFloat

    init(_ assetName: String, height: CGFloat = 180) {
        self.assetName = assetName
        self.height = height
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
            .saturation(0.7)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, ColorTheme.nero.opacity(0.6), ColorTheme.nero],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height * 0.6)
            }
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [ColorTheme.nero.opacity(0.3), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height * 0.3)
            }
            .accessibilityHidden(true)
    }
}

/// CommandPanel variant with a cinematic hero image above the eyebrow.
struct CinematicCommandPanel<Content: View, Actions: View>: View {
    let assetName: String
    let eyebrow: String
    let bannerHeight: CGFloat
    private let content: Content
    private let actions: Actions

    init(
        assetName: String,
        eyebrow: String,
        bannerHeight: CGFloat = 180,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.assetName = assetName
        self.eyebrow = eyebrow
        self.bannerHeight = bannerHeight
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CinematicBanner(assetName, height: bannerHeight)

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

extension CinematicCommandPanel where Actions == EmptyView {
    init(
        assetName: String,
        eyebrow: String,
        bannerHeight: CGFloat = 180,
        @ViewBuilder content: () -> Content
    ) {
        self.assetName = assetName
        self.eyebrow = eyebrow
        self.bannerHeight = bannerHeight
        self.content = content()
        self.actions = EmptyView()
    }
}
