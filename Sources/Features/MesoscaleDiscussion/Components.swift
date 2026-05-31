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
        Text(inZone ? "In zone" : "Outside")
            .font(.caption.weight(.semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
//            .skyAwareChip(
//                cornerRadius: SkyAwareRadius.tile,
//                tint: inZone ? .green.opacity(0.14) : .white.opacity(0.08)
//            )
    }
}

struct WatchProbabilityBar: View {
    let progress: Double
    var color: Color = .skyAwareAccent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.65),
                                color
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth(in: geo.size.width))
            }
        }
        .frame(height: 8)
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 100)
    }

    private func fillWidth(in totalWidth: CGFloat) -> CGFloat {
        guard clampedProgress > 0 else { return 0 }
        return max(8, totalWidth * (clampedProgress / 100))
    }
}

struct ExpiryLabel: View {
    let remaining: TimeInterval // seconds
    
    private var text: String {
        if remaining <= 0 { return "Expired" }
        let minutes = Int(remaining / 60) % 60
        let hours = Int(remaining / 3600)
        if hours > 0 { return "Ends in \(hours)h \(minutes)m" }
        return "Ends in \(minutes)m"
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .skyAwareChip(cornerRadius: SkyAwareRadius.chipCompact, tint: .white.opacity(0.08))
    }
}
