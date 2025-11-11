//
//  ext+Bundle.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/10/25.
//

import Foundation

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    var fullVersion: String {
        "\(appVersion) (\(buildNumber))"
    }
}
