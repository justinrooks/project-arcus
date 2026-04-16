//
//  HomeProjectionStore.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import SwiftData

@ModelActor
actor HomeProjectionStore {
    func projection(for context: LocationContext) throws -> HomeProjectionRecord? {
        try fetchProjection(withKey: HomeProjection.projectionKey(for: context))?.record
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
        watches: [WatchRowDTO],
        mesos: [MdDTO],
        for context: LocationContext,
        loadedAt: Date = .now
    ) throws -> HomeProjectionRecord {
        let projection = try fetchOrCreateModel(for: context, touchedAt: loadedAt)
        projection.activeAlerts = watches
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
}
