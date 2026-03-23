import SwiftUI

// MARK: - Reusable Card Components

extension GuideLibraryView {

    func collectionCard(_ collection: GuideCollection) -> some View {
        let guides = appState.guideService.featuredCollection(collection)
        let previewGuides = Array(guides.prefix(2))
        let tint = collectionAccent(for: collection)

        return Button {
            activateCollection(collection)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    Text(collection.title.uppercased())
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)

                    Spacer(minLength: 0)

                    Text("\(guides.count) guides")
                        .font(RediTypography.caption)
                        .foregroundStyle(ColorTheme.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ColorTheme.panel.opacity(0.8), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(collection.title)
                        .font(.headline)
                        .foregroundStyle(ColorTheme.text)
                    Text(collection.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(ColorTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(previewGuides) { guide in
                        HStack(alignment: .center, spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(tint.opacity(0.14))
                                    .frame(width: 28, height: 28)

                                RediIcon(guide.heroIconName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(tint)
                                    .frame(width: 14, height: 14)
                            }

                            Text(guide.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ColorTheme.text)
                                .lineLimit(2)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text(collection == .emergency ? "High-stress first" : "Curated offline bundle")
                        .font(.caption)
                        .foregroundStyle(ColorTheme.textTertiary)

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                }
            }
            .frame(width: 244, alignment: .leading)
            .padding(18)
            .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous))
        }
        .buttonStyle(CardPressButtonStyle())
    }

    func guideRow(_ guide: Guide) -> some View {
        let tint = accent(for: guide.category)

        return ZStack(alignment: .topTrailing) {
            Button {
                openGuide(guide)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(tint.opacity(0.16))
                                .frame(width: 48, height: 48)

                            RediIcon(guide.heroIconName)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(tint)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(guide.category.title.uppercased())
                                .font(RediTypography.caption)
                                .foregroundStyle(ColorTheme.textTertiary)

                            Text(guide.title)
                                .font(.headline)
                                .foregroundStyle(ColorTheme.text)

                            Text(guide.summary)
                                .font(.subheadline)
                                .foregroundStyle(ColorTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)
                    }

                    TrustPillGroup(items: trustItems(for: guide))

                    HStack(spacing: 12) {
                        Label("Stored offline", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textTertiary)

                        Text("Reviewed \(guide.lastReviewed)")
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textTertiary)

                        if !guide.sources.isEmpty {
                            Text("\(guide.sources.count) sources")
                                .font(.caption)
                                .foregroundStyle(ColorTheme.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ColorTheme.textTertiary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.card, style: .continuous))
            }
            .buttonStyle(CardPressButtonStyle())

            guideSaveButton(for: guide)
                .padding(12)
        }
    }

    func spotlightGuideCard(
        _ guide: Guide,
        eyebrow: String,
        detail: String,
        tint: Color
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                openGuide(guide)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(eyebrow.uppercased())
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.textTertiary)

                        Spacer(minLength: 0)

                        Text(detail)
                            .font(RediTypography.caption)
                            .foregroundStyle(ColorTheme.textTertiary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(ColorTheme.panel.opacity(0.84), in: Capsule())
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tint.opacity(0.15))
                            .frame(width: 46, height: 46)

                        RediIcon(guide.heroIconName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(tint)
                            .frame(width: 18, height: 18)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(guide.title)
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)
                            .lineLimit(2)

                        Text(guide.summary)
                            .font(.subheadline)
                            .foregroundStyle(ColorTheme.textSecondary)
                            .lineLimit(3)
                    }

                    TrustPillGroup(items: Array(trustItems(for: guide).prefix(3)))

                    HStack(spacing: 8) {
                        Label("Stored offline", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(ColorTheme.textTertiary)

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 252, alignment: .leading)
                .padding(18)
                .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous))
            }
            .buttonStyle(CardPressButtonStyle())

            guideSaveButton(for: guide)
                .padding(12)
        }
    }

    func categoryDirectoryCard(category: GuideCategory, guides: [Guide]) -> some View {
        let tint = accent(for: category)
        let isSelected = selectedCategory == category
        let officialCount = guides.filter { guide in
            guide.sources.contains(where: { $0.kind == .official })
        }.count

        return Button {
            selectedCategory = isSelected ? nil : category
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill((isSelected ? ColorTheme.background : tint).opacity(isSelected ? 0.14 : 0.14))
                            .frame(width: 40, height: 40)

                        RediIcon(category.systemImage)
                            .foregroundStyle(isSelected ? ColorTheme.background : tint)
                            .frame(width: 18, height: 18)
                    }

                    Spacer(minLength: 0)

                    Text("\(guides.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? ColorTheme.background : ColorTheme.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((isSelected ? Color.white.opacity(0.16) : ColorTheme.panelRaised), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(category.title)
                        .font(.headline)
                        .foregroundStyle(isSelected ? ColorTheme.background : ColorTheme.text)

                    Text(categorySummary(for: category))
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? ColorTheme.background.opacity(0.82) : ColorTheme.textSecondary)
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    Text(officialCount == 0 ? "Offline shelf" : "\(officialCount) official")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? ColorTheme.background.opacity(0.92) : tint)

                    Spacer(minLength: 0)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? ColorTheme.background : tint)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 188, alignment: .leading)
            .padding(16)
            .background(ColorTheme.panel, in: RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RediRadius.hero, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.16) : ColorTheme.dividerStrong, lineWidth: 1)
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }

    func guideSaveButton(for guide: Guide) -> some View {
        Button {
            _ = toggleSavedGuide(guide.id)
        } label: {
            Image(systemName: isGuideSaved(guide.id) ? "bookmark.fill" : "bookmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isGuideSaved(guide.id) ? ColorTheme.accent : ColorTheme.textTertiary)
                .frame(width: 34, height: 34)
                .background(ColorTheme.panel.opacity(0.92), in: Circle())
                .overlay(
                    Circle()
                        .stroke(ColorTheme.dividerStrong, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
