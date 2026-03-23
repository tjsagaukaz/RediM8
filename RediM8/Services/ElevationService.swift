import CoreLocation
import Foundation

/// Offline elevation data service for terrain-aware routing.
///
/// Loads SRTM-derived elevation grids bundled with region packs.
/// Provides elevation queries for routing penalties and flood/fire risk assessment.
///
/// Data format: `.elev` files — simple grid of Int16 elevation values (metres above sea level).
/// Grid resolution: ~90m (3 arc-second SRTM) or ~30m (1 arc-second) depending on pack.
///
/// Integration:
///   - Flood avoidance: penalize edges at low elevation near water bodies
///   - Fire corridor avoidance: penalize edges in valleys (fire funnels)
///   - Terrain difficulty: penalize steep gradients for foot/vehicle profiles
@MainActor
final class ElevationService {

    // MARK: - Types

    struct ElevationGrid {
        let origin: CLLocationCoordinate2D // SW corner
        let cellSizeDegrees: Double        // Grid cell size in degrees
        let cols: Int
        let rows: Int
        let data: [Int16]                  // Row-major, SW to NE

        func elevation(at coordinate: CLLocationCoordinate2D) -> Int16? {
            let col = Int((coordinate.longitude - origin.longitude) / cellSizeDegrees)
            let row = Int((coordinate.latitude - origin.latitude) / cellSizeDegrees)
            guard col >= 0, col < cols, row >= 0, row < rows else { return nil }
            return data[row * cols + col]
        }
    }

    struct TerrainPenalty {
        let coordinate: CLLocationCoordinate2D
        let elevation: Int16
        let penalty: Double
        let reason: TerrainRisk
    }

    enum TerrainRisk: String {
        case floodPlain     // Low elevation near rivers — flood risk
        case valleyFunnel   // Valley bottom — fire acceleration
        case steepGradient  // Steep slope — slow travel
        case coastal        // Near sea level — storm surge risk
    }

    /// Terrain analysis result for a route segment.
    struct TerrainProfile {
        let minElevation: Int16
        let maxElevation: Int16
        let totalAscent: Int
        let totalDescent: Int
        let floodRiskSegments: Int
        let valleySegments: Int

        var elevationRange: Int { Int(maxElevation) - Int(minElevation) }

        var ascentText: String {
            if totalAscent >= 1000 {
                return String(format: "%.1f km", Double(totalAscent) / 1000)
            }
            return "\(totalAscent) m"
        }

        var descentText: String {
            if totalDescent >= 1000 {
                return String(format: "%.1f km", Double(totalDescent) / 1000)
            }
            return "\(totalDescent) m"
        }
    }

    // MARK: - Configuration

    private enum Config {
        /// Elevation below which flood risk penalties apply (metres above sea level).
        static let floodPlainThreshold: Int16 = 10
        /// Coastal storm surge threshold (metres above sea level).
        static let coastalThreshold: Int16 = 5
        /// Gradient (metres per 100m horizontal) above which steep penalty applies.
        static let steepGradientThreshold: Double = 15.0
        /// Penalty multipliers for terrain hazards.
        static let floodPlainPenalty: Double = 3.0
        static let valleyPenalty: Double = 2.0
        static let steepPenalty: Double = 1.5
        static let coastalPenalty: Double = 4.0
    }

    // MARK: - State

    private var grid: ElevationGrid?
    @Published private(set) var isLoaded = false

    // MARK: - Loading

    /// Load an elevation grid from a `.elev` file bundled with a region pack.
    ///
    /// File format (binary, little-endian):
    ///   - 8 bytes: origin latitude (Float64)
    ///   - 8 bytes: origin longitude (Float64)
    ///   - 8 bytes: cell size in degrees (Float64)
    ///   - 4 bytes: columns (UInt32)
    ///   - 4 bytes: rows (UInt32)
    ///   - remaining: Int16 elevation values (row-major, cols * rows * 2 bytes)
    func load(from url: URL) throws {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count >= 32 else {
            throw ElevationError.invalidFormat
        }

        let originLat = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Float64.self) }
        let originLon = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Float64.self) }
        let cellSize = data.withUnsafeBytes { $0.load(fromByteOffset: 16, as: Float64.self) }
        let cols = data.withUnsafeBytes { $0.load(fromByteOffset: 24, as: UInt32.self) }
        let rows = data.withUnsafeBytes { $0.load(fromByteOffset: 28, as: UInt32.self) }

        let headerSize = 32
        let expectedDataSize = Int(cols) * Int(rows) * 2
        guard data.count >= headerSize + expectedDataSize else {
            throw ElevationError.invalidFormat
        }

        let elevations: [Int16] = try data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                throw ElevationError.invalidFormat
            }
            let ptr = baseAddress.advanced(by: headerSize)
                .assumingMemoryBound(to: Int16.self)
            return Array(UnsafeBufferPointer(start: ptr, count: Int(cols) * Int(rows)))
        }

        grid = ElevationGrid(
            origin: CLLocationCoordinate2D(latitude: originLat, longitude: originLon),
            cellSizeDegrees: cellSize,
            cols: Int(cols),
            rows: Int(rows),
            data: elevations
        )
        isLoaded = true
    }

    func unload() {
        grid = nil
        isLoaded = false
    }

    // MARK: - Queries

    /// Query elevation at a coordinate. Returns nil if no grid loaded or outside bounds.
    func elevation(at coordinate: CLLocationCoordinate2D) -> Int16? {
        grid?.elevation(at: coordinate)
    }

    /// Compute terrain penalties for a set of coordinates (e.g. graph nodes near a route).
    /// Returns penalties that should be applied as HazardZones to the routing engine.
    func terrainHazardZones(
        along coordinates: [CLLocationCoordinate2D],
        hazardTypes: Set<TerrainRisk> = [.floodPlain, .valleyFunnel, .coastal]
    ) -> [OfflineRoutingService.HazardZone] {
        guard let grid else { return [] }

        var zones: [OfflineRoutingService.HazardZone] = []
        var seen = Set<String>() // Deduplicate by grid cell

        for coord in coordinates {
            let col = Int((coord.longitude - grid.origin.longitude) / grid.cellSizeDegrees)
            let row = Int((coord.latitude - grid.origin.latitude) / grid.cellSizeDegrees)
            let cellKey = "\(col),\(row)"
            guard !seen.contains(cellKey) else { continue }
            seen.insert(cellKey)

            guard let elev = grid.elevation(at: coord) else { continue }

            // Flood plain: low elevation
            if hazardTypes.contains(.floodPlain) && elev < Config.floodPlainThreshold && elev >= 0 {
                zones.append(OfflineRoutingService.HazardZone(
                    center: coord,
                    radiusMetres: 200,
                    penalty: Config.floodPlainPenalty,
                    kind: .flood
                ))
            }

            // Coastal storm surge
            if hazardTypes.contains(.coastal) && elev < Config.coastalThreshold && elev >= 0 {
                zones.append(OfflineRoutingService.HazardZone(
                    center: coord,
                    radiusMetres: 300,
                    penalty: Config.coastalPenalty,
                    kind: .stormSurge
                ))
            }

            // Valley detection: check if point is lower than surrounding cells
            if hazardTypes.contains(.valleyFunnel) {
                let neighbors = [
                    grid.elevation(at: CLLocationCoordinate2D(
                        latitude: coord.latitude + grid.cellSizeDegrees,
                        longitude: coord.longitude
                    )),
                    grid.elevation(at: CLLocationCoordinate2D(
                        latitude: coord.latitude - grid.cellSizeDegrees,
                        longitude: coord.longitude
                    )),
                    grid.elevation(at: CLLocationCoordinate2D(
                        latitude: coord.latitude,
                        longitude: coord.longitude + grid.cellSizeDegrees
                    )),
                    grid.elevation(at: CLLocationCoordinate2D(
                        latitude: coord.latitude,
                        longitude: coord.longitude - grid.cellSizeDegrees
                    ))
                ].compactMap { $0 }

                if neighbors.count >= 3 {
                    let higherCount = neighbors.filter { $0 > elev + 20 }.count
                    if higherCount >= 3 {
                        // Point is in a valley (3+ neighbors significantly higher)
                        zones.append(OfflineRoutingService.HazardZone(
                            center: coord,
                            radiusMetres: 150,
                            penalty: Config.valleyPenalty,
                            kind: .fire
                        ))
                    }
                }
            }
        }

        return zones
    }

    /// Compute a terrain profile for a route polyline.
    func profile(for coordinates: [CLLocationCoordinate2D]) -> TerrainProfile? {
        guard let grid, coordinates.count >= 2 else { return nil }

        var minElev: Int16 = .max
        var maxElev: Int16 = .min
        var totalAscent = 0
        var totalDescent = 0
        var floodRisk = 0
        var valleys = 0
        var prevElev: Int16?

        for coord in coordinates {
            guard let elev = grid.elevation(at: coord) else { continue }

            minElev = min(minElev, elev)
            maxElev = max(maxElev, elev)

            if let prev = prevElev {
                let diff = Int(elev) - Int(prev)
                if diff > 0 { totalAscent += diff }
                else { totalDescent += abs(diff) }
            }

            if elev < Config.floodPlainThreshold && elev >= 0 { floodRisk += 1 }
            prevElev = elev
        }

        guard minElev != .max else { return nil }

        return TerrainProfile(
            minElevation: minElev,
            maxElevation: maxElev,
            totalAscent: totalAscent,
            totalDescent: totalDescent,
            floodRiskSegments: floodRisk,
            valleySegments: valleys
        )
    }

    /// Compute gradient penalty multiplier between two points.
    func gradientPenalty(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        guard let elevFrom = elevation(at: from),
              let elevTo = elevation(at: to) else { return 1.0 }

        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let horizontalDist = loc1.distance(from: loc2)
        guard horizontalDist > 0 else { return 1.0 }

        let gradient = abs(Double(elevTo) - Double(elevFrom)) / (horizontalDist / 100)
        if gradient > Config.steepGradientThreshold {
            return Config.steepPenalty
        }
        return 1.0
    }

    // MARK: - Errors

    enum ElevationError: Error, LocalizedError {
        case invalidFormat
        case fileNotFound

        var errorDescription: String? {
            switch self {
            case .invalidFormat: "Elevation data file format is invalid."
            case .fileNotFound: "Elevation data file not found for this region."
            }
        }
    }
}
