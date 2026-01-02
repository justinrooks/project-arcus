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
            case "extreme":   return c(.red.opacity(0.70),   .red.opacity(0.60))
            case "severe":    return c(.orange.opacity(0.75), .orange.opacity(0.65))
            case "moderate":  return c(.yellow.opacity(0.80), .yellow.opacity(0.70))
            case "minor":     return c(.green.opacity(0.65),  .green.opacity(0.55))
            default:          return c(.secondary.opacity(0.6), .secondary.opacity(0.5))
            }

        case .certainty(let v):
            switch v.lowercased() {
            case "observed", "confirmed", "likely":
                return c(.teal.opacity(0.70), .teal.opacity(0.60))
            case "possible":
                return c(.blue.opacity(0.65), .blue.opacity(0.55))
            default:
                return c(.secondary.opacity(0.6), .secondary.opacity(0.5))
            }

        case .urgency(let v):
            switch v.lowercased() {
            case "immediate": return c(.red.opacity(0.65), .red.opacity(0.55))
            case "expected":  return c(.orange.opacity(0.70), .orange.opacity(0.60))
            case "future":    return c(.blue.opacity(0.60), .blue.opacity(0.50))
            default:          return c(.secondary.opacity(0.6), .secondary.opacity(0.5))
            }

        case .sender:
            return c(.indigo.opacity(0.55), .indigo.opacity(0.45))

        case .instruction:
            return c(.mint.opacity(0.55), .mint.opacity(0.45))

        case .response:
            return c(.purple.opacity(0.55), .purple.opacity(0.45))
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

//// MARK: - Example Usage
//
//struct WatchChipsRow: View {
//    let severity: String
//    let certainty: String
//    let urgency: String
//    let senderName: String?
//    let instruction: String?
//    let response: String?
//
//    var body: some View {
//        ScrollView(.horizontal, showsIndicators: false) {
//            HStack(spacing: 8) {
//                StatusChip(kind: .severity(severity))
//                StatusChip(kind: .certainty(certainty))
//                StatusChip(kind: .urgency(urgency))
//
//                if let senderName, !senderName.isEmpty {
//                    StatusChip(kind: .sender(senderName))
//                }
//                if let instruction, !instruction.isEmpty {
//                    StatusChip(kind: .instruction(instruction))
//                }
//                if let response, !response.isEmpty {
//                    StatusChip(kind: .response(response))
//                }
//            }
//            .padding(.vertical, 2)
//        }
//    }
//}
