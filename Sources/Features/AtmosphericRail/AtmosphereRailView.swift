//
//  AtmosphereRailView.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/3/26.
//

import SwiftUI
import ArcusCore

struct AtmosphericConditionsCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let weather: SummaryWeather?
    let airQuality: AirQualityCurrentResponse?
    var isOffline: Bool = false

    private var model: AtmosphericConditionsDisplayModel {
        AtmosphericConditionsDisplayModel(
            weather: weather,
            airQuality: airQuality
        )
    }

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isOffline, weather != nil {
                Text("Offline. Showing saved local data.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            contentSurface
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("summary-atmospheric-conditions")
    }

    private var contentSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            metricsStrip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: SkyAwareRadius.card, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: SkyAwareRadius.card, style: .continuous)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.06 : 0.10), lineWidth: 0.8)
                        .allowsHitTesting(false)
                }
        }
    }

    @ViewBuilder
    private var metricsStrip: some View {
        Group {
            if adaptiveLayout.usesVerticalMetricRows {
                VStack(alignment: .leading, spacing: SkyAwareSpacing.standard) {
                    ForEach(model.secondaryMetrics) { metric in
                        AtmosphericMetricColumn(metric: metric, layout: .stacked)
                    }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    AtmosphericMetricsGrid(metrics: model.secondaryMetrics)
                    AtmosphericMetricsStack(metrics: model.secondaryMetrics)
                }
            }
        }
        .animation(SkyAwareMotion.settle(reduceMotion), value: model.secondaryMetrics)
    }
}

struct AtmosphericConditionsDisplayModel: Sendable, Equatable {
    struct Metric: Identifiable, Sendable, Equatable {
        enum Kind: String, Identifiable, Sendable {
            case aqi
            case visibility
            case pressure
            case humidity
            case wind

            var id: String { rawValue }
        }

        let kind: Kind
        let title: String
        let value: String
        let iconName: String?
        let detail: String?
        let semanticAccent: AirQualityPresentation.SemanticAccent?
        let accessibilityValue: String?

        init(
            kind: Kind,
            title: String,
            value: String,
            iconName: String? = nil,
            detail: String? = nil,
            semanticAccent: AirQualityPresentation.SemanticAccent? = nil,
            accessibilityValue: String? = nil
        ) {
            self.kind = kind
            self.title = title
            self.value = value
            self.iconName = iconName
            self.detail = detail
            self.semanticAccent = semanticAccent
            self.accessibilityValue = accessibilityValue
        }

        var id: String { kind.id }
    }

    let secondaryMetrics: [Metric]

    init(
        weather: SummaryWeather?,
        airQuality: AirQualityCurrentResponse? = nil
    ) {
        let visibility = weather.flatMap { Self.visibilityMetric($0.visibility) }
        let pressureTrend = weather.map { Self.pressureTrendMetric($0.pressureTrend) }
        let humidity = weather.map { Self.formatHumidity($0.humidity) }
        let wind = weather.map(Self.windMetric)
        let aqi = AirQualityPresentation(
            aqi: airQuality?.aqi,
            primaryPollutant: airQuality?.primaryPollutant
        )
        let metrics: [Metric] = [
            .init(
                kind: .aqi,
                title: "Air Quality",
                value: aqi?.value ?? "—",
                iconName: "circle.hexagongrid.fill",
                detail: aqi?.shortCategory,
                semanticAccent: aqi?.semanticAccent,
                accessibilityValue: aqi?.accessibilityValue ?? "Unavailable"
            ),
            .init(
                kind: .visibility,
                title: "Visibility",
                value: weather?.visibility.map(Self.formatVisibility) ?? "—",
                iconName: "eye",
                detail: visibility,
                accessibilityValue: visibility.map {
                    "\(weather?.visibility.map(Self.formatVisibility) ?? "—"), \($0)"
                } ?? "Unavailable"
            ),
            .init(
                kind: .pressure,
                title: "Pressure",
                value: weather.map { Self.formatPressure($0.pressure) } ?? "—",
                iconName: pressureTrend?.icon ?? "barometer",
                detail: pressureTrend?.label,
                accessibilityValue: weather.map {
                    "\(Self.formatPressure($0.pressure)), \(pressureTrend?.label ?? "trend unavailable")"
                } ?? "Unavailable"
            ),
            .init(
                kind: .humidity,
                title: "Humidity",
                value: humidity ?? "—",
                iconName: "humidity.fill",
                accessibilityValue: humidity ?? "Unavailable"
            ),
            .init(
                kind: .wind,
                title: "Wind",
                value: wind?.value ?? "—",
                iconName: "wind",
                detail: wind?.gust,
                accessibilityValue: wind?.accessibilityValue ?? "Unavailable"
            )
        ]
        secondaryMetrics = metrics
    }

    private static func formatHumidity(_ humidity: Double) -> String {
        "\((humidity * 100).formatted(.number.precision(.fractionLength(0))))%"
    }

    private static func windMetric(
        _ weather: SummaryWeather
    ) -> (value: String, gust: String?, accessibilityValue: String) {
        let speed = weather.windSpeed.converted(to: .milesPerHour).value
        let speedText = "\(speed.formatted(.number.precision(.fractionLength(0)))) mph"
        let direction = weather.windDirection.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = direction.isEmpty ? speedText : "\(direction) · \(speedText)"
        let gustSpeed = weather.windGust?.converted(to: .milesPerHour).value
        let gust = gustSpeed.flatMap {
            $0 > speed ? "Gusts \($0.formatted(.number.precision(.fractionLength(0)))) mph" : nil
        }
        let accessibilityValue = gust.map { "\(value), \($0)" } ?? value
        return (value, gust, accessibilityValue)
    }

    private static func formatVisibility(_ visibility: Measurement<UnitLength>) -> String {
        let miles = visibility.converted(to: .miles).value
        return "\(miles.formatted(.number.precision(.fractionLength(1)))) mi"
    }

    private static func visibilityMetric(_ visibility: Measurement<UnitLength>?) -> String? {
        guard let visibility else { return nil }
        return String(localized: visibility.converted(to: .miles).value >= 10 ? "Good" : "Reduced")
    }

    private static func pressureTrendMetric(_ trend: String) -> (label: String?, icon: String?) {
        switch trend.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "rising": return (String(localized: "Rising"), "arrow.up")
        case "falling": return (String(localized: "Falling"), "arrow.down")
        case "steady": return (String(localized: "Steady"), "arrow.left.and.right")
        default:
            let legacyLabel = trend.trimmingCharacters(in: .whitespacesAndNewlines)
            return legacyLabel.isEmpty ? (nil, nil) : (legacyLabel, nil)
        }
    }

    private static func formatPressure(_ pressure: Measurement<UnitPressure>) -> String {
        let inHg = pressure.converted(to: .inchesOfMercury).value
        return "\(inHg.formatted(.number.precision(.fractionLength(2)))) inHg"
    }

}

struct AirQualityPresentation: Sendable, Equatable {
    enum SemanticAccent: Sendable, Equatable {
        case good
        case moderate
        case caution
        case unhealthy
        case veryUnhealthy
        case hazardous
    }

    let value: String
    let shortCategory: String
    let accessibilityCategory: String
    let semanticAccent: SemanticAccent
    let primaryPollutant: String?

    init?(aqi: Int?, primaryPollutant: String?) {
        guard let aqi, aqi >= 0 else {
            return nil
        }

        let category: (String, String, SemanticAccent) = switch aqi {
        case 0...50:
            ("Good", "good", SemanticAccent.good)
        case 51...100:
            ("Moderate", "moderate", SemanticAccent.moderate)
        case 101...150:
            ("USG", "unhealthy for sensitive groups", SemanticAccent.caution)
        case 151...200:
            ("Unhealthy", "unhealthy", SemanticAccent.unhealthy)
        case 201...300:
            ("Very Unhealthy", "very unhealthy", SemanticAccent.veryUnhealthy)
        default:
            ("Hazardous", "hazardous", SemanticAccent.hazardous)
        }

        self.value = aqi.formatted()
        self.shortCategory = category.0
        self.accessibilityCategory = category.1
        self.semanticAccent = category.2
        let trimmedPollutant = primaryPollutant?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.primaryPollutant = trimmedPollutant?.isEmpty == false ? trimmedPollutant : nil
    }

    var accessibilityValue: String {
        var accessibilityText = "Air quality index \(value), \(accessibilityCategory)."
        if let primaryPollutant {
            accessibilityText += " Primary pollutant \(primaryPollutant)."
        }
        return accessibilityText
    }
}

private struct AtmosphericMetricsGrid: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let metrics: [AtmosphericConditionsDisplayModel.Metric]

    private var topRow: [AtmosphericConditionsDisplayModel.Metric] {
        metrics.filter { [.aqi, .visibility, .pressure].contains($0.kind) }
    }

    private var bottomRow: [AtmosphericConditionsDisplayModel.Metric] {
        metrics.filter { [.humidity, .wind].contains($0.kind) }
    }

    var body: some View {
        VStack(spacing: SkyAwareSpacing.standard) {
            metricRow(topRow)
            metricRow(bottomRow)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(SkyAwareMotion.settle(reduceMotion), value: metrics)
    }

    private func metricRow(_ rowMetrics: [AtmosphericConditionsDisplayModel.Metric]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(rowMetrics.enumerated()), id: \.element.id) { index, metric in
                AtmosphericMetricColumn(metric: metric, layout: .rail)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .center)))

                if index < rowMetrics.count - 1 {
                    Divider()
                        .overlay(colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.08))
                        .padding(.vertical, 2)
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct AtmosphericMetricsStack: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let metrics: [AtmosphericConditionsDisplayModel.Metric]

    var body: some View {
        VStack(alignment: .leading, spacing: SkyAwareSpacing.standard) {
            ForEach(metrics) { metric in
                AtmosphericMetricColumn(metric: metric, layout: .stacked)
                    .transition(.opacity.combined(with: .offset(y: 4)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(SkyAwareMotion.settle(reduceMotion), value: metrics)
    }
}

private struct AtmosphericMetricColumn: View {
    enum Layout {
        case rail
        case stacked

        var verticalSpacing: CGFloat {
            switch self {
            case .rail:
                5
            case .stacked:
                6
            }
        }
    }

    let metric: AtmosphericConditionsDisplayModel.Metric
    let layout: Layout

    var body: some View {
        VStack(alignment: .center, spacing: layout.verticalSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let iconName = metric.iconName {
                    Image(systemName: iconName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(iconColor)
                        .accessibilityHidden(true)
                }

                Text(metric.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
                .frame(maxWidth: .infinity)

            Text(metric.value)
                .font(.body.weight(.semibold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .lineLimit(metric.kind == .aqi ? 1 : nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            if let detail = metric.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(metric.semanticAccent == nil ? .secondary : valueColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }

        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(metric.title)
        .accessibilityValue(metric.accessibilityValue ?? metric.value)
    }

    private var iconColor: Color {
        metric.semanticAccent == nil ? .secondary : valueColor
    }

    private var valueColor: Color {
        switch metric.semanticAccent {
        case .good:
            .riskAllClear
        case .moderate:
            .riskSlight
        case .caution:
            .warningYellow
        case .unhealthy:
            .riskEnhanced
        case .veryUnhealthy:
            .riskModerate
        case .hazardous:
            .riskHigh
        case nil:
            .primary
        }
    }
}

#Preview("Atmospheric Conditions - Calm Light") {
    AtmosphericConditionsCard(weather: AtmosphericConditionsPreviewData.calm, airQuality: nil)
}

#Preview("Atmospheric Conditions - Moist") {
    AtmosphericConditionsCard(weather: AtmosphericConditionsPreviewData.stormSupportive, airQuality: nil)
}

#Preview("Atmospheric Conditions - Very Moist") {
    AtmosphericConditionsCard(weather: AtmosphericConditionsPreviewData.veryMoist, airQuality: nil)
}

#Preview("Atmospheric Conditions - Good AQI") {
    AtmosphericConditionsCard(
        weather: AtmosphericConditionsPreviewData.calm,
        airQuality: AtmosphericConditionsPreviewData.hiddenAirQuality
    )
}

#Preview("Atmospheric Conditions - With AQI") {
    AtmosphericConditionsCard(
        weather: AtmosphericConditionsPreviewData.stormSupportive,
        airQuality: AtmosphericConditionsPreviewData.validAirQuality
    )
}

#Preview("Atmospheric Conditions - Hazardous AQI") {
    AtmosphericConditionsCard(
        weather: AtmosphericConditionsPreviewData.stormSupportive,
        airQuality: AtmosphericConditionsPreviewData.hazardousAirQuality
    )
}

#Preview("Atmospheric Conditions - Long Wind") {
    AtmosphericConditionsCard(weather: AtmosphericConditionsPreviewData.longWind, airQuality: nil)
}

#Preview("Atmospheric Conditions - Unavailable Weather") {
    AtmosphericConditionsCard(weather: nil, airQuality: nil)
}

#Preview("Atmospheric Conditions - Cached Offline") {
    AtmosphericConditionsCard(
        weather: AtmosphericConditionsPreviewData.stormSupportive,
        airQuality: nil,
        isOffline: true
    )
}

#Preview("Atmospheric Conditions - Resolving") {
    AtmosphericConditionsCard(weather: nil, airQuality: nil)
        .placeholder(true, animated: false)
        .summaryResolving(true, todayContentState: .noCacheResolving, style: .subtle)
        .allowsHitTesting(false)
}

#Preview("Atmospheric Conditions - Light Mode") {
    AtmosphericConditionsCard(weather: AtmosphericConditionsPreviewData.stormSupportive, airQuality: nil)
        .preferredColorScheme(.light)
}

#Preview("Atmospheric Conditions - Dark Mode") {
    AtmosphericConditionsCard(weather: AtmosphericConditionsPreviewData.veryMoist, airQuality: nil)
        .preferredColorScheme(.dark)
}

#Preview("Atmospheric Conditions - Large Dynamic Type") {
    AtmosphericConditionsCard(weather: AtmosphericConditionsPreviewData.stormSupportive, airQuality: nil)
        .environment(\.dynamicTypeSize, .accessibility3)
}

private enum AtmosphericConditionsPreviewData {
    static let hiddenAirQuality: AirQualityCurrentResponse? = {
        let json = """
        {"aqi":46,"category":{"identifier":2,"name":"Good"},"primaryPollutant":"O3","observedAt":"2026-07-12T21:00:00Z","sourceIdentifier":"airnow"}
        """

        return try? DecoderFactory.iso8601.decode(
            AirQualityCurrentResponse.self,
            from: Data(json.utf8)
        )
    }()

    static let validAirQuality: AirQualityCurrentResponse? = {
        let json = """
        {"aqi":121,"category":{"identifier":3,"name":"Unhealthy for Sensitive Groups"},"primaryPollutant":"PM2.5","observedAt":"2026-07-12T21:00:00Z","sourceIdentifier":"airnow"}
        """

        return try? DecoderFactory.iso8601.decode(
            AirQualityCurrentResponse.self,
            from: Data(json.utf8)
        )
    }()

    static let hazardousAirQuality: AirQualityCurrentResponse? = {
        let json = """
        {"aqi":301,"category":{"identifier":5,"name":"Hazardous"},"primaryPollutant":"PM2.5","observedAt":"2026-07-12T21:00:00Z","sourceIdentifier":"airnow"}
        """

        return try? DecoderFactory.iso8601.decode(
            AirQualityCurrentResponse.self,
            from: Data(json.utf8)
        )
    }()

    static let calm = SummaryWeather(
        temperature: Measurement(value: 58.0, unit: .fahrenheit),
        symbolName: "cloud.sun.fill",
        conditionText: "Cool and steady",
        asOf: .now,
        dewPoint: Measurement(value: 52.0, unit: .fahrenheit),
        humidity: 0.45,
        windSpeed: Measurement(value: 8.0, unit: .milesPerHour),
        windGust: nil,
        windDirection: "NW",
        pressure: Measurement(value: 30.04, unit: .inchesOfMercury),
        pressureTrend: "steady"
    )

    static let stormSupportive = SummaryWeather(
        temperature: Measurement(value: 82.0, unit: .fahrenheit),
        symbolName: "cloud.bolt.rain.fill",
        conditionText: "Warm, moist, and unsettled",
        asOf: .now,
        dewPoint: Measurement(value: 68.0, unit: .fahrenheit),
        humidity: 0.71,
        windSpeed: Measurement(value: 14.0, unit: .milesPerHour),
        windGust: Measurement(value: 22.0, unit: .milesPerHour),
        windDirection: "S",
        pressure: Measurement(value: 29.82, unit: .inchesOfMercury),
        pressureTrend: "falling"
    )

    static let veryMoist = SummaryWeather(
        temperature: Measurement(value: 86.0, unit: .fahrenheit),
        symbolName: "cloud.drizzle.fill",
        conditionText: "Very humid",
        asOf: .now,
        dewPoint: Measurement(value: 72.0, unit: .fahrenheit),
        humidity: 0.84,
        windSpeed: Measurement(value: 11.0, unit: .milesPerHour),
        windGust: nil,
        windDirection: "SE",
        pressure: Measurement(value: 29.76, unit: .inchesOfMercury),
        pressureTrend: "falling"
    )

    static let longWind = SummaryWeather(
        temperature: Measurement(value: 83.0, unit: .fahrenheit),
        symbolName: "wind",
        conditionText: "Breezy with a long directional label",
        asOf: .now,
        dewPoint: Measurement(value: 67.0, unit: .fahrenheit),
        humidity: 0.62,
        windSpeed: Measurement(value: 18.0, unit: .milesPerHour),
        windGust: Measurement(value: 27.0, unit: .milesPerHour),
        windDirection: "South-southeast",
        pressure: Measurement(value: 29.68, unit: .inchesOfMercury),
        pressureTrend: "falling"
    )
}
