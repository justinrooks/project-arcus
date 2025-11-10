//
//  SummaryStatus.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/5/25.
//

import SwiftUI

struct SummaryStatus: View {
    let location: String
    let updatedAt: Date
    
    var body: some View {
        HStack {
            Label(location, systemImage: "location")
                .font(.callout.weight(.semibold))
            Text("-")
                .foregroundStyle(.secondary)
            TimeView(time: updatedAt)
        }
        .lineLimit(1)
        .truncationMode(.tail)
    }
}

private struct TimeView: View {
    let time: Date
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let (textString, color, weight) = relativeTime()

        Text("\(textString)")
            .font(.callout.weight(weight))
            .foregroundStyle(color)
            .monospacedDigit()
    }
    
    private func relativeTime() -> (String, Color, Font.Weight)  {
        let now:Date = .now
        let seconds = Int(now.timeIntervalSince(time))
        if seconds <= 0 {
            return ("just now", Color(red: 0.4, green: 0.8, blue: 0.4) , .thin)
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: time, relativeTo: Date())
        
        let freshness:FreshnessState = {
            switch(seconds) {
            case 0..<7200: return .healthy // 1 hr
            case 7200..<14400: return .warning // 2-4 hrs
            default: return .expired // over 4 hrs
            }
        }()
        
        let color = getColor(for: colorScheme, with: freshness)
        
        return ("\(relative)", color , freshness == .expired ? .bold : .semibold)
    }
    
    enum FreshnessState { case healthy, warning, expired}
    
    private func getColor(for mode:ColorScheme, with level: FreshnessState) -> Color {
        let c:Color = {
            switch(mode, level) {
            case (.light, .healthy): return Color(red: 0.1, green: 0.5, blue: 0.1)
            case (.dark, .healthy):  return Color(red: 0.4, green: 0.8, blue: 0.4)
            case (.light, .warning): return Color(red: 0.8, green: 0.5, blue: 0.0)
            case (.dark, .warning):  return Color(red: 1.0, green: 0.7, blue: 0.0)
            case (.light, .expired): return Color(red: 0.6, green: 0.1, blue: 0.1)
            case (.dark, .expired):  return Color(red: 1.0, green: 0.3, blue: 0.3)
            case (_, _):             return Color(red: 0.1, green: 0.5, blue: 0.1)
            }
        }()
        
        return c
    }
}

#Preview {
    SummaryStatus(location: "Denver, CO", updatedAt: .now.addingTimeInterval(-10000))
}

