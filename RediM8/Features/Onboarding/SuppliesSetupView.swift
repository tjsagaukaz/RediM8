import SwiftUI

struct SuppliesSetupView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModeHeroCard(
                eyebrow: "Supplies",
                title: "Rough numbers are enough.",
                subtitle: "Capture what you have right now so RediM8 can show the gaps honestly.",
                iconName: "water",
                accent: ColorTheme.info,
                backgroundAssetName: "preparedness_flatlay",
                backgroundImageOffset: CGSize(width: 10, height: 0)
            ) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(viewModel.livePreviewScore.overall)%")
                            .font(.system(size: 42, weight: .black))
                            .foregroundStyle(ColorTheme.text)
                        Text("Current snapshot")
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textMuted)
                    }

                    Spacer()

                    StatusBadge(tier: viewModel.livePreviewScore.tier)
                }
            }

            PanelCard(title: "Current Supplies", subtitle: "Move the sliders until they roughly match reality.") {
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
        }
    }

    private func supplySlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        target: Double,
        suffix: String,
        tint: Color
    ) -> some View {
        let ratio = target > 0 ? min(value.wrappedValue / target, 1) : 1
        let gap = max(target - value.wrappedValue, 0)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)

                Spacer()

                Text("\(value.wrappedValue.roundedIntString)\(suffix == "%" ? "" : " ")\(suffix)")
                    .font(.headline)
                    .foregroundStyle(ColorTheme.text)
            }

            HStack {
                Text("Target \(target.roundedIntString)\(suffix == "%" ? "" : " ")\(suffix)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)

                Spacer()

                Text(gap == 0 ? "On target" : "Gap \(gap.roundedIntString)\(suffix == "%" ? "" : " ")\(suffix)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(gap == 0 ? ColorTheme.ready : ColorTheme.textFaint)
            }

            ReadinessMeter(value: ratio, tint: tint, height: 10)

            Slider(value: value, in: range)
                .tint(tint)
        }
        .padding(16)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
