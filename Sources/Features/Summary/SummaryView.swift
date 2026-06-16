//
//  SummaryView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/9/25.
//

import SwiftUI

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

    enum LocalAlertsPresentationState: Equatable {
        case unavailable
        case loading
        case alerts
        case empty
    }

    let snap: LocationSnapshot?
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let mesos: [MdDTO]
    let alerts: [AlertDTO]
    let outlook: ConvectiveOutlookDTO?
    let weather: SummaryWeather?
    let todayContentState: TodayContentState
    let readinessState: SummaryReadinessState
    let resolutionState: SummaryResolutionState
    let showsOfflineToken: Bool
    let headerCondenseProgress: CGFloat
    let locationReliabilityRailState: LocationReliabilityRailState?
    let onOpenMapLayer: (MapLayer) -> Void
    let onOpenAlerts: () -> Void
    let onOpenOutlooks: () -> Void

    private var hasActiveAlerts: Bool {
        !mesos.isEmpty || !alerts.isEmpty
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

    private var localAlertsPresentationState: LocalAlertsPresentationState {
        Self.localAlertsPresentationState(
            todayContentState: todayContentState,
            hasActiveAlerts: hasActiveAlerts,
            isLocationUnavailable: isLocationUnavailable
        )
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
    private var summaryContent: some View {
        SummaryStatus(
            statusText: statusText,
            weather: weather,
            resolutionState: resolutionState,
            showsOfflineToken: showsOfflineToken,
            isLocationUnavailable: isLocationUnavailable,
            condenseProgress: headerCondenseProgress
        )

        if isLocationUnavailable {
            unavailableCard(
                title: "Location Required",
                message: "Enable location access to load local risk, alerts, and weather conditions.",
                symbol: "location.slash"
            )
        } else {
            riskSnapshotContent

            AtmosphericConditionsCard(weather: weather, isOffline: showsOfflineToken)
                .allowsHitTesting(!isWeatherLoading)
                .placeholder(isWeatherLoading && showsOfflineToken == false, animated: true)
                .summaryResolving(
                    resolutionState.isResolving(.atmosphere) && showsOfflineToken == false,
                    style: .subtle
                )
        }

        if let locationReliabilityRailState {
            LocationReliabilitySummaryRailView(
                onOpen: locationReliabilityRailState.onOpen,
                onDismiss: locationReliabilityRailState.onDismiss
            )
        }

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
                isLoading: localAlertsPresentationState == .loading,
                isOffline: showsOfflineToken,
                onOpenAlertCenter: onOpenAlerts
            )
            .summaryResolving(
                Self.appliesLocalAlertsResolving(
                    presentationState: localAlertsPresentationState,
                    resolutionState: resolutionState,
                    showsOfflineToken: showsOfflineToken
                ),
                style: .subtle
            )
        }

        OutlookSummaryCard(
            outlook: outlook,
            isLoading: outlook == nil && (readinessState == .loadingLocation || readinessState == .resolvingLocalContext),
            isPending: outlook == nil && !(readinessState == .loadingLocation || readinessState == .resolvingLocalContext),
            onBrowseAllOutlooks: onOpenOutlooks
        )
        .summaryResolving(resolutionState.isResolving(.outlook), style: .subtle)

        AttributionView()
    }

    var body: some View {
        VStack(spacing: 18) {
            if todayContentState.showsResolvingSurface {
                LoadingView(message: resolutionState.primaryActiveMessage ?? readinessState.statusText)
            } else {
                summaryContent
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

    static func localAlertsPresentationState(
        todayContentState: TodayContentState,
        hasActiveAlerts: Bool,
        isLocationUnavailable: Bool
    ) -> LocalAlertsPresentationState {
        if isLocationUnavailable {
            return .unavailable
        }
        if hasActiveAlerts {
            return .alerts
        }
        if todayContentState.showsResolvingSurface {
            return .loading
        }

        return .empty
    }

    static func appliesLocalAlertsResolving(
        presentationState: LocalAlertsPresentationState,
        resolutionState: SummaryResolutionState,
        showsOfflineToken: Bool
    ) -> Bool {
        guard showsOfflineToken == false, resolutionState.isResolving(.alerts) else {
            return false
        }

        switch presentationState {
        case .alerts, .empty:
            return true
        case .loading, .unavailable:
            return false
        }
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

private struct SummaryPreviewContent: View {
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let weather: SummaryWeather?
    let todayContentState: TodayContentState
    let readinessState: SummaryReadinessState
    let showsOfflineToken: Bool
    let outlook: ConvectiveOutlookDTO?
    let mesos: [MdDTO]
    let alerts: [AlertDTO]

    init(
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        fireRisk: FireRiskLevel? = .extreme,
        weather: SummaryWeather?,
        todayContentState: TodayContentState = .current,
        readinessState: SummaryReadinessState = .ready,
        showsOfflineToken: Bool = false,
        outlook: ConvectiveOutlookDTO? = ConvectiveOutlook.sampleOutlookDtos.first,
        mesos: [MdDTO] = MD.sampleDiscussionDTOs,
        alerts: [AlertDTO] = Watch.sampleWatchRows
    ) {
        self.stormRisk = stormRisk
        self.severeRisk = severeRisk
        self.fireRisk = fireRisk
        self.weather = weather
        self.todayContentState = todayContentState
        self.readinessState = readinessState
        self.showsOfflineToken = showsOfflineToken
        self.outlook = outlook
        self.mesos = mesos
        self.alerts = alerts
    }

    var body: some View {
        SummaryView(
            snap: .init(
                coordinates: .init(latitude: 39.75, longitude: -104.44),
                timestamp: .now,
                accuracy: 20,
                placemarkSummary: "Bennett, CO"
            ),
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            fireRisk: fireRisk,
            mesos: mesos,
            alerts: alerts,
            outlook: outlook,
            weather: weather,
            todayContentState: todayContentState,
            readinessState: readinessState,
            resolutionState: SummaryResolutionState(),
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
}
