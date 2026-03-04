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

    private var formattedTemperature: String? {
        guard let weather else { return nil }
        return formatTemperature(weather.temperature)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            contentRow
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .cardBackground(cornerRadius: SkyAwareRadius.section, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }

    private var header: some View {
        Text("Current Conditions")
            .sectionLabel()
    }

    private var contentRow: some View {
        HStack(spacing: 10) {
            Label(location, systemImage: "location.fill")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            weatherContent
        }
    }

    @ViewBuilder
    private var weatherContent: some View {
        HStack(spacing: 6) {
            if let weather, let formattedTemperature {
                Text(formattedTemperature)
                    .monospacedDigit()
                Image(systemName: weather.symbolName)
                    .symbolVariant(.fill)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
    }

    private func formatTemperature(_ temperature: Measurement<UnitTemperature>) -> String {
        Self.temperatureFormatter.string(from: temperature)
    }
}

#Preview {
    VStack {
        SummaryStatus(
            location: "Denver, CO",
            weather: .init(
                temperature: Measurement(
                    value: 37.0,
                    unit: .fahrenheit
                ),
                symbolName: "sun.max",
                conditionText: "test",
                asOf: .now,
                dewPoint: Measurement(
                    value: 45.0,
                    unit: .fahrenheit
                ),
                humidity: 0.15,
                windSpeed: .init(value: 15.0, unit: .milesPerHour),
                windGust: nil,
                windDirection: "NNW",
                pressure: .init(value: 0.25, unit: .inchesOfMercury),
                pressureTrend: "climbing"
            )
        )
        SummaryStatus(
            location: "Topeka, KS",
            weather: .init(
                temperature: Measurement(
                    value: 47.0,
                    unit: .fahrenheit
                ),
                symbolName: "cloud",
                conditionText: "test",
                asOf: .now,
                dewPoint: Measurement(
                    value: 45.0,
                    unit: .fahrenheit
                ),
                humidity: 0.15,
                windSpeed: .init(value: 15.0, unit: .milesPerHour),
                windGust: nil,
                windDirection: "SSE",
                pressure: .init(value: 0.25, unit: .inchesOfMercury),
                pressureTrend: "falling"
            )
        )
    }
}
