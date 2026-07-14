//
//  SummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI
import Foundation
import ArcusCore

enum SummaryReadinessState: Equatable {
    case loadingLocation
    case resolvingLocalContext
    case loadingLocalData
    case ready
    case locationUnavailable

    var statusText: String {
        switch self {
        case .loadingLocation:
            "Finding your location…"
        case .resolvingLocalContext:
            "Getting your area ready…"
        case .loadingLocalData:
            "Bringing in your conditions…"
        case .ready:
            "Ready"
        case .locationUnavailable:
            "Location not available"
        }
    }
}

enum SummaryContentPresentationState: Equatable {
    case current
    case stale
    case resolving
    case unavailable
    case confirmedEmpty

    static func from(
        isOffline: Bool,
        hasContent: Bool,
        isResolving: Bool,
        isConfirmedEmpty: Bool = false
    ) -> SummaryContentPresentationState {
        if hasContent {
            return isOffline ? .stale : .current
        }

        if isResolving && isOffline == false {
            return .resolving
        }

        if isConfirmedEmpty {
            return .confirmedEmpty
        }

        return .unavailable
    }

    var badgeText: String? {
        switch self {
        case .current, .confirmedEmpty, .resolving:
            return nil
        case .stale:
            return "Offline"
        case .unavailable:
            return "Unavailable"
        }
    }

    var badgeSymbolName: String {
        switch self {
        case .stale:
            return "wifi.slash"
        case .unavailable:
            return "exclamationmark.circle"
        case .current, .resolving, .confirmedEmpty:
            return "circle.fill"
        }
    }

    var accessibilityLabel: String? {
        switch self {
        case .stale:
            return "Offline. Showing saved local data."
        case .unavailable:
            return "Unavailable. No saved local data."
        case .current, .resolving, .confirmedEmpty:
            return nil
        }
    }
}

struct SummaryAvailabilityBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let state: SummaryContentPresentationState

    var body: some View {
        if let badgeText = state.badgeText {
            Label(badgeText, systemImage: state.badgeSymbolName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                )
                .accessibilityLabel(state.accessibilityLabel ?? badgeText)
        }
    }
}

struct SummaryView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    struct LocationReliabilityRailState {
        let onOpen: () -> Void
        let onDismiss: () -> Void
    }

    let snap: LocationSnapshot?
    let stormSetup: StormSetupDTO?
    let stormSetupProfileAnalysisResponse: AnvilAnalyzeProfileResponse?
    let stormSetupPreferences: StormSetupPreferences
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let mesos: [MdDTO]
    let alerts: [AlertDTO]
    let outlook: ConvectiveOutlookDTO?
    let weather: SummaryWeather?
    let airQuality: AirQualityCurrentResponse?
    let locationTimeZone: TimeZone
    let todayContentState: TodayContentState
    let localAlertsDisplayState: LocalAlertsDisplayState
    let readinessState: SummaryReadinessState
    let resolutionState: SummaryResolutionState
    let isRefreshInFlight: Bool
    let showsOfflineToken: Bool
    let headerCondenseProgress: CGFloat
    let locationReliabilityRailState: LocationReliabilityRailState?
    let onOpenMapLayer: (MapLayer) -> Void
    let onOpenAlerts: () -> Void
    let onOpenOutlooks: () -> Void

#if DEBUG
    @AppStorage("stormSetupForceDisplay", store: UserDefaults.shared)
    private var stormSetupForceDisplay: Bool = false
#endif

    init(
        snap: LocationSnapshot? = nil,
        stormSetup: StormSetupDTO? = nil,
        stormSetupProfileAnalysisResponse: AnvilAnalyzeProfileResponse? = nil,
        stormSetupPreferences: StormSetupPreferences = StormSetupPreferences(),
        stormRisk: StormRiskLevel? = nil,
        severeRisk: SevereWeatherThreat? = nil,
        fireRisk: FireRiskLevel? = nil,
        mesos: [MdDTO] = [],
        alerts: [AlertDTO] = [],
        outlook: ConvectiveOutlookDTO? = nil,
        weather: SummaryWeather? = nil,
        airQuality: AirQualityCurrentResponse? = nil,
        locationTimeZone: TimeZone = .autoupdatingCurrent,
        todayContentState: TodayContentState,
        localAlertsDisplayState: LocalAlertsDisplayState,
        readinessState: SummaryReadinessState,
        resolutionState: SummaryResolutionState,
        isRefreshInFlight: Bool = false,
        showsOfflineToken: Bool,
        headerCondenseProgress: CGFloat,
        locationReliabilityRailState: LocationReliabilityRailState? = nil,
        onOpenMapLayer: @escaping (MapLayer) -> Void,
        onOpenAlerts: @escaping () -> Void,
        onOpenOutlooks: @escaping () -> Void
    ) {
        self.snap = snap
        self.stormSetup = stormSetup
        self.stormSetupProfileAnalysisResponse = stormSetupProfileAnalysisResponse
        self.stormSetupPreferences = stormSetupPreferences
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
        self.mesos = mesos
        self.alerts = alerts
        self.outlook = outlook
        self.weather = weather
        self.airQuality = airQuality
        self.locationTimeZone = locationTimeZone
        self.todayContentState = todayContentState
        self.localAlertsDisplayState = localAlertsDisplayState
        self.readinessState = readinessState
        self.resolutionState = resolutionState
        self.isRefreshInFlight = isRefreshInFlight
        self.showsOfflineToken = showsOfflineToken
        self.headerCondenseProgress = headerCondenseProgress
        self.locationReliabilityRailState = locationReliabilityRailState
        self.onOpenMapLayer = onOpenMapLayer
        self.onOpenAlerts = onOpenAlerts
        self.onOpenOutlooks = onOpenOutlooks
    }

    private var isWeatherLoading: Bool {
        weather == nil
    }

    private var statusText: String {
        if let placemark = snap?.placemarkSummary {
            return placemark
        }
        return readinessState.statusText
    }

    private var isLocationUnavailable: Bool {
        readinessState == .locationUnavailable
    }

    enum StormSetupSlotState: Equatable {
        case hidden
        case loading
        case visible(StormSetupDetailPresentation)

        var isVisible: Bool {
            if case .visible = self {
                return true
            }
            return false
        }
    }

    private var hasActiveAlerts: Bool {
        !mesos.isEmpty || !alerts.isEmpty
    }

    private var localAlertsPresentationState: LocalAlertsPresentationState {
        localAlertsDisplayState.presentationState
    }

    private var hasMeaningfulContent: Bool {
        snap != nil ||
        weather != nil ||
        stormRisk != nil ||
        severeRisk != nil ||
        fireRisk != nil ||
        outlook != nil ||
        hasActiveAlerts
    }

    private var showsEmptyResolving: Bool {
        Self.showsEmptyResolving(
            readinessState: readinessState,
            resolutionState: resolutionState,
            hasMeaningfulContent: hasMeaningfulContent,
            isLocationUnavailable: isLocationUnavailable
        )
    }

    private var severeMapLayer: MapLayer {
        switch severeRisk ?? .allClear {
        case .allClear:
            .categorical
        case .wind:
            .wind
        case .hail:
            .hail
        case .tornado:
            .tornado
        }
    }

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    @ViewBuilder
    private var badgeRow: some View {
        Group {
            if adaptiveLayout.usesStackedHeroTiles {
                VStack(spacing: 10) {
                    stormRiskButton
                    severeRiskButton
                }
            } else {
                HStack(spacing: 10) {
                    stormRiskButton
                    severeRiskButton
                }
            }
        }
        .padding(.top, 8)
    }

    private var stormRiskButton: some View {
        let stormRiskShowsResolvingPlaceholder = Self.showsRiskResolvingPlaceholder(
            hasRiskValue: stormRisk != nil,
            todayContentState: todayContentState,
            showsOfflineToken: showsOfflineToken
        )

        return Button {
            onOpenMapLayer(.categorical)
        } label: {
            StormRiskBadgeView(
                level: stormRisk,
                isOffline: showsOfflineToken,
                isResolving: resolutionState.isResolving(.stormRisk),
                showsResolvingPlaceholder: stormRiskShowsResolvingPlaceholder
            )
                .contentShape(RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous))
        }
        .buttonStyle(
            SkyAwarePressableButtonStyle(
                cornerRadius: SkyAwareRadius.large,
                pressedScale: 0.992,
                pressedOverlayOpacity: 0.06
            )
        )
        .summaryResolving(
            resolutionState.isResolving(.stormRisk) && stormRiskShowsResolvingPlaceholder == false && showsOfflineToken == false,
            todayContentState: todayContentState,
            style: .subtle
        )
        .accessibilityHint("Opens the severe risk map.")
    }

    private var severeRiskButton: some View {
        let severeRiskShowsResolvingPlaceholder = Self.showsRiskResolvingPlaceholder(
            hasRiskValue: severeRisk != nil,
            todayContentState: todayContentState,
            showsOfflineToken: showsOfflineToken
        )

        return Button {
            onOpenMapLayer(severeMapLayer)
        } label: {
            SevereWeatherBadgeView(
                threat: severeRisk,
                isOffline: showsOfflineToken,
                isResolving: resolutionState.isResolving(.severeRisk),
                showsResolvingPlaceholder: severeRiskShowsResolvingPlaceholder
            )
                .contentShape(RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous))
        }
        .buttonStyle(
            SkyAwarePressableButtonStyle(
                cornerRadius: SkyAwareRadius.large,
                pressedScale: 0.992,
                pressedOverlayOpacity: 0.06
            )
        )
        .summaryResolving(
            resolutionState.isResolving(.severeRisk) && severeRiskShowsResolvingPlaceholder == false && showsOfflineToken == false,
            todayContentState: todayContentState,
            style: .subtle
        )
        .accessibilityHint("Opens the highlighted severe threat map.")
    }

    private var fireRiskButton: some View {
        Button {
            onOpenMapLayer(.fire)
        } label: {
                FireWeatherRailView(
                    level: fireRisk,
                    isOffline: showsOfflineToken,
                    showsResolvingPlaceholder: Self.showsRiskResolvingPlaceholder(
                        hasRiskValue: fireRisk != nil,
                        todayContentState: todayContentState,
                        showsOfflineToken: showsOfflineToken
                    )
                )
            .contentShape(RoundedRectangle(cornerRadius: SkyAwareRadius.large, style: .continuous))
        }
        .buttonStyle(
            SkyAwarePressableButtonStyle(
                cornerRadius: SkyAwareRadius.large,
                pressedScale: 0.992,
                pressedOverlayOpacity: 0.06
            )
        )
        .summaryResolving(
            resolutionState.isResolving(.fireRisk) && fireRisk != nil && showsOfflineToken == false,
            todayContentState: todayContentState,
            style: .subtle
        )
        .accessibilityHint("Opens the fire risk map.")
    }

    @ViewBuilder
    private var riskSnapshotContent: some View {
        VStack(spacing: 12) {
            PrimaryAwarenessPanel(
                stormRisk: stormRisk,
                severeRisk: severeRisk,
                fireRisk: fireRisk,
                alerts: alerts,
                todayContentState: todayContentState,
                resolutionState: resolutionState,
                showsOfflineToken: showsOfflineToken,
                onOpenMapLayer: onOpenMapLayer,
                onOpenAlerts: onOpenAlerts
            )
        }
    }

    @ViewBuilder
    private func summaryContent(now: Date) -> some View {
        let stormSetupSlotState = stormSetupSlotState(now: now)
        let sectionPlan = Self.sectionPlan(
            localAlertsDisplayState: localAlertsDisplayState,
            showsStormSetup: stormSetupSlotState.isVisible,
            hasLocationReliabilityRail: locationReliabilityRailState != nil
        )

        ForEach(sectionPlan.sections) { section in
            sectionView(for: section, stormSetupSlotState: stormSetupSlotState)
        }
    }

    var body: some View {
        let now = Date()
        VStack(spacing: 18) {
            if todayContentState.showsResolvingSurface {
                LoadingView(message: resolutionState.primaryActiveMessage ?? readinessState.statusText)
            } else {
                summaryContent(now: now)
                    .transition(.summaryContentEntrance(reduceMotion: reduceMotion))
            }

            Spacer(minLength: 14)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .animation(SkyAwareMotion.settle(reduceMotion), value: todayContentState.showsResolvingSurface)
    }

    private func emptySectionCard(title: String, message: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .sectionLabel()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardBackground(
            cornerRadius: SkyAwareRadius.card,
            shadowOpacity: colorScheme == .dark ? 0.06 : 0.10,
            shadowRadius: colorScheme == .dark ? 6 : 8,
            shadowY: colorScheme == .dark ? 2 : 3
        )
    }

    private func unavailableCard(title: String, message: String, symbol: String) -> some View {
        emptySectionCard(title: title, message: message, symbol: symbol)
    }

    @ViewBuilder
    private func sectionView(
        for section: SummarySectionKind,
        stormSetupSlotState: StormSetupSlotState
    ) -> some View {
        switch section {
        case .currentConditions:
            SummaryStatus(
                statusText: statusText,
                weather: weather,
                resolutionState: resolutionState,
                todayContentState: todayContentState,
                showsOfflineToken: showsOfflineToken,
                isLocationUnavailable: isLocationUnavailable,
                condenseProgress: headerCondenseProgress
            )

        case .primaryAwareness:
            if isLocationUnavailable {
                unavailableCard(
                    title: "Location Required",
                    message: "Enable location access to load local risk, alerts, and weather conditions.",
                    symbol: "location.slash"
                )
            } else {
                riskSnapshotContent
            }

        case .localAlerts:
            localAlertsSection

        case .stormSetup:
            Group {
                switch stormSetupSlotState {
                case .hidden:
                    EmptyView()

                case .loading:
                    StormSetupSummaryCard(
                        presentation: .loadingPlaceholder,
                        isLoading: true
                    )
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("summary-storm-setup-card-loading")
                    .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .center)))

                case .visible(let presentation):
                    NavigationLink {
                        StormSetupDetailView(presentation: presentation)
                    } label: {
                        StormSetupSummaryCard(presentation: presentation.summaryPresentation)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("summary-storm-setup-card")
                    .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .center)))
                }
            }
            .animation(SkyAwareMotion.settle(reduceMotion), value: stormSetupSlotState)

        case .atmosphericConditions:
            if isLocationUnavailable == false {
                AtmosphericConditionsCard(weather: weather, airQuality: airQuality, isOffline: showsOfflineToken)
                    .allowsHitTesting(!isWeatherLoading)
                    .placeholder(isWeatherLoading && showsOfflineToken == false, animated: true)
                    .summaryResolving(
                        resolutionState.isResolving(.atmosphere) && showsOfflineToken == false,
                        todayContentState: todayContentState,
                        style: .subtle
                    )
            }

        case .locationReliability:
            if let locationReliabilityRailState {
                LocationReliabilitySummaryRailView(
                    onOpen: locationReliabilityRailState.onOpen,
                    onDismiss: locationReliabilityRailState.onDismiss
                )
            }

        case .outlookSummary:
            OutlookSummaryCard(
                outlook: outlook,
                isLoading: outlook == nil && (readinessState == .loadingLocation || readinessState == .resolvingLocalContext),
                isPending: outlook == nil && !(readinessState == .loadingLocation || readinessState == .resolvingLocalContext),
                todayContentState: todayContentState,
                onBrowseAllOutlooks: onOpenOutlooks
            )
            .summaryResolving(
                resolutionState.isResolving(.outlook),
                todayContentState: todayContentState,
                style: .subtle
            )

        case .attribution:
            AttributionView()
        }
    }

    @ViewBuilder
    private var localAlertsSection: some View {
        switch localAlertsPresentationState {
        case .unavailable:
            unavailableCard(
                title: "Location Required",
                message: "Active alerts appear after SkyAware resolves your local county and fire zone.",
                symbol: "location.slash"
            )

        case .loading, .alerts, .empty:
            ActiveAlertSummaryView(
                mesos: mesos,
                alerts: alerts,
                localAlertsDisplayState: localAlertsDisplayState,
                todayContentState: todayContentState,
                isOffline: localAlertsDisplayState.showsOfflineStatusCopy,
                onOpenAlertCenter: onOpenAlerts
            )
            .summaryResolving(
                localAlertsDisplayState.usesSummaryResolvingTreatment &&
                resolutionState.isResolving(.alerts),
                todayContentState: todayContentState,
                style: .subtle
            )
        }
    }

    private func stormSetupDetailPresentation(now: Date) -> StormSetupDetailPresentation? {
        guard let stormSetup else {
            return nil
        }

#if DEBUG
        if stormSetupForceDisplay {
            return StormSetupDetailPresentation(
                dto: stormSetup,
                preferences: stormSetupPreferences,
                forecastLocationTimeZone: locationTimeZone,
                profileAnalysisResponse: stormSetupProfileAnalysisResponse,
                now: now
            )
        }
#endif

        let selectionInput = StormSetupPolicyInput(
            preferences: stormSetupPreferences,
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            hasActiveAlert: !alerts.isEmpty,
            hasActiveMeso: !mesos.isEmpty,
            assessmentOverall: StormSetupAssessment(dto: stormSetup).assessment.overall,
            payloadExpiresAt: stormSetup.freshness.expiresAt,
            now: now
        )

        guard StormSetupDisplayPolicy.shouldShow(selectionInput) else {
            return nil
        }

        return StormSetupDetailPresentation(
            dto: stormSetup,
            preferences: stormSetupPreferences,
            forecastLocationTimeZone: locationTimeZone,
            profileAnalysisResponse: stormSetupProfileAnalysisResponse,
            now: now
        )
    }

    private func stormSetupSlotState(now: Date) -> StormSetupSlotState {
        Self.stormSetupSlotState(
            presentation: stormSetupDetailPresentation(now: now),
            hasStormSetup: stormSetup != nil,
            stormSetupEnabled: stormSetupPreferences.stormSetupEnabled,
            isRefreshInFlight: isRefreshInFlight,
            isLocationUnavailable: isLocationUnavailable
        )
    }

    static func stormSetupSlotState(
        presentation: StormSetupDetailPresentation?,
        hasStormSetup: Bool,
        stormSetupEnabled: Bool,
        isRefreshInFlight: Bool,
        isLocationUnavailable: Bool
    ) -> StormSetupSlotState {
        guard isLocationUnavailable == false, stormSetupEnabled else {
            return .hidden
        }

        if let presentation {
            return .visible(presentation)
        }

        if hasStormSetup == false, isRefreshInFlight {
            return .loading
        }

        return .hidden
    }

    private static func sectionPlan(
        localAlertsDisplayState: LocalAlertsDisplayState,
        showsStormSetup: Bool,
        hasLocationReliabilityRail: Bool
    ) -> SummarySectionPlan {
        SummarySectionPlan.make(
            localAlertsDisplayState: localAlertsDisplayState,
            showsStormSetup: showsStormSetup,
            hasLocationReliabilityRail: hasLocationReliabilityRail
        )
    }

    static func showsEmptyResolving(
        readinessState: SummaryReadinessState,
        resolutionState: SummaryResolutionState,
        hasMeaningfulContent: Bool,
        isLocationUnavailable: Bool
    ) -> Bool {
        isLocationUnavailable == false &&
        hasMeaningfulContent == false &&
        ((readinessState == .loadingLocation || readinessState == .resolvingLocalContext || readinessState == .loadingLocalData)
            || resolutionState.isRefreshing)
    }

    static func showsRiskResolvingPlaceholder(
        hasRiskValue: Bool,
        todayContentState: TodayContentState,
        showsOfflineToken: Bool
    ) -> Bool {
        guard showsOfflineToken == false, hasRiskValue == false else {
            return false
        }
        return todayContentState.showsResolvingSurface
    }
}

private struct SummaryContentEntranceModifier: ViewModifier {
    let blurRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: blurRadius)
            .opacity(blurRadius == 0 ? 1 : 0)
    }
}

private extension AnyTransition {
    static func summaryContentEntrance(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }

        return .modifier(
            active: SummaryContentEntranceModifier(blurRadius: SkyAwareMotion.resolvingBlur),
            identity: SummaryContentEntranceModifier(blurRadius: 0)
        )
    }
}
