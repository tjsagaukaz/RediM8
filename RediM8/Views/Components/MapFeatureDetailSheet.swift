import CoreLocation
import SwiftUI

/// Bottom sheet displaying details of a tapped map feature.
struct MapFeatureDetailSheet: View {
    let feature: MapSelectedFeature
    let currentLocation: CLLocation?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: feature.layer.systemImage)
                    .font(.title3)
                    .foregroundStyle(layerColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.layer.displayTitle.uppercased())
                        .font(RediTypography.label)
                        .tracking(1.0)
                        .foregroundStyle(layerColor)
                    Text(feature.title)
                        .font(RediTypography.bodyStrong)
                        .foregroundStyle(ColorTheme.text)
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
            }

            if let subtitle = feature.subtitle {
                Text(subtitle)
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
            }

            HStack(spacing: 16) {
                if let kind = feature.kind {
                    detailPill(label: "Type", value: kind)
                }
                if let quality = feature.quality {
                    detailPill(label: "Quality", value: quality)
                }
                if let distance = feature.distanceText(from: currentLocation) {
                    detailPill(label: "Distance", value: distance)
                }
            }
        }
        .padding(RediSpacing.content)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTheme.panelRaised, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
    }

    private func detailPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(ColorTheme.textFaint)
            Text(value)
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.text)
        }
    }

    private var layerColor: Color {
        switch feature.layer {
        case .waterPoint: ColorTheme.water
        case .shelter: ColorTheme.ready
        case .officialAlert: ColorTheme.danger
        case .beacon: ColorTheme.warning
        case .resource: ColorTheme.info
        case .unknown: ColorTheme.textTertiary
        }
    }
}
