//
//  SupportingRiskRowDisplayModel.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

enum SupportingRiskRowPresentationMode: Equatable, Sendable {
    case normal
    case subdued
    case supplemental
}

struct SupportingRiskRowDisplayModel: Equatable, Sendable {
    let title: String
    let detail: String
    let presentationMode: SupportingRiskRowPresentationMode

    static func severe(
        threat: SevereWeatherThreat,
        primarySource: SummaryAwarenessSource
    ) -> SupportingRiskRowDisplayModel {
        if primarySource == .severeRisk {
            return SupportingRiskRowDisplayModel(
                title: "Severe Risk",
                detail: supplementalSevereDetail(for: threat),
                presentationMode: .supplemental
            )
        }

        return SupportingRiskRowDisplayModel(
            title: threat.message,
            detail: threat.dynamicSummary.isEmpty ? threat.summary : threat.dynamicSummary,
            presentationMode: .normal
        )
    }

    static func storm(
        level: StormRiskLevel,
        primarySource: SummaryAwarenessSource
    ) -> SupportingRiskRowDisplayModel {
        if primarySource == .stormRisk {
            return SupportingRiskRowDisplayModel(
                title: "Storm Risk",
                detail: supplementalStormDetail(for: level),
                presentationMode: .supplemental
            )
        }

        return SupportingRiskRowDisplayModel(
            title: level.message,
            detail: level.summary,
            presentationMode: .normal
        )
    }

    static func fire(
        level: FireRiskLevel,
        primarySource: SummaryAwarenessSource
    ) -> SupportingRiskRowDisplayModel {
        let presentation = level.supportingPresentation()

        if presentation.isSubdued {
            return SupportingRiskRowDisplayModel(
                title: presentation.title,
                detail: presentation.detail,
                presentationMode: .subdued
            )
        }

        if primarySource == .fireRisk {
            return SupportingRiskRowDisplayModel(
                title: "Fire Risk",
                detail: supplementalFireDetail(for: level),
                presentationMode: .supplemental
            )
        }

        return SupportingRiskRowDisplayModel(
            title: presentation.title,
            detail: presentation.detail,
            presentationMode: .normal
        )
    }

    private static func supplementalSevereDetail(for threat: SevereWeatherThreat) -> String {
        switch threat {
        case .allClear:
            return "No active severe threat"
        case .wind:
            return "Wind is the main severe signal"
        case .hail:
            return "Hail is the main severe signal"
        case .tornado:
            return "Tornado is the main severe signal"
        }
    }

    private static func supplementalStormDetail(for level: StormRiskLevel) -> String {
        switch level {
        case .allClear:
            return "No severe storms expected"
        case .thunderstorm:
            return "Thunderstorms possible"
        case .marginal:
            return "Low-end severe setup"
        case .slight:
            return "Elevated storm environment"
        case .enhanced:
            return "Severe storms possible today"
        case .moderate, .high:
            return "Primary outlook signal"
        }
    }

    private static func supplementalFireDetail(for level: FireRiskLevel) -> String {
        switch level {
        case .clear:
            return "No elevated fire weather risk"
        case .elevated:
            return "Wind and dry air are the drivers"
        case .critical:
            return "Rapid spread potential remains elevated"
        case .extreme:
            return "Very dry, windy conditions support fast spread"
        }
    }
}
