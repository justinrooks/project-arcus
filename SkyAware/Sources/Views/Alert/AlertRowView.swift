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
            Image(systemName: iconForType(alert.alertType))
                .foregroundColor(colorForType(alert.alertType))
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(colorForType(alert.alertType).opacity(0.15))
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.cardBackground)
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
        )
        
    }

    // MARK: - Helpers

    func iconForType(_ type: AlertType) -> String {
        switch type {
        case .watch: return "exclamationmark.triangle"
        case .mesoscale: return "waveform.path.ecg"
        }
    }

    func colorForType(_ type: AlertType) -> Color {
        switch type {
        case .watch: return .red
        case .mesoscale: return .orange
        }
    }

    func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    AlertRowView(alert: MD.sampleDiscussions.first!)
}
