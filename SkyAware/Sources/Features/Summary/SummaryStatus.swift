//
//  SummaryStatus.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/5/25.
//

import SwiftUI

struct SummaryStatus: View {
    let location: String
    let updatedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Location")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 10) {
                Label(location, systemImage: "location.fill")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let updatedAt {
                    TimeView(time: updatedAt)
                } else {
                    Text("Updating…")
                        .font(.callout.weight(.regular))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .cardBackground(cornerRadius: 22, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }
}

private struct TimeView: View {
    let time: Date
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let (textString, color, weight) = relativeTime(at: context.date)
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(textString)
                    .font(.callout.weight(weight))
                    .foregroundStyle(color)
                    .monospacedDigit()
            }
        }
    }
    
    private func relativeTime(at now: Date) -> (String, Color, Font.Weight)  {
        let seconds = Int(now.timeIntervalSince(time))
        if seconds <= 0 {
            return ("just now", Color(red: 0.4, green: 0.8, blue: 0.4) , .thin)
        }
        let relative = Self.formatter.localizedString(for: time, relativeTo: now)
        
        let freshness:FreshnessState = {
            switch(seconds) {
            case 0..<3600: return .healthy // <1 hr old
            case 3600..<14400: return .warning // 1-4 hrs
            default: return .expired // over 4 hrs
            }
        }()
        
        let color = getColor(for: colorScheme, with: freshness)
        
        return ("\(relative)", color , freshness == .expired ? .bold : .semibold)
    }
    
    enum FreshnessState { case healthy, warning, expired}
    
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
    
    private func getColor(for mode:ColorScheme, with level: FreshnessState) -> Color {
        switch(mode, level) {
        case (.light, .healthy): return Color(red: 0.22, green: 0.65, blue: 0.41)
        case (.dark, .healthy):  return Color(red: 0.48, green: 0.86, blue: 0.56)
        case (.light, .warning): return Color(red: 0.92, green: 0.70, blue: 0.30)
        case (.dark, .warning):  return Color(red: 0.98, green: 0.8, blue: 0.46)
        case (.light, .expired): return Color(red: 0.8, green: 0.32, blue: 0.32)
        case (.dark, .expired):  return Color(red: 1.0, green: 0.56, blue: 0.56)
        @unknown default: return .secondary
        }
    }
}

#Preview {
    SummaryStatus(location: "Denver, CO", updatedAt: .now.addingTimeInterval(-16000))
}
