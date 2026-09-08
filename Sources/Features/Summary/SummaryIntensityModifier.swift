import CoreLocation
import Foundation
import OSLog
import SwiftUI

struct LocalSevereIntensity: Equatable, Sendable {
    let presentation: SevereIntensityPresentation
    let expires: Date
}

struct SummaryIntensityRequest: Equatable, Sendable {
    let projectionKey: String
    let latitude: Double
    let longitude: Double
    let threat: SevereWeatherThreat
    let sourceToken: String

    init?(projection: HomeProjectionRecord?, location: LocationSnapshot?, threat: SevereWeatherThreat?,
          contentState: TodayContentState) {
        guard contentState != .noCacheResolving, contentState != .unavailable,
              let projection, let location, let threat, threat != .allClear, threat.probability > 0,
              projection.severeRisk == threat,
              projection.latitude == location.coordinates.latitude,
              projection.longitude == location.coordinates.longitude,
              let token = projection.convectiveSourceToken, token.hasPrefix("forecast:") else { return nil }
        latitude = projection.latitude
        projectionKey = projection.projectionKey
        longitude = projection.longitude
        self.threat = threat
        sourceToken = token
    }
}

/// A transient read of already-persisted geometry. Task identity prevents first-frame location leakage.
struct SummaryIntensityModifier: ViewModifier {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.scenePhase) private var scenePhase
    @State private var loadedRequest: SummaryIntensityRequest?
    @State private var loadedIntensity: LocalSevereIntensity?

    let request: SummaryIntensityRequest?
    let refreshRevision: Date?
    let isRefreshing: Bool

    private struct LoadKey: Equatable {
        let request: SummaryIntensityRequest?
        let revision: Date?
        let isActive: Bool
        let isRefreshing: Bool
    }

    func body(content: Content) -> some View {
        let key = LoadKey(request: request, revision: refreshRevision,
                          isActive: scenePhase == .active, isRefreshing: isRefreshing)
        content
            .environment(\.severeIntensity, visibleIntensity)
            .task(id: key) {
                guard let request, key.isActive else { return }
                do {
                    let result = try await dependencies.severeRiskRepo.localIntensity(
                        for: CLLocationCoordinate2D(latitude: request.latitude, longitude: request.longitude),
                        threat: request.threat,
                        sourceToken: request.sourceToken
                    )
                    try Task.checkCancellation()
                    loadedRequest = request
                    loadedIntensity = nil
                    if let result, let presentation = SevereIntensityPresentation(hazard: result.hazard, level: result.level) {
                        loadedIntensity = LocalSevereIntensity(presentation: presentation, expires: result.expires)
                        try await Task.sleep(for: .seconds(max(0, result.expires.timeIntervalSinceNow)))
                        loadedIntensity = nil
                    }
                } catch is CancellationError {
                    // A new location, forecast, or scene state owns the next read.
                } catch {
                    if !Task.isCancelled {
                        loadedIntensity = nil
                        Logger.reposSevereRisk.error("Unable to read local storm intensity")
                    }
                }
            }
    }

    private var visibleIntensity: SevereIntensityPresentation? {
        Self.visibleIntensity(request: request, loadedRequest: loadedRequest, intensity: loadedIntensity, now: .now)
    }

    static func visibleIntensity(
        request: SummaryIntensityRequest?, loadedRequest: SummaryIntensityRequest?,
        intensity: LocalSevereIntensity?, now: Date
    ) -> SevereIntensityPresentation? {
        guard request != nil, loadedRequest == request, let intensity, intensity.expires > now else { return nil }
        return intensity.presentation
    }
}
