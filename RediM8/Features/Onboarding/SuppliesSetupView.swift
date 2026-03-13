import SwiftUI

struct SuppliesSetupView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModeHeroCard(
                eyebrow: "Readiness Snapshot",
                title: "Rough numbers are enough to start.",
                subtitle: "This step is about honesty, not perfection. Capture what you have right now so RediM8 can show clearer gaps and less false confidence.",
                iconName: "water",
                accent: ColorTheme.info
            ) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(viewModel.livePreviewScore.overall)%")
                            .font(.system(size: 42, weight: .black))
                            .foregroundStyle(ColorTheme.text)
                        Text("Current readiness snapshot")
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textMuted)
                    }

                    Spacer()

                    StatusBadge(tier: viewModel.livePreviewScore.tier)
                }
            }

            PanelCard(title: "Household Supplies", subtitle: "Adjust these toward your current reality") {
                VStack(spacing: 18) {
                    supplySlider(
                        title: "Water stored",
                        value: $viewModel.supplies.waterLitres,
                        range: 0...200,
                        target: viewModel.prepTargets.waterLitres,
                        suffix: "L",
                        tint: ColorTheme.info
                    )

                    supplySlider(
                        title: "Food supply",
                        value: $viewModel.supplies.foodDays,
                        range: 0...21,
                        target: viewModel.prepTargets.foodDays,
                        suffix: "days",
                        tint: ColorTheme.ready
                    )

                    supplySlider(
                        title: "Fuel stored",
                        value: $viewModel.supplies.fuelLitres,
                        range: 0...120,
                        target: viewModel.prepTargets.fuelLitres,
                        suffix: "L",
                        tint: ColorTheme.warning
                    )

                    supplySlider(
                        title: "Battery reserve",
                        value: $viewModel.supplies.batteryCapacity,
                        range: 0...100,
                        target: viewModel.prepTargets.batteryCapacity,
                        suffix: "%",
                        tint: ColorTheme.danger
                    )
                }
            }

            PanelCard(title: "What The Snapshot Means", subtitle: "Fast interpretation, not spreadsheeting") {
                VStack(alignment: .leading, spacing: 10) {
                    snapshotLine(title: "Water", detail: waterSummary)
                    snapshotLine(title: "Food", detail: foodSummary)
                    snapshotLine(title: "Fuel", detail: fuelSummary)
                    snapshotLine(title: "Power", detail: batterySummary)
                }
            }
        }
    }

    private var waterSummary: String {
        summary(current: viewModel.supplies.waterLitres, target: viewModel.prepTargets.waterLitres, suffix: "L")
    }

    private var foodSummary: String {
        summary(current: viewModel.supplies.foodDays, target: viewModel.prepTargets.foodDays, suffix: "days")
    }

    private var fuelSummary: String {
        summary(current: viewModel.supplies.fuelLitres, target: viewModel.prepTargets.fuelLitres, suffix: "L")
    }

    private var batterySummary: String {
        summary(current: viewModel.supplies.batteryCapacity, target: viewModel.prepTargets.batteryCapacity, suffix: "%")
    }

    private func summary(current: Double, target: Double, suffix: String) -> String {
        if current >= target {
            return "\(current.roundedIntString)\(suffix == "%" ? "" : " ")\(suffix) is meeting or exceeding the current target."
        }

        let gap = max((target - current).rounded(), 0)
        return "\(gap.roundedIntString)\(suffix == "%" ? "" : " ")\(suffix) below the current target."
    }

    private func supplySlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        target: Double,
        suffix: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
                Spacer()
                Text("\(value.wrappedValue.roundedIntString)\(suffix == "%" ? "" : " ")\(suffix)")
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
            }

            Text("Target: \(target.roundedIntString)\(suffix == "%" ? "" : " ")\(suffix)")
                .font(.caption)
                .foregroundStyle(tint)

            Slider(value: value, in: range)
                .tint(tint)
        }
        .padding(16)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func snapshotLine(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textFaint)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
