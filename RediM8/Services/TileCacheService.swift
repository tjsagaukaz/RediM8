import Combine
import CoreLocation
import Foundation
import MapLibre

/// Manages opportunistic tile caching via MapLibre's MLNOfflineStorage.
///
/// Two caching strategies:
/// 1. **Ambient cache** — MapLibre automatically caches tiles the user views.
///    We set a generous max size so viewed tiles survive app restarts.
/// 2. **Region packs** — Explicit tile downloads for installed map pack regions,
///    enabling full offline basemap coverage without internet.
@MainActor
final class TileCacheService: ObservableObject {
    private enum Config {
        static let ambientCacheSizeBytes: UInt = 100 * 1024 * 1024 // 100 MB
        static let minZoom: Double = 3
        static let maxZoom: Double = 12
        static let contextPrefix = "redim8-tile-pack-"
    }

    enum PackDownloadState: Equatable {
        case idle
        case downloading(packID: String, progress: Double)
        case complete(packID: String)
        case failed(packID: String, message: String)
    }

    @Published private(set) var downloadState: PackDownloadState = .idle
    @Published private(set) var cacheSizeBytes: UInt64 = 0

    private let storage: MLNOfflineStorage
    private var progressObserver: NSObjectProtocol?
    private var errorObserver: NSObjectProtocol?

    init() {
        self.storage = MLNOfflineStorage.shared
        configureAmbientCache()
        refreshCacheSize()
        observeProgress()
    }

    deinit {
        if let observer = progressObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = errorObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Ambient Cache

    private func configureAmbientCache() {
        storage.setMaximumAmbientCacheSize(Config.ambientCacheSizeBytes) { error in
            if let error {
                print("[TileCacheService] Failed to set ambient cache size: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Region Pack Downloads

    /// Download tiles for a map pack region so it's available offline.
    func downloadTiles(
        for pack: OfflineMapPack,
        styleURL: URL
    ) {
        let sw = CLLocationCoordinate2D(
            latitude: pack.center.latitude - pack.latitudeDelta / 2,
            longitude: pack.center.longitude - pack.longitudeDelta / 2
        )
        let ne = CLLocationCoordinate2D(
            latitude: pack.center.latitude + pack.latitudeDelta / 2,
            longitude: pack.center.longitude + pack.longitudeDelta / 2
        )
        let bounds = MLNCoordinateBounds(sw: sw, ne: ne)

        let region = MLNTilePyramidOfflineRegion(
            styleURL: styleURL,
            bounds: bounds,
            fromZoomLevel: Config.minZoom,
            toZoomLevel: Config.maxZoom
        )

        let contextString = "\(Config.contextPrefix)\(pack.id)"
        guard let context = contextString.data(using: .utf8) else { return }

        downloadState = .downloading(packID: pack.id, progress: 0)

        storage.addPack(for: region, withContext: context) { [weak self] mlnPack, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.downloadState = .failed(
                        packID: pack.id,
                        message: error.localizedDescription
                    )
                    return
                }
                mlnPack?.resume()
            }
        }
    }

    /// Cancel any in-progress download.
    func cancelDownload() {
        guard case let .downloading(packID, _) = downloadState else { return }
        let contextString = "\(Config.contextPrefix)\(packID)"

        storage.packs?.forEach { pack in
            if let ctx = String(data: pack.context, encoding: .utf8), ctx == contextString {
                pack.suspend()
            }
        }
        downloadState = .idle
    }

    /// Remove cached tiles for a specific map pack.
    func removeTiles(for packID: String) {
        let contextString = "\(Config.contextPrefix)\(packID)"

        storage.packs?.forEach { pack in
            if let ctx = String(data: pack.context, encoding: .utf8), ctx == contextString {
                storage.removePack(pack) { [weak self] error in
                    Task { @MainActor in
                        if error == nil {
                            self?.refreshCacheSize()
                        }
                    }
                }
            }
        }
    }

    /// Check if tiles are already cached for a pack.
    func hasCachedTiles(for packID: String) -> Bool {
        let contextString = "\(Config.contextPrefix)\(packID)"
        return storage.packs?.contains { pack in
            guard let ctx = String(data: pack.context, encoding: .utf8) else { return false }
            return ctx == contextString && pack.state == .complete
        } ?? false
    }

    /// Clear the ambient cache (tiles cached from browsing, not explicit downloads).
    func clearAmbientCache() {
        storage.clearAmbientCache { [weak self] _ in
            Task { @MainActor in
                self?.refreshCacheSize()
            }
        }
    }

    // MARK: - Cache Size

    func refreshCacheSize() {
        cacheSizeBytes = storage.countOfBytesCompleted
    }

    var cacheSizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(cacheSizeBytes), countStyle: .file)
    }

    // MARK: - Progress Observation

    private func observeProgress() {
        progressObserver = NotificationCenter.default.addObserver(
            forName: .MLNOfflinePackProgressChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      let pack = notification.object as? MLNOfflinePack else { return }

                guard let ctx = String(data: pack.context, encoding: .utf8),
                      ctx.hasPrefix(Config.contextPrefix) else { return }

                let packID = String(ctx.dropFirst(Config.contextPrefix.count))
                let progress = pack.progress

                if pack.state == .complete {
                    self.downloadState = .complete(packID: packID)
                    self.refreshCacheSize()
                } else if progress.countOfResourcesExpected > 0 {
                    let fraction = Double(progress.countOfResourcesCompleted) / Double(progress.countOfResourcesExpected)
                    self.downloadState = .downloading(packID: packID, progress: fraction)
                }
            }
        }

        errorObserver = NotificationCenter.default.addObserver(
            forName: .MLNOfflinePackError,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self,
                      let pack = notification.object as? MLNOfflinePack else { return }

                guard let ctx = String(data: pack.context, encoding: .utf8),
                      ctx.hasPrefix(Config.contextPrefix) else { return }

                let packID = String(ctx.dropFirst(Config.contextPrefix.count))
                let error = notification.userInfo?[MLNOfflinePackUserInfoKey.error] as? NSError
                self.downloadState = .failed(
                    packID: packID,
                    message: error?.localizedDescription ?? "Download failed."
                )
            }
        }
    }
}
