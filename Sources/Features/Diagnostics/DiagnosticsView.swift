//
//  DiagnosticsView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/10/25.
//

import SwiftUI
import OSLog
import SwiftData

struct DiagnosticsView: View {
    @Environment(LocationSession.self) private var locationSession
    @Query(sort: [SortDescriptor(\HomeProjection.updatedAt, order: .reverse)])
    private var cachedProjections: [HomeProjection]

    @State private var cacheStatusMessage: String?
    private let logger = Logger.uiSettings

    private var diagnostics: IngestionDiagnosticsData? {
        Self.resolveIngestionDiagnostics(
            from: cachedProjections.map(\.record),
            currentContext: locationSession.currentContext
        )
    }

    var body: some View {
        List {
            if let diagnostics {
                Section("Projection Context") {
                    LabeledContent("Viewing") {
                        Text(diagnostics.projectionSourceTitle)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Placemark") {
                        Text(displayValue(diagnostics.projection.placemarkSummary))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Location Timestamp") {
                        timestampValue(diagnostics.projection.locationTimestamp)
                    }

                    LabeledContent("H3 Cell") {
                        Text(diagnostics.h3CellDisplay)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    LabeledContent("County") {
                        Text(displayValue(diagnostics.projection.countyCode))
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Forecast Zone") {
                        Text(displayValue(diagnostics.projection.forecastZone))
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Fire Zone") {
                        Text(displayValue(diagnostics.projection.fireZone))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Projection Key")
                            .font(.subheadline.weight(.semibold))
                        Text(diagnostics.projection.projectionKey)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section("Ingestion Lanes") {
                    ForEach(diagnostics.laneStatuses) { laneStatus in
                        LabeledContent(laneStatus.title) {
                            timestampValue(laneStatus.lastSuccessfulLoadAt)
                        }
                    }
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "No Cached Ingestion Data Yet",
                        systemImage: "tray.fill",
                        description: Text("Run ingestion once to populate projection-backed diagnostics.")
                    )
                }
            }

            Section("Actions") {
                Button("Clear Network Cache") {
                    clearCache()
                }
                .skyAwareGlassButtonStyle()

                if let cacheStatusMessage {
                    Text(cacheStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(.skyAwareBackground)
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        cacheStatusMessage = "Network cache cleared. Your next fetch should be live."
        logger.notice("Diagnostics cleared shared URL cache")
    }

    private func displayValue(_ value: String?) -> String {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return "Unavailable"
        }
        return trimmed
    }

    @ViewBuilder
    private func timestampValue(_ date: Date?) -> some View {
        if let date {
            VStack(alignment: .trailing, spacing: 2) {
                Text(date, format: Self.timestampFormat)
                    .foregroundStyle(.secondary)
                Text(date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.trailing)
        } else {
            Text("Not loaded yet")
                .foregroundStyle(.secondary)
        }
    }
}

extension DiagnosticsView {
    struct IngestionDiagnosticsData: Equatable, Sendable {
        enum ProjectionSource: Equatable, Sendable {
            case currentContext
            case latestCached
        }

        struct LaneStatus: Identifiable, Equatable, Sendable {
            let id: String
            let title: String
            let lastSuccessfulLoadAt: Date?
        }

        let projectionSource: ProjectionSource
        let projection: HomeProjectionRecord

        var projectionSourceTitle: String {
            switch projectionSource {
            case .currentContext:
                return "Current location projection"
            case .latestCached:
                return "Latest cached projection"
            }
        }

        var h3CellDisplay: String {
            String(UInt64(bitPattern: projection.h3Cell), radix: 16)
        }

        var laneStatuses: [LaneStatus] {
            [
                LaneStatus(
                    id: "hot-alerts",
                    title: "Hot Alerts",
                    lastSuccessfulLoadAt: projection.lastHotAlertsLoadAt
                ),
                LaneStatus(
                    id: "slow-products",
                    title: "Slow Products",
                    lastSuccessfulLoadAt: projection.lastSlowProductsLoadAt
                ),
                LaneStatus(
                    id: "weather",
                    title: "Weather",
                    lastSuccessfulLoadAt: projection.lastWeatherLoadAt
                ),
                LaneStatus(
                    id: "projection",
                    title: "Projection Update",
                    lastSuccessfulLoadAt: projection.updatedAt
                )
            ]
        }
    }

    static let timestampFormat = Date.FormatStyle.dateTime
        .month(.abbreviated)
        .day()
        .year()
        .hour(.defaultDigits(amPM: .abbreviated))
        .minute()

    static func resolveIngestionDiagnostics(
        from projections: [HomeProjectionRecord],
        currentContext: LocationContext?
    ) -> IngestionDiagnosticsData? {
        if let currentContext {
            let projectionKey = HomeProjection.projectionKey(for: currentContext)
            if let projection = projections.first(where: { $0.projectionKey == projectionKey }) {
                return IngestionDiagnosticsData(
                    projectionSource: .currentContext,
                    projection: projection
                )
            }
        }

        guard let fallback = projections.max(by: { $0.updatedAt < $1.updatedAt }) else {
            return nil
        }

        return IngestionDiagnosticsData(
            projectionSource: .latestCached,
            projection: fallback
        )
    }
}

#Preview {
    NavigationStack {
        DiagnosticsView()
            .navigationTitle("Ingestion Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
    }
    .environment(LocationSession.preview)
    .modelContainer(DiagnosticsViewPreviewData.modelContainer)
}

@MainActor
private enum DiagnosticsViewPreviewData {
    static let modelContainer: ModelContainer = {
        let schema = Schema([HomeProjection.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        if let previewContext = LocationSession.preview.currentContext {
            let projection = HomeProjection(
                context: previewContext,
                createdAt: .now.addingTimeInterval(-3_600),
                lastViewedAt: .now
            )
            projection.lastHotAlertsLoadAt = .now.addingTimeInterval(-300)
            projection.lastSlowProductsLoadAt = .now.addingTimeInterval(-1_800)
            projection.lastWeatherLoadAt = .now.addingTimeInterval(-120)
            projection.updatedAt = .now.addingTimeInterval(-120)
            context.insert(projection)
        }

        try! context.save()
        return container
    }()
}
