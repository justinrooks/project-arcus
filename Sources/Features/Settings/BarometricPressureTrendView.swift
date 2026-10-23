//
//  BarometricPressureTrendView.swift
//  SkyAware
//

import CoreLocation
import Charts
import CoreMotion
import CoreTransferable
import Observation
import SwiftUI
import UniformTypeIdentifiers

struct PressureSample: Equatable, Identifiable, Sendable {
    let timestamp: Date
    let pressureHPA: Double

    var id: Date { timestamp }
}

struct PressureCSVExport: Transferable, Sendable {
    let data: Data
    let filename: String

    init(samples: [PressureSample], sessionStartedAt: Date) {
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let filenameFormatter = DateFormatter()
        filenameFormatter.locale = Locale(identifier: "en_US_POSIX")
        filenameFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        filenameFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        filename = "pressure-samples-\(filenameFormatter.string(from: sessionStartedAt)).csv"

        let rows = ["timestamp_utc,elapsed_seconds,pressure_hpa"] + samples.map { sample in
            let elapsed = sample.timestamp.timeIntervalSince(sessionStartedAt)
            return "\(timestampFormatter.string(from: sample.timestamp)),\(elapsed),\(sample.pressureHPA)"
        }
        data = Data(rows.joined(separator: "\n").appending("\n").utf8)
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            export.data
        }
        .suggestedFileName { $0.filename }
    }
}

struct PressureChartPoint: Identifiable, Sendable {
    let sample: PressureSample
    let seriesID: Int
    let seriesSampleCount: Int

    var id: Date { sample.timestamp }
}

enum PressureChartData {
    static func points(from samples: [PressureSample]) -> [PressureChartPoint] {
        guard samples.isEmpty == false else { return [] }

        var segments: [[PressureSample]] = []
        var segmentStart = 0
        for index in samples.indices.dropFirst() {
            let gap = samples[index].timestamp.timeIntervalSince(samples[index - 1].timestamp)
            if gap > PressureTrendCalculator.sampleTolerance {
                segments.append(Array(samples[segmentStart..<index]))
                segmentStart = index
            }
        }
        segments.append(Array(samples[segmentStart...]))

        return segments.enumerated().flatMap { seriesID, segment in
            segment.map { sample in
                PressureChartPoint(sample: sample, seriesID: seriesID, seriesSampleCount: segment.count)
            }
        }
    }
}

enum PressureObservationFormatting {
    static func samplingGap(_ duration: TimeInterval, locale: Locale = .autoupdatingCurrent) -> String {
        // Keep any gap above the five-second coverage threshold visibly above 5.0 seconds.
        let hundredthSeconds = (duration * 100).rounded(.up) / 100
        let value = hundredthSeconds.formatted(
            FloatingPointFormatStyle<Double>.number
                .locale(locale)
                .precision(.fractionLength(1...2))
        )
        return "\(value)s"
    }
}

struct PressureObservationStatistics: Equatable, Sendable {
    let minimum: Double?
    let maximum: Double?
    let range: Double?
    let mean: Double?
    let standardDeviation: Double?
    let sampleCount: Int
    let observationSpan: TimeInterval
    let largestSamplingGap: TimeInterval

    init(samples: [PressureSample]) {
        sampleCount = samples.count
        observationSpan = samples.first.flatMap { first in
            samples.last.map { $0.timestamp.timeIntervalSince(first.timestamp) }
        } ?? 0
        largestSamplingGap = zip(samples, samples.dropFirst())
            .map { $1.timestamp.timeIntervalSince($0.timestamp) }
            .max() ?? 0

        guard let first = samples.first else {
            minimum = nil
            maximum = nil
            range = nil
            mean = nil
            standardDeviation = nil
            return
        }

        var low = first.pressureHPA
        var high = first.pressureHPA
        var runningMean = 0.0
        var squaredDifferences = 0.0
        for (index, sample) in samples.enumerated() {
            low = min(low, sample.pressureHPA)
            high = max(high, sample.pressureHPA)
            let count = Double(index + 1)
            let difference = sample.pressureHPA - runningMean
            runningMean += difference / count
            squaredDifferences += difference * (sample.pressureHPA - runningMean)
        }

        minimum = low
        maximum = high
        range = high - low
        mean = runningMean
        standardDeviation = sqrt(squaredDifferences / Double(samples.count))
    }

    var yAxisDomain: ClosedRange<Double> {
        guard let minimum, let maximum else { return 0...1 }
        let span = maximum - minimum
        let padding = max(span * 0.1, 0.05)
        return (minimum - padding)...(maximum + padding)
    }
}

struct PressureTrendCalculator: Sendable {
    static let window: TimeInterval = 15 * 60
    static let retention: TimeInterval = 60 * 60
    // Allow normal ~1 Hz jitter without bridging a collection outage.
    static let sampleTolerance: TimeInterval = 5

    private(set) var samples: [PressureSample] = []

    @discardableResult
    mutating func addSample(timestamp: Date, pressureKPA: Double) -> Bool {
        guard samples.last.map({ timestamp > $0.timestamp }) ?? true else { return false }
        samples.append(PressureSample(timestamp: timestamp, pressureHPA: pressureKPA * 10))
        let cutoff = timestamp.addingTimeInterval(-Self.retention)
        samples.removeAll { $0.timestamp < cutoff }
        return true
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
            guard self.calculator.addSample(timestamp: timestamp, pressureKPA: pressure) else { return }
            if self.lastUpdated == nil, let sessionStartedAt = self.sessionStartedAt {
                self.sessionStartedAt = min(sessionStartedAt, timestamp)
            }
            self.lastUpdated = timestamp
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
struct PressureElevationFix: Equatable, Sendable {
    let altitudeMeters: Double
    let verticalAccuracyMeters: Double
    let timestamp: Date

    static func accepted(
        altitude: Double,
        verticalAccuracy: Double,
        horizontalAccuracy: Double,
        timestamp: Date,
        now: Date
    ) -> PressureElevationFix? {
        let age = now.timeIntervalSince(timestamp)
        guard altitude.isFinite,
              verticalAccuracy.isFinite, verticalAccuracy > 0, verticalAccuracy <= 100,
              horizontalAccuracy.isFinite, horizontalAccuracy >= 0, horizontalAccuracy <= 100,
              age >= 0, age <= 300 else { return nil }
        return PressureElevationFix(
            altitudeMeters: altitude,
            verticalAccuracyMeters: verticalAccuracy,
            timestamp: timestamp
        )
    }

    static func displayValue(meters: Double, locale: Locale = .autoupdatingCurrent) -> String {
        let unit: UnitLength = locale.measurementSystem == .us ? .feet : .meters
        return Measurement(value: meters, unit: UnitLength.meters)
            .converted(to: unit)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided).locale(locale))
    }

    func isFresh(at now: Date) -> Bool {
        let age = now.timeIntervalSince(timestamp)
        return age >= 0 && age <= 300
    }
}

@MainActor
@Observable
final class PressureElevationReader: NSObject, CLLocationManagerDelegate {
    private(set) var fix: PressureElevationFix?
    private(set) var unavailable = false
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .notDetermined, .denied, .restricted:
            unavailable = true
        @unknown default:
            unavailable = true
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            Task { @MainActor [weak self] in self?.unavailable = true }
            return
        }
        let altitude = location.altitude
        let verticalAccuracy = location.verticalAccuracy
        let horizontalAccuracy = location.horizontalAccuracy
        let timestamp = location.timestamp
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.fix = PressureElevationFix.accepted(
                altitude: altitude,
                verticalAccuracy: verticalAccuracy,
                horizontalAccuracy: horizontalAccuracy,
                timestamp: timestamp,
                now: .now
            )
            self.unavailable = self.fix == nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.unavailable = true }
    }
}

struct BarometricPressureTrendView: View {
    @State private var model = BarometricPressureModel()
    @State private var elevationReader = PressureElevationReader()

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
                TimelineView(.periodic(from: .now, by: 30)) { timeline in
                    sectionCard(title: "Location Elevation", symbol: "mountain.2", accent: .primary) {
                        if let fix = elevationReader.fix, fix.isFresh(at: timeline.date) {
                            LabeledContent("Altitude", value: PressureElevationFix.displayValue(meters: fix.altitudeMeters))
                            LabeledContent("Vertical Accuracy", value: PressureElevationFix.displayValue(meters: fix.verticalAccuracyMeters))
                            LabeledContent("Fix Time", value: fix.timestamp.formatted(date: .omitted, time: .standard))
                            LabeledContent("Fix Age", value: fix.timestamp.formatted(.relative(presentation: .numeric)))
                            Text("Core Location altitude may use sensor fusion. It is not survey-grade and does not establish why pressure changed.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Elevation unavailable")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                let export = PressureCSVExport(
                    samples: model.calculator.samples,
                    sessionStartedAt: model.sessionStartedAt ?? Date()
                )
                ShareLink(item: export, preview: SharePreview(export.filename)) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(model.calculator.samples.isEmpty)
                Button("Reset / Restart", systemImage: "arrow.clockwise") { model.restart() }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color(.skyAwareBackground).ignoresSafeArea())
        .task {
            model.start()
            elevationReader.requestIfAuthorized()
        }
        .onDisappear { model.stop() }
    }

    private func pressureContent(at now: Date) -> some View {
        let snapshot = model.calculator.snapshot(at: now)
        let samples = model.calculator.samples
        let statistics = PressureObservationStatistics(samples: samples)

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

            sectionCard(title: "Pressure History", symbol: "chart.xyaxis.line", accent: .primary) {
                if samples.isEmpty {
                    Text("Waiting for pressure measurements…")
                        .foregroundStyle(.secondary)
                        .frame(height: 180, alignment: .center)
                        .frame(maxWidth: .infinity)
                } else {
                    Chart(PressureChartData.points(from: samples)) { point in
                        LineMark(
                            x: .value("Observation time", point.sample.timestamp),
                            y: .value("Station pressure", point.sample.pressureHPA),
                            series: .value("Observed segment", point.seriesID)
                        )
                        .interpolationMethod(.linear)
                        if point.seriesSampleCount == 1 {
                            PointMark(
                                x: .value("Observation time", point.sample.timestamp),
                                y: .value("Station pressure", point.sample.pressureHPA)
                            )
                            .symbolSize(30)
                        }
                    }
                    .chartYScale(domain: statistics.yAxisDomain)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(
                                format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))
                            )
                        }
                    }
                    .frame(height: 190)
                    .accessibilityLabel("Retained station pressure history in hectopascals")
                }

                Text("Measured samples · latest 60 minutes retained")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let first = samples.first, let last = samples.last {
                    LabeledContent("Observation Start", value: first.timestamp.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Observation End", value: last.timestamp.formatted(date: .abbreviated, time: .shortened))
                }
            }

            sectionCard(title: "Observation Statistics", symbol: "function", accent: .primary) {
                if let minimum = statistics.minimum,
                   let maximum = statistics.maximum,
                   let range = statistics.range,
                   let mean = statistics.mean,
                   let standardDeviation = statistics.standardDeviation {
                    LabeledContent("Minimum", value: pressureText(minimum))
                    LabeledContent("Maximum", value: pressureText(maximum))
                    LabeledContent("Range", value: pressureText(range))
                    LabeledContent("Mean", value: pressureText(mean))
                    LabeledContent("Std. Deviation", value: pressureText(standardDeviation))
                } else {
                    Text("Insufficient evidence: no pressure measurements yet.")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Sample Count", value: "\(statistics.sampleCount)")
                LabeledContent("Observed Span", value: durationText(statistics.observationSpan))
                LabeledContent(
                    "Largest Sampling Gap",
                    value: PressureObservationFormatting.samplingGap(statistics.largestSamplingGap)
                )
                LabeledContent(
                    "Coverage",
                    value: statistics.largestSamplingGap > PressureTrendCalculator.sampleTolerance
                        ? "Gaps observed" : statistics.sampleCount > 1 ? "Continuous" : "Insufficient evidence"
                )
            }

        }
    }

    private func pressureText(_ value: Double, signed: Bool = false) -> String {
        value.formatted(
            .number
                .sign(strategy: signed ? .always(includingZero: true) : .never)
                .precision(.fractionLength(2))
        )
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
