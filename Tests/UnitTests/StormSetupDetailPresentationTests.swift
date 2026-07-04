#if canImport(Testing)
import Foundation
import Testing
@testable import SkyAware

@Suite("Storm Setup Detail Presentation")
struct StormSetupDetailPresentationTests {
    @Test("readable content is ordered and cleaned")
    func readableContentIsOrderedAndCleaned() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(
                summary: "  Strongly supportive guidance.  ",
                overall: "strong",
                instability: "supportive",
                moisture: "unknown",
                lowLevelRotation: "conditional",
                deepShear: "strong",
                cloudBase: "weak",
                capInhibition: "weak",
                limitingFactors: ["", "  ", "capping"],
                primaryDrivers: ["", "shear"],
                confidence: "unknown"
            ),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.assessmentTitle == "Strong Setup")
        #expect(presentation.summaryText == "Strongly supportive guidance.")
        #expect(presentation.confidenceText == nil)
        #expect(presentation.ingredientRows.map(\.title) == [
            "Instability",
            "Moisture",
            "Low-level rotation",
            "Deep shear",
            "Cloud bases",
            "Cap / inhibition"
        ])
        #expect(presentation.ingredientRows.map(\.value) == [
            "Supportive",
            "Unavailable",
            "Conditional",
            "Strong",
            "High",
            "Weak"
        ])
        #expect(presentation.limitingFactors == ["capping"])
        #expect(presentation.primaryDrivers == ["shear"])
    }

    @Test("metadata formatting respects UTC run time and local valid time")
    func metadataFormattingRespectsUTCAndLocalTime() {
        let mountainTime = TimeZone(identifier: "America/Denver")!
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(
                modelRunTime: date("2026-06-01T17:00:00Z"),
                validTime: date("2026-06-01T18:00:00Z"),
                fetchedAt: date("2026-06-01T18:41:00Z"),
                forecastHour: 1
            ),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: mountainTime,
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.provenanceHeadline == "HRRR forecast model · 17Z run · f01 · valid 12 PM MDT")
        #expect(presentation.updatedText == "Updated 12:41 PM")
        #expect(presentation.freshnessText == nil)
    }

    @Test("cross-day metadata includes a date and forecast hours pad correctly")
    func crossDayMetadataIncludesDateAndPadsForecastHours() {
        let timeZone = TimeZone(identifier: "America/Denver")!
        let oneHour = StormSetupDetailPresentation(
            dto: makeDTO(forecastHour: 1, validTime: date("2026-06-01T18:00:00Z")),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: timeZone,
            now: date("2026-06-02T18:00:00Z")
        )
        let twelveHours = StormSetupDetailPresentation(
            dto: makeDTO(forecastHour: 12, validTime: date("2026-06-01T18:00:00Z")),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: timeZone,
            now: date("2026-06-02T18:00:00Z")
        )
        let hundredHours = StormSetupDetailPresentation(
            dto: makeDTO(forecastHour: 100, validTime: date("2026-06-01T18:00:00Z")),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: timeZone,
            now: date("2026-06-02T18:00:00Z")
        )

        #expect(oneHour.provenanceHeadline.contains("f01"))
        #expect(twelveHours.provenanceHeadline.contains("f12"))
        #expect(hundredHours.provenanceHeadline.contains("f100"))
        #expect(oneHour.provenanceHeadline.contains("Jun 1"))
        #expect(oneHour.updatedText.contains("Jun 1"))
    }

    @Test("freshness states remain explicit")
    func freshnessStatesRemainExplicit() {
        let stale = StormSetupDetailPresentation(
            dto: makeDTO(isStale: true, isDegraded: false),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T19:00:00Z")
        )
        let degraded = StormSetupDetailPresentation(
            dto: makeDTO(isStale: false, isDegraded: true),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T19:00:00Z")
        )
        let combined = StormSetupDetailPresentation(
            dto: makeDTO(isStale: true, isDegraded: true),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(stale.freshnessText == "Guidance may be out of date.")
        #expect(degraded.freshnessText == "Some guidance details are limited.")
        #expect(combined.freshnessText == "Guidance may be out of date and some details are limited.")
    }

    @Test("advanced rows obey effective gating and preserve meaningful zeros")
    func advancedRowsObeyGatingAndPreserveZeros() {
        let gatedOff = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T19:00:00Z")
        )
        let storedButDisabled = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: false, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T19:00:00Z")
        )
        let enabled = StormSetupDetailPresentation(
            dto: makeDTO(
                raw: .init(
                    mlcapeJkg: 1_850,
                    mucapeJkg: 0,
                    sbcapeJkg: .nan,
                    mlcinJkg: -42,
                    srh01kmM2s2: nil,
                    srh03kmM2s2: 0,
                    shear06kmKt: 31.2,
                    mllclM: .infinity,
                    tempDewPtDeltaF: 4,
                    threeCapeJkg: 95
                ),
                anvilEvidence: .init(
                    status: "available",
                    scp: .init(support: "supportive"),
                    stp: .init(support: "conditional"),
                    ship: .init(support: "weak"),
                    diagnostics: .init(
                        hasEffectiveLayer: true,
                        hasStormMotion: nil,
                        qualityProfileLevelCount: 3,
                        warnings: ["pressure-level diagnostics trimmed"]
                    )
                )
            ),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(gatedOff.advancedRows.isEmpty)
        #expect(storedButDisabled.advancedRows.isEmpty)
        #expect(enabled.advancedRows.map(\.title) == [
            "MLCAPE — J/kg",
            "MUCAPE — J/kg",
            "MLCIN — J/kg",
            "0–3 km SRH — m²/s²",
            "0–6 km shear — kt",
            "Temperature/dew-point spread — °F",
            "0–3 km CAPE / 3CAPE — J/kg",
            "SCP signal",
            "STP signal",
            "SHIP signal",
            "Effective layer available",
            "Profile level count"
        ])
        #expect(enabled.advancedRows.map(\.value) == [
            "1,850",
            "0",
            "-42",
            "0",
            "31",
            "4",
            "95",
            "Supportive",
            "Conditional",
            "Weak",
            "Yes",
            "3"
        ])
        #expect(enabled.diagnosticsNoteText == "Some advanced diagnostics are limited.")
    }

    @Test("presentation omits raw transport details and warning strings")
    func presentationOmitsRawTransportDetails() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(
                sourceKind: "dev",
                primaryDownloadURL: "https://example.invalid/storm-setup",
                anvilEvidence: .init(
                    status: "available",
                    scp: nil,
                    stp: nil,
                    ship: nil,
                    diagnostics: .init(
                        hasEffectiveLayer: nil,
                        hasStormMotion: nil,
                        qualityProfileLevelCount: nil,
                        warnings: ["pressure-level diagnostics trimmed"]
                    )
                )
            ),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.provenanceHeadline.contains("https://") == false)
        #expect(presentation.provenanceHeadline.contains("dev") == false)
        #expect(presentation.modelGuidanceBody.contains("https://") == false)
        #expect(presentation.diagnosticsNoteText == "Some advanced diagnostics are limited.")
        #expect(presentation.diagnosticsNoteText?.contains("pressure-level diagnostics trimmed") == false)
    }

    @Test("missing anvil evidence does not change readable rows")
    func missingAnvilEvidenceDoesNotChangeReadableRows() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(anvilEvidence: nil),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.ingredientRows.count == 6)
        #expect(presentation.advancedRows.isEmpty == false)
        #expect(presentation.advancedRows.contains(where: { $0.title == "SCP signal" }) == false)
    }
}

private func makeDTO(
    summary: String? = "The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation.",
    overall: String = "strong",
    instability: String = "supportive",
    moisture: String = "supportive",
    lowLevelRotation: String = "conditional",
    deepShear: String = "strong",
    cloudBase: String = "weak",
    capInhibition: String = "weak",
    limitingFactors: [String] = ["capping"],
    primaryDrivers: [String] = ["instability", "shear"],
    confidence: String = "high",
    modelRunTime: Date = date("2026-06-01T17:00:00Z"),
    validTime: Date = date("2026-06-01T18:00:00Z"),
    fetchedAt: Date = date("2026-06-01T18:41:00Z"),
    forecastHour: Int = 3,
    isStale: Bool = false,
    isDegraded: Bool = false,
    raw: StormSetupDTO.Raw = .init(
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
    sourceKind: String = "production",
    primaryDownloadURL: String? = "https://example.invalid/storm-setup",
    anvilEvidence: StormSetupDTO.AnvilEvidence? = nil
) -> StormSetupDTO {
    StormSetupDTO(
        h3Cell: 8_623_451_234_567_890,
        freshness: .init(
            isStale: isStale,
            isDegraded: isDegraded,
            modelRunTime: modelRunTime,
            sourceValidTime: validTime,
            forecastHour: forecastHour,
            fetchedAt: fetchedAt,
            expiresAt: date("2026-06-01T22:00:00Z")
        ),
        source: .init(
            model: "HRRR",
            product: "Storm Setup",
            domain: "severe",
            fieldSetVersion: "1",
            sourceKind: sourceKind,
            runTime: modelRunTime,
            validTime: validTime,
            forecastHour: forecastHour,
            bbox: .init(toplat: 41.5, leftlon: -104.3, rightlon: -96.2, bottomlat: 36.8),
            primaryDownloadURL: primaryDownloadURL
        ),
        raw: raw,
        assessment: .init(
            overall: overall,
            summary: summary,
            instability: instability,
            moisture: moisture,
            lowLevelRotation: lowLevelRotation,
            deepShear: deepShear,
            cloudBase: cloudBase,
            capInhibition: capInhibition,
            limitingFactors: limitingFactors,
            confidence: confidence,
            primaryDrivers: primaryDrivers,
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

private func date(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)!
}
#endif
