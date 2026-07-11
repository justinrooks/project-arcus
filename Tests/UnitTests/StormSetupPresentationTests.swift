#if canImport(Testing)
import ArcusCore
import Foundation
import Testing
@testable import SkyAware

@Suite("Storm Setup Presentation")
struct StormSetupPresentationTests {
    @Test("ArcusCore support values and limiter copy render cleanly")
    func arcusCoreSupportValuesAndLimiterCopyRenderCleanly() {
        let presentation = StormSetupSummaryPresentation(
            response: makeCurrentResponse(
                tornadoViability: .init(
                    overall: .supportive,
                    realization: .realized,
                    primaryFailureMode: .none,
                    confidence: .moderate,
                    summary: "Supportive setup.",
                    details: .init(
                        stormViability: .supportive,
                        supercellViability: .strong,
                        tornadoEfficiency: .supportive,
                        inhibition: .weak,
                        instability: .supportive,
                        moisture: .strong,
                        cloudBase: .weak,
                        deepShear: .strong,
                        lowLevelRotation: .conditional,
                        lowLevelStretching: .supportive,
                        cloudBaseEfficiency: .supportive,
                        supercellComposite: .strong,
                        tornadoComposite: .supportive,
                        stormMode: .conditional
                    ),
                    limitingFactors: [.strongCap, .poorMoisture]
                )
            ),
            timeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T18:00:00Z")
        )

        #expect(presentation.overallTitle == "Supportive Setup")
        #expect(presentation.ingredientRows.map(\.value) == ["Supportive", "Conditional", "High"])
        #expect(presentation.limiterText == "Strong cap")
        #expect(presentation.accessibilityValue.contains("Strong cap"))
    }

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

    @Test("source line keeps useful guidance when model metadata is missing")
    func sourceLine_keepsUsefulGuidanceWhenModelMetadataIsMissing() {
        let timeZone = TimeZone(identifier: "America/Denver")!
        let presentation = StormSetupSummaryPresentation(
            dto: makeDTO(
                validTime: date("2026-06-01T18:00:00Z"),
                model: nil
            ),
            timeZone: timeZone,
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(
            presentation.sourceLine.replacingOccurrences(of: "\u{202F}", with: " ")
                == "Guidance · valid near 12 PM"
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

private func makeCurrentResponse(
    setup: StormSetupCurrentSetupResponse = .init(
        h3Cell: 8_623_451_234_567_890,
        centroid: .init(latitude: 39.5, longitude: -100.0),
        source: .init(
            model: .hrrr,
            product: .wrfsfc,
            domain: .conus,
            runTime: date("2026-06-01T18:00:00Z"),
            forecastHour: 3,
            validTime: date("2026-06-01T21:00:00Z"),
            fieldSetVersion: .tornadoV1,
            bbox: .init(leftlon: -104.3, rightlon: -96.2, toplat: 41.5, bottomlat: 36.8),
            primaryDownloadURL: URL(string: "https://example.invalid/storm-setup"),
            idxURL: nil
        ),
        surfaceHeightMslM: 1132.4,
        freshness: .init(
            sourceValidTime: date("2026-06-01T21:00:00Z"),
            modelRunTime: date("2026-06-01T18:00:00Z"),
            forecastHour: 3,
            fetchedAt: date("2026-06-01T21:03:00Z"),
            expiresAt: date("2026-06-01T22:30:00Z"),
            isStale: false,
            isDegraded: false
        )
    ),
    ingredients: StormSetupTornadoIngredientsResponse = .init(
        canonical: .init(
            sbcapeJkg: 1_700,
            mlcapeJkg: 1_850,
            mucapeJkg: 2_200.5,
            mlcinJkg: -42,
            dcapeJkg: nil,
            mllclM: 980,
            tempDewPtDeltaF: 4.5,
            threeCapeJkg: 95,
            lclLfcSeparationM: nil,
            lapseRate03kmCkm: nil,
            lapseRate700500mbCkm: nil,
            shear06kmKt: 42,
            shear03kmKt: 31,
            shear01kmKt: 18,
            effectiveShearKt: nil,
            srh01kmM2s2: 125.5,
            srh03kmM2s2: 175,
            effectiveSrhM2s2: nil,
            supercellComposite: nil,
            significantTornadoFixed: nil,
            significantTornadoEffective: nil,
            significantHail: nil,
            bunkersRightMotion: nil,
            bunkersLeftMotion: nil,
            stormRelativeWind46km: nil,
            meanWind850300mb: nil,
            diagnostics: nil,
            effectiveBulkShearMs: nil,
            effectiveLayer: nil,
            stormMotion: nil
        ),
        diagnostics: .empty
    ),
    profileAnalysis: AnvilAnalyzeProfileResponse? = .init(
        effectiveLayer: .init(
            status: "found",
            basePressureMb: 915,
            topPressureMb: 750,
            baseMetersAgl: 850,
            topMetersAgl: 1_800
        ),
        stormMotion: .init(
            status: "found",
            bunkersRight: .init(
                uKt: 12.0,
                vKt: -8.0,
                speedKt: 18.0,
                directionTowardDeg: 215.0,
                uMs: 6.2,
                vMs: -4.1,
                speedMs: 9.2
            )
        ),
        mucape: 2_200.5,
        mlcape: 1_850,
        mlcin: -42,
        mllclMetersAgl: 980,
        effectiveSrh: 135,
        effectiveBulkShearMs: 24.5,
        scp: 0.7,
        stpCin: 0.9,
        stpFixed: 1.2,
        ship: 2.1,
        srh01km: nil,
        srh03km: nil,
        sbcape: nil,
        sbcin: nil,
        bulkShear06kmMs: nil,
        lapserate03km: nil,
        threeCapeJkg: nil,
        quality: .init(profileLevelCount: 36, warnings: [])
    ),
    tornadoViability: TornadoViabilityReport = .init(
        overall: .supportive,
        realization: .realized,
        primaryFailureMode: .none,
        confidence: .moderate,
        summary: "Supportive setup.",
        details: .init(
            stormViability: .supportive,
            supercellViability: .strong,
            tornadoEfficiency: .supportive,
            inhibition: .weak,
            instability: .supportive,
            moisture: .strong,
            cloudBase: .weak,
            deepShear: .strong,
            lowLevelRotation: .conditional,
            lowLevelStretching: .supportive,
            cloudBaseEfficiency: .supportive,
            supercellComposite: .strong,
            tornadoComposite: .supportive,
            stormMode: .conditional
        ),
        limitingFactors: [.strongCap, .poorMoisture]
    )
) -> StormSetupCurrentResponse {
    .init(setup: setup, ingredients: ingredients, profileAnalysis: profileAnalysis, tornadoViability: tornadoViability)
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
    isDegraded: Bool = false,
    model: String? = "HRRR",
    sourceValidTime: Date? = nil,
    runTime: Date? = date("2026-06-01T18:00:00Z"),
    forecastHour: Int? = 3,
    fieldSetVersion: String? = "1",
    bbox: StormSetupDTO.Bbox? = .init(toplat: 41.5, leftlon: -104.3, rightlon: -96.2, bottomlat: 36.8),
    surfaceHeightMslM: Double? = 1132.4
) -> StormSetupDTO {
    StormSetupDTO(
        h3Cell: 8_623_451_234_567_890,
        freshness: .init(
            isStale: isStale,
            isDegraded: isDegraded,
            modelRunTime: runTime,
            sourceValidTime: sourceValidTime ?? validTime,
            forecastHour: forecastHour,
            fetchedAt: date("2026-06-01T21:03:00Z"),
            expiresAt: date("2026-06-01T22:00:00Z")
        ),
        source: .init(
            model: model,
            product: "Storm Setup",
            domain: "severe",
            fieldSetVersion: fieldSetVersion,
            sourceKind: "production",
            runTime: runTime,
            validTime: validTime,
            forecastHour: forecastHour,
            bbox: bbox,
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
        surfaceHeightMslM: surfaceHeightMslM
    )
}

private func date(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)!
}
#endif
