//
//  UserDefaultsStore.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import Foundation

public final class UserDefaultsStore: KeyValueStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(suiteName: String? = nil) {
        if let suiteName { self.defaults = UserDefaults(suiteName: suiteName) ?? .standard }
        else { self.defaults = .standard }
    }

    public func get<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        // Fast path for String and Data to avoid JSON round‑trip
        if T.self == String.self, let s = defaults.string(forKey: key) { return s as? T }
        if T.self == Data.self, let d = defaults.data(forKey: key) { return d as? T }

        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    public func set<T: Encodable>(_ key: String, value: T?) {
        if value == nil { defaults.removeObject(forKey: key); return }

        // Fast path for String/Data
        if let s = value as? String { defaults.set(s, forKey: key); return }
        if let d = value as? Data { defaults.set(d, forKey: key); return }

        if let encoded = try? encoder.encode(value) {
            defaults.set(encoded, forKey: key)
        }
    }

    public func remove(_ key: String) { defaults.removeObject(forKey: key) }
}
