//
//  WatchStatusChip.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/31/25.
//

import Foundation
import SwiftUI

// MARK: - Chip Model

enum WatchChipKind {
    case severity(String)
    case certainty(String)
    case urgency(String)

    var title: String {
        switch self {
        case .severity(let v):    return "Severity: \(v)"
        case .certainty(let v):   return "Certainty: \(v)"
        case .urgency(let v):     return "Urgency: \(v)"
        }
    }

    var systemImage: String {
        switch self {
        case .severity:    return "exclamationmark.triangle"
        case .certainty:   return "checkmark.seal"
        case .urgency:     return "clock"
        }
    }

    /// Calm, complementary, not duplicating your risk gradients.
    /// This stays neutral so the hazard colors remain reserved for actual weather meaning.
    func tint(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .semanticMetadata.opacity(0.80) : .semanticMetadata
    }
}

// MARK: - Chip View

struct StatusChip: View {
    let kind: WatchChipKind

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let tint = kind.tint(for: scheme)

        HStack(spacing: 6) {
            Image(systemName: kind.systemImage)
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)

            Text(kind.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .skyAwareChip(cornerRadius: SkyAwareRadius.hero, tint: tint.opacity(0.18))
        .overlay {
            RoundedRectangle(cornerRadius: SkyAwareRadius.hero, style: .continuous)
                .stroke(tint.opacity(scheme == .dark ? 0.35 : 0.25), lineWidth: 1)
        }
        .accessibilityLabel(kind.title)
    }
}

#Preview("Metadata Chips") {
    VStack(alignment: .leading, spacing: 10) {
        StatusChip(kind: .severity("Severe"))
        StatusChip(kind: .certainty("Likely"))
        StatusChip(kind: .urgency("Immediate"))
    }
    .padding(16)
    .background(.skyAwareBackground)
}

#Preview("Metadata Chips Dark") {
    VStack(alignment: .leading, spacing: 10) {
        StatusChip(kind: .severity("Severe"))
        StatusChip(kind: .certainty("Likely"))
        StatusChip(kind: .urgency("Immediate"))
    }
    .padding(16)
    .background(.skyAwareBackground)
    .preferredColorScheme(.dark)
}
