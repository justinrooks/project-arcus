#if canImport(Testing)
import Foundation
import Testing
@testable import SkyAware

@Suite("Storm Setup Presentation")
struct StormSetupPresentationTests {
    @Test("maps signals to readable ingredient text")
    func mapsSignalsToReadableIngredientText() {
        let presentation = StormSetupSummaryPresentation(
            dto: makeDTO(
                overall: "strong",
                instability: "supportive",
                rotation: "conditional",
                cloudBase: "strong"
            ),
            timeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T18:00:00Z")
        )

        #expect(presentation.overallTitle == "Strong Setup")
        #expect(presentation.ingredientRows.map(\.title) == ["Instability", "Rotation", "Cloud bases"])
        #expect(presentation.ingredientRows.map(\.value) == ["Supportive", "Conditional", "Low"])
    }

    @Test("unknown values become unavailable")
    func unknownValuesBecomeUnavailable() {
        let presentation = StormSetupSummaryPresentation(
            dto: makeDTO(
                overall: "unknown",
                instability: "unknown",
                rotation: "unknown",
                cloudBase: "unknown"
            ),
            timeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T18:00:00Z")
        )

        #expect(presentation.overallTitle == "Unavailable")
        #expect(presentation.ingredientRows.map(\.value) == ["Unavailable", "Unavailable", "Unavailable"])
    }

    @Test("limiter selection skips blank entries")
    func limiterSelection_skipsBlankEntries() {
        let presentation = StormSetupSummaryPresentation(
            dto: makeDTO(
                limitingFactors: ["", "   ", "capping", "shear"]
            ),
            timeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T18:00:00Z")
        )

        #expect(presentation.limiterText == "capping")
    }

    @Test("source line uses the forecast-location time zone")
    func sourceLine_usesForecastLocationTimeZone() {
        let timeZone = TimeZone(identifier: "America/Denver")!
        let presentation = StormSetupSummaryPresentation(
            dto: makeDTO(validTime: date("2026-06-01T18:00:00Z")),
            timeZone: timeZone,
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(
            presentation.sourceLine.replacingOccurrences(of: "\u{202F}", with: " ")
                == "HRRR guidance · valid near 12 PM"
        )
    }

    @Test("freshness copy stays calm for stale degraded and combined guidance")
    func freshnessCopy_staysCalm() {
        let stale = StormSetupSummaryPresentation(
            dto: makeDTO(isStale: true, isDegraded: false),
            timeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T18:00:00Z")
        )
        let degraded = StormSetupSummaryPresentation(
            dto: makeDTO(isStale: false, isDegraded: true),
            timeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T18:00:00Z")
        )
        let combined = StormSetupSummaryPresentation(
            dto: makeDTO(isStale: true, isDegraded: true),
            timeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T18:00:00Z")
        )

        #expect(stale.freshnessText == "Guidance may be out of date.")
        #expect(degraded.freshnessText == "Some guidance details are limited.")
        #expect(combined.freshnessText == "Guidance may be out of date and some details are limited.")
    }

    @Test("presentation output omits raw transport details")
    func presentation_outputOmitsRawTransportDetails() {
        let presentation = StormSetupSummaryPresentation(
            dto: makeDTO(),
            timeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T18:00:00Z")
        )

        #expect(presentation.summaryProse?.contains("https://") == false)
        #expect(presentation.sourceLine.contains("https://") == false)
        #expect(presentation.sourceLine.contains("fieldSetVersion") == false)
        #expect(presentation.accessibilityValue.contains("debug") == false)
        #expect(presentation.accessibilityValue.contains("https://") == false)
    }

    @Test("summary card puts the overall assessment before fallback prose")
    @MainActor
    func summaryCard_putsOverallAssessmentBeforeFallbackProse() {
        let presentation = StormSetupSummaryPresentation(
            dto: makeDTO(
                summary: nil,
                overall: "weak",
                instability: "supportive",
                rotation: "supportive",
                cloudBase: "strong"
            ),
            timeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T18:00:00Z")
        )

        #expect(StormSetupSummaryCard.summaryCopyLines(for: presentation) == [
            "Weak Setup",
            "Guidance summary unavailable."
        ])
    }
}

private func makeDTO(
    summary: String? = "The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation.",
    overall: String = "strong",
    instability: String = "supportive",
    rotation: String = "conditional",
    cloudBase: String = "strong",
    limitingFactors: [String] = ["capping"],
    validTime: Date = date("2026-06-01T21:00:00Z"),
    isStale: Bool = false,
    isDegraded: Bool = false
) -> StormSetupDTO {
    StormSetupDTO(
        h3Cell: 8_623_451_234_567_890,
        freshness: .init(
            isStale: isStale,
            isDegraded: isDegraded,
            modelRunTime: date("2026-06-01T18:00:00Z"),
            sourceValidTime: validTime,
            forecastHour: 3,
            fetchedAt: date("2026-06-01T21:03:00Z"),
            expiresAt: date("2026-06-01T22:00:00Z")
        ),
        source: .init(
            model: "HRRR",
            product: "Storm Setup",
            domain: "severe",
            fieldSetVersion: "1",
            sourceKind: "production",
            runTime: date("2026-06-01T18:00:00Z"),
            validTime: validTime,
            forecastHour: 3,
            bbox: .init(toplat: 41.5, leftlon: -104.3, rightlon: -96.2, bottomlat: 36.8),
            primaryDownloadURL: "https://example.invalid/storm-setup"
        ),
        raw: .init(
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

private func date(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)!
}
#endif
