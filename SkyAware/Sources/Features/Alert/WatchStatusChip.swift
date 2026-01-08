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
    case sender(String)
    case instruction(String)
    case response(String)

    var title: String {
        switch self {
        case .severity(let v):    return "Severity: \(v)"
        case .certainty(let v):   return "Certainty: \(v)"
        case .urgency(let v):     return "Urgency: \(v)"
        case .sender(let v):      return "Sender: \(v)"
        case .instruction(let v): return "Instruction"
        case .response(let v):    return "Response: \(v)"
        }
    }

    var systemImage: String {
        switch self {
        case .severity:    return "exclamationmark.triangle"
        case .certainty:   return "checkmark.seal"
        case .urgency:     return "clock"
        case .sender:      return "person.crop.circle"
        case .instruction: return "list.bullet.rectangle"
        case .response:    return "waveform.path.ecg"
        }
    }

    /// Calm, complementary, not duplicating your risk gradients.
    /// This is *not* your SPC risk color system; it's metadata chips.
    func tint(for scheme: ColorScheme) -> Color {
        func c(_ light: Color, _ dark: Color) -> Color { scheme == .dark ? dark : light }

        switch self {
        case .severity(let v):
            switch v.lowercased() {
            case "extreme":   return c(.riskHigh.opacity(0.70),      .riskHigh.opacity(0.60))
            case "severe":    return c(.riskModerate.opacity(0.75),  .riskModerate.opacity(0.65))
            case "moderate":  return c(.riskEnhanced.opacity(0.80),  .riskEnhanced.opacity(0.70))
            case "minor":     return c(.riskMarginal.opacity(0.65),  .riskMarginal.opacity(0.55))
            default:          return c(.secondary.opacity(0.6), .secondary.opacity(0.5))
            }

        case .certainty(let v):
            switch v.lowercased() {
            case "observed", "confirmed", "likely":
                return c(.windTeal.opacity(0.70), .windTeal.opacity(0.60))
            case "possible":
                return c(.hailBlue.opacity(0.65), .hailBlue.opacity(0.55))
            default:
                return c(.secondary.opacity(0.6), .secondary.opacity(0.5))
            }

        case .urgency(let v):
            switch v.lowercased() {
            case "immediate": return c(.tornadoRed.opacity(0.65), .tornadoRed.opacity(0.55))
            case "expected":  return c(.riskEnhanced.opacity(0.70), .riskEnhanced.opacity(0.60))
            case "future":    return c(.hailBlue.opacity(0.60), .hailBlue.opacity(0.50))
            default:          return c(.secondary.opacity(0.6), .secondary.opacity(0.5))
            }

        case .sender:
            return c(.mesoPurple.opacity(0.55), .mesoPurple.opacity(0.45))

        case .instruction:
            return c(.windTeal.opacity(0.55), .windTeal.opacity(0.45))

        case .response:
            return c(.mesoPurple.opacity(0.55), .mesoPurple.opacity(0.45))
        }
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
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(tint.opacity(scheme == .dark ? 0.35 : 0.25), lineWidth: 1)
        }
        .accessibilityLabel(kind.title)
    }
}
