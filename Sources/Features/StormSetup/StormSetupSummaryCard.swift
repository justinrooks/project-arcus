//
//  StormSetupSummaryCard.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI

struct StormSetupSummaryCard: View {
    let presentation: StormSetupSummaryPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Text(presentation.overallTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let summaryProse = presentation.summaryProse {
                Text(summaryProse)
                    .font(.subheadline)
                    .todaySupportingText()
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Guidance summary unavailable.")
                    .font(.subheadline)
                    .todaySupportingText()
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let freshnessText = presentation.freshnessText {
                Text(freshnessText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .todayCardBackground(cornerRadius: SkyAwareRadius.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
        .accessibilityHint(presentation.accessibilityHint)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "cloud.bolt.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Storm Setup")
                .todaySectionLabel()
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
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
