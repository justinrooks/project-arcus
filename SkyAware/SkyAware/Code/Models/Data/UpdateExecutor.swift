//
//  UpdateExecutor.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/14/25.
//

import Foundation
import CryptoKit

public enum UpdateOutcome {
    case notModified
    case changed(content: Data, newTag: HTTPCacheTag?, contentHash: String?)
    case failed(error: Error, cooldownUntil: Date?)
}

public struct RetryPolicy {
    public let delays: [TimeInterval] = [10, 15, 20, 25]   // seconds
    public let cooldown: TimeInterval = 25 * 60            // 25 minutes
}

public final class UpdateExecutor {
    private let http: HTTPClient
    private let policy: RetryPolicy

    public init(http: HTTPClient, policy: RetryPolicy) {
        self.http = http
        self.policy = policy
    }

    /// Performs HEAD to check freshness; GET only if changed.
    /// - Parameters:
    ///   - url: feed endpoint
    ///   - prior: cached ETag/Last-Modified (from Persistence)
    ///   - computeHashIfNeeded: if true, compute SHA-256 when ETag/LM absent
    public func fetchIfChanged(
        url: URL,
        prior: HTTPCacheTag?,
        computeHashIfNeeded: Bool = true
    ) async -> UpdateOutcome {

        do {
            // 1) HEAD with conditionals if we have them
            var headHeaders: [String: String] = [:]
            if let etag = prior?.etag { headHeaders["If-None-Match"] = etag }
            if let lm = prior?.lastModified { headHeaders["If-Modified-Since"] = lm }

            let headResp = try await runWithRetry { [http] in
                try await http.head(url, headers: headHeaders)
            }

            // 304 Not Modified → we’re done
            if headResp.status == 304 {
                return .notModified
            }

            // Some servers don’t support HEAD well—treat 405/501/403 as “do a GET sniff”
            let shouldDoGet: Bool = {
                switch headResp.status {
                case 200...299, 304, 405, 501, 403: return true
                default: return true // be permissive: a GET will clarify
                }
            }()

            guard shouldDoGet else { return .notModified }

            // Prepare GET conditionals too (can save bytes if server supports)
            var getHeaders: [String: String] = [:]
            if let etag = prior?.etag { getHeaders["If-None-Match"] = etag }
            if let lm = prior?.lastModified { getHeaders["If-Modified-Since"] = lm }

            let getResp = try await runWithRetry { [http] in
                try await http.get(url, headers: getHeaders)
            }

            // GET 304 (rare but possible) → not modified
            if getResp.status == 304 {
                return .notModified
            }

            guard (200...299).contains(getResp.status), let body = getResp.data else {
                // Non-success → suggest cooldown to the scheduler
                return .failed(error: URLError(.badServerResponse),
                               cooldownUntil: Date().addingTimeInterval(policy.cooldown))
            }

            // Extract new validators
            let newTag = HTTPCacheTag(
                etag: getResp.header("ETag"),
                lastModified: getResp.header("Last-Modified")
            )

            // If we got an ETag/LM and it equals prior, treat as not modified
            if let et = newTag.etag, let priorET = prior?.etag, et == priorET {
                return .notModified
            }
            if let lm = newTag.lastModified, let priorLM = prior?.lastModified, lm == priorLM {
                return .notModified
            }

            // Optional: body hash fallback for endpoints that lack validators
            let hash: String?
            if computeHashIfNeeded, newTag.etag == nil, newTag.lastModified == nil {
                hash = Self.sha256(body)
            } else {
                hash = nil
            }

            return .changed(content: body, newTag: newTag, contentHash: hash)

        } catch {
            // Network failed after retries → advise cooldown
            return .failed(error: error,
                           cooldownUntil: Date().addingTimeInterval(policy.cooldown))
        }
    }

    // MARK: - Retry/backoff runner
    private func runWithRetry(_ op: @escaping () async throws -> HTTPResponse) async throws -> HTTPResponse {
        var lastError: Error?
        for (i, delay) in policy.delays.enumerated() {
            do {
                return try await op()
            } catch {
                lastError = error
                // After the last attempt, break and throw
                if i == policy.delays.count - 1 { break }
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    // MARK: - Hashing
    private static func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
