import Foundation

// MARK: - Unified Error Model

/// App-wide error type that maps service-specific errors into user-facing categories.
/// Every ViewModel publishes `AppError?` so the UI can show meaningful failure state.
enum AppError: LocalizedError, Equatable {
    case networkUnavailable
    case dataCorrupted(detail: String)
    case serviceUnavailable(service: String)
    case permissionDenied(type: String)
    case routingFailed(detail: String)
    case storageFailed(detail: String)
    case purchaseFailed(detail: String)
    case unknown(String)

    var errorDescription: String? { userMessage }

    var userMessage: String {
        switch self {
        case .networkUnavailable:
            return "No network connection available."
        case .dataCorrupted(let detail):
            return "Data could not be loaded safely: \(detail)"
        case .serviceUnavailable(let service):
            return "\(service) is currently unavailable."
        case .permissionDenied(let type):
            return "\(type) permission is required."
        case .routingFailed(let detail):
            return "Route calculation failed: \(detail)"
        case .storageFailed(let detail):
            return "Storage error: \(detail)"
        case .purchaseFailed(let detail):
            return "Purchase failed: \(detail)"
        case .unknown(let message):
            return message.isEmpty ? "Something went wrong." : message
        }
    }

    /// Short label for status indicators (badges, banners).
    var shortLabel: String {
        switch self {
        case .networkUnavailable: return "OFFLINE"
        case .dataCorrupted: return "DATA ERROR"
        case .serviceUnavailable: return "UNAVAILABLE"
        case .permissionDenied: return "PERMISSION"
        case .routingFailed: return "ROUTE ERROR"
        case .storageFailed: return "STORAGE"
        case .purchaseFailed: return "PURCHASE"
        case .unknown: return "ERROR"
        }
    }
}

// MARK: - System State

/// Observable system health for any ViewModel or system.
/// UI binds to this to show HEALTHY / DEGRADED / UNAVAILABLE indicators.
enum SystemState: Equatable {
    case healthy
    case degraded(reason: String)
    case unavailable(reason: String)

    var isHealthy: Bool {
        if case .healthy = self { return true }
        return false
    }

    var isDegraded: Bool {
        if case .degraded = self { return true }
        return false
    }

    var isUnavailable: Bool {
        if case .unavailable = self { return true }
        return false
    }

    var statusLabel: String {
        switch self {
        case .healthy: return "OPERATIONAL"
        case .degraded: return "DEGRADED"
        case .unavailable: return "UNAVAILABLE"
        }
    }

    var reason: String? {
        switch self {
        case .healthy: return nil
        case .degraded(let reason): return reason
        case .unavailable(let reason): return reason
        }
    }
}

// MARK: - Error Mapping

/// Maps any service-level error into the unified `AppError` domain.
/// Add cases here as new error types are introduced.
func mapToAppError(_ error: Error) -> AppError {
    // Service-specific errors
    if let elevation = error as? ElevationService.ElevationError {
        switch elevation {
        case .invalidFormat:
            return .dataCorrupted(detail: "Elevation data format is invalid.")
        case .fileNotFound:
            return .dataCorrupted(detail: "Elevation data file not found.")
        }
    }

    if let routing = error as? OfflineRoutingService.RoutingError {
        return .routingFailed(detail: routing.localizedDescription)
    }

    if let secure = error as? SecureStoreError {
        return .storageFailed(detail: secure.localizedDescription)
    }

    if let vault = error as? DocumentVaultError {
        return .storageFailed(detail: vault.localizedDescription)
    }

    if let beacon = error as? BeaconServiceError {
        return .serviceUnavailable(service: "Beacon: \(beacon.localizedDescription)")
    }

    if let purchase = error as? PurchaseError {
        return .purchaseFailed(detail: purchase.localizedDescription)
    }

    // Network errors (NSURLErrorDomain)
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain {
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorDataNotAllowed:
            return .networkUnavailable
        case NSURLErrorTimedOut:
            return .serviceUnavailable(service: "Network request timed out")
        default:
            return .networkUnavailable
        }
    }

    // Generic fallback
    return .unknown(error.localizedDescription)
}
