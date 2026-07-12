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
    @State private var activeTip: DewPointTip?

    let weather: SummaryWeather?
    let airQuality: AirQualityCurrentResponse?
    var isOffline: Bool = false

    private var model: AtmosphericConditionsDisplayModel {
        AtmosphericConditionsDisplayModel(weather: weather, airQuality: airQuality)
    }

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    private var atmosphereBackground: LinearGradient {
        let colors: [Color] = colorScheme == .dark
        ? [
            Color(red: 0.14, green: 0.20, blue: 0.26).opacity(0.95),
            Color(red: 0.09, green: 0.13, blue: 0.17).opacity(0.95)
        ]
        : [
            Color(red: 0.92, green: 0.96, blue: 0.98),
            Color(red: 0.87, green: 0.92, blue: 0.95)
        ]

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if isOffline, weather != nil {
                Text("Offline. Showing saved local data.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            contentSurface
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .cardBackground(
            cornerRadius: SkyAwareRadius.section,
            shadowOpacity: colorScheme == .dark ? 0.08 : 0.11,
            shadowRadius: colorScheme == .dark ? 8 : 10,
            shadowY: colorScheme == .dark ? 3 : 4
        )
        .accessibilityIdentifier("summary-atmospheric-conditions")
    }

    private var header: some View {
        HStack(spacing: 6) {
            Label("Atmospheric Conditions", systemImage: "gauge.with.dots.needle.50percent")
                .symbolVariant(.fill)
                .sectionLabel()
        }
    }

    private var contentSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            leadMetricRow
                .padding(.bottom, 6)

            Divider()
                .overlay(colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.07))
                .padding(.vertical, 4)

            metricsStrip
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: SkyAwareRadius.card, style: .continuous)
                .fill(atmosphereBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: SkyAwareRadius.card, style: .continuous)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.10 : 0.18), lineWidth: 0.8)
                        .allowsHitTesting(false)
                }
        }
    }

    private var leadMetricRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Dew Point")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(model.dewPointDescriptor)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            dewPointValueControl
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var dewPointValueControl: some View {
        if let value = model.dewPointValue {
            Button {
                activeTip = activeTip == .dewPoint ? nil : .dewPoint
            } label: {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.orange.opacity(colorScheme == .dark ? 0.78 : 0.72))
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 4)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dew Point \(value)")
            .accessibilityHint("Shows dew point explanation.")
            .popover(item: $activeTip, attachmentAnchor: .rect(.bounds), arrowEdge: .top) { tip in
                switch tip {
                case .dewPoint:
                    DewPointTipView(
                        currentValue: value,
                        dewPointF: model.dewPointFahrenheit
                    )
                    .presentationCompactAdaptation(.popover)
                }
            }
        } else {
            Text("Unavailable")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var metricsStrip: some View {
        if adaptiveLayout.usesVerticalMetricRows {
            VStack(alignment: .leading, spacing: SkyAwareSpacing.standard) {
                ForEach(model.secondaryMetrics) { metric in
                    AtmosphericMetricRow(metric: metric, isCompact: false)
                }
            }
        } else {
            LazyVGrid(
                columns: secondaryMetricColumns,
                alignment: .leading,
                spacing: SkyAwareSpacing.standard
            ) {
                ForEach(model.secondaryMetrics) { metric in
                    AtmosphericMetricRow(metric: metric, isCompact: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private var secondaryMetricColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: SkyAwareSpacing.standard, alignment: .top),
            count: max(model.secondaryMetrics.count, 1)
        )
    }
}

struct AtmosphericConditionsDisplayModel: Sendable, Equatable {
    struct Metric: Identifiable, Sendable, Equatable {
        enum Kind: String, Identifiable, Sendable {
            case humidity
            case wind
            case pressure
            case aqi

            var id: String { rawValue }
        }

        let kind: Kind
        let title: String
        let value: String
        let iconName: String
        let detail: String?
        let semanticAccent: AirQualityPresentation.SemanticAccent?
        let accessibilityValue: String?

        init(
            kind: Kind,
            title: String,
            value: String,
            iconName: String,
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

    let dewPointValue: String?
    let dewPointFahrenheit: Double?
    let dewPointDescriptor: String
    let secondaryMetrics: [Metric]

    init(weather: SummaryWeather?, airQuality: AirQualityCurrentResponse? = nil) {
        guard let weather else {
            dewPointValue = nil
            dewPointFahrenheit = nil
            dewPointDescriptor = DewPointDescriptor.text(for: nil)
            secondaryMetrics = Self.unavailableMetrics
            return
        }

        let dewPoint = weather.dewPoint.converted(to: .fahrenheit).value
        dewPointValue = Self.formatTemperature(weather.dewPoint)
        dewPointFahrenheit = dewPoint
        dewPointDescriptor = DewPointDescriptor.text(for: dewPoint)
        var metrics: [Metric] = [
            .init(
                kind: .humidity,
                title: "Humidity",
                value: Self.formatHumidity(weather.humidity),
                iconName: "humidity.fill"
            ),
            .init(
                kind: .wind,
                title: "Wind",
                value: Self.formatWind(
                    speed: weather.windSpeed,
                    direction: weather.windDirection
                ),
                iconName: "wind"
            ),
            .init(
                kind: .pressure,
                title: "Pressure",
                value: Self.formatPressure(weather.pressure),
                iconName: "gauge.with.dots.needle.50percent"
            )
        ]

        if let airQuality = AirQualityPresentation(
            aqi: airQuality?.aqi,
            primaryPollutant: airQuality?.primaryPollutant
        ) {
            metrics.append(
                Metric(
                    kind: .aqi,
                    title: "AQI",
                    value: airQuality.value,
                    iconName: "circle.hexagongrid.fill",
                    detail: airQuality.shortCategory,
                    semanticAccent: airQuality.semanticAccent,
                    accessibilityValue: airQuality.accessibilityValue
                )
            )
        }

        secondaryMetrics = metrics
    }

    private static func temperatureFormatter() -> MeasurementFormatter {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter
    }

    private static func formatTemperature(_ temperature: Measurement<UnitTemperature>) -> String {
        temperatureFormatter().string(from: temperature)
    }

    private static func formatHumidity(_ humidity: Double) -> String {
        let percent = humidity * 100
        return "\(percent.formatted(.number.precision(.fractionLength(0))))%"
    }

    private static func formatWind(
        speed: Measurement<UnitSpeed>,
        direction: String
    ) -> String {
        let mph = speed.converted(to: .milesPerHour).value
        let formattedSpeed = "\(mph.formatted(.number.precision(.fractionLength(0)))) mph"
        let cleanDirection = direction.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanDirection.isEmpty == false else {
            return formattedSpeed
        }

        return "\(cleanDirection) \(formattedSpeed)"
    }

    private static func formatPressure(_ pressure: Measurement<UnitPressure>) -> String {
        let inHg = pressure.converted(to: .inchesOfMercury).value
        return "\(inHg.formatted(.number.precision(.fractionLength(2)))) inHg"
    }

    private static var unavailableMetrics: [Metric] {
        [
            .init(kind: .humidity, title: "Humidity", value: "—", iconName: "humidity.fill"),
            .init(kind: .wind, title: "Wind", value: "—", iconName: "wind"),
            .init(kind: .pressure, title: "Pressure", value: "—", iconName: "gauge.with.dots.needle.50percent")
        ]
    }
}

struct AirQualityPresentation: Sendable, Equatable {
    enum SemanticAccent: Sendable, Equatable {
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
        guard let aqi, aqi >= 101 else {
            return nil
        }

        let category: (String, String, SemanticAccent) = switch aqi {
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

enum DewPointDescriptor {
    static func text(for dewPointF: Double?) -> String {
        guard let dewPointF else {
            return "Dew point unavailable"
        }

        switch dewPointF {
        case ..<50:
            return "Dry air in place"
        case 50..<60:
            return "Comfortable moisture"
        case 60..<65:
            return "Moisture increasing"
        case 65..<70:
            return "Moist air may support storms"
        default:
            return "Very moist air in place"
        }
    }
}

private enum DewPointTip: String, Identifiable {
    case dewPoint

    var id: String { rawValue }
}

private struct DewPointTipView: View {
    let currentValue: String
    let dewPointF: Double?

    private var bodyCopy: String {
        "Dew point measures how much moisture is in the air. Higher values can help storms organize, but dew point alone does not determine severe weather."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dew Point")
                .font(.headline.weight(.semibold))

            Text(bodyCopy)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Current value: \(currentValue)")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let dewPointF {
                Text(DewPointDescriptor.text(for: dewPointF))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(width: 360, alignment: .leading)
    }
}

private struct AtmosphericMetricRow: View {
    let metric: AtmosphericConditionsDisplayModel.Metric
    let isCompact: Bool

    var body: some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: metric.iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(metric.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Text(metric.value)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = metric.detail {
                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(valueColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(metric.title)
            .accessibilityValue(metric.accessibilityValue ?? metric.value)
        } else {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: metric.iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 15, alignment: .leading)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(metric.value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(valueColor)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail = metric.detail {
                        Text(detail)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(valueColor)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(metric.title)
            .accessibilityValue(metric.accessibilityValue ?? metric.value)
        }
    }

    private var valueColor: Color {
        switch metric.semanticAccent {
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

#Preview("Atmospheric Conditions - Unavailable Weather") {
    AtmosphericConditionsCard(weather: nil, airQuality: nil)
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
}
