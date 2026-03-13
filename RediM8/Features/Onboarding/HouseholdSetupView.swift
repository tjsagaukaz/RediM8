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
                eyebrow: "Plan Basics",
                title: "Save the details that matter when leaving quickly.",
                subtitle: "A simple count, one route, one meeting point, and one contact go further in an emergency than a huge profile no one finishes.",
                iconName: "family",
                accent: ColorTheme.ready,
                backgroundAssetName: "onboarding_route",
                backgroundImageOffset: CGSize(width: -28, height: 0)
            ) {
                TrustPillGroup(items: [
                    TrustPillItem(title: "Route saved offline", tone: .verified),
                    TrustPillItem(title: "Contacts available locally", tone: .info),
                    TrustPillItem(title: "Edit later anytime", tone: .neutral)
                ])
            }

            PanelCard(title: "Who Are You Planning For?", subtitle: "People and pets change water, transport, and timing") {
                VStack(spacing: 14) {
                    countCard(
                        title: "People",
                        value: viewModel.peopleCount,
                        detail: "Human household members who need supplies and transport."
                    ) {
                        Stepper("People: \(viewModel.peopleCount)", value: $viewModel.peopleCount, in: 1...12)
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)
                    }

                    countCard(
                        title: "Pets",
                        value: viewModel.petCount,
                        detail: "Pets increase water needs and change evacuation speed."
                    ) {
                        Stepper("Pets: \(viewModel.petCount)", value: $viewModel.petCount, in: 0...12)
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)
                    }
                }
            }

            PanelCard(title: "Fast Plan Basics", subtitle: "The minimum plan we want ready from day one") {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Primary meeting point", text: $viewModel.primaryMeetingPoint)
                        .textFieldStyle(TacticalTextFieldStyle())

                    TextField("Primary evacuation route", text: $viewModel.primaryEvacuationRoute, axis: .vertical)
                        .textFieldStyle(TacticalTextFieldStyle())

                    HStack(spacing: 12) {
                        TextField("Emergency contact name", text: $viewModel.emergencyContactName)
                            .textFieldStyle(TacticalTextFieldStyle())

                        TextField("Phone", text: $viewModel.emergencyContactPhone)
                            .textFieldStyle(TacticalTextFieldStyle())
                            .keyboardType(.phonePad)
                    }

                    TextField("Household care notes or medication reminders", text: $viewModel.medicalNotes, axis: .vertical)
                        .textFieldStyle(TacticalTextFieldStyle())

                    Text("Keep this lightweight. One clear route and one reachable contact are already better than nothing.")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textFaint)
                }
            }

            PanelCard(title: "Targets From Your Scenarios", subtitle: "Planning targets generated from your household and selected risks") {
                LazyVGrid(columns: columns, spacing: 12) {
                    targetCard(title: "Water", value: "\(viewModel.prepTargets.waterLitres.roundedIntString)L", detail: "Stored supply target", tint: ColorTheme.info)
                    targetCard(title: "Food", value: "\(viewModel.prepTargets.foodDays.roundedIntString) days", detail: "Shelf-stable meals", tint: ColorTheme.ready)
                    targetCard(title: "Fuel", value: "\(viewModel.prepTargets.fuelLitres.roundedIntString)L", detail: "Vehicle or generator reserve", tint: ColorTheme.warning)
                    targetCard(title: "Battery", value: "\(viewModel.prepTargets.batteryCapacity.roundedIntString)%", detail: "Power reserve target", tint: ColorTheme.danger)
                }

                Text("These are planning targets, not guarantees. Conditions, closures, and access can still change.")
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textFaint)
                    .padding(.top, 12)
            }
        }
    }

    private func countCard<Content: View>(title: String, value: Int, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                Spacer()
                Text(String(value))
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(ColorTheme.ready)
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textMuted)

            content()
        }
        .padding(16)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func targetCard(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(RediTypography.caption)
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(ColorTheme.text)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(ColorTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(16)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}
