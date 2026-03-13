import SwiftUI

struct Emergency72HourView: View {
    let plan: Emergency72HourPlan
    let nearbyWaterSources: [NearbyWaterPoint]
    let waterSourceContext: String
    let waterSourceStatusMessage: String?
    let isChecklistItemComplete: (String) -> Bool
    let setChecklistItemComplete: (String, Bool) -> Void

    var body: some View {
        PanelCard(title: "72-Hour Emergency Plan", subtitle: "Three-day household targets for outages and disrupted services") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    metricCard(
                        title: "Water Required",
                        value: "\(plan.waterRequiredLitres.roundedIntString)L",
                        detail: "\(plan.waterPerPersonPerDayLitres.roundedIntString)L per person per day"
                    )

                    metricCard(
                        title: "Food Required",
                        value: "\(plan.foodRequiredCalories)",
                        detail: "\(plan.foodCaloriesPerPersonPerDay) cal per person per day"
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Supply Targets")
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)

                    ForEach(plan.supplyTargets) { target in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(target.title)
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)
                                Text("Need \(formatted(target.required)) \(target.unit) | Have \(formatted(target.current)) \(target.unit)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(target.gap > 0 ? "Gap \(formatted(target.gap)) \(target.unit)" : "Ready")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(target.gap > 0 ? ColorTheme.warning : ColorTheme.ready)
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                if waterGap > 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Known Water Sources")
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)

                        NearbyWaterSourcesSection(
                            sources: nearbyWaterSources,
                            contextText: waterSourceContext,
                            emptyMessage: waterSourceStatusMessage
                        )
                    }
                }

                contentBlock(title: "Recommended Gear", items: plan.recommendedGear.map { "\($0.name): \($0.description)" })
                contentBlock(title: "Essential Tasks", items: plan.essentialTasks.map { "\($0.title): \($0.description)" })

                VStack(alignment: .leading, spacing: 14) {
                    Text("72-Hour Checklist")
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)

                    ForEach(plan.checklists) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ColorTheme.info)

                            ForEach(section.items) { item in
                                Toggle(
                                    isOn: Binding(
                                        get: { isChecklistItemComplete(item.id) },
                                        set: { setChecklistItemComplete(item.id, $0) }
                                    )
                                ) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(.headline)
                                            .foregroundStyle(ColorTheme.text)
                                        Text(item.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.switch)
                            }
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    private func metricCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(ColorTheme.text)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func contentBlock(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(ColorTheme.text)

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(item)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        value.roundedIntString
    }

    private var waterGap: Double {
        plan.supplyTargets.first(where: { $0.id == "water" })?.gap ?? 0
    }
}
