//
//  AlertRowView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/28/25.
//

import SwiftUI

struct AlertRowView: View {
    let alert: any AlertItem

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
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                
                Text("Issued \(relativeDate(alert.issued))")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
//                if alert.alertType == .watch {
                    if let sevTags = alert.severeRiskTags {
                        Text(sevTags)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.tornadoRed)
                    }
//                }
            }
            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(14)
        .cardBackground(cornerRadius: SkyAwareRadius.row, shadowOpacity: 0.04, shadowRadius: 4, shadowY: 1)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers
    
    private func relativeDate(_ date: Date) -> String {
        Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    if let sample = MD.sampleDiscussionDTOs.first {
        AlertRowView(alert: sample)
    }
    AlertRowView(alert: Watch.sampleWatchRows.last ?? Watch.sampleWatchRows[0])
    AlertRowView(alert: Watch.sampleWatchRows[3])
}
