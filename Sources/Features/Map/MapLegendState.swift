//
//  MapLegendState.swift
//  SkyAware
//
//  Created by Codex on 7/13/26.
//

import ArcusCore
import Foundation

struct MapForecastPeriod: Sendable, Equatable {
    let issued: Date
    let valid: Date
    let expires: Date
}

struct MapLegendState: Sendable {
    let presentationState: MapLegendPresentationState
    let layer: MapLayer
    let severeItems: [SevereLegendItem]
    let fireItems: [FireLegendItem]
    let showsHatchingExplanation: Bool
    var forecastDay: SPCForecastDay = .day1
    var forecastPeriod: MapForecastPeriod?

    var allowsInteraction: Bool {
        showsHatchingExplanation &&
        !severeItems.isEmpty &&
        presentationState != .loading &&
        presentationState != .confirmedEmpty &&
        presentationState != .unavailable
    }

    static func loading(for layer: MapLayer) -> MapLegendState {
        MapLegendState(
            presentationState: .loading,
            layer: layer,
            severeItems: [],
            fireItems: [],
            showsHatchingExplanation: false
        )
    }

    static func resolving(
        for layer: MapLayer,
        severeItems: [SevereLegendItem],
        fireItems: [FireLegendItem],
        showsHatchingExplanation: Bool
    ) -> MapLegendState {
        MapLegendState(
            presentationState: .resolving,
            layer: layer,
            severeItems: severeItems,
            fireItems: fireItems,
            showsHatchingExplanation: showsHatchingExplanation
        )
    }

    static func current(
        for layer: MapLayer,
        severeItems: [SevereLegendItem],
        fireItems: [FireLegendItem],
        showsHatchingExplanation: Bool
    ) -> MapLegendState {
        MapLegendState(
            presentationState: .current,
            layer: layer,
            severeItems: severeItems,
            fireItems: fireItems,
            showsHatchingExplanation: showsHatchingExplanation
        )
    }

    static func confirmedEmpty(for layer: MapLayer) -> MapLegendState {
        MapLegendState(
            presentationState: .confirmedEmpty,
            layer: layer,
            severeItems: [],
            fireItems: [],
            showsHatchingExplanation: false
        )
    }

    static func stale(
        for layer: MapLayer,
        severeItems: [SevereLegendItem],
        fireItems: [FireLegendItem],
        showsHatchingExplanation: Bool
    ) -> MapLegendState {
        MapLegendState(
            presentationState: .stale,
            layer: layer,
            severeItems: severeItems,
            fireItems: fireItems,
            showsHatchingExplanation: showsHatchingExplanation
        )
    }

    static func unavailable(for layer: MapLayer) -> MapLegendState {
        MapLegendState(
            presentationState: .unavailable,
            layer: layer,
            severeItems: [],
            fireItems: [],
            showsHatchingExplanation: false
        )
    }

    func withPresentationState(_ presentationState: MapLegendPresentationState) -> MapLegendState {
        var state = MapLegendState(
            presentationState: presentationState,
            layer: layer,
            severeItems: severeItems,
            fireItems: fireItems,
            showsHatchingExplanation: showsHatchingExplanation
        )
        state.forecastDay = forecastDay
        state.forecastPeriod = forecastPeriod
        return state
    }

    func withForecast(day: SPCForecastDay, period: MapForecastPeriod? = nil) -> MapLegendState {
        var state = self
        state.forecastDay = day
        state.forecastPeriod = period
        return state
    }

    var headlineText: String {
        forecastDay == .day2 || forecastDay == .day3
            ? "\(forecastDay.description) · \(statusHeadlineText)" : statusHeadlineText
    }

    private var statusHeadlineText: String {
        switch presentationState {
        case .loading:
            "Getting \(layer.legendSubject)…"
        case .resolving:
            "\(layer.legendDisplayTitle) · Updating"
        case .current:
            layer.legendDisplayTitle
        case .confirmedEmpty:
            "No \(layer.legendSubject)"
        case .stale:
            "\(layer.legendDisplayTitle) saved locally"
        case .unavailable:
            "\(layer.legendDisplayTitle) unavailable"
        }
    }

    var voiceOverText: String {
        guard forecastDay == .day2 || forecastDay == .day3 else { return statusVoiceOverText }
        let periodText = forecastPeriod.map {
            " Issued \($0.issued.formatted()). Valid \($0.valid.formatted()) through \($0.expires.formatted())."
        } ?? ""
        let status = presentationState == .stale ? "Showing saved forecast data." : statusVoiceOverText
        return "\(forecastDay.description). \(status)\(periodText)"
    }

    private var statusVoiceOverText: String {
        switch presentationState {
        case .loading:
            "Getting \(layer.legendSubject). Loading."
        case .resolving:
            "Updating \(layer.legendSubject). Showing saved data while the refresh completes."
        case .current:
            "\(layer.legendDisplayTitle) loaded."
        case .confirmedEmpty:
            "No \(layer.legendSubject). Successfully loaded and confirmed empty."
        case .stale:
            "\(layer.legendDisplayTitle) saved locally. Refresh failed."
        case .unavailable:
            "\(layer.legendDisplayTitle) unavailable. No saved data."
        }
    }
}

enum MapLegendPresentationState: Sendable, Equatable {
    case loading
    case resolving
    case current
    case confirmedEmpty
    case stale
    case unavailable
}

struct SevereLegendItem: Sendable, Hashable, Identifiable {
    let id: String
    let probability: ThreatProbability
    let fillHex: String?
    let strokeHex: String?
}

struct FireLegendItem: Sendable, Hashable, Identifiable {
    let riskLevel: Int
    let riskLevelDescription: String
    let fillHex: String?
    let strokeHex: String?

    var id: Int { riskLevel }
}

private extension MapLayer {
    var legendDisplayTitle: String {
        switch self {
        case .categorical:
            return "Severe Risk"
        case .wind:
            return "Wind Risk"
        case .hail:
            return "Hail Risk"
        case .tornado:
            return "Tornado Risk"
        case .meso:
            return "Mesoscale"
        case .fire:
            return "Fire Risk"
        }
    }

    var legendSubject: String {
        switch self {
        case .categorical:
            return "severe risk"
        case .wind:
            return "wind risk"
        case .hail:
            return "hail risk"
        case .tornado:
            return "tornado risk"
        case .meso:
            return "mesoscale"
        case .fire:
            return "fire risk"
        }
    }
}
