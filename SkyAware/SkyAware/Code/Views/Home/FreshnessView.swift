//
//  FreshnessView.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import SwiftUI

struct FreshnessView: View {
    var lastUpdated: Date? { SharedPrefs.lastGlobalSuccess() }
    
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
