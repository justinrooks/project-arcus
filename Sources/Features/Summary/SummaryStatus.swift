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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsOfflineExplanation = false

    let statusText: String
    let weather: SummaryWeather?
    let resolutionState: SummaryResolutionState
    let todayContentState: TodayContentState
    let showsOfflineToken: Bool
    let isLocationUnavailable: Bool
    let condenseProgress: CGFloat

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

    private var clampedCondenseProgress: CGFloat {
        min(max(condenseProgress, 0), 1)
    }

    private var headerSpacing: CGFloat {
        10 - (2 * clampedCondenseProgress)
    }

    private var contentSpacing: CGFloat {
        10 - (2 * clampedCondenseProgress)
    }

    private var verticalPadding: CGFloat {
        12 - (3 * clampedCondenseProgress)
    }

    private var cardCornerRadius: CGFloat {
        SkyAwareRadius.section - clampedCondenseProgress
    }

    private var cardShadowOpacity: Double {
        0.08 - (0.03 * clampedCondenseProgress)
    }

    private var cardShadowRadius: CGFloat {
        8 - (2 * clampedCondenseProgress)
    }

    private var cardShadowY: CGFloat {
        3 - clampedCondenseProgress
    }

    private var titleFont: Font {
        clampedCondenseProgress > 0.5 ? .subheadline.weight(.semibold) : .headline.weight(.semibold)
    }

    private var locationFont: Font {
        .headline.weight(.bold)
    }

    private var settledConditionOpacity: Double {
        1 - (0.55 * clampedCondenseProgress)
    }

    private var adaptiveLayout: SkyAwareAdaptiveLayout {
        SkyAwareAdaptiveLayout(dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8 - (2 * clampedCondenseProgress)) {
            header
            if isLocationUnavailable {
                locationUnavailableCard
            } else {
                contentRow
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, verticalPadding)
        .cardBackground(
            cornerRadius: cardCornerRadius,
            shadowOpacity: cardShadowOpacity,
            shadowRadius: cardShadowRadius,
            shadowY: cardShadowY
        )
        .animation(SkyAwareMotion.settle(reduceMotion), value: clampedCondenseProgress)
    }

    private var locationUnavailableCard: some View {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: SkyAwareRadius.card, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
        }
    }

    private var header: some View {
        HStack(spacing: headerSpacing) {
            Text("Current Conditions")
                .font(titleFont)
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

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
                .transition(.opacity)
            }
        }
        .animation(SkyAwareMotion.message(reduceMotion), value: showsOfflineToken)
    }

    private var contentRow: some View {
        Group {
            if adaptiveLayout.usesStackedHeroTiles {
                VStack(alignment: .leading, spacing: 8) {
                    statusContent
                    weatherContent
                }
            } else {
                HStack(alignment: .top, spacing: contentSpacing) {
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
                .lineLimit(adaptiveLayout.usesStackedHeroTiles ? 2 : 1)
                .truncationMode(.tail)

            SummaryStatusSecondaryLine(
                message: todayContentState.showsCalmUpdatingCue
                    ? resolutionState.primaryActiveMessage ?? resolutionState.recentCompletedMessage
                    : nil
            )
        }
        .animation(SkyAwareMotion.message(reduceMotion), value: statusText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var weatherContent: some View {
        VStack(alignment: adaptiveLayout.usesStackedHeroTiles ? .leading : .trailing, spacing: 2) {
            HStack(spacing: 6) {
                if let visibleWeather, let formattedTemperature {
                    Text(formattedTemperature)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: visibleWeather.temperature.value))
                    Image(systemName: visibleWeather.symbolName)
                        .symbolVariant(.fill)
                        .contentTransition(.opacity)
                } else {
                    Text("00°")
                        .monospacedDigit()
                        .hidden()
                        .accessibilityHidden(true)
                    Image(systemName: "sun.max.fill")
                        .hidden()
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 20, alignment: adaptiveLayout.usesStackedHeroTiles ? .leading : .trailing)

            Group {
                SummarySettledConditionLine(
                    conditionText: visibleWeather?.conditionText,
                    isRefreshing: todayContentState.showsCalmUpdatingCue
                )
            }
            .font(.footnote)
            .opacity(settledConditionOpacity)
            .multilineTextAlignment(adaptiveLayout.usesStackedHeroTiles ? .leading : .trailing)
            .lineLimit(1)
            .frame(minHeight: 18, alignment: adaptiveLayout.usesStackedHeroTiles ? .leading : .trailing)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .frame(
            minWidth: adaptiveLayout.usesStackedHeroTiles ? 0 : 80 - (8 * clampedCondenseProgress),
            alignment: adaptiveLayout.usesStackedHeroTiles ? .leading : .trailing
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
    @State private var displayedMessage: String?

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
        ZStack(alignment: .leading) {
            if let displayedMessage {
                Text(displayedMessage)
                    .id(displayedMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(messageTransition)
            } else {
                Text(" ")
                    .foregroundStyle(.clear)
                    .accessibilityHidden(true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.footnote.weight(.medium))
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 18, alignment: .leading)
        .clipped()
        .animation(SkyAwareMotion.message(reduceMotion), value: displayedMessage)
        .task(id: message) {
            setDisplayedMessage(message)
        }
    }

    @MainActor
    private func setDisplayedMessage(_ message: String?) {
        withAnimation(SkyAwareMotion.message(reduceMotion)) {
            displayedMessage = message
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

#Preview {
    VStack {
        SummaryStatus(
            statusText: "Denver, CO",
            weather: .init(
                temperature: Measurement(
                    value: 37.0,
                    unit: .fahrenheit
                ),
                symbolName: "sun.max",
                conditionText: "Clear",
                asOf: .now,
                dewPoint: Measurement(
                    value: 45.0,
                    unit: .fahrenheit
                ),
                humidity: 0.15,
                windSpeed: .init(value: 15.0, unit: .milesPerHour),
                windGust: nil,
                windDirection: "NNW",
                pressure: .init(value: 0.25, unit: .inchesOfMercury),
                pressureTrend: "climbing"
            ),
            resolutionState: SummaryResolutionState(),
            todayContentState: .current,
            showsOfflineToken: false,
            isLocationUnavailable: false,
            condenseProgress: 0
        )
        SummaryStatus(
            statusText: "Topeka, KS",
            weather: .init(
                temperature: Measurement(
                    value: 47.0,
                    unit: .fahrenheit
                ),
                symbolName: "cloud",
                conditionText: "Cloudy",
                asOf: .now,
                dewPoint: Measurement(
                    value: 45.0,
                    unit: .fahrenheit
                ),
                humidity: 0.15,
                windSpeed: .init(value: 15.0, unit: .milesPerHour),
                windGust: nil,
                windDirection: "SSE",
                pressure: .init(value: 0.25, unit: .inchesOfMercury),
                pressureTrend: "falling"
            ),
            resolutionState: SummaryResolutionState(),
            todayContentState: .current,
            showsOfflineToken: true,
            isLocationUnavailable: false,
            condenseProgress: 0.75
        )
        SummaryStatus(
            statusText: "Location not available",
            weather: nil,
            resolutionState: SummaryResolutionState(),
            todayContentState: .noCacheResolving,
            showsOfflineToken: false,
            isLocationUnavailable: true,
            condenseProgress: 0.75
        )
    }
}
