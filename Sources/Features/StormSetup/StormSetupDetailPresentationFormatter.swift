import ArcusCore
import Foundation

enum StormSetupDetailPresentationFormatter {
    static func confidenceText(for confidence: StormSetupConfidence) -> String? {
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

    static func confidenceText(for confidence: SnapshotConfidence) -> String? {
        switch confidence {
        case .high:
            "High confidence"
        case .moderate:
            "Medium confidence"
        case .low, .degraded:
            "Low confidence"
        }
    }

    static func freshnessText(isStale: Bool, isDegraded: Bool) -> String? {
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

    static func provenanceHeadline(
        model: String?,
        runTime: Date?,
        validTime: Date?,
        forecastHour: Int?,
        timeZone: TimeZone,
        now: Date
    ) -> String {
        let modelText = model?.trimmedNonEmpty.map { "\($0) forecast model" } ?? "Forecast"
        var components: [String] = [modelText]

        if let runTime {
            components.append("\(formattedUTCModelRun(runTime)) run")
        }

        if let forecastHour {
            components.append(formattedForecastHour(forecastHour))
        }

        if let validTime {
            let validText = formattedLocationTime(
                validTime,
                timeZone: timeZone,
                now: now,
                includeMinutes: false,
                includeZone: true
            )
            components.append("valid \(validText)")
        }

        return components.joined(separator: " · ")
    }

    static func updatedText(from date: Date, timeZone: TimeZone, now: Date) -> String {
        "Updated \(formattedLocationTime(date, timeZone: timeZone, now: now, includeMinutes: true, includeZone: false))"
    }

    static func cleanTextList(_ values: [String]) -> [String] {
        values.compactMap { $0.trimmedNonEmpty }
    }

    static func cleanLimiterList(_ values: [String]) -> [String] {
        values.compactMap { readableLimiter(from: $0) }
    }

    static func combinedNoteText(_ texts: String?...) -> String? {
        let values = texts.compactMap { $0?.trimmedNonEmpty }
        guard values.isEmpty == false else {
            return nil
        }

        return values.joined(separator: " ")
    }

    static func readableLimiter(_ limiter: TornadoViabilityLimiter) -> String {
        switch limiter {
        case .weakInstability:
            "Weak Instability"
        case .weakDeepShear:
            "Weak Deep Shear"
        case .weakLowLevelRotation:
            "Weak Low-Level Rotation"
        case .weakLowLevelStretching:
            "Weak Low-Level Stretching"
        case .elevatedCloudBases:
            "Elevated Cloud Bases"
        case .strongCap:
            "Strong Cap"
        case .conditionalInitiation:
            "Conditional Initiation"
        case .weakStormOrganization:
            "Weak Storm Organization"
        case .fixedEffectiveStpDisagreement:
            "Fixed Effective STP Disagreement"
        case .poorMoisture:
            "Poor Moisture"
        case .missingStormMode:
            "Missing Storm Mode"
        case .unknown:
            "Unavailable"
        }
    }

    static func readableLimiter(from value: String) -> String? {
        let trimmed = value.trimmedNonEmpty
        guard let trimmed else { return nil }

        switch normalizedLimiterKey(trimmed) {
        case "weakinstability":
            return "Weak Instability"
        case "weakdeepshear":
            return "Weak Deep Shear"
        case "weaklowlevelrotation":
            return "Weak Low-Level Rotation"
        case "weaklowlevelstretching":
            return "Weak Low-Level Stretching"
        case "elevatedcloudbases":
            return "Elevated Cloud Bases"
        case "strongcap":
            return "Strong Cap"
        case "conditionalinitiation":
            return "Conditional Initiation"
        case "weakstormorganization":
            return "Weak Storm Organization"
        case "fixedeffectivestpdisagreement":
            return "Fixed Effective STP Disagreement"
        case "poormoisture":
            return "Poor Moisture"
        case "missingstormmode":
            return "Missing Storm Mode"
        default:
            return trimmed
        }
    }

    static func row(title: String, value: String) -> StormSetupDetailPresentation.Row {
        .init(title: title, value: value, accessibilityLabel: "\(title). \(value).")
    }

    private static func row(title: String, value: StormSetupSignal) -> StormSetupDetailPresentation.Row {
        .init(
            title: title,
            value: StormSetupSummaryPresentation.readableSignal(value),
            accessibilityLabel: "\(title). \(StormSetupSummaryPresentation.readableSignal(value))."
        )
    }

    static func formattedWholeValue(_ value: Double?) -> String? {
        guard let value, value.isFinite else { return nil }

        let rounded = value.rounded(.toNearestOrAwayFromZero)
        let normalized = rounded == 0 ? 0 : rounded
        return normalized.formatted(.number)
    }

    static func makeCompositeRow(
        title: String,
        accessibilityTitle: String,
        value: Double?
    ) -> StormSetupDetailPresentation.Row? {
        guard let formatted = formattedCompositeValue(value) else {
            return nil
        }

        return .init(title: title, value: formatted, accessibilityLabel: "\(accessibilityTitle). \(formatted).")
    }

    static func makeWholeRow(
        title: String,
        accessibilityTitle: String,
        value: Double?
    ) -> StormSetupDetailPresentation.Row? {
        guard let formatted = formattedWholeValue(value) else {
            return nil
        }

        return .init(title: title, value: formatted, accessibilityLabel: "\(accessibilityTitle). \(formatted).")
    }

    static func makeOneDecimalRow(
        title: String,
        accessibilityTitle: String,
        value: Double?
    ) -> StormSetupDetailPresentation.Row? {
        guard let formatted = formattedOneDecimalValue(value) else {
            return nil
        }

        return .init(title: title, value: formatted, accessibilityLabel: "\(accessibilityTitle). \(formatted).")
    }

    static func appendIfPresent(_ row: StormSetupDetailPresentation.Row?, to rows: inout [StormSetupDetailPresentation.Row]) {
        guard let row else { return }
        rows.append(row)
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

    private static func normalizedLimiterKey(_ value: String) -> String {
        value.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map { Character($0) }
            .map(String.init)
            .joined()
            .lowercased()
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
}

enum AdvancedValueFormat {
    case whole
    case decimalIfNeeded
    case signal
}

extension Array where Element == StormSetupDetailPresentation.Row {
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

extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
