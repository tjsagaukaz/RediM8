import Foundation

// MARK: - Hazard Feed

extension MapViewModel {
    var hazardFeedStatusValue: String {
        if hazardFeedIsFetching && hazardFeedLastSuccessfulFetch == nil {
            return "Syncing"
        }

        if hazardFeedLastSuccessfulFetch == nil {
            return hazardFeedLastRefreshError == nil ? "Pending" : "Unavailable"
        }

        if hazardFeedLastRefreshError != nil || hazardFeedService.isFeedStale {
            return "Stale"
        }

        return hazardFeedService.feedFreshnessText
    }

    var hazardFeedHeadline: String {
        if hazardFeedLastRefreshError != nil {
            return hazardFeedLastSuccessfulFetch == nil
                ? "No official hazard feed cache yet"
                : "Official hazard feeds need attention"
        }

        if hazardFeedLastSuccessfulFetch != nil {
            return hazardFeedService.isFeedStale
                ? "Route hazard overlays may be older than usual"
                : "Official hazard feeds refreshed for routing"
        }

        return hazardFeedIsFetching
            ? "Syncing live hazard feeds"
            : "Connect once to mirror route hazard feeds"
    }

    var hazardFeedDetail: String {
        if let hazardFeedLastRefreshError {
            return hazardFeedLastRefreshError
        }

        if let hazardFeedLastSuccessfulFetch {
            if hazardFeedService.isFeedStale {
                return "Route hazard overlays may be older than usual. Last successful refresh \(DateFormatter.rediM8Short.string(from: hazardFeedLastSuccessfulFetch))."
            }

            return "BOM and state fire feeds were refreshed \(DateFormatter.rediM8Short.string(from: hazardFeedLastSuccessfulFetch)) for route hazard awareness."
        }

        return "Connect once so RediM8 can mirror official hazard feeds for route and safety overlays."
    }

    var hazardFeedTone: OperationalStatusTone {
        if hazardFeedLastSuccessfulFetch == nil {
            if hazardFeedLastRefreshError != nil {
                return .danger
            }
            return hazardFeedIsFetching ? .info : .caution
        }

        return hazardFeedLastRefreshError != nil || hazardFeedService.isFeedStale ? .caution : .ready
    }

    var hazardFeedUnavailableMessage: String? {
        hazardFeedLastRefreshError
    }
}
