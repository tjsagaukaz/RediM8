import CoreLocation
import SwiftUI

struct NearestResourceView: View {
    let appState: AppState
    let currentLocation: CLLocation?

    @State private var selectedCategory: NearestResourceService.ResourceCategory = .water
    @State private var results: [NearestResourceService.NearestResult] = []
    @State private var isQuerying = false

    private var service: NearestResourceService {
        NearestResourceService(
            waterPointService: appState.waterPointService,
            shelterService: appState.shelterService,
            mapService: appState.mapService,
            mapDataService: appState.mapDataService
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            categorySelector
                .padding(.horizontal, RediSpacing.screen)
                .padding(.top, RediSpacing.content)
                .padding(.bottom, RediSpacing.compact)

            Divider()
                .background(ColorTheme.divider)

            if let location = currentLocation {
                resultsList(for: location)
            } else {
                noLocationState
            }
        }
        .background(ColorTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("NEAREST RESOURCE")
                        .font(RediTypography.data)
                        .foregroundStyle(ColorTheme.text)
                    Text("KNN SURVIVAL QUERY")
                        .font(RediTypography.label)
                        .tracking(1.2)
                        .foregroundStyle(ColorTheme.textTertiary)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: selectedCategory) { _, _ in
            runQuery()
        }
        .onAppear {
            runQuery()
        }
    }

    // MARK: - Category Selector

    private var categorySelector: some View {
        HStack(spacing: RediSpacing.compact) {
            ForEach(NearestResourceService.ResourceCategory.allCases) { category in
                Button {
                    selectedCategory = category
                } label: {
                    HStack(spacing: RediSpacing.tight) {
                        Image(systemName: category.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(category.title)
                            .font(RediTypography.label)
                            .tracking(1.2)
                    }
                    .foregroundStyle(
                        selectedCategory == category
                            ? ColorTheme.accent
                            : ColorTheme.textTertiary
                    )
                    .padding(.horizontal, RediSpacing.content)
                    .padding(.vertical, RediSpacing.compact)
                    .background(
                        selectedCategory == category
                            ? ColorTheme.accent.opacity(0.1)
                            : ColorTheme.graphite,
                        in: RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RediRadius.chip, style: .continuous)
                            .stroke(
                                selectedCategory == category
                                    ? ColorTheme.accent.opacity(0.3)
                                    : ColorTheme.divider,
                                lineWidth: 0.5
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Results

    private func resultsList(for location: CLLocation) -> some View {
        ScrollView {
            if results.isEmpty {
                emptyState
                    .padding(.top, RediSpacing.section)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        resultRow(result, index: index + 1)

                        if index < results.count - 1 {
                            Divider()
                                .background(ColorTheme.dividerSubtle)
                                .padding(.leading, RediSpacing.screen)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func resultRow(_ result: NearestResourceService.NearestResult, index: Int) -> some View {
        HStack(alignment: .top, spacing: RediSpacing.content) {
            Text("\(index)")
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.accent)
                .frame(width: 20, alignment: .trailing)

            VStack(alignment: .leading, spacing: RediSpacing.micro) {
                Text(result.name.uppercased())
                    .font(RediTypography.bodyStrong)
                    .foregroundStyle(ColorTheme.text)
                    .lineLimit(1)

                Text(result.subtitle)
                    .font(RediTypography.caption)
                    .foregroundStyle(ColorTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(result.distanceText)
                .font(RediTypography.data)
                .foregroundStyle(ColorTheme.text)
        }
        .padding(.horizontal, RediSpacing.screen)
        .padding(.vertical, RediSpacing.content)
        .contentShape(Rectangle())
        .onTapGesture {
            openInMaps(result)
        }
    }

    // MARK: - States

    private var noLocationState: some View {
        VStack(spacing: RediSpacing.content) {
            Spacer()
            Image(systemName: "location.slash")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(ColorTheme.textTertiary)
            Text("LOCATION UNAVAILABLE")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
            Text("Enable location services to find nearest resources.")
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, RediSpacing.screen)
    }

    private var emptyState: some View {
        VStack(spacing: RediSpacing.content) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(ColorTheme.textTertiary)
            Text("NO RESULTS")
                .font(RediTypography.label)
                .tracking(1.2)
                .foregroundStyle(ColorTheme.textTertiary)
            Text("No \(selectedCategory.title.lowercased()) resources found in offline data.")
                .font(RediTypography.caption)
                .foregroundStyle(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, RediSpacing.screen)
    }

    // MARK: - Actions

    private func runQuery() {
        guard let location = currentLocation else {
            results = []
            return
        }

        let coordinate = location.coordinate
        let installedPackIDs = appState.mapDataService.loadInstalledPackIDs()

        results = service.nearest(
            selectedCategory,
            to: coordinate,
            installedPackIDs: installedPackIDs,
            limit: 5
        )
    }

    private func openInMaps(_ result: NearestResourceService.NearestResult) {
        let encodedName = result.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? result.name
        if let url = URL(string: "maps://?ll=\(result.coordinate.latitude),\(result.coordinate.longitude)&q=\(encodedName)") {
            UIApplication.shared.open(url)
        }
    }
}
