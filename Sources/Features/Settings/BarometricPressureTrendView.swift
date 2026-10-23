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
    static let retention: TimeInterval = 60 * 60
    // Allow normal ~1 Hz jitter without bridging a collection outage.
    static let sampleTolerance: TimeInterval = 5

    private(set) var samples: [PressureSample] = []

    mutating func addSample(timestamp: Date, pressureKPA: Double) {
        guard samples.last.map({ timestamp > $0.timestamp }) ?? true else { return }
        samples.append(PressureSample(timestamp: timestamp, pressureHPA: pressureKPA * 10))
        let cutoff = timestamp.addingTimeInterval(-Self.retention)
        samples.removeAll { $0.timestamp < cutoff }
    }

    func snapshot(at now: Date) -> PressureTrendSnapshot {
        guard let current = samples.last else {
            return PressureTrendSnapshot(current: nil, baseline: nil, change: nil, historyDuration: 0)
        }

        let historyDuration = current.timestamp.timeIntervalSince(samples.first?.timestamp ?? current.timestamp)
        guard historyDuration >= Self.window,
              (0...Self.sampleTolerance).contains(now.timeIntervalSince(current.timestamp)) else {
            return PressureTrendSnapshot(
                current: current,
                baseline: nil,
                change: nil,
                historyDuration: historyDuration
            )
        }

        let target = current.timestamp.addingTimeInterval(-Self.window)
        let baseline = samples.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(target)) < abs(rhs.timestamp.timeIntervalSince(target))
        }
        // Include gaps straddling the target, but allow recovery once an outage
        // ends at or before the start of the observation window.
        let hasCollectionGap = zip(samples, samples.dropFirst()).contains { earlier, later in
            later.timestamp > target
                && later.timestamp.timeIntervalSince(earlier.timestamp) > Self.sampleTolerance
        }
        let eligibleBaseline = baseline.flatMap {
            !hasCollectionGap && abs($0.timestamp.timeIntervalSince(target)) <= Self.sampleTolerance ? $0 : nil
        }
        let change = eligibleBaseline.map { current.pressureHPA - $0.pressureHPA }
        return PressureTrendSnapshot(
            current: current,
            baseline: eligibleBaseline,
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

    private(set) var sessionStartedAt: Date?
    private var collectionID: UUID?
    private let isAvailable: () -> Bool
    private let startUpdates: (@escaping @MainActor (Date, Double?, String?) -> Void) -> Void
    private let stopUpdates: () -> Void

    init(
        isAvailable: @escaping () -> Bool = { CMAltimeter.isRelativeAltitudeAvailable() },
        startUpdates: ((@escaping @MainActor (Date, Double?, String?) -> Void) -> Void)? = nil,
        stopUpdates: (() -> Void)? = nil
    ) {
        let altimeter = CMAltimeter()
        self.isAvailable = isAvailable
        self.startUpdates = startUpdates ?? { receive in
            altimeter.startRelativeAltitudeUpdates(to: .main) { data, error in
                // Core Motion timestamps are seconds since boot, not callback delivery times.
                let timestamp = Date(timeIntervalSinceNow: (data?.timestamp ?? ProcessInfo.processInfo.systemUptime)
                    - ProcessInfo.processInfo.systemUptime)
                receive(timestamp, data?.pressure.doubleValue, error?.localizedDescription)
            }
        }
        self.stopUpdates = stopUpdates ?? { altimeter.stopRelativeAltitudeUpdates() }
    }

    func start(at now: Date = Date()) {
        guard isCollecting == false else { return }
        guard isAvailable() else {
            errorMessage = "This device does not have a barometric pressure sensor."
            return
        }

        errorMessage = nil
        sessionStartedAt = sessionStartedAt ?? now
        let id = UUID()
        collectionID = id
        isCollecting = true
        startUpdates { [weak self] timestamp, pressure, error in
            guard let self, self.collectionID == id, self.isCollecting else { return }
            if let error {
                self.errorMessage = error
                self.stop()
                return
            }
            guard let pressure else { return }
            self.calculator.addSample(timestamp: timestamp, pressureKPA: pressure)
            self.lastUpdated = self.calculator.samples.last?.timestamp
        }
    }

    func stop() {
        collectionID = nil
        guard isCollecting else { return }
        isCollecting = false
        stopUpdates()
    }

    func restart(at now: Date = Date()) {
        stop()
        calculator = PressureTrendCalculator()
        sessionStartedAt = nil
        lastUpdated = nil
        errorMessage = nil
        start(at: now)
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
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        pressureContent(at: Date())
                    }
                }
                Button("Reset / Restart", systemImage: "arrow.clockwise") { model.restart() }
                    .buttonStyle(.bordered)
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

    private func pressureContent(at now: Date) -> some View {
        let snapshot = model.calculator.snapshot(at: now)

        return VStack(alignment: .leading, spacing: 18) {
            sectionCard(title: "Current Pressure", symbol: "gauge.with.dots.needle.67percent", accent: .primary) {
                if let current = snapshot.current {
                    Text(current.pressureHPA, format: .number.precision(.fractionLength(2)))
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
                    Text(change, format: .number.sign(strategy: .always(includingZero: true)).precision(.fractionLength(2)))
                        .font(.title2.weight(.semibold))
                    Text("hPa · \(snapshot.trend.title)")
                        .foregroundStyle(.secondary)
                    Text("15 minutes ago: \(baseline.pressureHPA, format: .number.precision(.fractionLength(2))) hPa")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let current = snapshot.current,
                          now.timeIntervalSince(current.timestamp) > PressureTrendCalculator.sampleTolerance {
                    Text("Sensor reading is stale. Waiting for a fresh reading…")
                        .foregroundStyle(.secondary)
                } else if snapshot.historyDuration >= PressureTrendCalculator.window {
                    Text("Insufficient history: collection gap in the 15-minute window. Waiting for continuous readings…")
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView(value: min(snapshot.historyDuration / PressureTrendCalculator.window, 1))
                    Text("Collecting… \(durationText(snapshot.historyDuration)) / 15m")
                        .foregroundStyle(.secondary)
                }
            }

            sectionCard(title: "Collection", symbol: "waveform.path.ecg", accent: .primary) {
                if let startedAt = model.sessionStartedAt {
                    LabeledContent("Session Elapsed", value: durationText(now.timeIntervalSince(startedAt)))
                }
                LabeledContent("Retained History", value: durationText(snapshot.historyDuration))
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
