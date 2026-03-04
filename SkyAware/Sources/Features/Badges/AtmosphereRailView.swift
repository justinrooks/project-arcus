//
//  AtmosphereRailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/3/26.
//

import SwiftUI

struct AtmosphereRailView: View {
    @Environment(\.colorScheme) private var colorScheme
    let weather: SummaryWeather?
    let level: FireRiskLevel

    private static let temperatureFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter
    }()

    private var atmosphereSummary: String {
        guard let weather else {
            return "Loading atmospheric metrics…"
        }

        let condition = weather.conditionText.isEmpty ? "Atmospheric conditions" : weather.conditionText
        return "\(condition)."
    }

    private var formattedDewPoint: String? {
        guard let weather else { return nil }
        return formatTemperature(weather.dewPoint)
    }

    private var formattedHumidity: String? {
        guard let weather else { return nil }
        let percent = weather.humidity * 100
        return "\(percent.formatted(.number.precision(.fractionLength(0))))%"
    }

    private var formattedWind: String? {
        guard let weather else { return nil }
        let mph = weather.windSpeed.converted(to: .milesPerHour).value
        return "\(mph.formatted(.number.precision(.fractionLength(0)))) mph"
    }

    private var formattedPressure: String? {
        guard let weather else { return nil }
        let inHg = weather.pressure.converted(to: .inchesOfMercury).value
        return "\(inHg.formatted(.number.precision(.fractionLength(2)))) inHg"
    }

    private var pressureTrendLabel: String {
        guard let trend = weather?.pressureTrend.trimmingCharacters(in: .whitespacesAndNewlines),
              !trend.isEmpty else {
            return "Trend unavailable"
        }

        return trend.capitalized
    }

    private var pressureTrendSymbol: String {
        guard let trend = weather?.pressureTrend.lowercased() else { return "arrow.left.and.right" }

        if trend.contains("fall") || trend.contains("drop") || trend.contains("down") {
            return "arrow.down.right"
        }

        if trend.contains("climb") || trend.contains("rise") || trend.contains("up") {
            return "arrow.up.right"
        }

        return "arrow.left.and.right"
    }

    private var metrics: [AtmosphereMetric] {
        [
            .init(title: "Dew Point",
                  value: formattedDewPoint ?? "—",
                  detail: nil,
                  symbol: "thermometer.sun"),
            .init(title: "Humidity",
                  value: formattedHumidity ?? "—",
                  detail: nil,
                  symbol: "humidity.fill"),
            .init(title: "Wind",
                  value: formattedWind ?? "—",
                  detail: weather?.windDirection ?? "Direction unavailable",
                  symbol: "wind"),
            .init(title: "Pressure",
                  value: formattedPressure ?? "—",
                  detail: pressureTrendLabel,
                  symbol: pressureTrendSymbol)
        ]
    }

    private let metricColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 2, alignment: .leading),
        GridItem(.flexible(), spacing: 2, alignment: .leading)
    ]

    private var atmosphereBackground: LinearGradient {
        // Intentionally non-semantic: instrumentation, not risk.
        let colors: [Color] = colorScheme == .dark
        ? [Color(red: 0.16, green: 0.24, blue: 0.30).opacity(0.92),
           Color(red: 0.08, green: 0.11, blue: 0.15).opacity(0.92)]
        : [Color(red: 0.92, green: 0.96, blue: 0.97),
           Color(red: 0.88, green: 0.93, blue: 0.95)]

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func formatTemperature(_ temperature: Measurement<UnitTemperature>) -> String {
        Self.temperatureFormatter.string(from: temperature)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .symbolVariant(.fill)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("Atmospheric Conditions")
                    .sectionLabel()
            }

            Text(atmosphereSummary)
                .formatSummaryText(for: colorScheme)
                .lineLimit(1)

            Divider()
                .overlay(colorScheme == .dark ? .white.opacity(0.22) : .black.opacity(0.14))

            metricGrid
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .railStyle(background: atmosphereBackground)
    }

    @ViewBuilder
    private var metricGrid: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 10) {
                metricGridContent
            }
        } else {
            metricGridContent
        }
    }

    private var metricGridContent: some View {
        LazyVGrid(columns: metricColumns, spacing: 8) {
            ForEach(metrics) { metric in
                AtmosphereMetricTile(metric: metric)
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AtmosphereMetric: Identifiable {
    var id: String { title }
    let title: String
    let value: String
    let detail: String?
    let symbol: String
}

private struct AtmosphereMetricTile: View {
    let metric: AtmosphereMetric
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: metric.symbol)
                    .symbolRenderingMode(.monochrome)
                    .font(.caption.weight(.semibold))
                    .imageScale(.medium)
                    .frame(width: 24, height: 18, alignment: .leading)
                    .padding(.leading, 2)
                    .layoutPriority(1)
                Text(metric.title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(0)
            }
            .foregroundStyle(.secondary)

            Text(metric.value)
                .font(.callout.weight(metric.title == "Dew Point" ? .bold : .semibold))
                .foregroundStyle(metric.title == "Dew Point"
                                 ? Color.orange.opacity(colorScheme == .dark ? 0.75 : 0.70)
                                 : .primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let detail = metric.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 2)
        .padding(.vertical, 2)
    }
}

#Preview {
    VStack {
        AtmosphereRailView(weather: .init(
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
            pressure: .init(value: 29.95, unit: .inchesOfMercury),
            pressureTrend: "climbing"
        ), level: .clear)
        AtmosphereRailView(weather: nil, level: .clear)
        AtmosphereRailView(weather: .init(
            temperature: Measurement(
                value: 48.0,
                unit: .fahrenheit
            ),
            symbolName: "cloud.drizzle",
            conditionText: "Scattered showers",
            asOf: .now,
            dewPoint: Measurement(
                value: 43.0,
                unit: .fahrenheit
            ),
            humidity: 0.82,
            windSpeed: .init(value: 8.0, unit: .milesPerHour),
            windGust: nil,
            windDirection: "SE",
            pressure: .init(value: 29.58, unit: .inchesOfMercury),
            pressureTrend: "falling"
        ), level: .elevated)
    }
}
