import SwiftUI

/// Semantic status for metric values.
enum MetricStatus {
    case normal
    case ready
    case warning
    case danger
}

/// A single metric item for display in MetricGrid.
struct MetricItem: Identifiable {
    let label: String
    let value: String
    let status: MetricStatus

    var id: String { label }

    init(label: String, value: String, status: MetricStatus = .normal) {
        self.label = label
        self.value = value
        self.status = status
    }
}

/// Dense 2/3/4 column data grid — command interface pattern.
/// Labels left, values right, semantic color on status values.
struct MetricGrid: View {
    let items: [MetricItem]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        let count: Int
        if dynamicTypeSize.isAccessibilitySize {
            count = 1
        } else {
            switch sizeClass {
            case .regular:
                count = 4
            default:
                count = 2
            }
        }
        return Array(repeating: GridItem(.flexible(), spacing: RediSpacing.content), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: RediSpacing.content) {
            ForEach(items) { item in
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: RediSpacing.micro) {
                            Text(item.label)
                                .font(RediTypography.label)
                                .tracking(1.2)
                                .foregroundStyle(ColorTheme.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(item.value)
                                .font(RediTypography.data)
                                .foregroundStyle(statusColor(item.status))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        HStack(spacing: RediSpacing.tight) {
                            Text(item.label.uppercased())
                                .font(RediTypography.label)
                                .tracking(1.2)
                                .foregroundStyle(ColorTheme.textTertiary)
                                .lineLimit(1)

                            Spacer(minLength: RediSpacing.micro)

                            Text(item.value)
                                .font(RediTypography.data)
                                .foregroundStyle(statusColor(item.status))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 32, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(item.label)
                .accessibilityValue(item.value)
            }
        }
    }

    private func statusColor(_ status: MetricStatus) -> Color {
        switch status {
        case .normal: ColorTheme.text
        case .ready: ColorTheme.ready
        case .warning: ColorTheme.warning
        case .danger: ColorTheme.danger
        }
    }
}
