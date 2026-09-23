//
//  BarometricPressureTrendView.swift
//  SkyAware
//

import CoreMotion
import Observation
import SwiftUI

struct PressureSample: Equatable, Sendable {
    let timestamp: Date
    let pressureHPA: Double
}

struct PressureTrendCalculator: Sendable {
    static let window: TimeInterval = 15 * 60

    private(set) var samples: [PressureSample] = []

    mutating func addSample(timestamp: Date, pressureKPA: Double) {
        samples.append(PressureSample(timestamp: timestamp, pressureHPA: pressureKPA * 10))
        let cutoff = timestamp.addingTimeInterval(-Self.window)
        samples.removeAll { $0.timestamp < cutoff }
    }

    func snapshot(at now: Date) -> PressureTrendSnapshot {
        guard let current = samples.last else {
            return PressureTrendSnapshot(current: nil, baseline: nil, change: nil, historyDuration: 0)
        }

        let historyDuration = max(0, now.timeIntervalSince(samples.first?.timestamp ?? now))
        guard historyDuration >= Self.window else {
            return PressureTrendSnapshot(
                current: current,
                baseline: nil,
                change: nil,
                historyDuration: historyDuration
            )
        }

        let target = now.addingTimeInterval(-Self.window)
        let baseline = samples.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(target)) < abs(rhs.timestamp.timeIntervalSince(target))
        }
        let change = baseline.map { current.pressureHPA - $0.pressureHPA }
        return PressureTrendSnapshot(
            current: current,
            baseline: baseline,
            change: change,
            historyDuration: historyDuration
        )
    }
}

struct PressureTrendSnapshot: Equatable, Sendable {
    let current: PressureSample?
    let baseline: PressureSample?
    let change: Double?
    let historyDuration: TimeInterval

    var trend: PressureTrend {
        guard let change else { return .collecting }
        if change > 0 { return .rising }
        if change < 0 { return .falling }
        return .stable
    }
}

enum PressureTrend: String, Sendable {
    case collecting
    case rising
    case falling
    case stable

    var title: String {
        switch self {
        case .collecting: "Collecting"
        case .rising: "Rising"
        case .falling: "Falling"
        case .stable: "Stable"
        }
    }
}

@MainActor
@Observable
final class BarometricPressureModel {
    private(set) var calculator = PressureTrendCalculator()
    private(set) var isCollecting = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?

    private let altimeter = CMAltimeter()

    var snapshot: PressureTrendSnapshot {
        calculator.snapshot(at: Date())
    }

    func start() {
        guard isCollecting == false else { return }
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            errorMessage = "This device does not have a barometric pressure sensor."
            return
        }

        errorMessage = nil
        isCollecting = true
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self else { return }
            if let error {
                self.errorMessage = error.localizedDescription
                self.stop()
                return
            }
            guard let data else { return }
            let timestamp = Date()
            self.calculator.addSample(timestamp: timestamp, pressureKPA: data.pressure.doubleValue)
            self.lastUpdated = timestamp
        }
    }

    func stop() {
        guard isCollecting else { return }
        altimeter.stopRelativeAltitudeUpdates()
        isCollecting = false
    }
}

#if DEBUG
struct BarometricPressureTrendView: View {
    @State private var model = BarometricPressureModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let errorMessage = model.errorMessage {
                    sectionCard(title: "Pressure Sensor", symbol: "exclamationmark.triangle", accent: .orange) {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    pressureContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color(.skyAwareBackground).ignoresSafeArea())
        .task { model.start() }
        .onDisappear { model.stop() }
    }

    private var pressureContent: some View {
        let snapshot = model.snapshot

        return VStack(alignment: .leading, spacing: 18) {
            sectionCard(title: "Current Pressure", symbol: "gauge.with.dots.needle.67percent", accent: .primary) {
                if let current = snapshot.current {
                    Text(current.pressureHPA, format: .number.precision(.fractionLength(1)))
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    Text("hPa")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Waiting for a sensor reading…")
                        .foregroundStyle(.secondary)
                }
            }

            sectionCard(title: "15-Minute Change", symbol: "arrow.up.arrow.down", accent: .primary) {
                if let change = snapshot.change, let baseline = snapshot.baseline {
                    Text(change, format: .number.sign(strategy: .always(includingZero: true)).precision(.fractionLength(1)))
                        .font(.title2.weight(.semibold))
                    Text("hPa · \(snapshot.trend.title)")
                        .foregroundStyle(.secondary)
                    Text("15 minutes ago: \(baseline.pressureHPA, format: .number.precision(.fractionLength(1))) hPa")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView(value: min(snapshot.historyDuration / PressureTrendCalculator.window, 1))
                    Text("Collecting… \(durationText(snapshot.historyDuration)) / 15m")
                        .foregroundStyle(.secondary)
                }
            }

            sectionCard(title: "Collection", symbol: "waveform.path.ecg", accent: .primary) {
                LabeledContent("Samples", value: "\(model.calculator.samples.count)")
                if let lastUpdated = model.lastUpdated {
                    LabeledContent("Last Updated", value: lastUpdated.formatted(date: .omitted, time: .standard))
                }
            }
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        return "\(totalSeconds / 60)m \(totalSeconds % 60)s"
    }

    private func sectionCard<Content: View>(
        title: String,
        symbol: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(accent)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: SkyAwareRadius.card, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3)
    }
}
#endif
