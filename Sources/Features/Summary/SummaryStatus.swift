//
//  SummaryStatus.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/5/25.
//

import SwiftUI

struct SummaryStatus: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsOfflineExplanation = false

    let statusText: String
    let weather: SummaryWeather?
    let resolutionState: SummaryResolutionState
    let showsOfflineToken: Bool
    let condenseProgress: CGFloat

    private static let temperatureFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter
    }()

    private var formattedTemperature: String? {
        guard let weather else { return nil }
        return formatTemperature(weather.temperature)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8 - (2 * clampedCondenseProgress)) {
            header
            contentRow
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
        HStack(alignment: .top, spacing: contentSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Label(statusText, systemImage: "location.fill")
                    .font(locationFont)
                    .foregroundStyle(.primary)
                    .contentTransition(.opacity)
                    .lineLimit(clampedCondenseProgress > 0.55 ? 1 : 2)

                SummaryStatusSecondaryLine(
                    resolutionState: resolutionState
                )
            }
            .animation(SkyAwareMotion.message(reduceMotion), value: statusText)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            weatherContent
        }
    }

    @ViewBuilder
    private var weatherContent: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 6) {
                if let weather, let formattedTemperature {
                    Text(formattedTemperature)
                        .monospacedDigit()
                    Image(systemName: weather.symbolName)
                        .symbolVariant(.fill)
                }
            }
            .frame(minHeight: 20, alignment: .trailing)

            Group {
                SummarySettledConditionLine(
                    conditionText: weather?.conditionText,
                    resolutionState: resolutionState
                )
            }
            .font(.footnote)
            .opacity(settledConditionOpacity)
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .frame(minHeight: 18, alignment: .trailing)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .frame(minWidth: 80 - (8 * clampedCondenseProgress), alignment: .trailing)
        .contentTransition(.opacity)
        .animation(SkyAwareMotion.message(reduceMotion), value: formattedTemperature)
        .animation(SkyAwareMotion.message(reduceMotion), value: weather?.symbolName)
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
        .fireWeather
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
            tint: tint.opacity(colorScheme == .dark ? 0.20 : 0.12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SkyAwareRadius.chipCompact, style: .continuous)
                .stroke(
                    tint.opacity(colorScheme == .dark ? 0.34 : 0.22),
                    lineWidth: 1
                )
        }
        .accessibilityLabel("Offline")
        .accessibilityHint("Shows what offline mode means.")
    }
}

private struct SummaryStatusSecondaryLine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let resolutionState: SummaryResolutionState
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
        .task(id: taskState) {
            await updateDisplayedMessage()
        }
    }

    private var taskState: SecondaryLineTaskState {
        SecondaryLineTaskState(
            activeMessages: resolutionState.activeMessages,
            recentCompletedMessage: resolutionState.recentCompletedMessage,
            recentCompletedDeadline: resolutionState.recentCompletedDeadline
        )
    }

    @MainActor
    private func updateDisplayedMessage() async {
        let activeMessages = resolutionState.activeMessages
        if activeMessages.isEmpty == false {
            if activeMessages.count == 1 {
                setDisplayedMessage(activeMessages[0])
                return
            }

            var index = 0
            setDisplayedMessage(activeMessages[index])

            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(3))
                if Task.isCancelled { return }
                index = (index + 1) % activeMessages.count
                setDisplayedMessage(activeMessages[index])
            }

            return
        }

        if let recentCompletedMessage = resolutionState.recentCompletedMessage {
            setDisplayedMessage(recentCompletedMessage)

            if let recentCompletedDeadline = resolutionState.recentCompletedDeadline {
                let remainingMilliseconds = max(
                    Int((recentCompletedDeadline.timeIntervalSinceNow * 1_000).rounded(.up)),
                    0
                )

                if remainingMilliseconds > 0 {
                    try? await Task.sleep(for: .milliseconds(remainingMilliseconds))
                }
            }

            if Task.isCancelled { return }
        }

        setDisplayedMessage(nil)
    }

    @MainActor
    private func setDisplayedMessage(_ message: String?) {
        withAnimation(SkyAwareMotion.message(reduceMotion)) {
            displayedMessage = message
        }
    }
}

private struct SecondaryLineTaskState: Equatable {
    let activeMessages: [String]
    let recentCompletedMessage: String?
    let recentCompletedDeadline: Date?
}

private struct SummarySettledConditionLine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let conditionText: String?
    let resolutionState: SummaryResolutionState

    var body: some View {
        Group {
            if shouldShowCondition, let conditionText {
                Text(conditionText)
                    .foregroundStyle(.secondary)
            } else {
                Text(" ")
                    .foregroundStyle(.clear)
                    .accessibilityHidden(true)
            }
        }
        .contentTransition(.opacity)
        .animation(SkyAwareMotion.message(reduceMotion), value: shouldShowCondition)
    }

    private var shouldShowCondition: Bool {
        resolutionState.isRefreshing == false && resolutionState.recentCompletedMessage == nil
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
            showsOfflineToken: false,
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
            showsOfflineToken: true,
            condenseProgress: 0.75
        )
    }
}
