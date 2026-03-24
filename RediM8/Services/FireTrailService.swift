import Foundation

final class FireTrailService {
    private let trailDataset: TrackDataset

    init(bundle: Bundle = .main) {
        do {
            trailDataset = try bundle.decode("FireTrails.json", as: TrackDataset.self)
        } catch {
            RediLogger.basemap.error("Failed to decode FireTrails.json: \(error.localizedDescription, privacy: .public)")
            trailDataset = TrackDataset(lastUpdated: .distantPast, tracks: [])
        }
    }

    var lastUpdated: Date {
        trailDataset.lastUpdated
    }

    var dataFreshness: DataFreshness {
        TrustLayer.dataFreshness(lastUpdated: lastUpdated, sourceKind: .curatedBundle)
    }

    var freshnessImpactMessage: String {
        "Route accessibility may be inaccurate"
    }

    var didLoadOfflineData: Bool {
        !trailDataset.tracks.isEmpty
    }

    var allTrails: [TrackSegment] {
        trailDataset.tracks
    }

    func fireTrails(for installedPackIDs: Set<String>) -> [TrackSegment] {
        trailDataset.tracks.filter { trail in
            trail.isFireAccessTrail && isFeatureAvailable(trail.packIDs, within: installedPackIDs)
        }
    }

    private func isFeatureAvailable(_ featurePackIDs: [String], within installedPackIDs: Set<String>) -> Bool {
        featurePackIDs.isEmpty || !Set(featurePackIDs).isDisjoint(with: installedPackIDs)
    }
}
