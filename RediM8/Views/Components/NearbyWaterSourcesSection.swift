import SwiftUI

struct WaterQualityPill: View {
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

struct NearbyWaterSourcesSection: View {
    let sources: [NearbyWaterPoint]
    let contextText: String?
    let emptyMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let contextText, !contextText.isEmpty {
                Text(contextText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if sources.isEmpty {
                if let emptyMessage, !emptyMessage.isEmpty {
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(sources) { source in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.point.name)
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)
                                Text("\(source.point.kind.title) • \(source.distanceText)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            WaterQualityPill(
                                title: source.point.quality.title,
                                tint: tint(for: source.point.quality)
                            )
                        }

                        Text(source.point.notes)
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.text)

                        Text(source.point.source)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func tint(for quality: WaterQualityLabel) -> Color {
        switch quality {
        case .drinkingWater:
            ColorTheme.water
        case .nonPotable:
            ColorTheme.warning
        case .seasonal, .unknownQuality:
            ColorTheme.info
        }
    }
}
