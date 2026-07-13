//
//  LocationUploadQueueStore.swift
//  SkyAware
//

import Foundation

protocol LocationUploadQueueStoring: Sendable {
    func loadPendingRequests() async -> [PersistedLocationUploadRequest]
    func savePendingRequests(_ requests: [PersistedLocationUploadRequest]) async
}

actor UserDefaultsLocationUploadQueueStore: LocationUploadQueueStoring {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(suiteName: String, key: String) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.key = key
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadPendingRequests() async -> [PersistedLocationUploadRequest] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? decoder.decode([PersistedLocationUploadRequest].self, from: data)) ?? []
    }

    func savePendingRequests(_ requests: [PersistedLocationUploadRequest]) async {
        if requests.isEmpty {
            defaults.removeObject(forKey: key)
            return
        }
        if let data = try? encoder.encode(requests) {
            defaults.set(data, forKey: key)
        }
    }
}
