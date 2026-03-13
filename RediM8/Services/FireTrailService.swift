import Foundation

final class FireTrailService {
    private let trailDataset: TrackDataset

    init(bundle: Bundle = .main) {
        trailDataset = (try? bundle.decode("FireTrails.json", as: TrackDataset.self))
            ?? TrackDataset(lastUpdated: .distantPast, tracks: [])
    }

    var lastUpdated: Date {
        trailDataset.lastUpdated
    }

    var didLoadOfflineData: Bool {
        !trailDataset.tracks.isEmpty
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
