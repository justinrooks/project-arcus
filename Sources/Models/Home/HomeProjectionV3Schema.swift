import ArcusCore
import Foundation
import SwiftData

/// Frozen representation of the v3 model shipped in v1.3.0 (build 228).
/// Keep this type unchanged so v3 stores can be migrated into the current schema.
enum SkyAwarePersistenceSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static let models: [any PersistentModel.Type] = [
        ConvectiveOutlook.self,
        MD.self,
        StormRisk.self,
        SevereRisk.self,
        BgRunSnapshot.self,
        Watch.self,
        FireRisk.self,
        HomeProjection.self
    ]

    @Model
    final class ConvectiveOutlook {
        var id: UUID
        @Attribute(.unique) var title: String
        var link: URL
        var published: Date
        var fullText: String?
        var summary: String
        var riskLevel: String?
        var issued: Date?
        var validUntil: Date?
        var day: Int?

        init(
            title: String,
            link: URL,
            published: Date,
            fullText: String,
            summary: String,
            day: Int?,
            riskLevel: String?,
            issued: Date?,
            validUntil: Date?
        ) {
            id = UUID()
            self.title = title
            self.link = link
            self.published = published
            self.fullText = fullText
            self.summary = summary
            self.day = day
            self.riskLevel = riskLevel
            self.issued = issued
            self.validUntil = validUntil
        }
    }

    struct HomeProjectionWeatherPayload: Sendable, Codable, Equatable {
        let temperatureFahrenheit: Double
        let symbolName: String
        let conditionText: String
        let asOf: Date
        let dewPointFahrenheit: Double
        let humidity: Double
        let windSpeedMilesPerHour: Double
        let windGustMilesPerHour: Double?
        let windDirection: String
        let pressureInchesOfMercury: Double
        let pressureTrend: String
    }

    @Model
    final class HomeProjection {
        var id: UUID
        var projectionKey: String
        var latitude: Double
        var longitude: Double
        var h3Cell: Int64
        var countyCode: String
        var forecastZone: String?
        var fireZone: String
        var placemarkSummary: String?
        var timeZoneId: String?
        var locationTimestamp: Date
        var createdAt: Date
        var updatedAt: Date
        var lastViewedAt: Date?
        var weatherPayload: HomeProjectionWeatherPayload?
        var stormSetupCurrentResponseData: Data?
        var stormRisk: StormRiskLevel?
        var severeRiskKindRawValue: String?
        var severeRiskProbability: Double?
        var fireRisk: FireRiskLevel?
        var convectiveRiskComparisonLocationKey: String?
        var convectiveRiskComparisonSourceKey: String?
        var fireRiskComparisonLocationKey: String?
        var fireRiskComparisonSourceKey: String?
        var activeAlerts: [AlertDTO]
        var activeMesos: [MdDTO]
        var airQualityAQI: Int?
        var airQualityCategoryIdentifier: Int?
        var airQualityCategoryName: String?
        var airQualityCategoryIsPresent: Bool?
        var airQualityPrimaryPollutant: String?
        var airQualityObservedAt: Date?
        var airQualitySourceIdentifier: String?
        var lastHotAlertsLoadAt: Date?
        var lastSlowProductsLoadAt: Date?
        var lastWeatherLoadAt: Date?
        var lastAirQualityLoadAt: Date?
        var lastStormSetupLoadAt: Date?

        init(context: LocationContext, createdAt: Date = .now, lastViewedAt: Date? = nil) {
            id = UUID()
            projectionKey = [
                "h3:\(context.h3Cell)",
                "county:\(Self.normalizedKeyComponent(context.grid.countyCode))",
                "forecast:\(Self.normalizedKeyComponent(context.grid.forecastZone))",
                "fire:\(Self.normalizedKeyComponent(context.grid.fireZone))"
            ].joined(separator: "|")
            latitude = context.snapshot.coordinates.latitude
            longitude = context.snapshot.coordinates.longitude
            h3Cell = context.h3Cell
            countyCode = context.grid.countyCode ?? ""
            forecastZone = context.grid.forecastZone
            fireZone = context.grid.fireZone ?? ""
            placemarkSummary = context.snapshot.placemarkSummary
            timeZoneId = context.grid.timeZoneId
            locationTimestamp = context.snapshot.timestamp
            self.createdAt = createdAt
            updatedAt = createdAt
            self.lastViewedAt = lastViewedAt
            weatherPayload = nil
            stormSetupCurrentResponseData = nil
            stormRisk = nil
            severeRiskKindRawValue = nil
            severeRiskProbability = nil
            fireRisk = nil
            convectiveRiskComparisonLocationKey = nil
            convectiveRiskComparisonSourceKey = nil
            fireRiskComparisonLocationKey = nil
            fireRiskComparisonSourceKey = nil
            activeAlerts = []
            activeMesos = []
            airQualityAQI = nil
            airQualityCategoryIdentifier = nil
            airQualityCategoryName = nil
            airQualityCategoryIsPresent = nil
            airQualityPrimaryPollutant = nil
            airQualityObservedAt = nil
            airQualitySourceIdentifier = nil
            lastHotAlertsLoadAt = nil
            lastSlowProductsLoadAt = nil
            lastWeatherLoadAt = nil
            lastAirQualityLoadAt = nil
            lastStormSetupLoadAt = nil
        }

        private static func normalizedKeyComponent(_ value: String?) -> String {
            guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                  normalized.isEmpty == false else {
                return "unknown"
            }
            return normalized
        }
    }
}
