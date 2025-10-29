//
//  ext+URLCache.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import Foundation

extension URLCache {
    static let skyAwareCache = URLCache(
        memoryCapacity: 4 * 1024 * 1024, // 4 MB
        diskCapacity: 100 * 1024 * 1024, // 100 MB
        diskPath: "skyaware-dataCache"
    )
}
