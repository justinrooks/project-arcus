//
//  StormSetupPresentation.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

enum SummarySectionKind: String, Identifiable, Sendable, Equatable {
    case currentConditions
    case primaryAwareness
    case localAlerts
    case stormSetup
    case atmosphericConditions
    case locationReliability
    case outlookSummary
    case attribution

    var id: String { rawValue }
}

struct SummarySectionPlan: Sendable, Equatable {
    let sections: [SummarySectionKind]

    static func make(
        localAlertsDisplayState: LocalAlertsDisplayState,
        showsStormSetup: Bool,
        hasLocationReliabilityRail: Bool
    ) -> SummarySectionPlan {
        let localAlertsArePopulated = localAlertsDisplayState.presentationState == .alerts
        let supportingSection: SummarySectionKind = showsStormSetup ? .stormSetup : .atmosphericConditions

        var sections: [SummarySectionKind] = [
            .currentConditions,
            .primaryAwareness
        ]

        if localAlertsArePopulated {
            sections.append(.localAlerts)
            sections.append(supportingSection)

            if hasLocationReliabilityRail {
                sections.append(.locationReliability)
            }
        } else {
            sections.append(supportingSection)

            if hasLocationReliabilityRail {
                sections.append(.locationReliability)
            }

            sections.append(.localAlerts)
        }

        sections.append(.outlookSummary)
        sections.append(.attribution)
        return .init(sections: sections)
    }
}

struct StormSetupSummaryPresentation: Sendable, Equatable {
    struct IngredientRow: Identifiable, Sendable, Equatable {
        enum Kind: String, Identifiable, Sendable, Equatable {
            case instability
            case rotation
            case cloudBases

            var id: String { rawValue }
        }

        let kind: Kind
        let title: String
        let value: String

        var id: String { kind.id }
    }

    let overallTitle: String
    let summaryProse: String?
    let ingredientRows: [IngredientRow]
    let limiterText: String?
    let freshnessText: String?
    let sourceLine: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityHint: String

    init(dto: StormSetupDTO, timeZone: TimeZone, now: Date = .now) {
        let assessment = StormSetupAssessment(dto: dto)

        overallTitle = Self.readableTitle(for: assessment.assessment.overall)
        summaryProse = assessment.assessment.summary?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        ingredientRows = [
            .init(
                kind: .instability,
                title: "Instability",
                value: Self.readableSignal(assessment.assessment.instability)
            ),
            .init(
                kind: .rotation,
                title: "Rotation",
                value: Self.readableSignal(assessment.assessment.lowLevelRotation)
            ),
            .init(
                kind: .cloudBases,
                title: "Cloud bases",
                value: Self.readableCloudBase(assessment.assessment.cloudBase)
            )
        ]
        limiterText = Self.firstMeaningfulLimiter(from: assessment.assessment.limitingFactors)
        freshnessText = Self.freshnessCopy(
            isStale: dto.freshness.isStale,
            isDegraded: dto.freshness.isDegraded
        )
        sourceLine = Self.sourceLine(
            model: dto.source.model,
            validTime: dto.source.validTime,
            timeZone: timeZone,
            now: now
        )

        let accessibilityParts = [
            overallTitle,
            summaryProse,
            ingredientRows.map { "\($0.title): \($0.value)" }.joined(separator: ". "),
            limiterText.map { "Limiter: \($0)" },
            freshnessText,
            sourceLine
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }

        accessibilityLabel = "Storm Setup"
        accessibilityValue = accessibilityParts.joined(separator: ". ")
        accessibilityHint = "Opens Storm Setup details."
    }

    private static func readableTitle(for signal: StormSetupSignal) -> String {
        switch signal {
        case .supportive:
            "Supportive Setup"
        case .strong:
            "Strong Setup"
        case .conditional:
            "Conditional Setup"
        case .weak:
            "Weak Setup"
        case .unknown:
            "Unavailable"
        }
    }

    private static func readableSignal(_ signal: StormSetupSignal) -> String {
        switch signal {
        case .supportive:
            "Supportive"
        case .strong:
            "Strong"
        case .conditional:
            "Conditional"
        case .weak:
            "Weak"
        case .unknown:
            "Unavailable"
        }
    }

    private static func readableCloudBase(_ signal: StormSetupSignal) -> String {
        switch signal {
        case .supportive, .strong:
            "Low"
        case .conditional:
            "Mixed"
        case .weak:
            "High"
        case .unknown:
            "Unavailable"
        }
    }

    private static func firstMeaningfulLimiter(from factors: [String]) -> String? {
        factors
            .compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .first
    }

    private static func freshnessCopy(isStale: Bool, isDegraded: Bool) -> String? {
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

    private static func sourceLine(
        model: String,
        validTime: Date,
        timeZone: TimeZone,
        now: Date
    ) -> String {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelPrefix = trimmedModel.isEmpty ? "Guidance" : "\(trimmedModel) guidance"
        return "\(modelPrefix) · valid near \(formattedHour(validTime, timeZone: timeZone, now: now))"
    }

    private static func formattedHour(_ date: Date, timeZone: TimeZone, now: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let formatter = Date.FormatStyle(
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: calendar,
            timeZone: timeZone
        )
            .hour(.defaultDigits(amPM: .abbreviated))

        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(formatter)
        }

        return date.formatted(
            Date.FormatStyle(
                locale: Locale(identifier: "en_US_POSIX"),
                calendar: calendar,
                timeZone: timeZone
            )
                .month(.abbreviated)
                .day()
                .hour(.defaultDigits(amPM: .abbreviated))
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
