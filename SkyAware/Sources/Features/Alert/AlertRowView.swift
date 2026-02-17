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

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Type Badge
            let title = parseWatchType(from: alert.title)
            let (icon, color) = styleForType(alert.alertType, title)
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.headline.weight(.semibold))
                .frame(width: 36, height: 36)
                .skyAwareChip(cornerRadius: 12, tint: color.opacity(0.16))

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                
                Text("Issued \(relativeDate(alert.issued))")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .cardRowBackground()
    }

    // MARK: - Helpers
    
    func relativeDate(_ date: Date) -> String {
        Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func parseWatchType(from text: String) -> String? {
        let pattern = #"(.+?)\s+Watch\b"#

        if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let issued = String(text[match])
            
            return issued.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }
}

#Preview {
    if let sample = MD.sampleDiscussionDTOs.first {
        AlertRowView(alert: sample)
    }
    AlertRowView(alert: Watch.sampleWatchRows.last ?? Watch.sampleWatchRows[0])
}
