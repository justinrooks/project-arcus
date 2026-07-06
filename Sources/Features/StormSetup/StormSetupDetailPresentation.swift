//
//  StormSetupDetailPresentation.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

struct StormSetupDetailPresentation: Sendable, Equatable {
    struct Row: Identifiable, Sendable, Equatable {
        let title: String
        let value: String
        let accessibilityLabel: String

        var id: String { "\(title)|\(value)" }
    }

    let summaryPresentation: StormSetupSummaryPresentation
    let profileAnalysisResponse: StormSetupProfileAnalysisDTO.Response?
    let assessmentTitle: String
    let summaryText: String?
    let confidenceText: String?
    let ingredientRows: [Row]
    let limitingFactors: [String]
    let primaryDrivers: [String]
    let provenanceHeadline: String
    let updatedText: String
    let freshnessText: String?
    let advancedRows: [Row]
    let profileAnalysisRows: [Row]
    let profileAnalysisNoteText: String?
    let diagnosticsNoteText: String?
    let modelGuidanceTitle: String
    let modelGuidanceBody: String

    init(
        dto: StormSetupDTO,
        preferences: StormSetupPreferences,
        forecastLocationTimeZone: TimeZone,
        profileAnalysisResponse: StormSetupProfileAnalysisDTO.Response? = nil,
        now: Date = .now
    ) {
        let assessment = StormSetupAssessment(dto: dto)

        summaryPresentation = StormSetupSummaryPresentation(
            dto: dto,
            timeZone: forecastLocationTimeZone,
            now: now
        )
        self.profileAnalysisResponse = preferences.effectiveDetailedIngredientsEnabled ? profileAnalysisResponse : nil
        assessmentTitle = StormSetupSummaryPresentation.readableTitle(for: assessment.assessment.overall)
        summaryText = assessment.assessment.summary?.trimmedNonEmpty
        confidenceText = Self.confidenceText(for: assessment.assessment.confidence)
        ingredientRows = Self.makeIngredientRows(from: assessment.assessment)
        limitingFactors = Self.cleanTextList(assessment.assessment.limitingFactors)
        primaryDrivers = Self.cleanTextList(assessment.assessment.primaryDrivers)
        provenanceHeadline = Self.provenanceHeadline(
            model: dto.source.model,
            runTime: dto.source.runTime,
            validTime: dto.source.validTime,
            forecastHour: dto.source.forecastHour,
            timeZone: forecastLocationTimeZone,
            now: now
        )
        updatedText = Self.updatedText(from: dto.freshness.fetchedAt, timeZone: forecastLocationTimeZone, now: now)
        freshnessText = Self.freshnessText(isStale: dto.freshness.isStale, isDegraded: dto.freshness.isDegraded)

        let advanced = Self.makeAdvancedRows(
            dto: dto,
            assessmentAnvil: assessment.anvilEvidence,
            preferences: preferences
        )
        advancedRows = advanced.rows
        diagnosticsNoteText = advanced.diagnosticsNoteText

        let profileAnalysis = Self.makeProfileAnalysis(
            from: preferences.effectiveDetailedIngredientsEnabled ? profileAnalysisResponse : nil
        )
        profileAnalysisRows = profileAnalysis.rows
        profileAnalysisNoteText = profileAnalysis.noteText

        modelGuidanceTitle = "About HRRR guidance"
        modelGuidanceBody = Self.modelGuidanceBody
    }

    private static func makeIngredientRows(from assessment: StormSetupAssessment.ReadableAssessment) -> [Row] {
        [
            row(title: "Instability", value: StormSetupSummaryPresentation.readableSignal(assessment.instability)),
            row(title: "Moisture", value: StormSetupSummaryPresentation.readableSignal(assessment.moisture)),
            row(
                title: "Low-level rotation",
                value: StormSetupSummaryPresentation.readableSignal(assessment.lowLevelRotation)
            ),
            row(title: "Deep shear", value: StormSetupSummaryPresentation.readableSignal(assessment.deepShear)),
            row(title: "Cloud bases", value: StormSetupSummaryPresentation.readableCloudBase(assessment.cloudBase)),
            row(title: "Cap / inhibition", value: StormSetupSummaryPresentation.readableSignal(assessment.capInhibition))
        ]
    }

    private static func makeAdvancedRows(
        dto: StormSetupDTO,
        assessmentAnvil: StormSetupAssessment.AnvilEvidence?,
        preferences: StormSetupPreferences
    ) -> (rows: [Row], diagnosticsNoteText: String?) {
        guard preferences.effectiveDetailedIngredientsEnabled else {
            return ([], nil)
        }

        var rows: [Row] = []
        rows.appendNumericRow(title: "MLCAPE — J/kg", value: dto.raw.mlcapeJkg, format: .whole, accessibilityTitle: "Mixed-layer CAPE")
        rows.appendNumericRow(title: "MUCAPE — J/kg", value: dto.raw.mucapeJkg, format: .whole, accessibilityTitle: "Most-unstable CAPE")
        rows.appendNumericRow(title: "SBCAPE — J/kg", value: dto.raw.sbcapeJkg, format: .whole, accessibilityTitle: "Surface-based CAPE")
        rows.appendNumericRow(title: "MLCIN — J/kg", value: dto.raw.mlcinJkg, format: .whole, accessibilityTitle: "Mixed-layer CIN")
        rows.appendNumericRow(title: "0–1 km SRH — m²/s²", value: dto.raw.srh01kmM2s2, format: .whole, accessibilityTitle: "Zero to one kilometer storm-relative helicity")
        rows.appendNumericRow(title: "0–3 km SRH — m²/s²", value: dto.raw.srh03kmM2s2, format: .whole, accessibilityTitle: "Zero to three kilometer storm-relative helicity")
        rows.appendNumericRow(title: "0–6 km shear — kt", value: dto.raw.shear06kmKt, format: .whole, accessibilityTitle: "Zero to six kilometer shear")
        rows.appendNumericRow(title: "MLLCL — m", value: dto.raw.mllclM, format: .whole, accessibilityTitle: "Mixed-layer lifted condensation level")
        rows.appendNumericRow(
            title: "Temperature/dew-point spread — °F",
            value: dto.raw.tempDewPtDeltaF,
            format: .decimalIfNeeded,
            accessibilityTitle: "Temperature and dew-point spread"
        )
        rows.appendNumericRow(
            title: "0–3 km CAPE / 3CAPE — J/kg",
            value: dto.raw.threeCapeJkg,
            format: .whole,
            accessibilityTitle: "Zero to three kilometer CAPE"
        )

        if let anvil = assessmentAnvil {
            rows.appendSignalRow(
                title: "SCP signal",
                value: anvil.scp.support,
                accessibilityTitle: "S C P signal"
            )
            rows.appendSignalRow(
                title: "STP signal",
                value: anvil.stp.support,
                accessibilityTitle: "S T P signal"
            )
            rows.appendSignalRow(
                title: "SHIP signal",
                value: anvil.ship.support,
                accessibilityTitle: "S H I P signal"
            )

            if anvil.diagnostics.hasEffectiveLayer == true {
                rows.append(Row(
                    title: "Effective layer available",
                    value: "Yes",
                    accessibilityLabel: "Effective layer available. Yes."
                ))
            }

            if anvil.diagnostics.hasStormMotion == true {
                rows.append(Row(
                    title: "Storm motion available",
                    value: "Yes",
                    accessibilityLabel: "Storm motion available. Yes."
                ))
            }

            if let profileLevelCount = anvil.diagnostics.qualityProfileLevelCount {
                rows.append(Row(
                    title: "Profile level count",
                    value: profileLevelCount.formatted(),
                    accessibilityLabel: "Profile level count. \(profileLevelCount)."
                ))
            }
        }

        let noteText = assessmentAnvil?.diagnostics.warnings.isEmpty == false
            ? "Some advanced diagnostics are limited."
            : nil

        return (rows, noteText)
    }

    private static func makeProfileAnalysis(
        from response: StormSetupProfileAnalysisDTO.Response?
    ) -> (rows: [Row], noteText: String?) {
        guard let response else {
            return ([], nil)
        }

        var rows: [Row] = []
        Self.appendIfPresent(Self.makeCompositeRow(title: "SCP", accessibilityTitle: "Supercell composite parameter", value: response.scp), to: &rows)
        Self.appendIfPresent(
            Self.makeCompositeRow(
                title: "STP — fixed",
                accessibilityTitle: "Significant tornado parameter fixed",
                value: response.stpFixed
            ),
            to: &rows
        )
        Self.appendIfPresent(
            Self.makeCompositeRow(
                title: "STP — CIN-adjusted",
                accessibilityTitle: "Significant tornado parameter C I N adjusted",
                value: response.stpCin
            ),
            to: &rows
        )
        Self.appendIfPresent(
            Self.makeCompositeRow(title: "SHIP", accessibilityTitle: "Significant hail parameter", value: response.ship),
            to: &rows
        )
        Self.appendIfPresent(
            Self.makeWholeRow(
                title: "Effective SRH — m²/s²",
                accessibilityTitle: "Storm-relative helicity meters squared per second squared",
                value: response.effectiveSrh
            ),
            to: &rows
        )
        Self.appendIfPresent(
            Self.makeOneDecimalRow(
                title: "Effective bulk shear — m/s",
                accessibilityTitle: "Effective bulk shear meters per second",
                value: response.effectiveBulkShearMs
            ),
            to: &rows
        )
        rows.append(contentsOf: makeEffectiveLayerRows(from: response.effectiveLayer))
        rows.append(contentsOf: makeStormMotionRows(from: response.stormMotion))

        guard rows.isEmpty == false else {
            return ([], nil)
        }

        let noteText = response.quality?.warnings?.contains(where: { $0.trimmedNonEmpty != nil }) == true
            ? "Some profile details are limited."
            : nil

        return (rows, noteText)
    }

    private static func confidenceText(for confidence: StormSetupConfidence) -> String? {
        switch confidence {
        case .high:
            "High confidence"
        case .medium:
            "Medium confidence"
        case .low:
            "Low confidence"
        case .unknown:
            nil
        }
    }

    private static func freshnessText(isStale: Bool, isDegraded: Bool) -> String? {
        switch (isStale, isDegraded) {
        case (true, true):
            "Guidance may be out of date and some details are limited."
        case (true, false):
            "Guidance may be out of date."
        case (false, true):
            "Some guidance details are limited."
        case (false, false):
            nil
        }
    }

    private static func provenanceHeadline(
        model: String,
        runTime: Date,
        validTime: Date,
        forecastHour: Int,
        timeZone: TimeZone,
        now: Date
    ) -> String {
        let trimmedModel = model.trimmedNonEmpty ?? "Forecast"
        let runText = formattedUTCModelRun(runTime)
        let forecastHourText = formattedForecastHour(forecastHour)
        let validText = formattedLocationTime(
            validTime,
            timeZone: timeZone,
            now: now,
            includeMinutes: false,
            includeZone: true
        )
        return "\(trimmedModel) forecast model · \(runText) run · \(forecastHourText) · valid \(validText)"
    }

    private static func updatedText(from date: Date, timeZone: TimeZone, now: Date) -> String {
        "Updated \(formattedLocationTime(date, timeZone: timeZone, now: now, includeMinutes: true, includeZone: false))"
    }

    private static func formattedUTCModelRun(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let hour = calendar.component(.hour, from: date)
        return "\(hour)Z"
    }

    private static func formattedForecastHour(_ forecastHour: Int) -> String {
        if forecastHour < 100 {
            return String(format: "f%02d", forecastHour)
        }
        return "f\(forecastHour)"
    }

    private static func formattedLocationTime(
        _ date: Date,
        timeZone: TimeZone,
        now: Date,
        includeMinutes: Bool,
        includeZone: Bool
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var base = Date.FormatStyle(
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: calendar,
            timeZone: timeZone
        )
        .hour(.defaultDigits(amPM: .abbreviated))

        if includeMinutes {
            base = base.minute(.twoDigits)
        }

        let timeText = date.formatted(base)
        let dayText: String
        if calendar.isDate(date, inSameDayAs: now) {
            dayText = timeText
        } else {
            var expanded = Date.FormatStyle(
                locale: Locale(identifier: "en_US_POSIX"),
                calendar: calendar,
                timeZone: timeZone
            )
            .month(.abbreviated)
            .day()
            .hour(.defaultDigits(amPM: .abbreviated))

            if includeMinutes {
                expanded = expanded.minute(.twoDigits)
            }

            dayText = date.formatted(expanded)
        }

        guard includeZone else {
            return dayText
        }

        let zoneText = timeZone.abbreviation(for: date) ?? timeZone.abbreviation() ?? ""
        return zoneText.isEmpty ? dayText : "\(dayText) \(zoneText)"
    }

    private static func cleanTextList(_ values: [String]) -> [String] {
        values.compactMap { $0.trimmedNonEmpty }
    }

    private static func row(title: String, value: StormSetupSignal) -> Row {
        Row(
            title: title,
            value: StormSetupSummaryPresentation.readableSignal(value),
            accessibilityLabel: "\(title). \(StormSetupSummaryPresentation.readableSignal(value))."
        )
    }

    private static func row(title: String, value: String) -> Row {
        Row(title: title, value: value, accessibilityLabel: "\(title). \(value).")
    }

    private static func makeEffectiveLayerRows(from layer: StormSetupProfileAnalysisDTO.EffectiveLayer?) -> [Row] {
        guard let layer else { return [] }

        let status = layer.status?.trimmedNonEmpty?.lowercased()
        if status == "found" {
            var rows: [Row] = []
            rows.append(contentsOf: makeBoundRows(
                baseTitle: "Effective layer height",
                boundsTitle: "Effective layer height bounds",
                baseValue: layer.baseMetersAgl,
                topValue: layer.topMetersAgl,
                unit: "m AGL",
                accessibilityUnit: "meters above ground level"
            ))
            rows.append(contentsOf: makeBoundRows(
                baseTitle: "Effective layer pressure",
                boundsTitle: "Effective layer pressure bounds",
                baseValue: layer.basePressureMb,
                topValue: layer.topPressureMb,
                unit: "mb",
                accessibilityUnit: "millibars"
            ))
            return rows
        }

        if status == "notfound" {
            return [Row(
                title: "Effective layer",
                value: "Not identified",
                accessibilityLabel: "Effective layer. Not identified."
            )]
        }

        return []
    }

    private static func makeBoundRows(
        baseTitle: String,
        boundsTitle: String,
        baseValue: Double?,
        topValue: Double?,
        unit: String,
        accessibilityUnit: String
    ) -> [Row] {
        let base = formattedWholeValue(baseValue)
        let top = formattedWholeValue(topValue)

        switch (base, top) {
        case let (base?, top?):
            return [Row(
                title: boundsTitle,
                value: "\(base)–\(top) \(unit)",
                accessibilityLabel: "\(boundsTitle). \(base) to \(top) \(accessibilityUnit)."
            )]
        case let (base?, nil):
            return [Row(
                title: "\(baseTitle) base",
                value: "\(base) \(unit)",
                accessibilityLabel: "\(baseTitle) base. \(base) \(accessibilityUnit)."
            )]
        case let (nil, top?):
            return [Row(
                title: "\(baseTitle) top",
                value: "\(top) \(unit)",
                accessibilityLabel: "\(baseTitle) top. \(top) \(accessibilityUnit)."
            )]
        case (nil, nil):
            return []
        }
    }

    private static func makeStormMotionRows(from stormMotion: StormSetupProfileAnalysisDTO.StormMotion?) -> [Row] {
        guard let stormMotion, let bunkersRight = stormMotion.bunkersRight else {
            return []
        }

        let speed = formattedWholeValue(bunkersRight.speedKt)
        let direction = formattedWholeValue(bunkersRight.directionTowardDeg)

        switch (speed, direction) {
        case let (speed?, direction?):
            return [Row(
                title: "Bunkers-right storm motion",
                value: "\(speed) kt toward \(direction)°",
                accessibilityLabel: "Bunkers-right storm motion. \(speed) knots toward \(direction) degrees."
            )]
        case let (speed?, nil):
            return [Row(
                title: "Bunkers-right storm motion speed",
                value: "\(speed) kt",
                accessibilityLabel: "Bunkers-right storm motion speed. \(speed) knots."
            )]
        case let (nil, direction?):
            return [Row(
                title: "Bunkers-right storm motion direction",
                value: "toward \(direction)°",
                accessibilityLabel: "Bunkers-right storm motion direction. Toward \(direction) degrees."
            )]
        case (nil, nil):
            return []
        }
    }

    private static func formattedWholeValue(_ value: Double?) -> String? {
        guard let value, value.isFinite else { return nil }

        let rounded = value.rounded(.toNearestOrAwayFromZero)
        let normalized = rounded == 0 ? 0 : rounded
        return normalized.formatted(.number)
    }

    private static func formattedOneDecimalValue(_ value: Double?) -> String? {
        guard let value, value.isFinite else { return nil }

        if value == 0 {
            return "0"
        }

        let rounded = (value * 10).rounded(.toNearestOrAwayFromZero) / 10
        if rounded == 0 {
            return value.formatted(.number.precision(.significantDigits(1...2)))
        }

        let normalized = rounded == 0 ? 0 : rounded
        return normalized.formatted(.number.precision(.fractionLength(1)))
    }

    private static func formattedCompositeValue(_ value: Double?) -> String? {
        guard let value, value.isFinite else { return nil }

        if value == 0 {
            return "0"
        }

        let rounded = (value * 10).rounded(.toNearestOrAwayFromZero) / 10
        if rounded == 0 {
            return value.formatted(.number.precision(.significantDigits(1...2)))
        }

        let normalized = rounded == 0 ? 0 : rounded
        return normalized.formatted(.number.precision(.fractionLength(1)))
    }

    private static func makeCompositeRow(
        title: String,
        accessibilityTitle: String,
        value: Double?
    ) -> Row? {
        guard let formatted = formattedCompositeValue(value) else {
            return nil
        }

        return Row(title: title, value: formatted, accessibilityLabel: "\(accessibilityTitle). \(formatted).")
    }

    private static func makeWholeRow(
        title: String,
        accessibilityTitle: String,
        value: Double?
    ) -> Row? {
        guard let formatted = formattedWholeValue(value) else {
            return nil
        }

        return Row(title: title, value: formatted, accessibilityLabel: "\(accessibilityTitle). \(formatted).")
    }

    private static func makeOneDecimalRow(
        title: String,
        accessibilityTitle: String,
        value: Double?
    ) -> Row? {
        guard let formatted = formattedOneDecimalValue(value) else {
            return nil
        }

        return Row(title: title, value: formatted, accessibilityLabel: "\(accessibilityTitle). \(formatted).")
    }

    private static func appendIfPresent(_ row: Row?, to rows: inout [Row]) {
        guard let row else { return }
        rows.append(row)
    }

    private static let modelGuidanceBody = """
Values come from the HRRR forecast model, a high-resolution hourly model used for short-term guidance.
They are guidance, not observations, watches, or warnings.
SkyAware translates model values into plain-language signals.
Guidance can change between runs, especially while storms are forming.
"""
}

private enum AdvancedValueFormat {
    case whole
    case decimalIfNeeded
    case signal
}

private extension Array where Element == StormSetupDetailPresentation.Row {
    mutating func appendNumericRow(
        title: String,
        value: Double?,
        format: AdvancedValueFormat,
        accessibilityTitle: String
    ) {
        guard let value,
              value.isFinite
        else {
            return
        }

        let formatted: String
        switch format {
        case .whole:
            formatted = value.rounded(.toNearestOrAwayFromZero).formatted(.number)
        case .decimalIfNeeded:
            formatted = Self.formatDecimalIfNeeded(value)
        case .signal:
            formatted = value.formatted(.number)
        }

        append(.init(
            title: title,
            value: formatted,
            accessibilityLabel: "\(accessibilityTitle). \(formatted)."
        ))
    }

    mutating func appendSignalRow(
        title: String,
        value: StormSetupSignal,
        accessibilityTitle: String
    ) {
        guard value != .unknown else {
            return
        }

        let formatted = StormSetupSummaryPresentation.readableSignal(value)

        append(.init(
            title: title,
            value: formatted,
            accessibilityLabel: "\(accessibilityTitle). \(formatted)."
        ))
    }

    private static func formatDecimalIfNeeded(_ value: Double) -> String {
        let roundedToWhole = value.rounded(.toNearestOrAwayFromZero)
        if roundedToWhole == value {
            return roundedToWhole.formatted(.number.precision(.fractionLength(0)))
        }

        return value.formatted(.number.precision(.fractionLength(1)))
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
