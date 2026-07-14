//
//  StormSetupDetailPresentation.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import ArcusCore
import Foundation

struct StormSetupDetailPresentation: Sendable, Equatable {
    struct Row: Identifiable, Sendable, Equatable {
        let title: String
        let value: String
        let accessibilityLabel: String

        var id: String { "\(title)|\(value)" }
    }

    struct DetailIngredientGroup: Identifiable, Sendable, Equatable {
        let title: String
        let rows: [Row]
        let noteText: String?

        var id: String { title }
    }

    let summaryPresentation: StormSetupSummaryPresentation
    let profileAnalysisResponse: AnvilAnalyzeProfileResponse?
    let assessmentTitle: String
    let summaryText: String?
    let confidenceText: String?
    let ingredientRows: [Row]
    let limitingFactors: [String]
    let primaryDrivers: [String]
    let provenanceHeadline: String
    let updatedText: String
    let freshnessText: String?
    let detailIngredientGroups: [DetailIngredientGroup]
    let advancedRows: [Row]
    let profileAnalysisRows: [Row]
    let profileAnalysisNoteText: String?
    let diagnosticsNoteText: String?
    let modelGuidanceTitle: String
    let modelGuidanceBody: String

    init(
        response: StormSetupCurrentResponse,
        preferences: StormSetupPreferences,
        forecastLocationTimeZone: TimeZone,
        now: Date = .now
    ) {
        summaryPresentation = StormSetupSummaryPresentation(
            response: response,
            timeZone: forecastLocationTimeZone,
            now: now
        )
        profileAnalysisResponse = response.profileAnalysis
        assessmentTitle = StormSetupSummaryPresentation.readableTitle(for: response.tornadoViability.overall)
        summaryText = response.tornadoViability.summary.trimmedNonEmpty
        confidenceText = StormSetupDetailPresentationFormatter.confidenceText(for: response.tornadoViability.confidence)
        ingredientRows = StormSetupDetailIngredientRowsBuilder.makeIngredientRows(from: response.tornadoViability.details)
        limitingFactors = response.tornadoViability.limitingFactors.map(StormSetupDetailPresentationFormatter.readableLimiter)
        primaryDrivers = []
        provenanceHeadline = StormSetupDetailPresentationFormatter.provenanceHeadline(
            model: response.setup.source.model?.rawValue,
            runTime: response.setup.source.runTime,
            validTime: response.setup.source.validTime,
            forecastHour: response.setup.source.forecastHour,
            timeZone: forecastLocationTimeZone,
            now: now
        )
        updatedText = StormSetupDetailPresentationFormatter.updatedText(
            from: response.setup.freshness.fetchedAt,
            timeZone: forecastLocationTimeZone,
            now: now
        )
        freshnessText = StormSetupDetailPresentationFormatter.freshnessText(
            isStale: response.setup.freshness.isStale,
            isDegraded: response.setup.freshness.isDegraded
        )

        let advanced = StormSetupDetailAdvancedRowsBuilder.makeAdvancedRows(
            from: response.ingredients.canonical,
            diagnostics: response.ingredients.diagnostics
        )
        advancedRows = preferences.effectiveDetailedIngredientsEnabled ? advanced.rows : []
        diagnosticsNoteText = preferences.effectiveDetailedIngredientsEnabled ? advanced.diagnosticsNoteText : nil

        let profileAnalysis = StormSetupDetailAdvancedRowsBuilder.makeProfileAnalysis(
            from: preferences.effectiveDetailedIngredientsEnabled ? response.profileAnalysis : nil
        )
        profileAnalysisRows = profileAnalysis.rows
        profileAnalysisNoteText = profileAnalysis.noteText

        detailIngredientGroups = StormSetupDetailIngredientRowsBuilder.makeDetailIngredientGroups(
            fuelAndInstability: StormSetupDetailIngredientRowsBuilder.makeFuelAndInstabilityRows(from: response.ingredients.canonical),
            cloudBaseAndEffectiveLayer: StormSetupDetailIngredientRowsBuilder.makeCloudBaseAndEffectiveLayerRows(
                mllclM: response.ingredients.canonical.mllclM,
                effectiveLayer: profileAnalysisResponse?.effectiveLayer,
                effectiveLayerAvailability: profileAnalysisResponse?.effectiveLayer.status
            ),
            shearAndRotation: StormSetupDetailIngredientRowsBuilder.makeShearAndRotationRows(
                srh01kmM2s2: response.ingredients.canonical.srh01kmM2s2,
                srh03kmM2s2: response.ingredients.canonical.srh03kmM2s2,
                shear06kmKt: response.ingredients.canonical.shear06kmKt,
                effectiveSrhM2s2: profileAnalysisResponse?.effectiveSrh,
                effectiveBulkShearMs: profileAnalysisResponse?.effectiveBulkShearMs,
                stormMotion: profileAnalysisResponse?.stormMotion,
                stormMotionAvailability: profileAnalysisResponse?.stormMotion.status
            ),
            compositeParameters: StormSetupDetailAdvancedRowsBuilder.makeCompositeParameterRows(
                scp: profileAnalysisResponse?.scp,
                stpFixed: profileAnalysisResponse?.stpFixed,
                stpCin: profileAnalysisResponse?.stpCin,
                ship: profileAnalysisResponse?.ship
            ),
            showsDetailedIngredientSections: preferences.effectiveDetailedIngredientsEnabled,
            profileQuality: StormSetupDetailIngredientRowsBuilder.makeProfileQualityRows(
                profileLevelCount: profileAnalysisResponse?.quality.profileLevelCount
            ),
            profileQualityNoteText: StormSetupDetailPresentationFormatter.combinedNoteText(
                diagnosticsNoteText,
                profileAnalysisNoteText
            )
        )

        modelGuidanceTitle = "About HRRR guidance"
        modelGuidanceBody = Self.modelGuidanceBody
    }

    init(
        dto: StormSetupDTO,
        preferences: StormSetupPreferences,
        forecastLocationTimeZone: TimeZone,
        profileAnalysisResponse: AnvilAnalyzeProfileResponse? = nil,
        now: Date = .now
    ) {
        let assessment = StormSetupAssessment(dto: dto)

        summaryPresentation = StormSetupSummaryPresentation(
            dto: dto,
            timeZone: forecastLocationTimeZone,
            now: now
        )
        self.profileAnalysisResponse = profileAnalysisResponse
        assessmentTitle = StormSetupSummaryPresentation.readableTitle(for: assessment.assessment.overall)
        summaryText = assessment.assessment.summary?.trimmedNonEmpty
        confidenceText = StormSetupDetailPresentationFormatter.confidenceText(for: assessment.assessment.confidence)
        ingredientRows = StormSetupDetailIngredientRowsBuilder.makeIngredientRows(from: assessment.assessment)
        limitingFactors = StormSetupDetailPresentationFormatter.cleanLimiterList(assessment.assessment.limitingFactors)
        primaryDrivers = StormSetupDetailPresentationFormatter.cleanTextList(assessment.assessment.primaryDrivers)
        provenanceHeadline = StormSetupDetailPresentationFormatter.provenanceHeadline(
            model: dto.source.model,
            runTime: dto.source.runTime,
            validTime: dto.source.validTime,
            forecastHour: dto.source.forecastHour,
            timeZone: forecastLocationTimeZone,
            now: now
        )
        updatedText = StormSetupDetailPresentationFormatter.updatedText(
            from: dto.freshness.fetchedAt,
            timeZone: forecastLocationTimeZone,
            now: now
        )
        freshnessText = StormSetupDetailPresentationFormatter.freshnessText(
            isStale: dto.freshness.isStale,
            isDegraded: dto.freshness.isDegraded
        )

        let advanced = StormSetupDetailAdvancedRowsBuilder.makeAdvancedRows(
            dto: dto,
            assessmentAnvil: assessment.anvilEvidence,
            preferences: preferences
        )
        advancedRows = advanced.rows
        diagnosticsNoteText = advanced.diagnosticsNoteText

        let profileAnalysis = StormSetupDetailAdvancedRowsBuilder.makeProfileAnalysis(
            from: preferences.effectiveDetailedIngredientsEnabled ? profileAnalysisResponse : nil
        )
        profileAnalysisRows = profileAnalysis.rows
        profileAnalysisNoteText = profileAnalysis.noteText

        detailIngredientGroups = StormSetupDetailIngredientRowsBuilder.makeDetailIngredientGroups(
            fuelAndInstability: StormSetupDetailIngredientRowsBuilder.makeFuelAndInstabilityRows(from: dto.raw),
            cloudBaseAndEffectiveLayer: StormSetupDetailIngredientRowsBuilder.makeCloudBaseAndEffectiveLayerRows(
                mllclM: dto.raw.mllclM,
                effectiveLayer: profileAnalysisResponse?.effectiveLayer,
                effectiveLayerAvailability: profileAnalysisResponse?.effectiveLayer.status,
                hasEffectiveLayer: assessment.anvilEvidence?.diagnostics.hasEffectiveLayer
            ),
            shearAndRotation: StormSetupDetailIngredientRowsBuilder.makeShearAndRotationRows(
                srh01kmM2s2: dto.raw.srh01kmM2s2,
                srh03kmM2s2: dto.raw.srh03kmM2s2,
                shear06kmKt: dto.raw.shear06kmKt,
                effectiveSrhM2s2: profileAnalysisResponse?.effectiveSrh,
                effectiveBulkShearMs: profileAnalysisResponse?.effectiveBulkShearMs,
                stormMotion: profileAnalysisResponse?.stormMotion,
                stormMotionAvailability: profileAnalysisResponse?.stormMotion.status,
                hasStormMotion: assessment.anvilEvidence?.diagnostics.hasStormMotion
            ),
            compositeParameters: StormSetupDetailAdvancedRowsBuilder.makeCompositeParameterRows(
                scp: profileAnalysisResponse?.scp,
                stpFixed: profileAnalysisResponse?.stpFixed,
                stpCin: profileAnalysisResponse?.stpCin,
                ship: profileAnalysisResponse?.ship,
                signalEvidence: assessment.anvilEvidence
            ),
            showsDetailedIngredientSections: preferences.effectiveDetailedIngredientsEnabled,
            profileQuality: StormSetupDetailIngredientRowsBuilder.makeProfileQualityRows(
                profileLevelCount: profileAnalysisResponse?.quality.profileLevelCount ?? assessment.anvilEvidence?.diagnostics.qualityProfileLevelCount
            ),
            profileQualityNoteText: StormSetupDetailPresentationFormatter.combinedNoteText(
                diagnosticsNoteText,
                profileAnalysisNoteText
            )
        )

        modelGuidanceTitle = "About HRRR guidance"
        modelGuidanceBody = Self.modelGuidanceBody
    }

    private static let modelGuidanceBody = """
Values come from the HRRR forecast model, a high-resolution hourly model used for short-term guidance.
They are guidance, not observations, watches, or warnings.
SkyAware translates model values into plain-language signals.
Guidance can change between runs, especially while storms are forming.
"""
}
