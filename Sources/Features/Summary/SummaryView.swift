//
//  SummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI
import Foundation

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
    let stormSetupPreferences: StormSetupPreferences
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let mesos: [MdDTO]
    let alerts: [AlertDTO]
    let outlook: ConvectiveOutlookDTO?
    let weather: SummaryWeather?
    let locationTimeZone: TimeZone
    let todayContentState: TodayContentState
    let localAlertsDisplayState: LocalAlertsDisplayState
    let readinessState: SummaryReadinessState
    let resolutionState: SummaryResolutionState
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
        stormSetupPreferences: StormSetupPreferences = StormSetupPreferences(),
        stormRisk: StormRiskLevel? = nil,
        severeRisk: SevereWeatherThreat? = nil,
        fireRisk: FireRiskLevel? = nil,
        mesos: [MdDTO] = [],
        alerts: [AlertDTO] = [],
        outlook: ConvectiveOutlookDTO? = nil,
        weather: SummaryWeather? = nil,
        locationTimeZone: TimeZone = .autoupdatingCurrent,
        todayContentState: TodayContentState,
        localAlertsDisplayState: LocalAlertsDisplayState,
        readinessState: SummaryReadinessState,
        resolutionState: SummaryResolutionState,
        showsOfflineToken: Bool,
        headerCondenseProgress: CGFloat,
        locationReliabilityRailState: LocationReliabilityRailState? = nil,
        onOpenMapLayer: @escaping (MapLayer) -> Void,
        onOpenAlerts: @escaping () -> Void,
        onOpenOutlooks: @escaping () -> Void
    ) {
        self.snap = snap
        self.stormSetup = stormSetup
        self.stormSetupPreferences = stormSetupPreferences
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
        self.mesos = mesos
        self.alerts = alerts
        self.outlook = outlook
        self.weather = weather
        self.locationTimeZone = locationTimeZone
        self.todayContentState = todayContentState
        self.localAlertsDisplayState = localAlertsDisplayState
        self.readinessState = readinessState
        self.resolutionState = resolutionState
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
        let stormSetupDetailPresentation = stormSetupDetailPresentation(now: now)
        let sectionPlan = Self.sectionPlan(
            localAlertsDisplayState: localAlertsDisplayState,
            showsStormSetup: stormSetupDetailPresentation != nil,
            hasLocationReliabilityRail: locationReliabilityRailState != nil
        )

        ForEach(sectionPlan.sections) { section in
            sectionView(for: section, stormSetupDetailPresentation: stormSetupDetailPresentation)
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
        stormSetupDetailPresentation: StormSetupDetailPresentation?
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
            if isLocationUnavailable == false,
               let presentation = stormSetupDetailPresentation {
                NavigationLink {
                    StormSetupDetailView(presentation: presentation)
                } label: {
                    StormSetupSummaryCard(presentation: presentation.summaryPresentation)
                }
                .buttonStyle(.plain)
            }

        case .atmosphericConditions:
            if isLocationUnavailable == false {
                AtmosphericConditionsCard(weather: weather, isOffline: showsOfflineToken)
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
            now: now
        )
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

// MARK: Previews
#Preview("Summary – Thunderstorms") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .thunderstorm,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Tornado Primary") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Moderate Storm Risk") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .moderate,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Quiet Weather") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – AX1 Stacked Awareness") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .high,
            severeRisk: .hail(probability: 0.30),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            alerts: []
        )
        .environment(\.dynamicTypeSize, .accessibility1)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – No Cache Resolving Weather") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: nil,
            severeRisk: nil,
            fireRisk: nil,
            weather: nil,
            todayContentState: .noCacheResolving,
            readinessState: .loadingLocalData,
            showsOfflineToken: false,
            outlook: nil,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Weather") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: nil,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Complete") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .moderate,
            severeRisk: .hail(probability: 0.20),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Empty Alerts") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Unavailable Weather") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: nil,
            severeRisk: nil,
            fireRisk: nil,
            weather: nil,
            todayContentState: .unavailable,
            readinessState: .ready,
            showsOfflineToken: false,
            outlook: nil,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Populated Alerts") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Risk") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .high,
            severeRisk: .tornado(probability: 0.20),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Local Alerts Location Unavailable") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            readinessState: .locationUnavailable,
            mesos: [],
            alerts: []
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – No Cache Resolving") {
    NavigationStack {
        SummaryPreviewContent(
            snap: nil,
            stormRisk: nil,
            severeRisk: nil,
            fireRisk: nil,
            weather: nil,
            todayContentState: .noCacheResolving,
            readinessState: .loadingLocalData,
            outlook: nil,
            mesos: [],
            alerts: [],
            hasCachedProjectionForAlerts: false,
            lastHotAlertsLoadAt: nil
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Valid Cache Current") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .extreme,
            weather: SummaryPreviewData.weather,
            todayContentState: .current,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Composite") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .moderate,
            severeRisk: .hail(probability: 0.20),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows,
            resolutionState: SummaryPreviewData.calmRefreshState()
        )
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Cached Refreshing Empty Local Alerts") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: [],
            alerts: [],
            resolutionState: SummaryPreviewData.calmRefreshState(primaryTask: .alerts)
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Stale Cache") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .slight,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            todayContentState: .degraded,
            showsOfflineToken: true,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows
        )
        .environment(\.colorScheme, .light)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Stale Refreshing") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .moderate,
            severeRisk: .hail(probability: 0.15),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .staleRefreshing,
            showsOfflineToken: true,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: [],
            alerts: [],
            resolutionState: SummaryPreviewData.calmRefreshState(primaryTask: .weather)
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Degraded With Useful Cached Content") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .high,
            severeRisk: .tornado(probability: 0.20),
            fireRisk: .extreme,
            weather: SummaryPreviewData.weather,
            todayContentState: .degraded,
            showsOfflineToken: true,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Unavailable No Useful Data") {
    NavigationStack {
        SummaryPreviewContent(
            snap: nil,
            stormRisk: nil,
            severeRisk: nil,
            fireRisk: nil,
            weather: nil,
            todayContentState: .unavailable,
            readinessState: .ready,
            outlook: nil,
            mesos: [],
            alerts: [],
            hasCachedProjectionForAlerts: false,
            lastHotAlertsLoadAt: nil
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Partial Data Available") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .moderate,
            severeRisk: nil,
            fireRisk: nil,
            weather: nil,
            todayContentState: .current,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: [MD.sampleDiscussionDTOs[0]],
            alerts: [],
            hasCachedProjectionForAlerts: true,
            lastHotAlertsLoadAt: .now
        )
        .environment(\.dynamicTypeSize, .accessibility3)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Current Weather Retained During Refresh") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows,
            resolutionState: SummaryPreviewData.calmRefreshState(primaryTask: .weather)
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Atmospheric Values Retained During Refresh") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows,
            resolutionState: SummaryPreviewData.calmRefreshState(primaryTask: .weather)
        )
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Local Alerts Update Present") {
    NavigationStack {
        SummaryPreviewContent(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            weather: SummaryPreviewData.weather,
            todayContentState: .cachedRefreshing,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows,
            resolutionState: SummaryPreviewData.calmRefreshState(primaryTask: .alerts)
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Summary – Storm Setup Ordering") {
    NavigationStack {
        SummaryPreviewContent(
            stormSetup: SummaryPreviewData.stormSetup,
            stormSetupPreferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
            stormRisk: .moderate,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            weather: SummaryPreviewData.weather,
            locationTimeZone: TimeZone(identifier: "America/Denver")!,
            todayContentState: .current,
            outlook: ConvectiveOutlook.sampleOutlookDtos.first,
            mesos: MD.sampleDiscussionDTOs,
            alerts: Watch.sampleWatchRows,
            localAlertsDisplayState: .current(content: .populated, source: .cached)
        )
        .environment(\.dynamicTypeSize, .accessibility1)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct SummaryPreviewContent: View {
    let snap: LocationSnapshot?
    let stormSetup: StormSetupDTO?
    let stormSetupPreferences: StormSetupPreferences
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let weather: SummaryWeather?
    let locationTimeZone: TimeZone
    let todayContentState: TodayContentState
    let readinessState: SummaryReadinessState
    let showsOfflineToken: Bool
    let outlook: ConvectiveOutlookDTO?
    let mesos: [MdDTO]
    let alerts: [AlertDTO]
    let resolutionState: SummaryResolutionState
    let localAlertsDisplayState: LocalAlertsDisplayState?
    let hasCachedProjectionForAlerts: Bool
    let lastHotAlertsLoadAt: Date?
    let isCurrentContextResolvedInPipeline: Bool

    init(
        snap: LocationSnapshot? = SummaryPreviewData.snapshot,
        stormSetup: StormSetupDTO? = nil,
        stormSetupPreferences: StormSetupPreferences = .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        fireRisk: FireRiskLevel? = .extreme,
        weather: SummaryWeather?,
        locationTimeZone: TimeZone = .current,
        todayContentState: TodayContentState = .current,
        readinessState: SummaryReadinessState = .ready,
        showsOfflineToken: Bool = false,
        outlook: ConvectiveOutlookDTO? = ConvectiveOutlook.sampleOutlookDtos.first,
        mesos: [MdDTO] = MD.sampleDiscussionDTOs,
        alerts: [AlertDTO] = Watch.sampleWatchRows,
        resolutionState: SummaryResolutionState = SummaryResolutionState(),
        localAlertsDisplayState: LocalAlertsDisplayState? = nil,
        hasCachedProjectionForAlerts: Bool = true,
        lastHotAlertsLoadAt: Date? = .now,
        isCurrentContextResolvedInPipeline: Bool = false
    ) {
        self.snap = snap
        self.stormSetup = stormSetup
        self.stormSetupPreferences = stormSetupPreferences
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
        self.weather = weather
        self.locationTimeZone = locationTimeZone
        self.todayContentState = todayContentState
        self.readinessState = readinessState
        self.showsOfflineToken = showsOfflineToken
        self.outlook = outlook
        self.mesos = mesos
        self.alerts = alerts
        self.resolutionState = resolutionState
        self.localAlertsDisplayState = localAlertsDisplayState
        self.hasCachedProjectionForAlerts = hasCachedProjectionForAlerts
        self.lastHotAlertsLoadAt = lastHotAlertsLoadAt
        self.isCurrentContextResolvedInPipeline = isCurrentContextResolvedInPipeline
    }

    var body: some View {
        let localAlertsDisplayState = localAlertsDisplayState ?? LocalAlertsDisplayState.from(
            todayContentState: todayContentState,
            hasCachedProjection: hasCachedProjectionForAlerts,
            isCurrentContextResolvedInPipeline: isCurrentContextResolvedInPipeline,
            lastHotAlertsLoadAt: lastHotAlertsLoadAt,
            hasActiveAlerts: !mesos.isEmpty || !alerts.isEmpty,
            isLocationUnavailable: readinessState == .locationUnavailable
        )

        SummaryView(
            snap: snap,
            stormSetup: stormSetup,
            stormSetupPreferences: stormSetupPreferences,
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            fireRisk: fireRisk,
            mesos: mesos,
            alerts: alerts,
            outlook: outlook,
            weather: weather,
            locationTimeZone: locationTimeZone,
            todayContentState: todayContentState,
            localAlertsDisplayState: localAlertsDisplayState,
            readinessState: readinessState,
            resolutionState: resolutionState,
            showsOfflineToken: showsOfflineToken,
            headerCondenseProgress: 0,
            locationReliabilityRailState: .init(onOpen: {}, onDismiss: {}),
            onOpenMapLayer: { _ in },
            onOpenAlerts: {},
            onOpenOutlooks: {}
        )
    }
}

private enum SummaryPreviewData {
    static let snapshot = LocationSnapshot(
        coordinates: .init(latitude: 39.75, longitude: -104.44),
        timestamp: .now,
        accuracy: 20,
        placemarkSummary: "Bennett, CO"
    )

    static let weather = SummaryWeather(
        temperature: Measurement(value: 82.0, unit: .fahrenheit),
        symbolName: "sun.max.fill",
        conditionText: "Warm and humid",
        asOf: .now,
        dewPoint: Measurement(value: 68.0, unit: .fahrenheit),
        humidity: 0.66,
        windSpeed: Measurement(value: 22.0, unit: .milesPerHour),
        windGust: Measurement(value: 34.0, unit: .milesPerHour),
        windDirection: "SSW",
        pressure: Measurement(value: 29.78, unit: .inchesOfMercury),
        pressureTrend: "falling"
    )

    static let stormSetup = StormSetupDTO(
        h3Cell: 8_623_451_234_567_890,
        freshness: .init(
            isStale: false,
            isDegraded: false,
            modelRunTime: .now,
            sourceValidTime: .now,
            forecastHour: 3,
            fetchedAt: .now,
            expiresAt: .now.addingTimeInterval(3_600)
        ),
        source: .init(
            model: "HRRR",
            product: "Storm Setup",
            domain: "severe",
            fieldSetVersion: "1",
            sourceKind: "production",
            runTime: .now,
            validTime: .now,
            forecastHour: 3,
            bbox: .init(toplat: 41.5, leftlon: -104.3, rightlon: -96.2, bottomlat: 36.8),
            primaryDownloadURL: "https://example.invalid/storm-setup"
        ),
        raw: .init(
            mlcapeJkg: 1_850,
            mucapeJkg: 2_200.5,
            sbcapeJkg: 1_700,
            mlcinJkg: -42,
            srh01kmM2s2: 125.5,
            srh03kmM2s2: 175,
            shear06kmKt: 42,
            mllclM: 980,
            tempDewPtDeltaF: 4.5,
            threeCapeJkg: 95
        ),
        assessment: .init(
            overall: "strong",
            summary: "The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation.",
            instability: "supportive",
            moisture: "supportive",
            lowLevelRotation: "conditional",
            deepShear: "strong",
            cloudBase: "weak",
            capInhibition: "weak",
            limitingFactors: ["capping"],
            confidence: "high",
            primaryDrivers: ["instability", "shear"],
            stormMode: "supportive",
            stormModeHint: "supportive",
            trend: "conditional",
            compositeSignal: "strong"
        ),
        anvilEvidence: nil,
        centroid: .init(latitude: 39.5, longitude: -100.0),
        surfaceHeightMslM: 1132.4
    )

    static func calmRefreshState(primaryTask: SummaryProviderTask = .weather) -> SummaryResolutionState {
        var state = SummaryResolutionState()
        state.begin(task: primaryTask, sections: [.conditions, .atmosphere, .alerts, .outlook])
        return state
    }
}
