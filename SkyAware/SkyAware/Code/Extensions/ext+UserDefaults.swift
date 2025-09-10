//
//  ext+UserDefaults.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/8/25.
//

import Foundation

public extension UserDefaults {
    @MainActor static let shared = UserDefaults(suiteName: "com.justinrooks.skyaware")
}
