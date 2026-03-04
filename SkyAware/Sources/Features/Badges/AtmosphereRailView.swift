//
//  AtmosphereRailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/3/26.
//

import SwiftUI

struct AtmosphereRailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var activeTip: AtmosphereTip?
    let weather: SummaryWeather?

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

    private var dewPointFahrenheit: Double? {
        weather?.dewPoint.converted(to: .fahrenheit).value
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
            .init(kind: .dewPoint,
                  title: "Dew Point",
                  value: formattedDewPoint ?? "—",
                  numericValue: dewPointFahrenheit,
                  detail: nil,
                  symbol: "thermometer.sun"),
            .init(kind: .humidity,
                  title: "Humidity",
                  value: formattedHumidity ?? "—",
                  numericValue: nil,
                  detail: nil,
                  symbol: "humidity.fill"),
            .init(kind: .wind,
                  title: "Wind",
                  value: formattedWind ?? "—",
                  numericValue: nil,
                  detail: weather?.windDirection ?? "Direction unavailable",
                  symbol: "wind"),
            .init(kind: .pressure,
                  title: "Pressure",
                  value: formattedPressure ?? "—",
                  numericValue: nil,
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
        metricGridContent
    }

    private var metricGridContent: some View {
        LazyVGrid(columns: metricColumns, spacing: 8) {
            ForEach(metrics) { metric in
                AtmosphereMetricTile(
                    metric: metric,
                    activeTip: $activeTip
                )
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum AtmosphereMetricKind: String, Identifiable {
    case dewPoint
    case humidity
    case wind
    case pressure

    var id: String { rawValue }
}

private struct AtmosphereMetric: Identifiable {
    var id: AtmosphereMetricKind { kind }
    let kind: AtmosphereMetricKind
    let title: String
    let value: String
    let numericValue: Double?
    let detail: String?
    let symbol: String
}

private enum AtmosphereTip: String, Identifiable {
    case dewPoint

    var id: String { rawValue }
}

private struct DewPointTipView: View {
    let currentValue: String
    let dewPointF: Double?

    private var dewPointHint: String? {
        guard let dp = dewPointF else { return nil }

        switch dp {
        case ..<55:
            return "The air is fairly dry. Strong thunderstorms are less likely."
        case 55..<60:
            return "Moisture is increasing, but still somewhat limited for stronger storms."
        case 60..<65:
            return "Moisture levels are supportive of developing thunderstorms."
        case 65..<70:
            return "Moisture is high and can support stronger storms."
        default:
            return "Very humid air. Storms can become intense if other conditions align."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dew Point")
                .font(.headline.weight(.semibold))

            Text("Dew point measures how much moisture is in the air. Moisture acts as fuel for thunderstorms.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if currentValue != "—" {
                Text("Current value: \(currentValue)")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let hint = dewPointHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("When dew points climb into the mid‑60s°F or higher, storms can grow stronger and the potential for severe weather increases.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(width: 360, alignment: .leading)
    }
}

private struct AtmosphereMetricTile: View {
    let metric: AtmosphereMetric
    @Binding var activeTip: AtmosphereTip?
    @Environment(\.colorScheme) private var colorScheme

    private var isDewPoint: Bool {
        metric.kind == .dewPoint
    }

    private var tileContent: some View {
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
                .font(.callout.weight(isDewPoint ? .bold : .semibold))
                .foregroundStyle(
                    isDewPoint
                    ? Color.orange.opacity(colorScheme == .dark ? 0.75 : 0.70)
                    : .primary
                )
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
    }

    var body: some View {
        Group {
            if isDewPoint {
                Button {
                    activeTip = activeTip == .dewPoint ? nil : .dewPoint
                } label: {
                    tileContent
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: SkyAwareRadius.medium, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Dew Point \(metric.value)")
                .accessibilityHint("Shows more detail about dew point.")
                .popover(item: $activeTip, attachmentAnchor: .rect(.bounds), arrowEdge: .top) { tip in
                    switch tip {
                    case .dewPoint:
                        DewPointTipView(currentValue: metric.value, dewPointF: metric.numericValue)
                            .presentationCompactAdaptation(.popover)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 6)
                .padding(.trailing, 4)
                .padding(.vertical, 6)
            } else {
                tileContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)
                    .padding(.trailing, 4)
                    .padding(.vertical, 6)
            }
        }
    }
}

#Preview {
    VStack {
        AtmosphereRailView(weather: .init(
            temperature: Measurement(value: 37.0, unit: .fahrenheit),
            symbolName: "sun.max",
            conditionText: "test",
            asOf: .now,
            dewPoint: Measurement(value: 45.0, unit: .fahrenheit),
            humidity: 0.15,
            windSpeed: .init(value: 15.0, unit: .milesPerHour),
            windGust: nil,
            windDirection: "NNW",
            pressure: .init(value: 29.95, unit: .inchesOfMercury),
            pressureTrend: "climbing"
        ))

        AtmosphereRailView(weather: nil)

        AtmosphereRailView(weather: .init(
            temperature: Measurement(value: 48.0, unit: .fahrenheit),
            symbolName: "cloud.drizzle",
            conditionText: "Scattered showers",
            asOf: .now,
            dewPoint: Measurement(value: 43.0, unit: .fahrenheit),
            humidity: 0.82,
            windSpeed: .init(value: 8.0, unit: .milesPerHour),
            windGust: nil,
            windDirection: "SE",
            pressure: .init(value: 29.58, unit: .inchesOfMercury),
            pressureTrend: "falling"
        ))
    }
}
