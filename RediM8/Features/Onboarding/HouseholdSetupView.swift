import SwiftUI

struct HouseholdSetupView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModeHeroCard(
                eyebrow: "Household",
                title: "Save the basics you need to leave fast.",
                subtitle: "One count, one route, one meeting point, and one contact is enough for day one.",
                iconName: "family",
                accent: ColorTheme.textTertiary,
                backgroundAssetName: "onboarding_route",
                backgroundImageOffset: CGSize(width: -28, height: 0)
            ) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Edit later anytime", tone: .neutral),
                    TrustPillItem(title: "Route saved locally", tone: .verified),
                    TrustPillItem(title: "Meeting point ready", tone: .info)
                ])
            }

            PanelCard(title: "Who Are You Planning For?", subtitle: "People and pets change water, transport, and timing.") {
                LazyVGrid(columns: columns, spacing: 12) {
                    countCard(title: "People", detail: "Need supplies and transport.") {
                        Stepper("People: \(viewModel.peopleCount)", value: $viewModel.peopleCount, in: 1...12)
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)
                    }

                    countCard(title: "Pets", detail: "Change pace and water use.") {
                        Stepper("Pets: \(viewModel.petCount)", value: $viewModel.petCount, in: 0...12)
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)
                    }
                }
            }

            PanelCard(title: "Leave-Now Basics", subtitle: "Keep this lightweight. You can add detail later.") {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Primary meeting point", text: $viewModel.primaryMeetingPoint)
                        .textFieldStyle(TacticalTextFieldStyle())

                    TextField("Primary evacuation route", text: $viewModel.primaryEvacuationRoute, axis: .vertical)
                        .textFieldStyle(TacticalTextFieldStyle())

                    TextField("Emergency contact name", text: $viewModel.emergencyContactName)
                        .textFieldStyle(TacticalTextFieldStyle())

                    TextField("Emergency contact phone", text: $viewModel.emergencyContactPhone)
                        .textFieldStyle(TacticalTextFieldStyle())
                        .keyboardType(.phonePad)

                    Text("Example route: Pacific Hwy north to community hall. Example meeting point: front gate across from school.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textFaint)
                }
            }

            PanelCard(title: "Planning Targets", subtitle: "Auto-generated from your risks and household.") {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Water \(viewModel.prepTargets.waterLitres.roundedIntString)L", tone: .info),
                    TrustPillItem(title: "Food \(viewModel.prepTargets.foodDays.roundedIntString) days", tone: .verified),
                    TrustPillItem(title: "Fuel \(viewModel.prepTargets.fuelLitres.roundedIntString)L", tone: .caution),
                    TrustPillItem(title: "Battery \(viewModel.prepTargets.batteryCapacity.roundedIntString)%", tone: .caution)
                ])
            }
        }
    }

    private func countCard<Content: View>(title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(RediTypography.bodyStrong)
                .foregroundStyle(ColorTheme.text)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textMuted)

            content()
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding(16)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
