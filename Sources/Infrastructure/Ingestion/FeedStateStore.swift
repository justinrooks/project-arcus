//
//  FeedStateStore.swift
//  SkyAware
//

import Foundation

enum FeedStateTransportSource: String, Codable, Sendable {
    case live
    case revalidated
    case localCache
    case errorFallback
}

enum FeedStateFailureClassification: String, Codable, Sendable {
    case cancelled
    case transport
    case rejected
}

struct FeedStateRecord: Codable, Sendable, Equatable {
    let feedID: String
    var lastAttemptAt: Date
    var lastNetworkSuccessAt: Date?
    var lastCanonicalAcceptanceAt: Date?
    var lastValidityAt: Date?
    var lastTransportSource: FeedStateTransportSource?
    var generation: Int
    var lastFailure: FeedStateFailureClassification?
    fileprivate var lastAttemptOrderingKey: String

    init(feedID: String, attemptedAt: Date) {
        self.feedID = feedID
        lastAttemptAt = attemptedAt
        lastNetworkSuccessAt = nil
        lastCanonicalAcceptanceAt = nil
        lastValidityAt = nil
        lastTransportSource = nil
        generation = 0
        lastFailure = nil
        lastAttemptOrderingKey = ""
    }
}

struct FeedStateUpdate: Sendable {
    let feedID: String
    let attemptedAt: Date
    let networkSucceededAt: Date?
    let canonicalAcceptedAt: Date?
    let validAt: Date?
    let transportSource: FeedStateTransportSource?
    let failure: FeedStateFailureClassification?

    init(
        feedID: String,
        attemptedAt: Date,
        networkSucceededAt: Date? = nil,
        canonicalAcceptedAt: Date? = nil,
        validAt: Date? = nil,
        transportSource: FeedStateTransportSource? = nil,
        failure: FeedStateFailureClassification? = nil
    ) {
        self.feedID = feedID
        self.attemptedAt = attemptedAt
        self.networkSucceededAt = networkSucceededAt
        self.canonicalAcceptedAt = canonicalAcceptedAt
        self.validAt = validAt
        self.transportSource = transportSource
        self.failure = failure
    }
}

enum FeedStateStoreError: Error, Equatable {
    case invalidFeedID
    case futureDate
    case unsupportedVersion(Int)
    case corruptData
}

actor FeedStateStore {
    private struct Sidecar: Codable, Sendable {
        static let currentVersion = 1

        let version: Int
        var records: [FeedStateRecord]
    }

    private struct VersionEnvelope: Decodable {
        let version: Int
    }

    private let fileURL: URL
    private let maximumRecordCount: Int
    private let nowProvider: @Sendable () -> Date
    private let fileManager: FileManager

    init(
        directoryURL: URL? = nil,
        maximumRecordCount: Int = 32,
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.maximumRecordCount = maximumRecordCount
        self.nowProvider = nowProvider
        fileURL = (directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager))
            .appendingPathComponent("feed-state.v1.json")
    }

    func record(for feedID: String) throws -> FeedStateRecord? {
        try load().records.first { $0.feedID == feedID }
    }

    func update(_ update: FeedStateUpdate) throws -> FeedStateRecord {
        guard update.feedID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw FeedStateStoreError.invalidFeedID
        }
        try validate(update)

        var sidecar: Sidecar
        do {
            sidecar = try load()
        } catch FeedStateStoreError.corruptData {
            sidecar = Sidecar(version: Sidecar.currentVersion, records: [])
        }
        let index = sidecar.records.firstIndex { $0.feedID == update.feedID }
        var record = index.map { sidecar.records[$0] } ?? FeedStateRecord(feedID: update.feedID, attemptedAt: update.attemptedAt)
        if update.replacesLatestAttempt(in: record) {
            record.lastAttemptAt = update.attemptedAt
            record.lastTransportSource = update.transportSource
            record.lastFailure = update.failure
            record.lastAttemptOrderingKey = update.attemptOrderingKey
        }
        record.lastNetworkSuccessAt = latest(record.lastNetworkSuccessAt, update.networkSucceededAt)
        if let canonicalAcceptedAt = update.canonicalAcceptedAt {
            record.lastCanonicalAcceptanceAt = latest(record.lastCanonicalAcceptanceAt, canonicalAcceptedAt)
            record.generation += 1
        }
        record.lastValidityAt = latest(record.lastValidityAt, update.validAt)

        if let index {
            sidecar.records[index] = record
        } else {
            sidecar.records.append(record)
        }
        sidecar.records.sort { $0.lastAttemptAt > $1.lastAttemptAt }
        sidecar.records = Array(sidecar.records.prefix(maximumRecordCount))
        try persist(sidecar)
        return record
    }

    private func load() throws -> Sidecar {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return Sidecar(version: Sidecar.currentVersion, records: [])
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw FeedStateStoreError.corruptData
        }
        let envelope: VersionEnvelope
        do {
            envelope = try JSONDecoder().decode(VersionEnvelope.self, from: data)
        } catch {
            throw FeedStateStoreError.corruptData
        }
        guard envelope.version == Sidecar.currentVersion else {
            throw FeedStateStoreError.unsupportedVersion(envelope.version)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sidecar: Sidecar
        do {
            sidecar = try decoder.decode(Sidecar.self, from: data)
        } catch {
            throw FeedStateStoreError.corruptData
        }
        guard sidecar.records.allSatisfy(isValid) else {
            throw FeedStateStoreError.corruptData
        }
        return sidecar
    }

    private func persist(_ sidecar: Sidecar) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(sidecar)
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    private func validate(_ update: FeedStateUpdate) throws {
        let dates = [update.attemptedAt, update.networkSucceededAt, update.canonicalAcceptedAt, update.validAt].compactMap { $0 }
        guard dates.allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }) else {
            throw FeedStateStoreError.corruptData
        }
        guard dates.allSatisfy({ $0 <= nowProvider() }) else {
            throw FeedStateStoreError.futureDate
        }
    }

    private func isValid(_ record: FeedStateRecord) -> Bool {
        record.feedID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
            record.generation >= 0 &&
            [record.lastAttemptAt, record.lastNetworkSuccessAt, record.lastCanonicalAcceptanceAt, record.lastValidityAt]
            .compactMap { $0 }
            .allSatisfy { $0.timeIntervalSinceReferenceDate.isFinite && $0 <= nowProvider() }
    }

    private func latest(_ current: Date?, _ candidate: Date?) -> Date? {
        switch (current, candidate) {
        case let (.some(current), .some(candidate)):
            max(current, candidate)
        case let (.some(current), .none):
            current
        case let (.none, .some(candidate)):
            candidate
        case (.none, .none):
            nil
        }
    }

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.justinrooks.skyaware", isDirectory: true)
    }
}

private extension FeedStateUpdate {
    var attemptOrderingKey: String {
        [
            attemptedAt.ISO8601Format(),
            networkSucceededAt?.ISO8601Format() ?? "",
            canonicalAcceptedAt?.ISO8601Format() ?? "",
            validAt?.ISO8601Format() ?? "",
            transportSource?.rawValue ?? "",
            failure?.rawValue ?? ""
        ].joined(separator: "|")
    }

    func replacesLatestAttempt(in record: FeedStateRecord) -> Bool {
        attemptedAt > record.lastAttemptAt ||
            (attemptedAt == record.lastAttemptAt && attemptOrderingKey > record.lastAttemptOrderingKey)
    }
}
