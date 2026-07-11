//
//  HomeProjectionStore.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import ArcusCore
import SwiftData

@ModelActor
actor HomeProjectionStore {
    func projection(for context: LocationContext) throws -> HomeProjectionRecord? {
        try fetchProjection(withKey: HomeProjection.projectionKey(for: context))?.record
    }

    func latestProjectionForWidgetSnapshotRefresh() throws -> HomeProjectionRecord? {
        try fetchLatestProjection()?.record
    }

    func fetchOrCreateProjection(
        for context: LocationContext,
        viewedAt: Date = .now
    ) throws -> HomeProjectionRecord {
        let projection = try fetchOrCreateModel(for: context, touchedAt: viewedAt, viewedAt: viewedAt)
        return projection.record
    }

    func updateWeather(
        _ weather: SummaryWeather?,
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> HomeProjectionRecord {
        let projection = try fetchOrCreateModel(for: context, touchedAt: loadedAt)
        projection.weatherPayload = weather.map(HomeProjectionWeatherPayload.init(summary:))
        projection.lastWeatherLoadAt = loadedAt
        projection.updatedAt = loadedAt
        try modelContext.save()
        return projection.record
    }

    func updateStormSetup(
        _ stormSetup: StormSetupCurrentResponse,
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> HomeProjectionRecord {
        let projection = try fetchOrCreateModel(for: context, touchedAt: loadedAt)
        projection.stormSetupCurrentResponse = stormSetup
        projection.lastStormSetupLoadAt = loadedAt
        projection.updatedAt = loadedAt
        try modelContext.save()
        return projection.record
    }

    func updateStormSetup(
        _ stormSetup: StormSetupDTO,
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> HomeProjectionRecord {
        try updateStormSetup(
            Self.makeStormSetupCurrentResponse(from: stormSetup),
            for: context,
            loadedAt: loadedAt
        )
    }

    func updateStormSetupProfileAnalysis(
        _ profileAnalysis: HomeProjectionStormSetupProfileAnalysisPayload,
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> HomeProjectionRecord {
        _ = profileAnalysis
        let projection = try fetchProjection(withKey: HomeProjection.projectionKey(for: context))
            ?? HomeProjection(context: context, createdAt: loadedAt)
        return projection.record
    }

    func updateSlowProducts(
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        fireRisk: FireRiskLevel?,
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> HomeProjectionRecord {
        let projection = try fetchOrCreateModel(for: context, touchedAt: loadedAt)
        projection.stormRisk = stormRisk
        projection.severeRisk = severeRisk
        projection.fireRisk = fireRisk
        projection.lastSlowProductsLoadAt = loadedAt
        projection.updatedAt = loadedAt
        try modelContext.save()
        return projection.record
    }

    func updateHotAlerts(
        alerts: [AlertDTO],
        mesos: [MdDTO],
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> HomeProjectionRecord {
        let projection = try fetchOrCreateModel(for: context, touchedAt: loadedAt)
        projection.activeAlerts = alerts
        projection.activeMesos = mesos
        projection.lastHotAlertsLoadAt = loadedAt
        projection.updatedAt = loadedAt
        try modelContext.save()
        return projection.record
    }

    private func fetchOrCreateModel(
        for context: LocationContext,
        touchedAt: Date,
        viewedAt: Date? = nil
    ) throws -> HomeProjection {
        if let existing = try fetchProjection(withKey: HomeProjection.projectionKey(for: context)) {
            existing.updateLocationContext(context, touchedAt: touchedAt, viewedAt: viewedAt)
            try modelContext.save()
            return existing
        }

        let projection = HomeProjection(context: context, createdAt: touchedAt, lastViewedAt: viewedAt)
        modelContext.insert(projection)
        try modelContext.save()
        return projection
    }

    private func fetchProjection(withKey projectionKey: String) throws -> HomeProjection? {
        let predicate = #Predicate<HomeProjection> { projection in
            projection.projectionKey == projectionKey
        }
        var descriptor = FetchDescriptor<HomeProjection>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchLatestProjection() throws -> HomeProjection? {
        var descriptor = FetchDescriptor<HomeProjection>(
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse),
                SortDescriptor(\.projectionKey, order: .forward)
            ]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private static func makeStormSetupCurrentResponse(from stormSetup: StormSetupDTO) -> StormSetupCurrentResponse {
        let canonical = Self.makeRawParameters(from: stormSetup.raw)
        return StormSetupCurrentResponse(
            setup: .init(
                h3Cell: stormSetup.h3Cell,
                centroid: .init(
                    latitude: stormSetup.centroid?.latitude ?? 0,
                    longitude: stormSetup.centroid?.longitude ?? 0
                ),
                source: .init(
                    sourceKind: .nomadsFilteredSubset,
                    model: stormSetup.source.model.flatMap(HrrrModel.init(rawValue:)),
                    product: stormSetup.source.product.flatMap(HrrrProduct.init(rawValue:)),
                    domain: stormSetup.source.domain.flatMap(HrrrDomain.init(rawValue:)),
                    runTime: stormSetup.source.runTime,
                    forecastHour: stormSetup.source.forecastHour,
                    validTime: stormSetup.source.validTime,
                    fieldSetVersion: stormSetup.source.fieldSetVersion.flatMap(HrrrFieldSetVersion.init(rawValue:)),
                    bbox: stormSetup.source.bbox.map {
                        .init(
                            leftlon: $0.leftlon,
                            rightlon: $0.rightlon,
                            toplat: $0.toplat,
                            bottomlat: $0.bottomlat
                        )
                    },
                    primaryDownloadURL: stormSetup.source.primaryDownloadURL.flatMap(URL.init(string:)),
                    idxURL: nil
                ),
                surfaceHeightMslM: stormSetup.surfaceHeightMslM,
                freshness: .init(
                    sourceValidTime: stormSetup.freshness.sourceValidTime,
                    modelRunTime: stormSetup.freshness.modelRunTime,
                    forecastHour: stormSetup.freshness.forecastHour,
                    fetchedAt: stormSetup.freshness.fetchedAt,
                    expiresAt: stormSetup.freshness.expiresAt,
                    isStale: stormSetup.freshness.isStale,
                    isDegraded: stormSetup.freshness.isDegraded
                )
            ),
            ingredients: .init(
                canonical: canonical,
                diagnostics: canonical
            ),
            profileAnalysis: nil,
            tornadoViability: .init(
                overall: Self.makeIngredientSupport(from: stormSetup.assessment.overall),
                realization: .unknown,
                primaryFailureMode: .none,
                confidence: Self.makeSnapshotConfidence(from: stormSetup.assessment.confidence),
                summary: stormSetup.assessment.summary ?? "",
                details: .init(
                    stormViability: Self.makeIngredientSupport(from: stormSetup.assessment.trend),
                    supercellViability: Self.makeIngredientSupport(from: stormSetup.assessment.overall),
                    tornadoEfficiency: .unknown,
                    inhibition: Self.makeIngredientSupport(from: stormSetup.assessment.capInhibition),
                    instability: Self.makeIngredientSupport(from: stormSetup.assessment.instability),
                    moisture: Self.makeIngredientSupport(from: stormSetup.assessment.moisture),
                    cloudBase: Self.makeIngredientSupport(from: stormSetup.assessment.cloudBase),
                    deepShear: Self.makeIngredientSupport(from: stormSetup.assessment.deepShear),
                    lowLevelRotation: Self.makeIngredientSupport(from: stormSetup.assessment.lowLevelRotation),
                    lowLevelStretching: .unknown,
                    cloudBaseEfficiency: .unknown,
                    supercellComposite: .unknown,
                    tornadoComposite: .unknown,
                    stormMode: Self.makeIngredientSupport(from: stormSetup.assessment.stormMode)
                ),
                limitingFactors: []
            )
        )
    }

    private static func makeIngredientSupport(from value: String?) -> IngredientSupport {
        IngredientSupport(rawValue: value ?? "") ?? .unknown
    }

    private static func makeSnapshotConfidence(from value: String?) -> SnapshotConfidence {
        switch value {
        case "high":
            return .high
        case "medium", "moderate":
            return .moderate
        case "low":
            return .low
        case "degraded":
            return .degraded
        default:
            return .moderate
        }
    }

    private static func makeRawParameters(from raw: StormSetupDTO.Raw) -> TornadoRawParameters {
        TornadoRawParameters(
            sbcapeJkg: raw.sbcapeJkg,
            mlcapeJkg: raw.mlcapeJkg,
            mucapeJkg: raw.mucapeJkg,
            mlcinJkg: raw.mlcinJkg,
            dcapeJkg: nil,
            mllclM: raw.mllclM,
            tempDewPtDeltaF: raw.tempDewPtDeltaF,
            threeCapeJkg: raw.threeCapeJkg,
            lclLfcSeparationM: nil,
            lapseRate03kmCkm: nil,
            lapseRate700500mbCkm: nil,
            shear06kmKt: raw.shear06kmKt,
            shear03kmKt: nil,
            shear01kmKt: nil,
            effectiveShearKt: nil,
            srh01kmM2s2: raw.srh01kmM2s2,
            srh03kmM2s2: raw.srh03kmM2s2,
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
        )
    }
}
