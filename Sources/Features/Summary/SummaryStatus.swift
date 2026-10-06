//
//  SummaryStatus.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/5/25.
//

import SwiftUI

struct SummaryWeatherLocationIdentity: Equatable, Sendable {
    let latitudeE4: Int
    let longitudeE4: Int
    let placemarkSummary: String?

    init(snapshot: LocationSnapshot?) {
        if let snapshot {
            latitudeE4 = Self.quantize(snapshot.coordinates.latitude)
            longitudeE4 = Self.quantize(snapshot.coordinates.longitude)
            placemarkSummary = snapshot.placemarkSummary
        } else {
            latitudeE4 = 0
            longitudeE4 = 0
            placemarkSummary = nil
        }
    }

    private static func quantize(_ value: Double) -> Int {
        Int((value * 10_000).rounded(.towardZero))
    }
}

struct SummaryStatus: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsOfflineExplanation = false

    let statusText: String
    let weather: SummaryWeather?
    let resolutionState: SummaryResolutionState
    let todayContentState: TodayContentState
    let showsOfflineToken: Bool
    let isLocationUnavailable: Bool

    private static let temperatureFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter
    }()

    private var visibleWeather: SummaryWeather? {
        weather
    }

    private var formattedTemperature: String? {
        guard let visibleWeather else { return nil }
        return formatTemperature(visibleWeather.temperature)
    }

    private var locationFont: Font {
        .title2.weight(.semibold)
    }

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    private var usesStackedConditionsLayout: Bool {
        adaptiveLayout.usesStackedHeroTiles || dynamicTypeSize >= .xxxLarge
    }

    var headerStatusMessage: String? {
        guard showsOfflineToken == false, isLocationUnavailable == false else { return nil }
        return secondaryStatusMessage
    }

    var secondaryStatusMessage: String? {
        let showsNativeManualRefreshProgress = todayContentState == .cachedRefreshing
            || todayContentState == .staleRefreshing

        return todayContentState.manualRefreshStatusMessage
            ?? (showsNativeManualRefreshProgress ? nil : resolutionState.primaryActiveMessage)
            ?? resolutionState.conditionsUpdatedMessage
            ?? (todayContentState.showsCalmUpdatingCue ? resolutionState.recentCompletedMessage : nil)
    }

    private var secondaryStatusDeadline: Date? {
        guard todayContentState.manualRefreshStatusMessage == nil,
              resolutionState.primaryActiveMessage == nil else { return nil }
        if resolutionState.conditionsUpdatedMessage != nil {
            return resolutionState.conditionsUpdatedDeadline
        }
        guard todayContentState.showsCalmUpdatingCue else { return nil }
        return resolutionState.recentCompletedDeadline
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if isLocationUnavailable {
                locationUnavailableMessage
            } else {
                contentRow
            }
        }
    }

    private var locationUnavailableMessage: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Location Required", systemImage: "location.slash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Enable location access to load local risk, alerts, and weather conditions.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        Group {
            if usesStackedConditionsLayout {
                VStack(alignment: .leading, spacing: 0) {
                    headerTitle
                    headerTrailingStatus(isTrailing: false)
                }
            } else {
                HStack(spacing: 10) {
                    headerTitle
                    Spacer(minLength: 12)
                    headerTrailingStatus(isTrailing: true)
                }
            }
        }
        .animation(SkyAwareMotion.message(reduceMotion), value: showsOfflineToken)
    }

    private var headerTitle: some View {
        Text("Current Conditions")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func headerTrailingStatus(isTrailing: Bool) -> some View {
        if showsOfflineToken {
            Button {
                showsOfflineExplanation = true
            } label: {
                SummaryOfflineToken()
            }
            .buttonStyle(
                SkyAwarePressableButtonStyle(
                    cornerRadius: SkyAwareRadius.chipCompact,
                    pressedScale: 0.985,
                    pressedOverlayOpacity: 0.08
                )
            )
            .popover(isPresented: $showsOfflineExplanation, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                OfflineExplanationView()
                    .presentationCompactAdaptation(.popover)
            }
            .padding(.top, isTrailing ? 0 : 6)
            .transition(.opacity)
        } else {
            SummaryStatusSecondaryLine(
                message: headerStatusMessage,
                recentCompletedDeadline: secondaryStatusDeadline,
                allowsWrapping: usesStackedConditionsLayout,
                isTrailing: isTrailing
            )
        }
    }

    private var contentRow: some View {
        Group {
            if usesStackedConditionsLayout {
                VStack(alignment: .leading, spacing: 8) {
                    statusContent
                    weatherContent
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    statusContent
                    Spacer(minLength: 8)
                    weatherContent
                }
            }
        }
    }

    private var statusContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(statusText, systemImage: "location.fill")
                .font(locationFont)
                .foregroundStyle(.primary)
                .contentTransition(.opacity)
                .lineLimit(usesStackedConditionsLayout ? nil : 1)
                .truncationMode(.tail)

        }
        .animation(SkyAwareMotion.message(reduceMotion), value: statusText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var weatherContent: some View {
        VStack(alignment: usesStackedConditionsLayout ? .leading : .trailing, spacing: 2) {
            HStack(spacing: 6) {
                if let visibleWeather, let formattedTemperature {
                    Text(formattedTemperature)
                        .monospacedDigit()
                        .font(.title2.weight(.semibold))
                        .contentTransition(.numericText(value: visibleWeather.temperature.value))
                    Image(systemName: visibleWeather.symbolName)
                        .symbolVariant(.fill)
                        .font(.title3)
                        .contentTransition(.opacity)
                } else {
                    Text("00°")
                        .monospacedDigit()
                        .font(.title2.weight(.semibold))
                        .hidden()
                        .accessibilityHidden(true)
                    Image(systemName: "sun.max.fill")
                        .font(.title3)
                        .hidden()
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 20, alignment: usesStackedConditionsLayout ? .leading : .trailing)

            Group {
                SummarySettledConditionLine(
                    conditionText: visibleWeather?.conditionText,
                    isRefreshing: todayContentState.showsCalmUpdatingCue
                )
            }
            .font(.footnote)
            .multilineTextAlignment(usesStackedConditionsLayout ? .leading : .trailing)
            .lineLimit(usesStackedConditionsLayout ? nil : 1)
            .frame(minHeight: 18, alignment: usesStackedConditionsLayout ? .leading : .trailing)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .frame(
            minWidth: usesStackedConditionsLayout ? 0 : 80,
            alignment: usesStackedConditionsLayout ? .leading : .trailing
        )
        .contentTransition(.opacity)
        .animation(SkyAwareMotion.message(reduceMotion), value: formattedTemperature)
        .animation(SkyAwareMotion.message(reduceMotion), value: visibleWeather?.symbolName)
        .animation(SkyAwareMotion.message(reduceMotion), value: visibleWeather?.conditionText)
    }

    private func formatTemperature(_ temperature: Measurement<UnitTemperature>) -> String {
        Self.temperatureFormatter.string(from: temperature)
    }
}

private struct OfflineExplanationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Offline")
                .font(.headline.weight(.semibold))

            Text("SkyAware is showing the latest local data already saved on your device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Conditions, alerts, and outlooks will refresh automatically once your connection returns.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(width: 300, alignment: .leading)
    }
}

private struct SummaryOfflineToken: View {
    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color {
        .semanticMetadata
    }

    var body: some View {
        HStack(spacing: 6) {
            Label("Offline", systemImage: "wifi.slash")
            Image(systemName: "info.circle")
                .font(.caption2.weight(.bold))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .skyAwareChip(
            cornerRadius: SkyAwareRadius.chipCompact,
            tint: Color.semanticMetadataSurface.opacity(colorScheme == .dark ? 0.24 : 0.16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SkyAwareRadius.chipCompact, style: .continuous)
                .stroke(
                    tint.opacity(colorScheme == .dark ? 0.32 : 0.22),
                    lineWidth: 1
                )
        }
        .accessibilityLabel("Offline")
        .accessibilityHint("Shows what offline mode means.")
    }
}

private struct SummaryStatusSecondaryLine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let message: String?
    let recentCompletedDeadline: Date?
    let allowsWrapping: Bool
    let isTrailing: Bool
    @State private var displayedMessage: String?

    private struct TaskIdentity: Equatable {
        let message: String?
        let recentCompletedDeadline: Date?
    }

    private var messageTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        return .asymmetric(
            insertion: .offset(y: 8).combined(with: .opacity),
            removal: .offset(y: -8).combined(with: .opacity)
        )
    }

    var body: some View {
        ZStack(alignment: isTrailing ? .trailing : .leading) {
            if let displayedMessage {
                Text(displayedMessage)
                    .id(displayedMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: isTrailing ? .trailing : .leading)
                    .transition(messageTransition)
            } else {
                EmptyView()
            }
        }
        .font(.footnote.weight(.medium))
        .lineLimit(allowsWrapping ? nil : 1)
        .frame(maxWidth: .infinity, alignment: isTrailing ? .trailing : .leading)
        .frame(minHeight: allowsWrapping ? 0 : 18, alignment: .leading)
        .padding(.top, isTrailing || displayedMessage == nil ? 0 : 6)
        .animation(SkyAwareMotion.message(reduceMotion), value: displayedMessage)
        .task(id: taskIdentity) {
            await setDisplayedMessage(message)
        }
    }

    private var taskIdentity: TaskIdentity {
        TaskIdentity(message: message, recentCompletedDeadline: recentCompletedDeadline)
    }

    @MainActor
    private func setDisplayedMessage(_ message: String?) async {
        withAnimation(SkyAwareMotion.message(reduceMotion)) {
            displayedMessage = message
        }

        guard message != nil, let recentCompletedDeadline else { return }

        let remaining = recentCompletedDeadline.timeIntervalSinceNow
        guard remaining > 0 else {
            withAnimation(SkyAwareMotion.message(reduceMotion)) {
                displayedMessage = nil
            }
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(Int64((remaining * 1_000).rounded(.up))))
        } catch {
            return
        }

        guard Task.isCancelled == false else { return }

        withAnimation(SkyAwareMotion.message(reduceMotion)) {
            displayedMessage = nil
        }
    }
}

private struct SummarySettledConditionLine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let conditionText: String?
    let isRefreshing: Bool

    var body: some View {
        Group {
            if let conditionText {
                Text(conditionText)
                    .foregroundStyle(.secondary)
            } else {
                Text(" ")
                    .foregroundStyle(.clear)
                    .accessibilityHidden(true)
            }
        }
        .opacity(isRefreshing ? 0.86 : 1)
        .contentTransition(.opacity)
        .animation(SkyAwareMotion.message(reduceMotion), value: conditionText)
        .animation(SkyAwareMotion.message(reduceMotion), value: isRefreshing)
    }
}

#Preview("Current Conditions · Light") {
    SummaryStatusPreviewSet()
        .preferredColorScheme(.light)
}

#Preview("Current Conditions · Dark") {
    SummaryStatusPreviewSet()
        .preferredColorScheme(.dark)
}

#Preview("Current Conditions · Accessibility") {
    SummaryStatusPreviewSet()
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Current Conditions · XXXLarge") {
    SummaryStatusPreviewSet()
        .environment(\.dynamicTypeSize, .xxxLarge)
}

private struct SummaryStatusPreviewSet: View {
    private let weather = SummaryWeather(
        temperature: Measurement(value: 73, unit: .fahrenheit),
        symbolName: "cloud",
        conditionText: "Partly Cloudy",
        asOf: .now,
        dewPoint: Measurement(value: 55, unit: .fahrenheit),
        humidity: 0.42,
        windSpeed: .init(value: 8, unit: .milesPerHour),
        windGust: nil,
        windDirection: "SE",
        pressure: .init(value: 0.25, unit: .inchesOfMercury),
        pressureTrend: "steady"
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SummaryStatus(
                statusText: "Clinton, IL",
                weather: weather,
                resolutionState: SummaryResolutionState(),
                todayContentState: .current,
                showsOfflineToken: false,
                isLocationUnavailable: false
            )
            SummaryStatus(
                statusText: "Clinton, IL",
                weather: weather,
                resolutionState: SummaryResolutionState(),
                todayContentState: .degraded,
                showsOfflineToken: true,
                isLocationUnavailable: false
            )
            SummaryStatus(
                statusText: "Location not available",
                weather: nil,
                resolutionState: SummaryResolutionState(),
                todayContentState: .noCacheResolving,
                showsOfflineToken: false,
                isLocationUnavailable: true
            )
            SummaryStatus(
                statusText: "Clinton, IL",
                weather: SummaryWeather(
                    temperature: Measurement(value: 73, unit: .fahrenheit),
                    symbolName: "cloud.bolt.rain",
                    conditionText: "Scattered thunderstorms with locally heavy rainfall",
                    asOf: .now,
                    dewPoint: Measurement(value: 68, unit: .fahrenheit),
                    humidity: 0.86,
                    windSpeed: .init(value: 12, unit: .milesPerHour),
                    windGust: nil,
                    windDirection: "SE",
                    pressure: .init(value: 0.25, unit: .inchesOfMercury),
                    pressureTrend: "steady"
                ),
                resolutionState: SummaryResolutionState(),
                todayContentState: .refreshFailedWithCache,
                showsOfflineToken: false,
                isLocationUnavailable: false
            )
        }
        .padding()
    }
}
