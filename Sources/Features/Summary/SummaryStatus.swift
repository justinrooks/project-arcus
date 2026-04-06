//
//  SummaryStatus.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/5/25.
//

import SwiftUI

struct SummaryStatus: View {
    let statusText: String
    let weather: SummaryWeather?
    let resolutionState: SummaryResolutionState

    private static let temperatureFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter
    }()

    private var formattedTemperature: String? {
        guard let weather else { return nil }
        return formatTemperature(weather.temperature)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            contentRow
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .cardBackground(cornerRadius: SkyAwareRadius.section, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }

    private var header: some View {
        Text("Current Conditions")
            .sectionLabel()
    }

    private var contentRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Label(statusText, systemImage: "location.fill")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                SummaryStatusSecondaryLine(
                    resolutionState: resolutionState
                )
            }
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
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .frame(minHeight: 18, alignment: .trailing)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .frame(minWidth: 88, alignment: .trailing)
    }

    private func formatTemperature(_ temperature: Measurement<UnitTemperature>) -> String {
        Self.temperatureFormatter.string(from: temperature)
    }
}

private struct SummaryStatusSecondaryLine: View {
    let resolutionState: SummaryResolutionState
    @State private var displayedMessage: String?

    var body: some View {
        Group {
            if let displayedMessage {
                Text(displayedMessage)
                    .foregroundStyle(.secondary)
            } else {
                Text(" ")
                    .foregroundStyle(.clear)
                    .accessibilityHidden(true)
            }
        }
        .font(.footnote)
        .lineLimit(1)
        .contentTransition(.opacity)
        .frame(minHeight: 18, alignment: .leading)
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
                displayedMessage = activeMessages[0]
                return
            }

            var index = 0
            displayedMessage = activeMessages[index]

            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(3))
                if Task.isCancelled { return }
                index = (index + 1) % activeMessages.count
                displayedMessage = activeMessages[index]
            }

            return
        }

        if let recentCompletedMessage = resolutionState.recentCompletedMessage {
            displayedMessage = recentCompletedMessage

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

        displayedMessage = nil
    }
}

private struct SecondaryLineTaskState: Equatable {
    let activeMessages: [String]
    let recentCompletedMessage: String?
    let recentCompletedDeadline: Date?
}

private struct SummarySettledConditionLine: View {
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
            resolutionState: SummaryResolutionState()
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
            resolutionState: SummaryResolutionState()
        )
    }
}
