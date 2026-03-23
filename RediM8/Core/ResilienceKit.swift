import Foundation

// MARK: - Retry with Exponential Backoff

/// Retries an async throwing task with exponential backoff.
/// Used for local operations that may transiently fail (file I/O, parsing, etc.)
///
/// NOTE: This is NOT used for network calls. RediM8 is fully offline.
func retry<T>(
    maxAttempts: Int = 3,
    initialDelay: TimeInterval = 0.5,
    maxDelay: TimeInterval = 30,
    shouldRetry: @escaping (Error) -> Bool = { _ in true },
    task: @escaping () async throws -> T
) async throws -> T {
    var currentDelay = initialDelay

    for attempt in 1...maxAttempts {
        do {
            return try await task()
        } catch {
            if attempt >= maxAttempts || !shouldRetry(error) {
                throw error
            }
            RediLogger.app.debug("Retry attempt \(attempt, privacy: .public)/\(maxAttempts, privacy: .public) after \(String(format: "%.1f", currentDelay), privacy: .public)s")
            try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
            currentDelay = min(currentDelay * 2, maxDelay)
        }
    }

    // Unreachable, but Swift requires it
    throw AppError.unknown("Retry exhausted")
}

/// Returns true if the error is a transient local I/O error worth retrying.
func isTransientError(_ error: Error) -> Bool {
    let nsError = error as NSError

    // File system transient errors
    if nsError.domain == NSCocoaErrorDomain {
        switch nsError.code {
        case CocoaError.fileReadUnknown.rawValue,
             CocoaError.fileWriteUnknown.rawValue:
            return true
        default:
            return false
        }
    }

    return false
}

// MARK: - Circuit Breaker

/// Prevents cascading failures by tripping open after repeated errors.
///
/// States:
///   - **closed**: Normal operation, requests pass through
///   - **open**: Requests are immediately rejected (fast fail)
///   - **halfOpen**: A single probe request is allowed through to test recovery
actor CircuitBreaker {
    enum State: Equatable {
        case closed
        case open(since: Date)
        case halfOpen
    }

    let name: String
    private let failureThreshold: Int
    private let resetTimeout: TimeInterval
    private var consecutiveFailures = 0
    private(set) var state: State = .closed

    init(name: String, failureThreshold: Int = 3, resetTimeout: TimeInterval = 60) {
        self.name = name
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
    }

    var isOpen: Bool {
        if case .open = state { return true }
        return false
    }

    func execute<T>(_ task: () async throws -> T) async throws -> T {
        switch state {
        case .closed:
            break
        case .open(let since):
            if Date.now.timeIntervalSince(since) >= resetTimeout {
                state = .halfOpen
                RediLogger.app.debug("Circuit breaker '\(self.name, privacy: .public)' half-open — probing")
            } else {
                throw AppError.serviceUnavailable(service: "\(name) is temporarily offline (circuit open)")
            }
        case .halfOpen:
            break
        }

        do {
            let result = try await task()
            consecutiveFailures = 0
            if state != .closed {
                RediLogger.app.debug("Circuit breaker '\(self.name, privacy: .public)' closed — recovered")
                DiagnosticStore.shared.log(.recovery, error: nil, context: [
                    "service": name,
                    "detail": "Circuit breaker recovered",
                    "systemState": "healthy"
                ])
            }
            state = .closed
            return result
        } catch {
            consecutiveFailures += 1
            if consecutiveFailures >= failureThreshold {
                state = .open(since: .now)
                RediLogger.app.error("Circuit breaker '\(self.name, privacy: .public)' opened after \(self.consecutiveFailures, privacy: .public) failures")
                DiagnosticStore.shared.log(.degraded, error: nil, context: [
                    "service": name,
                    "detail": "Circuit breaker opened after \(consecutiveFailures) failures",
                    "systemState": "degraded"
                ])
            }
            throw error
        }
    }

    func reset() {
        consecutiveFailures = 0
        state = .closed
    }
}

// MARK: - Timeout Wrapper

/// Races a task against a deadline. Throws if the task doesn't complete in time.
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    task: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await task()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw AppError.serviceUnavailable(service: "Operation timed out after \(Int(seconds))s")
        }

        guard let result = try await group.next() else {
            throw AppError.unknown("Task group completed without result")
        }
        group.cancelAll()
        return result
    }
}

// MARK: - Dead Letter Queue

/// Stores failed outbound messages for later retry.
/// Used by MeshService to buffer messages that couldn't be sent
/// (peer disconnected, encoding failure, etc.) and retry them
/// when connectivity is restored.
actor DeadLetterQueue {
    struct Entry: Identifiable {
        let id = UUID()
        let payload: Data
        let timestamp: Date
        let reason: String
        var attempts: Int = 0
    }

    private var entries: [Entry] = []
    private let maxEntries: Int
    private let maxAge: TimeInterval

    init(maxEntries: Int = 50, maxAge: TimeInterval = 2 * 60 * 60) {
        self.maxEntries = maxEntries
        self.maxAge = maxAge
    }

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }

    func enqueue(payload: Data, reason: String) {
        prune()
        if entries.count >= maxEntries {
            entries.removeFirst()
        }
        entries.append(Entry(payload: payload, timestamp: .now, reason: reason))
        RediLogger.mesh.debug("Dead letter queued (\(self.entries.count, privacy: .public) pending): \(reason, privacy: .public)")
        DiagnosticStore.shared.log(.error, error: nil, context: [
            "service": "mesh",
            "detail": "Message queued in dead letter: \(reason)",
            "systemState": "degraded"
        ])
    }

    func dequeueAll() -> [Entry] {
        let batch = entries
        entries.removeAll()
        return batch
    }

    func peek() -> [Entry] {
        prune()
        return entries
    }

    private func prune() {
        let cutoff = Date.now.addingTimeInterval(-maxAge)
        entries.removeAll { $0.timestamp < cutoff }
    }
}
