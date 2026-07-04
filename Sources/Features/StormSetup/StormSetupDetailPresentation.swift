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
    let diagnosticsNoteText: String?
    let modelGuidanceTitle: String
    let modelGuidanceBody: String

    init(
        dto: StormSetupDTO,
        preferences: StormSetupPreferences,
        forecastLocationTimeZone: TimeZone,
        now: Date = .now
    ) {
        let assessment = StormSetupAssessment(dto: dto)

        summaryPresentation = StormSetupSummaryPresentation(
            dto: dto,
            timeZone: forecastLocationTimeZone,
            now: now
        )
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
