//
//  SummaryStatus.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/5/25.
//

import SwiftUI

struct SummaryStatus: View {
    let location: String
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
                            .font(.headline)
                              .fontWeight(.semibold)
                              .foregroundStyle(.primary)
                              .monospacedDigit()
                        Image(systemName: weather.symbolName)
                            .symbolVariant(.fill)
                            .font(.subheadline)
                              .fontWeight(.semibold)
                              .foregroundStyle(.secondary)
                    }

                }
                .font(.callout.weight(.regular))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .cardBackground(cornerRadius: SkyAwareRadius.section, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }
}

#Preview {
    VStack {
        SummaryStatus(location: "Denver, CO", weather: .init(temperature: Measurement(value: 37.0, unit: .fahrenheit), symbolName: "sun.max", conditionText: "test", asOf: .now))
        SummaryStatus(location: "Denver, CO", weather: .init(temperature: Measurement(value: 47.0, unit: .fahrenheit), symbolName: "cloud", conditionText: "test", asOf: .now))
    }
}
