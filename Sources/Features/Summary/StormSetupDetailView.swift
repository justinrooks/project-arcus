//
//  StormSetupDetailView.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI

struct StormSetupDetailView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let presentation: StormSetupDetailPresentation

    @State private var showsGuidanceSheet = false

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                assessmentCard
                ingredientCard

                if presentation.limitingFactors.isEmpty == false {
                    textCard(title: "Limiting factors", values: presentation.limitingFactors)
                }

                if presentation.primaryDrivers.isEmpty == false {
                    textCard(title: "Primary drivers", values: presentation.primaryDrivers)
                }

                provenanceCard

                if presentation.advancedRows.isEmpty == false {
                    advancedCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(.skyAwareBackground)
        .navigationTitle("Storm Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.skyAwareBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsGuidanceSheet = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel(presentation.modelGuidanceTitle)
                .accessibilityHint("Explains how Storm Setup guidance is derived.")
            }
        }
        .sheet(isPresented: $showsGuidanceSheet) {
            StormSetupGuidanceSheet(
                title: presentation.modelGuidanceTitle,
                message: presentation.modelGuidanceBody
            )
        }
    }

    private var assessmentCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(presentation.assessmentTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let summaryText = presentation.summaryText {
                    Text(summaryText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let confidenceText = presentation.confidenceText {
                    Text(confidenceText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var ingredientCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Readable ingredients")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(presentation.ingredientRows) { row in
                        StormSetupDetailRowView(row: row)
                    }
                }
            }
        }
    }

    private var provenanceCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Source and freshness")
                    .font(.headline)

                Text(presentation.provenanceHeadline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(presentation.updatedText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                if let freshnessText = presentation.freshnessText {
                    Text(freshnessText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var advancedCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Advanced Details")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(presentation.advancedRows) { row in
                        StormSetupDetailRowView(row: row)
                    }
                }

                if let diagnosticsNoteText = presentation.diagnosticsNoteText {
                    Text(diagnosticsNoteText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func textCard(title: String, values: [String]) -> some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        Text(value)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground(
                cornerRadius: SkyAwareRadius.card,
                shadowOpacity: adaptiveLayout.usesAccessibilityLayout ? 0.06 : 0.10,
                shadowRadius: adaptiveLayout.usesAccessibilityLayout ? 10 : 12,
                shadowY: adaptiveLayout.usesAccessibilityLayout ? 4 : 6
            )
    }
}

private struct StormSetupDetailRowView: View {
    let row: StormSetupDetailPresentation.Row

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalRow
            stackedRow
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    private var horizontalRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(row.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 10)

            Text(row.value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stackedRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(row.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(row.value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct StormSetupGuidanceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .background(.skyAwareBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.skyAwareBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Readable detail") {
    NavigationStack {
        StormSetupDetailView(
            presentation: StormSetupDetailPresentation(
                dto: StormSetupDetailPreviewData.readableDTO,
                preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
                forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
                now: StormSetupDetailPreviewData.now
            )
        )
    }
}

#Preview("Advanced detail") {
    NavigationStack {
        StormSetupDetailView(
            presentation: StormSetupDetailPresentation(
                dto: StormSetupDetailPreviewData.advancedDTO,
                preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
                forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
                now: StormSetupDetailPreviewData.now
            )
        )
        .preferredColorScheme(.dark)
    }
}

#Preview("Partial payload") {
    NavigationStack {
        StormSetupDetailView(
            presentation: StormSetupDetailPresentation(
                dto: StormSetupDetailPreviewData.partialDTO,
                preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
                forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
                now: StormSetupDetailPreviewData.now
            )
        )
        .environment(\.dynamicTypeSize, .accessibility2)
    }
}

#Preview("Stale degraded detail") {
    NavigationStack {
        StormSetupDetailView(
            presentation: StormSetupDetailPresentation(
                dto: StormSetupDetailPreviewData.staleDegradedDTO,
                preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
                forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
                now: StormSetupDetailPreviewData.now
            )
        )
    }
}

#Preview("Large type detail") {
    NavigationStack {
        StormSetupDetailView(
            presentation: StormSetupDetailPresentation(
                dto: StormSetupDetailPreviewData.advancedDTO,
                preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
                forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
                now: StormSetupDetailPreviewData.now
            )
        )
        .environment(\.dynamicTypeSize, .accessibility5)
    }
}

#Preview("Dark readable detail") {
    NavigationStack {
        StormSetupDetailView(
            presentation: StormSetupDetailPresentation(
                dto: StormSetupDetailPreviewData.readableDTO,
                preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
                forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
                now: StormSetupDetailPreviewData.now
            )
        )
        .preferredColorScheme(.dark)
    }
}

private enum StormSetupDetailPreviewData {
    static let now = skyAwareDate("2026-06-01T18:00:00Z")

    static let readableDTO = makeDTO(
        summary: "The setup is supportive and ingredients are beginning to align.",
        overall: "supportive",
        isStale: false,
        isDegraded: false,
        anvilEvidence: nil
    )

    static let advancedDTO = makeDTO(
        summary: "The setup is strongly supportive.",
        overall: "strong",
        isStale: false,
        isDegraded: false,
        anvilEvidence: .init(
            status: "available",
            scp: .init(support: "supportive"),
            stp: .init(support: "conditional"),
            ship: .init(support: "weak"),
            diagnostics: .init(
                hasEffectiveLayer: true,
                hasStormMotion: true,
                qualityProfileLevelCount: 3,
                warnings: ["pressure-level diagnostics trimmed"]
            )
        )
    )

    static let partialDTO = makeDTO(
        summary: nil,
        overall: "conditional",
        isStale: false,
        isDegraded: false,
        rawOverrides: .init(
            mlcapeJkg: nil,
            mucapeJkg: 0,
            sbcapeJkg: nil,
            mlcinJkg: -12,
            srh01kmM2s2: nil,
            srh03kmM2s2: 0,
            shear06kmKt: 31.2,
            mllclM: nil,
            tempDewPtDeltaF: 4,
            threeCapeJkg: nil
        ),
        anvilEvidence: .init(
            status: "available",
            scp: nil,
            stp: .init(support: "supportive"),
            ship: nil,
            diagnostics: .init(
                hasEffectiveLayer: nil,
                hasStormMotion: false,
                qualityProfileLevelCount: nil,
                warnings: nil
            )
        )
    )

    static let staleDegradedDTO = makeDTO(
        summary: "Guidance remains supportive but should be checked again.",
        overall: "supportive",
        isStale: true,
        isDegraded: true,
        anvilEvidence: nil
    )

    private static func makeDTO(
        summary: String?,
        overall: String,
        isStale: Bool,
        isDegraded: Bool,
        rawOverrides: StormSetupDTO.Raw? = nil,
        anvilEvidence: StormSetupDTO.AnvilEvidence?
    ) -> StormSetupDTO {
        StormSetupDTO(
            h3Cell: 8_623_451_234_567_890,
            freshness: .init(
                isStale: isStale,
                isDegraded: isDegraded,
                modelRunTime: skyAwareDate("2026-06-01T18:00:00Z"),
                sourceValidTime: skyAwareDate("2026-06-01T21:00:00Z"),
                forecastHour: 3,
                fetchedAt: skyAwareDate("2026-06-01T21:03:00Z"),
                expiresAt: skyAwareDate("2026-06-01T22:00:00Z")
            ),
            source: .init(
                model: "HRRR",
                product: "Storm Setup",
                domain: "severe",
                fieldSetVersion: "1",
                sourceKind: "production",
                runTime: skyAwareDate("2026-06-01T18:00:00Z"),
                validTime: skyAwareDate("2026-06-01T21:00:00Z"),
                forecastHour: 3,
                bbox: .init(toplat: 41.5, leftlon: -104.3, rightlon: -96.2, bottomlat: 36.8),
                primaryDownloadURL: "https://example.invalid/storm-setup"
            ),
            raw: rawOverrides ?? .init(
                mlcapeJkg: 1_850,
                mucapeJkg: 2_200.5,
                sbcapeJkg: 1_700,
                mlcinJkg: -42,
                srh01kmM2s2: 125.5,
                srh03kmM2s2: 175,
                shear06kmKt: 42,
                mllclM: 980,
                tempDewPtDeltaF: 4.5,
                threeCapeJkg: 95
            ),
            assessment: .init(
                overall: overall,
                summary: summary,
                instability: "supportive",
                moisture: "supportive",
                lowLevelRotation: "conditional",
                deepShear: "strong",
                cloudBase: "supportive",
                capInhibition: "weak",
                limitingFactors: ["capping"],
                confidence: "high",
                primaryDrivers: ["instability", "shear"],
                stormMode: "supportive",
                stormModeHint: "supportive",
                trend: "conditional",
                compositeSignal: "strong"
            ),
            anvilEvidence: anvilEvidence,
            centroid: .init(latitude: 39.5, longitude: -100.0),
            surfaceHeightMslM: 1132.4
        )
    }
}

private func skyAwareDate(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)!
}
