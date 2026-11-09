//
//  LocationUploadQueueStore.swift
//  SkyAware
//

import Foundation

protocol LocationUploadQueueStoring: Sendable {
    func loadPendingRequests() async -> [PersistedLocationUploadRequest]
    func savePendingRequests(_ requests: [PersistedLocationUploadRequest]) async throws
}

/// Preserve Date's full reference-time value locally; accept the previous ISO-8601 representation on read.
/// Transport date coding remains owned by the HTTP clients.
enum LocationPersistenceCoding {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer()
            if let seconds = try? value.decode(Double.self) {
                return Date(timeIntervalSinceReferenceDate: seconds)
            }
            return try Date.ISO8601FormatStyle().parse(value.decode(String.self))
        }
        return decoder
    }
}

actor UserDefaultsLocationUploadQueueStore: LocationUploadQueueStoring {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = LocationPersistenceCoding.makeDecoder()

    init(suiteName: String, key: String) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.key = key
    }

    func loadPendingRequests() async -> [PersistedLocationUploadRequest] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? decoder.decode([PersistedLocationUploadRequest].self, from: data)) ?? []
    }

    func savePendingRequests(_ requests: [PersistedLocationUploadRequest]) async throws {
        if requests.isEmpty {
            defaults.removeObject(forKey: key)
            return
        }
        let data = try encoder.encode(requests)
        defaults.set(data, forKey: key)
    }
}
