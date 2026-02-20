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
    let weather: SummaryWeather?
    
    private static let temperatureFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Conditions")
                .font(.caption2)
                  .fontWeight(.semibold)
                  .textCase(.uppercase)
                  .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Label(location, systemImage: "location.fill")
                    .font(.headline)
                      .fontWeight(.semibold)
                      .foregroundStyle(.primary)
                Spacer(minLength: 8)
                
                HStack(spacing: 6) {
                    if let weather {
                        let temp = Self.temperatureFormatter.string(from: weather.temperature)
                        Text(temp)
//                        Text("\(45)°")
                            .font(.headline)
                              .fontWeight(.semibold)
                              .foregroundStyle(.primary)
                              .monospacedDigit()
                        Image(systemName: weather.symbolName)
//                            .renderingMode(.original)
                            .symbolVariant(.fill)
                            .font(.subheadline)
                              .fontWeight(.semibold)
                              .foregroundStyle(.secondary)
                    }

                }
                .font(.callout.weight(.regular))
                .foregroundStyle(.secondary)
                    
                
//                if let updatedAt {
//                    TimeView(time: updatedAt)
//                } else {
//                    Text("Updating…")
//                        .font(.callout.weight(.regular))
//                        .foregroundStyle(.secondary)
//                        .monospacedDigit()
//                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .cardBackground(cornerRadius: SkyAwareRadius.section, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }
}

private struct TimeView: View {
    let time: Date
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let (textString, color, weight) = relativeTime(at: context.date)
            HStack(spacing: 4) {
//                Image(systemName: "clock.arrow.circlepath")
//                    .font(.caption.weight(.semibold))
//                    .foregroundStyle(.secondary)
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
            return ("just now", .secondary , .thin)
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
//        case (.light, .healthy): return Color(red: 0.22, green: 0.65, blue: 0.41)
//        case (.dark, .healthy):  return Color(red: 0.48, green: 0.86, blue: 0.56)
        case (.light, .healthy): return .clear
        case (.dark, .healthy):  return .clear
        case (.light, .warning): return Color(red: 0.92, green: 0.70, blue: 0.30)
        case (.dark, .warning):  return Color(red: 0.98, green: 0.8, blue: 0.46)
        case (.light, .expired): return Color(red: 0.8, green: 0.32, blue: 0.32)
        case (.dark, .expired):  return Color(red: 1.0, green: 0.56, blue: 0.56)
        @unknown default: return .secondary
        }
    }
}

#Preview {
    VStack {
        SummaryStatus(location: "Denver, CO", updatedAt: .now.addingTimeInterval(-16000), weather: .init(temperature: Measurement(value: 37.0, unit: .fahrenheit), symbolName: "sun.max", conditionText: "test", asOf: .now))
        SummaryStatus(location: "Denver, CO", updatedAt: .now.addingTimeInterval(-16000), weather: .init(temperature: Measurement(value: 47.0, unit: .fahrenheit), symbolName: "cloud", conditionText: "test", asOf: .now))
    }
}
