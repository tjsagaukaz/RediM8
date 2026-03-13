import SwiftUI

struct OfflineDataManagementView: View {
    let appState: AppState

    @State private var installedPackIDs: Set<String>

    init(appState: AppState) {
        self.appState = appState
        _installedPackIDs = State(initialValue: appState.mapDataService.loadInstalledPackIDs())
    }

    private var installedSizeSummary: String {
        let totalSize = appState.mapDataService
            .packs(withIDs: installedPackIDs)
            .reduce(0) { $0 + $1.sizeMB }
        return totalSize == 1 ? "1 MB stored locally" : "\(totalSize) MB stored locally"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ModeHeroCard(
                    eyebrow: "Pack Storage",
                    title: "Offline Data",
                    subtitle: "Keep local map coverage on-device so routes, shelters, water points, and tracks still load when coverage drops away.",
                    iconName: "map_marker",
                    accent: ColorTheme.info,
                    backgroundAssetName: "map_remote_track"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(installedPackIDs.count) pack(s) installed")
                            .font(.headline)
                            .foregroundStyle(ColorTheme.text)
                        Text(installedSizeSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(TrustLayer.mapFreshnessNotice)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(appState.mapDataService.availablePacks) { pack in
                    PanelCard(title: pack.name, subtitle: pack.subtitle) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center) {
                                Text("\(pack.sizeMB) MB")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(ColorTheme.text)
                                Spacer()
                                Text(installedPackIDs.contains(pack.id) ? "Installed" : "Available")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(installedPackIDs.contains(pack.id) ? SettingsPalette.accent : ColorTheme.info)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background((installedPackIDs.contains(pack.id) ? SettingsPalette.mutedAccent : ColorTheme.info.opacity(0.16)), in: Capsule())
                            }

                            Text(pack.coverageSummary)
                                .font(.subheadline)
                                .foregroundStyle(ColorTheme.text)

                            Text("Layers: \(pack.supportedLayerSummary)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button(installedPackIDs.contains(pack.id) ? "Remove Pack" : "Install Pack") {
                                togglePack(pack.id)
                            }
                            .modifier(PackButtonStyleModifier(isInstalled: installedPackIDs.contains(pack.id)))
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle("Offline Data")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func togglePack(_ packID: String) {
        if installedPackIDs.contains(packID) {
            installedPackIDs = appState.mapDataService.removePack(packID, from: installedPackIDs)
        } else {
            installedPackIDs = appState.mapDataService.installPack(packID, into: installedPackIDs)
        }
    }
}

private struct PackButtonStyleModifier: ViewModifier {
    let isInstalled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isInstalled {
            content.buttonStyle(SecondaryActionButtonStyle())
        } else {
            content.buttonStyle(PrimaryActionButtonStyle())
        }
    }
}
