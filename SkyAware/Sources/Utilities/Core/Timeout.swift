//
//  Timeout.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/31/25.
//

import Foundation

/// Reusable timeout function. Executes the provided task closure against the timeout in seconds
/// - Parameters:
///   - timeout: seconds to wait
///   - task: the closure with a task to perform
/// - Throws: OtherError.TimeoutError
/// - Returns: T
func withTimeout<T: Sendable>(
    timeout: Double,
    _ task: @escaping @Sendable () async throws -> T
) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await task() }
        group.addTask {
            try await Task.sleep(for: .seconds(timeout))
            throw OtherErrors.timeoutError
        }
        let result = try await group.next()!
        group.cancelAll()
        
        return result
    }
}


/// Reusable timeout function. Includes the ability to provide a clock that can be paused
/// - Parameters:
///   - seconds: the timeout
///   - clock: clock to sleep
///   - op: operation to perform
/// - Throws: CancallationError
/// - Returns: T
func withTimeout<T: Sendable>(seconds: Double, clock: ContinuousClock, _ op: @Sendable @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask(operation: op)
        group.addTask {
            try await clock.sleep(for: .seconds(seconds))
            throw CancellationError()
        }
        let value = try await group.next()!
        group.cancelAll()
        return value
    }
}
