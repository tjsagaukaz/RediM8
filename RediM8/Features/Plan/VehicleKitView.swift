import SwiftUI

struct VehicleKitView: View {
    @ObservedObject var viewModel: VehicleKitViewModel
    var showsSummaryCard: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsSummaryCard {
                PanelCard(
                    title: "Vehicle Readiness Mode",
                    subtitle: "For 4WDs, tradies, campers, rural travel, and long-distance driving",
                    backgroundAssetName: "evacuation_vehicle_load",
                    backgroundImageOffset: CGSize(width: 18, height: 0)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .bottom, spacing: 12) {
                                vehicleReadinessHeadline
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                vehicleReadinessHeadline
                            }
                        }

                        Text("\(viewModel.plan.readiness.completedCount) / \(viewModel.plan.readiness.totalCount) vehicle essentials checked")
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)

                        ReadinessMeter(
                            value: viewModel.plan.readiness.progress,
                            tint: viewModel.plan.readiness.percentage >= 67 ? ColorTheme.ready : ColorTheme.warning,
                            height: 11
                        )

                        ForEach(viewModel.plan.contextLines, id: \.self) { line in
                            Text(line)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if !viewModel.plan.nextActions.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Pack next")
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)
                                ForEach(viewModel.plan.nextActions, id: \.self) { action in
                                    Text(action)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            PanelCard(title: "Vehicle Kit", subtitle: "Check every item before long trips or severe weather movement") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.plan.items) { item in
                        Button {
                            viewModel.setItemComplete(item.id, isComplete: !viewModel.isItemComplete(item.id))
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                RediIcon(item.systemImage)
                                    .foregroundStyle(item.isCritical ? ColorTheme.warning : ColorTheme.info)
                                    .frame(width: 18, height: 18)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(item.title)
                                            .font(.headline)
                                            .foregroundStyle(ColorTheme.text)
                                        if item.isCritical {
                                            Text("Priority")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(ColorTheme.warning)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(ColorTheme.warning.opacity(0.14), in: Capsule())
                                        }
                                    }

                                    Text(item.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()

                                Image(systemName: viewModel.isItemComplete(item.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(viewModel.isItemComplete(item.id) ? ColorTheme.ready : ColorTheme.divider)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(CardPressButtonStyle())
                    }
                }
            }
        }
    }

    private var vehicleReadinessHeadline: some View {
        Group {
            Text(viewModel.plan.readiness.percentage.percentageText)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(ColorTheme.text)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text("Ready")
                .font(.headline.weight(.semibold))
                .foregroundStyle(viewModel.plan.readiness.percentage >= 67 ? ColorTheme.ready : ColorTheme.warning)
        }
    }
}
