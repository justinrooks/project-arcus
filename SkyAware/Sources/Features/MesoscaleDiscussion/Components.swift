//
//  Components.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/8/25.
//

import Foundation
import SwiftUI

// MARK: - Components
struct KeyValueRow: View {
    let key: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key).labelStyle()
                .frame(width: 75, alignment: .leading)
            Text(value).valueStyle(multiline: true)
            Spacer(minLength: 0)
        }
    }
}

struct InZonePill: View {
    let inZone: Bool
    var body: some View {
        Text(inZone ? "IN ZONE" : "OUTSIDE")
            .font(.caption.weight(.semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
    }
}

struct WatchProbabilityBar: View {
    let progress: Double // 0...1
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.65), Color.accentColor],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: max(8, geo.size.width * (progress/100)))
            }
        }
        .frame(height: 8)
    }
}

struct ExpiryLabel: View {
    let remaining: TimeInterval // seconds
    
    private var text: String {
        if remaining <= 0 { return "Expired" }
        let minutes = Int(remaining / 60) % 60
        let hours = Int(remaining / 3600)
        if hours > 0 { return "Expires in \(hours)h \(minutes)m" }
        return "Expires in \(minutes)m"
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

