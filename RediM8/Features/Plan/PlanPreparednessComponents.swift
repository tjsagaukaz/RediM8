import SwiftUI

struct PreparednessGearRecommendationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let recommendation: PreparednessGearRecommendation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PreparednessGearRecommendationHeader(
                    reason: recommendation.reason,
                    heroThumbnailAssetName: recommendation.heroThumbnailAssetName
                )

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(recommendation.options) { option in
                        PreparednessGearOptionCard(option: option)
                    }
                }

                PreparednessGearRecommendationFootnote(disclosureText: recommendation.disclosureText)
            }
            .padding(RediSpacing.screen)
        }
        .navigationTitle(recommendation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .background(ColorTheme.background.ignoresSafeArea())
    }
}

struct PreparednessGearRecommendationCard: View {
    let recommendation: PreparednessGearRecommendation
    let action: () -> Void

    var body: some View {
        let tint = preparednessGearPriorityTint(recommendation.priority)

        return VStack(alignment: .leading, spacing: 12) {
            if let heroThumbnailAssetName = recommendation.heroThumbnailAssetName {
                Image(heroThumbnailAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(alignment: .top, spacing: 12) {
                RediIcon(recommendation.systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24, alignment: .center)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(recommendation.title)
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)

                        PlanCapsuleBadge(title: recommendation.priority.title, tint: tint)

                        if recommendation.featuredOption?.isBundle == true {
                            PlanCapsuleBadge(title: "Bundle", tint: ColorTheme.accent)
                        }
                    }

                    Text(recommendation.reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()

                Button(action: action) {
                    Label(recommendation.ctaTitle.uppercased(), systemImage: "arrow.up.right")
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.accent)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
    }
}

struct PrepareScenarioDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecommendation: PreparednessGearRecommendation?
    @State private var selectedGuide: Guide?

    let scenario: PrepareScenario
    let recommendations: [PreparednessGearRecommendation]
    let relatedGuides: [Guide]
    let areGearRecommendationsSuppressed: Bool

    private var bundleRecommendation: PreparednessGearRecommendation? {
        recommendations.first(where: { $0.featuredOption?.isBundle == true })
    }

    private var individualRecommendations: [PreparednessGearRecommendation] {
        recommendations.filter { $0.id != bundleRecommendation?.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(scenario.overview)
                        .font(.body)
                        .foregroundStyle(ColorTheme.textSecondary)

                    Text("Core needs")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(ColorTheme.text)
                }

                PanelCard(title: nil, subtitle: nil) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(scenario.coreNeeds.enumerated()), id: \.offset) { index, need in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1).")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(ColorTheme.textTertiary)

                                Text(need)
                                    .font(.headline)
                                    .foregroundStyle(ColorTheme.text)
                            }
                        }
                    }
                }

                if areGearRecommendationsSuppressed {
                    PanelCard(title: "Gear suggestions paused", subtitle: "RediM8 keeps active priority situations focused on immediate action.") {
                        Text("Come back to this preparation view after the active event settles. For now, use Ask Redi, the map, or emergency tools for the fastest next step.")
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                } else if let bundleRecommendation {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Fastest way to prepare")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(ColorTheme.text)

                        PreparednessGearRecommendationCard(recommendation: bundleRecommendation) {
                            selectedRecommendation = bundleRecommendation
                        }
                    }
                }

                if !areGearRecommendationsSuppressed, !individualRecommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(bundleRecommendation == nil ? "Recommended equipment" : "Build individually")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(ColorTheme.text)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(individualRecommendations) { recommendation in
                                PreparednessGearRecommendationCard(recommendation: recommendation) {
                                    selectedRecommendation = recommendation
                                }
                            }
                        }
                    }
                } else if !areGearRecommendationsSuppressed {
                    PanelCard(title: "Current setup", subtitle: "Your saved household details already cover the main essentials RediM8 checks for this scenario.") {
                        Text("You can still review the guides below if you want a refresher on the core steps and readiness checks.")
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }

                if !relatedGuides.isEmpty {
                    PanelCard(title: "Learn the basics", subtitle: "Open the deeper offline reference when you want the full guide behind these essentials.") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(relatedGuides) { guide in
                                Button {
                                    selectedGuide = guide
                                } label: {
                                    RediCommandCard(
                                        title: guide.title,
                                        detail: guide.summary,
                                        iconName: guide.heroIconName,
                                        tint: ColorTheme.textTertiary,
                                        badge: "Guide",
                                        prominence: .neutral,
                                        layout: .rail,
                                        minHeight: 78
                                    )
                                }
                                .buttonStyle(CardPressButtonStyle())
                            }
                        }
                    }
                }
            }
            .padding(RediSpacing.screen)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle(scenario.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(item: $selectedRecommendation) { recommendation in
            NavigationStack {
                PreparednessGearRecommendationSheet(recommendation: recommendation)
            }
            .rediSheetPresentation()
        }
        .sheet(item: $selectedGuide) { guide in
            NavigationStack {
                GuideDetailView(guide: guide)
            }
            .rediSheetPresentation()
        }
    }
}

struct PreparednessGearRecommendationHeader: View {
    let reason: String
    let heroThumbnailAssetName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let heroThumbnailAssetName {
                Image(heroThumbnailAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 176)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            Text(reason)
                .font(.body)
                .foregroundStyle(ColorTheme.textSecondary)

            Text("Recommended equipment")
                .font(.headline.weight(.bold))
                .foregroundStyle(ColorTheme.text)
        }
    }
}

struct PreparednessGearOptionCard: View {
    let option: PreparednessGearOption

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let thumbnailAssetName = option.thumbnailAssetName {
                Image(thumbnailAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: option.isBundle ? 150 : 110)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(alignment: .top, spacing: 10) {
                RediIcon(option.category.systemImageName)
                    .foregroundStyle(ColorTheme.textTertiary)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(option.title)
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)

                        PlanCapsuleBadge(
                            title: option.badgeTitle,
                            tint: option.isBundle ? ColorTheme.accent : ColorTheme.textTertiary
                        )
                    }

                    Text(option.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let partnerURL = option.partnerURL {
                PreparednessGearPartnerLink(partnerURL: partnerURL)
                    .padding(.leading, 30)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct PreparednessGearPartnerLink: View {
    let partnerURL: URL

    var body: some View {
        Link(destination: partnerURL) {
            Label("OPEN PARTNER LINK", systemImage: "arrow.up.right")
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.accent)
        }
    }
}

struct PreparednessGearRecommendationFootnote: View {
    let disclosureText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Optional gear guidance only. RediM8 keeps urgent and medical flows focused on immediate action.")
                .font(.caption)
                .foregroundStyle(ColorTheme.textTertiary)

            if let disclosureText {
                Text(disclosureText)
                    .font(.caption)
                    .foregroundStyle(ColorTheme.textTertiary)
            }
        }
    }
}

func preparednessGearPriorityTint(_ priority: PreparednessGearRecommendationPriority) -> Color {
    switch priority {
    case .critical:
        ColorTheme.warning
    case .recommended:
        ColorTheme.textTertiary
    }
}

extension GearCategory {
    var systemImageName: String {
        switch self {
        case .water:
            "water"
        case .food:
            "food"
        case .medical:
            "first_aid"
        case .power:
            "battery"
        case .communication:
            "radio"
        case .fireSafety:
            "fire_blanket"
        case .tools:
            "wrench.and.screwdriver.fill"
        case .vehicle:
            "vehicle"
        case .lighting:
            "flashlight"
        case .navigation:
            "compass"
        }
    }
}
