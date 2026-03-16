import CoreLocation
import Foundation

/// Analyzes a route corridor — a buffer zone around a computed route —
/// and queries spatial indexes for survival resources along the path.
///
/// Given a route's coordinate list, builds a corridor (default 200m buffer)
/// and finds water, shelters, fuel, and other resources near the route.
/// Results include distance along the route and offset from the route line.
@MainActor
final class RouteCorridor {

    // MARK: - Types

    struct CorridorResource {
        let name: String
        let subtitle: String
        let category: NearestResourceService.ResourceCategory
        let coordinate: CLLocationCoordinate2D
        /// Distance along the route from origin to the closest route point.
        let distanceAlongRouteMetres: CLLocationDistance
        /// Perpendicular distance from the route line.
        let offsetFromRouteMetres: CLLocationDistance

        var distanceAlongText: String {
            if distanceAlongRouteMetres >= 1000 {
                return String(format: "%.1f km ahead", distanceAlongRouteMetres / 1000)
            }
            return "\(Int(distanceAlongRouteMetres.rounded())) m ahead"
        }

        var offsetText: String {
            if offsetFromRouteMetres >= 1000 {
                return String(format: "%.1f km off route", offsetFromRouteMetres / 1000)
            }
            return "\(Int(offsetFromRouteMetres.rounded())) m off route"
        }
    }

    struct CorridorAnalysis {
        let route: OfflineRoutingService.Route
        let corridorWidthMetres: CLLocationDistance
        let waterSources: [CorridorResource]
        let shelters: [CorridorResource]
        let towns: [CorridorResource]

        var allResources: [CorridorResource] {
            (waterSources + shelters + towns)
                .sorted { $0.distanceAlongRouteMetres < $1.distanceAlongRouteMetres }
        }

        var hasWaterAccess: Bool { !waterSources.isEmpty }
        var hasShelterAccess: Bool { !shelters.isEmpty }

        /// Longest gap between water sources along the route.
        var longestWaterGapMetres: CLLocationDistance {
            guard waterSources.count > 1 else {
                return route.distanceMetres
            }
            let sorted = waterSources.sorted { $0.distanceAlongRouteMetres < $1.distanceAlongRouteMetres }
            var maxGap: CLLocationDistance = sorted[0].distanceAlongRouteMetres
            for i in 1 ..< sorted.count {
                let gap = sorted[i].distanceAlongRouteMetres - sorted[i - 1].distanceAlongRouteMetres
                maxGap = max(maxGap, gap)
            }
            // Also check gap from last water to destination
            let tailGap = route.distanceMetres - (sorted.last?.distanceAlongRouteMetres ?? 0)
            maxGap = max(maxGap, tailGap)
            return maxGap
        }

        var longestWaterGapText: String {
            let gap = longestWaterGapMetres
            if gap >= 1000 {
                return String(format: "%.0f km", gap / 1000)
            }
            return "\(Int(gap.rounded())) m"
        }
    }

    // MARK: - Properties

    private let nearestService: NearestResourceService
    private let installedPackIDs: Set<String>

    init(nearestService: NearestResourceService, installedPackIDs: Set<String>) {
        self.nearestService = nearestService
        self.installedPackIDs = installedPackIDs
    }

    // MARK: - Analysis

    /// Analyze a route corridor for survival resources.
    /// Samples the route at regular intervals and queries the R-tree for nearby resources.
    func analyze(
        route: OfflineRoutingService.Route,
        corridorWidthMetres: CLLocationDistance = 200
    ) -> CorridorAnalysis {
        let coordinates = route.coordinates
        guard coordinates.count >= 2 else {
            return CorridorAnalysis(
                route: route,
                corridorWidthMetres: corridorWidthMetres,
                waterSources: [],
                shelters: [],
                towns: []
            )
        }

        // Build cumulative distance array
        let cumulativeDistances = buildCumulativeDistances(coordinates)

        // Sample points along the route at intervals (every 500m or at each vertex)
        let sampleInterval: CLLocationDistance = 500
        let samplePoints = buildSamplePoints(coordinates, cumulativeDistances: cumulativeDistances, interval: sampleInterval)

        // Query all resource categories within the corridor
        let searchRadius = corridorWidthMetres * 2 // Search wider, filter later
        var waterSet = Set<String>()
        var shelterSet = Set<String>()
        var townSet = Set<String>()
        var waterResults: [CorridorResource] = []
        var shelterResults: [CorridorResource] = []
        var townResults: [CorridorResource] = []

        for (sampleCoord, _) in samplePoints {
            // Water
            let waterNearby = nearestService.nearest(
                .water,
                to: sampleCoord,
                installedPackIDs: installedPackIDs,
                limit: 3
            )
            for result in waterNearby where result.distanceMetres <= searchRadius && !waterSet.contains(result.id) {
                waterSet.insert(result.id)
                let (closestDist, offset) = closestRoutePoint(result.coordinate, coordinates: coordinates, cumulativeDistances: cumulativeDistances)
                if offset <= corridorWidthMetres {
                    waterResults.append(CorridorResource(
                        name: result.name,
                        subtitle: result.subtitle,
                        category: .water,
                        coordinate: result.coordinate,
                        distanceAlongRouteMetres: closestDist,
                        offsetFromRouteMetres: offset
                    ))
                }
            }

            // Shelters
            let shelterNearby = nearestService.nearest(
                .shelter,
                to: sampleCoord,
                installedPackIDs: installedPackIDs,
                limit: 3
            )
            for result in shelterNearby where result.distanceMetres <= searchRadius && !shelterSet.contains(result.id) {
                shelterSet.insert(result.id)
                let (closestDist, offset) = closestRoutePoint(result.coordinate, coordinates: coordinates, cumulativeDistances: cumulativeDistances)
                if offset <= corridorWidthMetres {
                    shelterResults.append(CorridorResource(
                        name: result.name,
                        subtitle: result.subtitle,
                        category: .shelter,
                        coordinate: result.coordinate,
                        distanceAlongRouteMetres: closestDist,
                        offsetFromRouteMetres: offset
                    ))
                }
            }

            // Towns
            let townNearby = nearestService.nearest(
                .town,
                to: sampleCoord,
                installedPackIDs: installedPackIDs,
                limit: 3
            )
            for result in townNearby where result.distanceMetres <= searchRadius && !townSet.contains(result.id) {
                townSet.insert(result.id)
                let (closestDist, offset) = closestRoutePoint(result.coordinate, coordinates: coordinates, cumulativeDistances: cumulativeDistances)
                if offset <= corridorWidthMetres {
                    townResults.append(CorridorResource(
                        name: result.name,
                        subtitle: result.subtitle,
                        category: .town,
                        coordinate: result.coordinate,
                        distanceAlongRouteMetres: closestDist,
                        offsetFromRouteMetres: offset
                    ))
                }
            }
        }

        return CorridorAnalysis(
            route: route,
            corridorWidthMetres: corridorWidthMetres,
            waterSources: waterResults.sorted { $0.distanceAlongRouteMetres < $1.distanceAlongRouteMetres },
            shelters: shelterResults.sorted { $0.distanceAlongRouteMetres < $1.distanceAlongRouteMetres },
            towns: townResults.sorted { $0.distanceAlongRouteMetres < $1.distanceAlongRouteMetres }
        )
    }

    // MARK: - Geometry Helpers

    private func buildCumulativeDistances(_ coords: [CLLocationCoordinate2D]) -> [CLLocationDistance] {
        var distances: [CLLocationDistance] = [0]
        for i in 1 ..< coords.count {
            let prev = CLLocation(latitude: coords[i - 1].latitude, longitude: coords[i - 1].longitude)
            let curr = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            distances.append(distances[i - 1] + prev.distance(from: curr))
        }
        return distances
    }

    private func buildSamplePoints(
        _ coords: [CLLocationCoordinate2D],
        cumulativeDistances: [CLLocationDistance],
        interval: CLLocationDistance
    ) -> [(CLLocationCoordinate2D, CLLocationDistance)] {
        guard let totalDistance = cumulativeDistances.last, totalDistance > 0 else { return [] }

        var points: [(CLLocationCoordinate2D, CLLocationDistance)] = []

        // Include all vertices
        for (i, coord) in coords.enumerated() {
            points.append((coord, cumulativeDistances[i]))
        }

        // Interpolate additional points at regular intervals
        var targetDistance = interval
        while targetDistance < totalDistance {
            // Find the segment containing this distance
            for i in 1 ..< cumulativeDistances.count {
                if cumulativeDistances[i] >= targetDistance {
                    let segmentStart = cumulativeDistances[i - 1]
                    let segmentLength = cumulativeDistances[i] - segmentStart
                    guard segmentLength > 0 else { break }
                    let fraction = (targetDistance - segmentStart) / segmentLength
                    let lat = coords[i - 1].latitude + (coords[i].latitude - coords[i - 1].latitude) * fraction
                    let lon = coords[i - 1].longitude + (coords[i].longitude - coords[i - 1].longitude) * fraction
                    points.append((CLLocationCoordinate2D(latitude: lat, longitude: lon), targetDistance))
                    break
                }
            }
            targetDistance += interval
        }

        return points.sorted { $0.1 < $1.1 }
    }

    /// Find the closest point on the route to a given coordinate.
    /// Returns (distance along route, perpendicular offset from route).
    private func closestRoutePoint(
        _ point: CLLocationCoordinate2D,
        coordinates: [CLLocationCoordinate2D],
        cumulativeDistances: [CLLocationDistance]
    ) -> (CLLocationDistance, CLLocationDistance) {
        let pointLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        var bestDist = CLLocationDistance.greatestFiniteMagnitude
        var bestAlong: CLLocationDistance = 0

        for i in 0 ..< coordinates.count {
            let segLoc = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let dist = pointLoc.distance(from: segLoc)
            if dist < bestDist {
                bestDist = dist
                bestAlong = cumulativeDistances[i]
            }
        }

        return (bestAlong, bestDist)
    }
}
