//
//  KvStore.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import Foundation

public protocol KeyValueStore {
    func get<T: Decodable>(_ key: String, as type: T.Type) -> T?
    func set<T: Encodable>(_ key: String, value: T?)
    func remove(_ key: String)
}
