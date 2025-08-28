//
//  FreshnessView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import SwiftUI

struct FreshnessView: View {
    var lastUpdated: Date? {
        let suite = UserDefaults(suiteName: "com.justinrooks.skyaware")
        guard let suite else { return nil}
        
        let lastGlobalSuccessAtKey = "lastGlobalSuccessAt"
        
        let time = suite.double(forKey: lastGlobalSuccessAtKey)
        return time > 0 ? Date(timeIntervalSince1970: time) : nil
//        SharedPrefs.lastGlobalSuccess()
    }
//    @AppStorage("lastUpdated") var lastUpdated: Date?
    
    var body: some View {
        if let last = lastUpdated {
            Text("Updated \(relativeTime(from: last))")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Text("No data yet")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

#Preview {
    FreshnessView()
}
