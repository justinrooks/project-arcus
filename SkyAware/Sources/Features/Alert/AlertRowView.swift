//
//  AlertRowView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/28/25.
//

import SwiftUI

struct AlertRowView: View {
    let alert: any AlertItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Type Badge
            let title = parseWatchType(from: alert.title)
            let (icon, color) = styleForType(alert.alertType, title)
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                
                Text(relativeDate(alert.issued))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .cardRowBackground()
    }

    // MARK: - Helpers

    func styleForType(_ type: AlertType, _ watchType: String?) -> (String, Color) {
        switch type {
        case .watch:
            if let watchType {
                return watchType == "Tornado Watch" ? ("tornado", .tornadoRed) : ("cloud.bolt.fill", .severeTstormWarn)
            } else {
                return ("exclamationmark.triangle", .red)
            }
        case .mesoscale: return ("waveform.path.ecg.magnifyingglass", .mesoPurple)
        }
    }
    
    func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
    AlertRowView(alert: MD.sampleDiscussionDTOs.first!)
    AlertRowView(alert: Watch.sampleWatchRows.last!)
    AlertRowView(alert: Watch.sampleWatchRows[0])
}
