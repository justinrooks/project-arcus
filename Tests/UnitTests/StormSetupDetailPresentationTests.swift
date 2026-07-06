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
                modelRunTime: date("2026-07-01T17:00:00Z"),
                validTime: date("2026-07-01T18:00:00Z"),
                fetchedAt: date("2026-07-01T18:41:00Z"),
                forecastHour: 1
            ),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: mountainTime,
            now: date("2026-07-01T19:00:00Z")
        )

        #expect(
            presentation.provenanceHeadline.replacingOccurrences(of: "\u{202F}", with: " ")
                == "HRRR forecast model · 17Z run · f01 · valid 12 PM MDT"
        )
        #expect(
            presentation.updatedText.replacingOccurrences(of: "\u{202F}", with: " ")
                == "Updated 12:41 PM"
        )
        #expect(presentation.freshnessText == nil)
    }

    @Test("provenance headline keeps available guidance timing when source metadata is missing")
    func provenanceHeadline_keepsAvailableGuidanceTimingWhenSourceMetadataIsMissing() {
        let mountainTime = TimeZone(identifier: "America/Denver")!
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(
                modelRunTime: nil,
                validTime: date("2026-07-01T18:00:00Z"),
                forecastHour: nil,
                model: nil
            ),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: mountainTime,
            now: date("2026-07-01T19:00:00Z")
        )

        #expect(
            presentation.provenanceHeadline.replacingOccurrences(of: "\u{202F}", with: " ")
                == "Forecast · valid 12 PM MDT"
        )
    }

    @Test("cross-day metadata includes a date and forecast hours pad correctly")
    func crossDayMetadataIncludesDateAndPadsForecastHours() {
        let timeZone = TimeZone(identifier: "America/Denver")!
        let oneHour = StormSetupDetailPresentation(
            dto: makeDTO(validTime: date("2026-06-01T18:00:00Z"), forecastHour: 1),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: timeZone,
            now: date("2026-06-02T18:00:00Z")
        )
        let twelveHours = StormSetupDetailPresentation(
            dto: makeDTO(validTime: date("2026-06-01T18:00:00Z"), forecastHour: 12),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: timeZone,
            now: date("2026-06-02T18:00:00Z")
        )
        let hundredHours = StormSetupDetailPresentation(
            dto: makeDTO(validTime: date("2026-06-01T18:00:00Z"), forecastHour: 100),
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

    @Test("enabled Detailed Ingredients retains the supplied profile analysis response")
    func enabledDetailedIngredientsRetainsSuppliedProfileAnalysisResponse() {
        let response = makeProfileAnalysisResponse()
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: response,
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisResponse == response)
    }

    @Test("disabled Detailed Ingredients suppresses the supplied profile analysis response")
    func disabledDetailedIngredientsSuppressesSuppliedProfileAnalysisResponse() {
        let response = makeProfileAnalysisResponse()
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: response,
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisResponse == nil)
    }

    @Test("summary presentation is identical with and without supplemental data")
    func summaryPresentationIsIdenticalWithAndWithoutSupplementalData() {
        let response = makeProfileAnalysisResponse()
        let withoutSupplementalData = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T19:00:00Z")
        )
        let withSupplementalData = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: response,
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(withoutSupplementalData.summaryPresentation == withSupplementalData.summaryPresentation)
        #expect(withoutSupplementalData.ingredientRows == withSupplementalData.ingredientRows)
        #expect(withoutSupplementalData.advancedRows == withSupplementalData.advancedRows)
    }

    @Test("profile analysis is suppressed when Detailed Ingredients are disabled")
    func profileAnalysisIsSuppressedWhenDetailedIngredientsAreDisabled() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.isEmpty)
        #expect(presentation.profileAnalysisNoteText == nil)
    }

    @Test("missing profile analysis response yields no section")
    func missingProfileAnalysisResponseYieldsNoSection() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.isEmpty)
        #expect(presentation.profileAnalysisNoteText == nil)
    }

    @Test("rich profile analysis rows are ordered and formatted")
    func richProfileAnalysisRowsAreOrderedAndFormatted() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.map(\.title) == [
            "SCP",
            "STP — fixed",
            "STP — CIN-adjusted",
            "SHIP",
            "Effective SRH — m²/s²",
            "Effective bulk shear — m/s",
            "Effective layer height bounds",
            "Effective layer pressure bounds",
            "Bunkers-right storm motion"
        ])
        #expect(presentation.profileAnalysisRows.map(\.value) == [
            "0.7",
            "1.2",
            "0.9",
            "2.1",
            "135",
            "24.5",
            "850–1,800 m AGL",
            "915–750 mb",
            "18 kt toward 215°"
        ])
        #expect(presentation.profileAnalysisNoteText == "Some profile details are limited.")
    }

    @Test("sparse profile analysis keeps only displayable values")
    func sparseProfileAnalysisKeepsOnlyDisplayableValues() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                scp: nil,
                stpFixed: nil,
                stpCin: 0.25,
                ship: nil,
                effectiveSrh: nil,
                effectiveBulkShearMs: 11.2,
                effectiveLayer: .init(
                    status: "found",
                    basePressureMb: nil,
                    topPressureMb: 775,
                    baseMetersAgl: nil,
                    topMetersAgl: 1_721
                ),
                stormMotion: .init(
                    status: "found",
                    bunkersRight: .init(
                        uMs: nil,
                        vMs: nil,
                        speedMs: nil,
                        uKt: nil,
                        vKt: nil,
                        speedKt: 28.2,
                        directionTowardDeg: nil
                    ),
                    uMs: 1,
                    vMs: 1,
                    speedMs: 1,
                    uKt: 1,
                    vKt: 1,
                    speedKt: 1,
                    directionTowardDeg: 1
                ),
                quality: .init(profileLevelCount: nil, warnings: nil)
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.map(\.title) == [
            "STP — CIN-adjusted",
            "Effective bulk shear — m/s",
            "Effective layer height top",
            "Effective layer pressure top",
            "Bunkers-right storm motion speed"
        ])
        #expect(presentation.profileAnalysisRows.map(\.value) == [
            "0.3",
            "11.2",
            "1,721 m AGL",
            "775 mb",
            "28 kt"
        ])
    }

    @Test("missing profile analysis fields are omitted independently")
    func missingProfileAnalysisFieldsAreOmittedIndependently() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                scp: 0.6,
                stpFixed: nil,
                stpCin: 0.4,
                ship: nil,
                effectiveSrh: 101,
                effectiveBulkShearMs: nil,
                effectiveLayer: nil,
                stormMotion: nil,
                quality: .init(profileLevelCount: nil, warnings: nil)
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.map(\.title) == [
            "SCP",
            "STP — CIN-adjusted",
            "Effective SRH — m²/s²"
        ])
        #expect(presentation.profileAnalysisRows.map(\.value) == [
            "0.6",
            "0.4",
            "101"
        ])
    }

    @Test("meaningful zeros are preserved")
    func meaningfulZerosArePreserved() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                scp: 0,
                stpFixed: 0,
                stpCin: 0,
                ship: 0,
                effectiveSrh: 0,
                effectiveBulkShearMs: 0,
                effectiveLayer: .init(
                    status: "found",
                    basePressureMb: 0,
                    topPressureMb: 0,
                    baseMetersAgl: 0,
                    topMetersAgl: 0
                ),
                stormMotion: .init(
                    status: "found",
                    bunkersRight: .init(
                        uMs: nil,
                        vMs: nil,
                        speedMs: nil,
                        uKt: nil,
                        vKt: nil,
                        speedKt: 0,
                        directionTowardDeg: 0
                    ),
                    uMs: nil,
                    vMs: nil,
                    speedMs: nil,
                    uKt: nil,
                    vKt: nil,
                    speedKt: nil,
                    directionTowardDeg: nil
                ),
                quality: .init(profileLevelCount: nil, warnings: nil)
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.map(\.value) == [
            "0",
            "0",
            "0",
            "0",
            "0",
            "0",
            "0–0 m AGL",
            "0–0 mb",
            "0 kt toward 0°"
        ])
    }

    @Test("negative zero is normalized to zero")
    func negativeZeroIsNormalizedToZero() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                scp: -0.0,
                stpFixed: -0.0,
                stpCin: -0.0,
                ship: -0.0,
                effectiveSrh: -0.0,
                effectiveBulkShearMs: -0.0,
                effectiveLayer: .init(
                    status: "found",
                    basePressureMb: -0.0,
                    topPressureMb: -0.0,
                    baseMetersAgl: -0.0,
                    topMetersAgl: -0.0
                ),
                stormMotion: .init(
                    status: "found",
                    bunkersRight: .init(
                        uMs: nil,
                        vMs: nil,
                        speedMs: nil,
                        uKt: nil,
                        vKt: nil,
                        speedKt: -0.0,
                        directionTowardDeg: -0.0
                    ),
                    uMs: nil,
                    vMs: nil,
                    speedMs: nil,
                    uKt: nil,
                    vKt: nil,
                    speedKt: nil,
                    directionTowardDeg: nil
                ),
                quality: .init(profileLevelCount: nil, warnings: nil)
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.allSatisfy { $0.value.contains("-0") == false })
    }

    @Test("non-finite values are omitted")
    func nonFiniteValuesAreOmitted() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                scp: .nan,
                stpFixed: .infinity,
                stpCin: -.infinity,
                ship: nil,
                effectiveSrh: .nan,
                effectiveBulkShearMs: .infinity,
                effectiveLayer: .init(
                    status: "found",
                    basePressureMb: .nan,
                    topPressureMb: .infinity,
                    baseMetersAgl: -.infinity,
                    topMetersAgl: nil
                ),
                stormMotion: .init(
                    status: "found",
                    bunkersRight: .init(
                        uMs: nil,
                        vMs: nil,
                        speedMs: nil,
                        uKt: nil,
                        vKt: nil,
                        speedKt: .nan,
                        directionTowardDeg: .infinity
                    ),
                    uMs: nil,
                    vMs: nil,
                    speedMs: nil,
                    uKt: nil,
                    vKt: nil,
                    speedKt: nil,
                    directionTowardDeg: nil
                ),
                quality: .init(profileLevelCount: nil, warnings: nil)
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.isEmpty)
    }

    @Test("tiny nonzero composite remains visibly nonzero")
    func tinyNonzeroCompositeRemainsVisiblyNonzero() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(scp: 0.04),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.first?.value != "0")
        #expect(presentation.profileAnalysisRows.first?.value == "0.04")
    }

    @Test("fixed and CIN-adjusted STP rows use distinct labels")
    func fixedAndCinAdjustedSTPRowsUseDistinctLabels() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.map(\.title).contains("STP — fixed"))
        #expect(presentation.profileAnalysisRows.map(\.title).contains("STP — CIN-adjusted"))
    }

    @Test("complete effective layer bounds render compact ranges")
    func completeEffectiveLayerBoundsRenderCompactRanges() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                effectiveLayer: .init(
                    status: "found",
                    basePressureMb: 946,
                    topPressureMb: 775,
                    baseMetersAgl: 0,
                    topMetersAgl: 1_721
                )
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.contains(where: { $0.title == "Effective layer height bounds" && $0.value == "0–1,721 m AGL" }))
        #expect(presentation.profileAnalysisRows.contains(where: { $0.title == "Effective layer pressure bounds" && $0.value == "946–775 mb" }))
    }

    @Test("partial effective layer bounds are labeled explicitly")
    func partialEffectiveLayerBoundsAreLabeledExplicitly() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                effectiveLayer: .init(
                    status: "found",
                    basePressureMb: nil,
                    topPressureMb: 775,
                    baseMetersAgl: 0,
                    topMetersAgl: nil
                )
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.map(\.title) == [
            "SCP",
            "STP — fixed",
            "STP — CIN-adjusted",
            "SHIP",
            "Effective SRH — m²/s²",
            "Effective bulk shear — m/s",
            "Effective layer height base",
            "Effective layer pressure top",
            "Bunkers-right storm motion"
        ])
    }

    @Test("notFound effective layer uses a calm fallback row")
    func notFoundEffectiveLayerUsesCalmFallbackRow() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                scp: nil,
                stpFixed: nil,
                stpCin: nil,
                ship: nil,
                effectiveSrh: nil,
                effectiveBulkShearMs: nil,
                effectiveLayer: .init(
                    status: "notFound",
                    basePressureMb: nil,
                    topPressureMb: nil,
                    baseMetersAgl: nil,
                    topMetersAgl: nil
                ),
                stormMotion: nil,
                quality: .init(profileLevelCount: nil, warnings: nil)
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows == [
            .init(
                title: "Effective layer",
                value: "Not identified",
                accessibilityLabel: "Effective layer. Not identified."
            )
        ])
    }

    @Test("unknown effective-layer status is not displayed verbatim")
    func unknownEffectiveLayerStatusIsNotDisplayedVerbatim() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                effectiveLayer: .init(
                    status: "mystery",
                    basePressureMb: 946,
                    topPressureMb: 775,
                    baseMetersAgl: 0,
                    topMetersAgl: 1_721
                )
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.map(\.title).contains("Effective layer") == false)
        #expect(presentation.profileAnalysisRows.map(\.value).contains("mystery") == false)
    }

    @Test("complete Bunkers-right motion renders speed and direction together")
    func completeBunkersRightMotionRendersSpeedAndDirectionTogether() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                stormMotion: .init(
                    status: "found",
                    bunkersRight: .init(
                        uMs: 8.4,
                        vMs: -4.2,
                        speedMs: 9.4,
                        uKt: 16.3,
                        vKt: -8.2,
                        speedKt: 18.3,
                        directionTowardDeg: 215
                    ),
                    uMs: 6.2,
                    vMs: -2.4,
                    speedMs: 6.6,
                    uKt: 12.1,
                    vKt: -4.7,
                    speedKt: 12.8,
                    directionTowardDeg: 201
                )
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.contains(where: { $0.title == "Bunkers-right storm motion" && $0.value == "18 kt toward 215°" }))
    }

    @Test("partial storm motion data renders the available component only")
    func partialStormMotionDataRendersAvailableComponentOnly() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                stormMotion: .init(
                    status: "found",
                    bunkersRight: .init(
                        uMs: nil,
                        vMs: nil,
                        speedMs: nil,
                        uKt: nil,
                        vKt: nil,
                        speedKt: 28,
                        directionTowardDeg: nil
                    ),
                    uMs: 6.2,
                    vMs: -2.4,
                    speedMs: 6.6,
                    uKt: 12.1,
                    vKt: -4.7,
                    speedKt: 12.8,
                    directionTowardDeg: 201
                )
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.contains(where: { $0.title == "Bunkers-right storm motion speed" && $0.value == "28 kt" }))
        #expect(presentation.profileAnalysisRows.contains(where: { $0.title == "Bunkers-right storm motion direction" }) == false)
    }

    @Test("U/V storm motion components stay hidden")
    func uvStormMotionComponentsStayHidden() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                stormMotion: .init(
                    status: "found",
                    bunkersRight: nil,
                    uMs: 6.2,
                    vMs: -2.4,
                    speedMs: 6.6,
                    uKt: 12.1,
                    vKt: -4.7,
                    speedKt: 12.8,
                    directionTowardDeg: 201
                )
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.contains(where: { $0.title.contains("storm motion") }) == false)
        #expect(presentation.profileAnalysisRows.contains(where: { $0.value.contains("12.1") || $0.value.contains("-2.4") }) == false)
    }

    @Test("empty profile warnings produce no note")
    func emptyProfileWarningsProduceNoNote() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                quality: .init(profileLevelCount: 36, warnings: [])
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows.isEmpty == false)
        #expect(presentation.profileAnalysisNoteText == nil)
    }

    @Test("nonempty profile warnings produce only the generic note")
    func nonemptyProfileWarningsProduceOnlyTheGenericNote() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(
                quality: .init(profileLevelCount: 36, warnings: ["profile trimmed", "debug ignored"])
            ),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisNoteText == "Some profile details are limited.")
        #expect(presentation.profileAnalysisNoteText?.contains("profile trimmed") == false)
    }

    @Test("legacy ingredients are not duplicated in profile analysis")
    func legacyIngredientsAreNotDuplicatedInProfileAnalysis() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(),
            now: date("2026-06-01T19:00:00Z")
        )

        let titles = presentation.profileAnalysisRows.map(\.title)
        #expect(titles.contains("MLCAPE") == false)
        #expect(titles.contains("MUCAPE") == false)
        #expect(titles.contains("MLCIN") == false)
        #expect(titles.contains("MLLCL") == false)
    }

    @Test("accessibility labels expand acronyms and units")
    func accessibilityLabelsExpandAcronymsAndUnits() {
        let presentation = StormSetupDetailPresentation(
            dto: makeDTO(),
            preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true),
            forecastLocationTimeZone: TimeZone(identifier: "America/Denver")!,
            profileAnalysisResponse: makeProfileAnalysisResponse(),
            now: date("2026-06-01T19:00:00Z")
        )

        #expect(presentation.profileAnalysisRows[0].accessibilityLabel == "Supercell composite parameter. 0.7.")
        #expect(presentation.profileAnalysisRows[4].accessibilityLabel == "Storm-relative helicity meters squared per second squared. 135.")
        #expect(presentation.profileAnalysisRows.last?.accessibilityLabel == "Bunkers-right storm motion. 18 knots toward 215 degrees.")
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
    modelRunTime: Date? = date("2026-06-01T17:00:00Z"),
    validTime: Date = date("2026-06-01T18:00:00Z"),
    fetchedAt: Date = date("2026-06-01T18:41:00Z"),
    forecastHour: Int? = 3,
    isStale: Bool = false,
    isDegraded: Bool = false,
    model: String? = "HRRR",
    fieldSetVersion: String? = "1",
    bbox: StormSetupDTO.Bbox? = .init(toplat: 41.5, leftlon: -104.3, rightlon: -96.2, bottomlat: 36.8),
    surfaceHeightMslM: Double? = 1132.4,
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
            model: model,
            product: "Storm Setup",
            domain: "severe",
            fieldSetVersion: fieldSetVersion,
            sourceKind: sourceKind,
            runTime: modelRunTime,
            validTime: validTime,
            forecastHour: forecastHour,
            bbox: bbox,
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
        surfaceHeightMslM: surfaceHeightMslM
    )
}

private func makeProfileAnalysisResponse(
    mlcape: Double? = 1_850,
    mucape: Double? = 2_200.5,
    mlcin: Double? = -42,
    mllclMetersAgl: Double? = 980,
    scp: Double? = 0.7,
    stpFixed: Double? = 1.2,
    stpCin: Double? = 0.9,
    ship: Double? = 2.1,
    effectiveSrh: Double? = 135,
    effectiveBulkShearMs: Double? = 24.5,
    effectiveLayer: StormSetupProfileAnalysisDTO.EffectiveLayer? = .init(
        status: "found",
        basePressureMb: 915,
        topPressureMb: 750,
        baseMetersAgl: 850,
        topMetersAgl: 1_800
    ),
    stormMotion: StormSetupProfileAnalysisDTO.StormMotion? = .init(
        status: "found",
        bunkersRight: .init(
            uMs: 8.4,
            vMs: -4.2,
            speedMs: 9.4,
            uKt: 16.3,
            vKt: -8.2,
            speedKt: 18.3,
            directionTowardDeg: 215
        ),
        uMs: 6.2,
        vMs: -2.4,
        speedMs: 6.6,
        uKt: 12.1,
        vKt: -4.7,
        speedKt: 12.8,
        directionTowardDeg: 201
    ),
    quality: StormSetupProfileAnalysisDTO.Quality? = .init(
        profileLevelCount: 36,
        warnings: ["profile trimmed", "debug ignored"]
    )
) -> StormSetupProfileAnalysisDTO.Response {
    StormSetupProfileAnalysisDTO.Response(
        mlcape: mlcape,
        mucape: mucape,
        mlcin: mlcin,
        mllclMetersAgl: mllclMetersAgl,
        scp: scp,
        stpFixed: stpFixed,
        stpCin: stpCin,
        ship: ship,
        effectiveSrh: effectiveSrh,
        effectiveBulkShearMs: effectiveBulkShearMs,
        effectiveLayer: effectiveLayer,
        stormMotion: stormMotion,
        quality: quality
    )
}

private func date(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)!
}
#endif
