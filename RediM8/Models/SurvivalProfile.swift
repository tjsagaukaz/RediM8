import Foundation

// MARK: - Survival Profile

/// Persistent survival-specific profile data that adapts system behavior.
/// Stored locally as part of UserProfile. Never synced without explicit consent.
struct SurvivalProfile: Codable, Equatable {

    // MARK: Vehicle

    var hasVehicle: Bool
    var vehicleType: VehicleType

    // MARK: Skill & Experience

    var skillLevel: SurvivalSkillLevel

    // MARK: Region

    var regionType: RegionType

    // MARK: Defaults

    static let `default` = SurvivalProfile(
        hasVehicle: false,
        vehicleType: .unknown,
        skillLevel: .beginner,
        regionType: .unknown
    )
}

// MARK: - Supporting Types

enum VehicleType: String, Codable, Equatable, CaseIterable {
    case unknown
    case sedan
    case suv
    case fourWheelDrive = "4wd"
    case van
    case truck

    var title: String {
        switch self {
        case .unknown: "Not Set"
        case .sedan: "Sedan"
        case .suv: "SUV"
        case .fourWheelDrive: "4WD"
        case .van: "Van"
        case .truck: "Truck"
        }
    }

    var isOffRoadCapable: Bool {
        self == .fourWheelDrive || self == .truck
    }
}

enum SurvivalSkillLevel: String, Codable, Equatable, CaseIterable {
    case beginner
    case intermediate
    case experienced

    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .experienced: "Experienced"
        }
    }
}

enum RegionType: String, Codable, Equatable, CaseIterable {
    case unknown
    case urban
    case suburban
    case rural
    case remote
    case outback

    var title: String {
        switch self {
        case .unknown: "Not Set"
        case .urban: "Urban"
        case .suburban: "Suburban"
        case .rural: "Rural"
        case .remote: "Remote"
        case .outback: "Outback"
        }
    }

    var isRemote: Bool {
        self == .remote || self == .outback
    }
}
