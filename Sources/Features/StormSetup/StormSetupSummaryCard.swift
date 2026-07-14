//
//  StormSetupSummaryCard.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI

struct StormSetupSummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let presentation: StormSetupSummaryPresentation
    let isLoading: Bool

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
        cardContent
            .placeholder(isLoading, animated: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .cardBackground(
                cornerRadius: SkyAwareRadius.section,
                shadowOpacity: colorScheme == .dark ? 0.08 : 0.11,
                shadowRadius: colorScheme == .dark ? 8 : 10,
                shadowY: colorScheme == .dark ? 3 : 4
            )
            .animation(SkyAwareMotion.settle(reduceMotion), value: isLoading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
        .accessibilityHint(presentation.accessibilityHint)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            summaryCopy

            detailSurface
        }
    }

    private var header: some View {
        Label("Storm Setup", systemImage: "cloud.bolt.fill")
            .symbolVariant(.fill)
            .sectionLabel()
    }

    private var summaryCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(presentation.overallTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let summaryProse = presentation.summaryProse {
                Text(summaryProse)
                    .font(.body)
                    .lineSpacing(4)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Guidance summary unavailable.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var detailSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            ingredientRows
                .padding(.bottom, 6)

            if presentation.limiterText != nil || presentation.freshnessText != nil {
                Divider()
                    .overlay(colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.07))
                    .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let limiterText = presentation.limiterText {
                    Text("Limiter: \(limiterText)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let freshnessText = presentation.freshnessText {
                    Text(freshnessText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(presentation.sourceLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    init(
        presentation: StormSetupSummaryPresentation = .loadingPlaceholder,
        isLoading: Bool = false
    ) {
        self.presentation = presentation
        self.isLoading = isLoading
    }

    @ViewBuilder
    private var ingredientRows: some View {
        if adaptiveLayout.usesStackedHeroTiles {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(presentation.ingredientRows) { row in
                    stackedRow(row)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(presentation.ingredientRows) { row in
                    horizontalRow(row)
                }
            }
        }
    }

    private func horizontalRow(_ row: StormSetupSummaryPresentation.IngredientRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(row.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 10)

            Text(row.value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stackedRow(_ row: StormSetupSummaryPresentation.IngredientRow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(row.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(row.value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    static func summaryCopyLines(for presentation: StormSetupSummaryPresentation) -> [String] {
        [
            presentation.overallTitle,
            presentation.summaryProse ?? "Guidance summary unavailable."
        ]
    }
}

#Preview("Storm Setup - Supportive Light") {
    NavigationStack {
        ScrollView {
            StormSetupSummaryCard(
                presentation: StormSetupSummaryPresentation(
                    dto: StormSetupPreviewData.supportiveDTO,
                    timeZone: .current,
                    now: StormSetupPreviewData.now
                )
            )
            .padding()
        }
        .background(.skyAwareBackground)
    }
}

#Preview("Storm Setup - Loading") {
    NavigationStack {
        ScrollView {
            StormSetupSummaryCard(
                presentation: .loadingPlaceholder,
                isLoading: true
            )
            .padding()
        }
        .background(.skyAwareBackground)
    }
}

#Preview("Storm Setup - Strong Dark") {
    NavigationStack {
        ScrollView {
            StormSetupSummaryCard(
                presentation: StormSetupSummaryPresentation(
                    dto: StormSetupPreviewData.strongDTO,
                    timeZone: TimeZone(identifier: "America/Denver")!,
                    now: StormSetupPreviewData.now
                )
            )
            .preferredColorScheme(.dark)
            .padding()
        }
        .background(.skyAwareBackground)
    }
}

#Preview("Storm Setup - Stale") {
    NavigationStack {
        ScrollView {
            StormSetupSummaryCard(
                presentation: StormSetupSummaryPresentation(
                    dto: StormSetupPreviewData.staleDTO,
                    timeZone: TimeZone(identifier: "America/Denver")!,
                    now: StormSetupPreviewData.now
                )
            )
            .padding()
        }
        .background(.skyAwareBackground)
    }
}

#Preview("Storm Setup - Degraded") {
    NavigationStack {
        ScrollView {
            StormSetupSummaryCard(
                presentation: StormSetupSummaryPresentation(
                    dto: StormSetupPreviewData.degradedDTO,
                    timeZone: TimeZone(identifier: "America/Denver")!,
                    now: StormSetupPreviewData.now
                )
            )
            .preferredColorScheme(.dark)
            .padding()
        }
        .background(.skyAwareBackground)
    }
}

#Preview("Storm Setup - Limiter Absent") {
    NavigationStack {
        ScrollView {
            StormSetupSummaryCard(
                presentation: StormSetupSummaryPresentation(
                    dto: StormSetupPreviewData.limiterAbsentDTO,
                    timeZone: TimeZone(identifier: "America/Denver")!,
                    now: StormSetupPreviewData.now
                )
            )
            .padding()
        }
        .background(.skyAwareBackground)
    }
}

#Preview("Storm Setup - Unknown Ingredients") {
    NavigationStack {
        ScrollView {
            StormSetupSummaryCard(
                presentation: StormSetupSummaryPresentation(
                    dto: StormSetupPreviewData.unknownDTO,
                    timeZone: TimeZone(identifier: "America/Denver")!,
                    now: StormSetupPreviewData.now
                )
            )
            .environment(\.dynamicTypeSize, .accessibility1)
            .padding()
        }
        .background(.skyAwareBackground)
    }
}

private enum StormSetupPreviewData {
    static let now = skyAwareDate("2026-06-01T18:00:00Z")

    static let supportiveDTO = makeDTO(
        summary: "The setup is supportive and ingredients are beginning to align.",
        overall: "supportive",
        instability: "supportive",
        rotation: "supportive",
        cloudBase: "supportive",
        limitingFactors: ["capping"],
        isStale: false,
        isDegraded: false
    )

    static let strongDTO = makeDTO(
        summary: "The setup is strongly supportive.",
        overall: "strong",
        instability: "strong",
        rotation: "supportive",
        cloudBase: "strong",
        limitingFactors: [""],
        isStale: false,
        isDegraded: false
    )

    static let staleDTO = makeDTO(
        summary: "Guidance remains supportive but should be checked again.",
        overall: "supportive",
        instability: "supportive",
        rotation: "conditional",
        cloudBase: "strong",
        limitingFactors: ["capping"],
        isStale: true,
        isDegraded: false
    )

    static let degradedDTO = makeDTO(
        summary: "Some details are limited, but the setup still leans supportive.",
        overall: "strong",
        instability: "strong",
        rotation: "conditional",
        cloudBase: "supportive",
        limitingFactors: ["weak lapse rates"],
        isStale: false,
        isDegraded: true
    )

    static let limiterAbsentDTO = makeDTO(
        summary: "The setup is supportive without a clear limiter.",
        overall: "supportive",
        instability: "supportive",
        rotation: "supportive",
        cloudBase: "conditional",
        limitingFactors: [""],
        isStale: false,
        isDegraded: false
    )

    static let unknownDTO = makeDTO(
        summary: nil,
        overall: "unknown",
        instability: "unknown",
        rotation: "unknown",
        cloudBase: "unknown",
        limitingFactors: [],
        isStale: false,
        isDegraded: false
    )

    private static func makeDTO(
        summary: String?,
        overall: String,
        instability: String,
        rotation: String,
        cloudBase: String,
        limitingFactors: [String],
        isStale: Bool,
        isDegraded: Bool
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
            raw: .init(
                mlcapeJkg: 1850,
                mucapeJkg: 2200.5,
                sbcapeJkg: 1700,
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
                instability: instability,
                moisture: "supportive",
                lowLevelRotation: rotation,
                deepShear: "strong",
                cloudBase: cloudBase,
                capInhibition: "weak",
                limitingFactors: limitingFactors,
                confidence: "high",
                primaryDrivers: ["instability", "shear"],
                stormMode: "supportive",
                stormModeHint: "supportive",
                trend: "conditional",
                compositeSignal: "strong"
            ),
            anvilEvidence: nil,
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
