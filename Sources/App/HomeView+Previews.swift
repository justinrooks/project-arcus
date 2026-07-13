import ArcusCore
import Foundation
import SwiftData
import SwiftUI

#Preview("Home") {
    HomeView(
        initialSnap: .init(
            coordinates: .init(latitude: 39.75, longitude: -104.44),
            timestamp: .now,
            accuracy: 20,
            placemarkSummary: "Bennett, CO"
        ),
        initialStormRisk: .slight,
        initialSevereRisk: .tornado(probability: 0.10),
        initialFireRisk: .extreme,
        initialMesos: MD.sampleDiscussionDTOs,
        initialAlerts: Watch.sampleWatchRows,
        initialOutlooks: ConvectiveOutlook.sampleOutlookDtos,
        initialOutlook: ConvectiveOutlook.sampleOutlookDtos.first
    )
    .environment(\.dependencies, Dependencies.unconfigured)
    .environment(LocationSession.preview)
    .environment(RemoteAlertPresentationState())
    .environment(RuntimeConnectivityState.preview)
    .modelContainer(HomeViewPreviewData.modelContainer)
}

@MainActor
private enum HomeViewPreviewData {
    static let modelContainer: ModelContainer = {
        let schema = Schema([HomeProjection.self, ConvectiveOutlook.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        if let previewContext = LocationSession.preview.currentContext {
            let projection = HomeProjection(
                context: previewContext,
                createdAt: .now,
                lastViewedAt: .now
            )
            projection.weatherPayload = HomeProjectionWeatherPayload(
                summary: SummaryWeather(
                    temperature: .init(value: 72, unit: .fahrenheit),
                    symbolName: "sun.max.fill",
                    conditionText: "Clear",
                    asOf: .now,
                    dewPoint: .init(value: 54, unit: .fahrenheit),
                    humidity: 0.45,
                    windSpeed: .init(value: 15, unit: .milesPerHour),
                    windGust: .init(value: 24, unit: .milesPerHour),
                    windDirection: "NW",
                    pressure: .init(value: 29.92, unit: .inchesOfMercury),
                    pressureTrend: "steady"
                )
            )
            projection.stormRisk = .slight
            projection.severeRisk = .tornado(probability: 0.10)
            projection.fireRisk = .extreme
            projection.activeMesos = MD.sampleDiscussionDTOs
            projection.activeAlerts = Watch.sampleWatchRows
            projection.updatedAt = .now
            context.insert(projection)
        }

        if let outlook = ConvectiveOutlook.sampleOutlookDtos.first {
            context.insert(
                ConvectiveOutlook(
                    title: outlook.title,
                    link: outlook.link,
                    published: outlook.published,
                    fullText: outlook.fullText,
                    summary: outlook.summary,
                    day: outlook.day,
                    riskLevel: outlook.riskLevel,
                    issued: outlook.issued ?? outlook.published,
                    validUntil: outlook.validUntil ?? outlook.published
                )
            )
        }

        try! context.save()
        return container
    }()
}
