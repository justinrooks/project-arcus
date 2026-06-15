//
//  AlertRowView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/28/25.
//

import SwiftUI

struct AlertRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let alert: any AlertItem

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var iconAndColor: (icon: String, color: Color) {
        let style = styleForType(alert.alertType, alert.title)
        return (style.0, style.1)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: iconAndColor.icon)
                .foregroundStyle(iconAndColor.color)
                .font(.headline.weight(.semibold))
                .frame(width: 40, height: 40)
                .skyAwareChip(cornerRadius: SkyAwareRadius.iconChip, tint: iconAndColor.color.opacity(0.16))

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(adaptiveLayout.usesAccessibilityLayout ? nil : 2)
                    .minimumScaleFactor(adaptiveLayout.usesAccessibilityLayout ? 1 : 0.85)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Issued \(relativeDate(alert.issued))")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let sevTags = alert.severeRiskTags {
                    Text(sevTags)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.tornadoRed)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Helpers

    private var accessibilityTitle: String {
        switch alert.alertType {
        case .mesoscale:
            return "Mesoscale Discussion \(alert.number)"
        case .watch:
            return alert.title
        }
    }

    private var accessibilityValue: String {
        var parts: [String] = ["Issued \(relativeDate(alert.issued))"]

        if let sevTags = alert.severeRiskTags?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           sevTags.isEmpty == false {
            parts.append(sevTags.replacingOccurrences(of: "\n", with: ", "))
        }

        return parts.joined(separator: ". ")
    }

    private var accessibilityHint: String {
        "Opens \(alert.alertType == .mesoscale ? "mesoscale discussion" : "weather alert") details."
    }
    
    private func relativeDate(_ date: Date) -> String {
        Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    VStack(spacing: 12) {
        if let sample = MD.sampleDiscussionDTOs.first {
            AlertRowView(alert: sample)
                .cardBackground(
                    cornerRadius: SkyAwareRadius.row,
                    shadowOpacity: 0.04,
                    shadowRadius: 4,
                    shadowY: 1
                )
        }

        AlertRowView(alert: Watch.sampleWatchRows.last ?? Watch.sampleWatchRows[0])
            .cardBackground(
                cornerRadius: SkyAwareRadius.row,
                shadowOpacity: 0.04,
                shadowRadius: 4,
                shadowY: 1
            )

        AlertRowView(alert: Watch.sampleWatchRows[3])
            .cardBackground(
                cornerRadius: SkyAwareRadius.row,
                shadowOpacity: 0.04,
                shadowRadius: 4,
                shadowY: 1
            )
    }
    .padding()
    .background(Color(.skyAwareBackground))
}
