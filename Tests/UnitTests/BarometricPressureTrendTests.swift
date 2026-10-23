import Foundation
import Testing
@testable import SkyAware

@Suite("Barometric pressure trend")
struct BarometricPressureTrendTests {
    @Test("CSV export is locale invariant and preserves retained pressure precision")
    func pressureCSVExport() {
        let sessionStart = Date(timeIntervalSince1970: 0.25)
        let samples = [
            PressureSample(timestamp: Date(timeIntervalSince1970: 1.25), pressureHPA: 831.123456789),
            PressureSample(timestamp: Date(timeIntervalSince1970: 2.5), pressureHPA: 840.000000001)
        ]

        let export = PressureCSVExport(samples: samples, sessionStartedAt: sessionStart)

        #expect(export.filename == "pressure-samples-19700101T000000Z.csv")
        #expect(String(decoding: export.data, as: UTF8.self) == """
        timestamp_utc,elapsed_seconds,pressure_hpa
        1970-01-01T00:00:01.250Z,1.0,831.123456789
        1970-01-01T00:00:02.500Z,2.25,840.000000001

        """)
    }

    @Test("CSV export handles empty and single-sample histories")
    func pressureCSVExportEmptyAndSingleSample() {
        let sessionStart = Date(timeIntervalSince1970: 0)
        let empty = PressureCSVExport(samples: [], sessionStartedAt: sessionStart)
        let single = PressureCSVExport(
            samples: [PressureSample(timestamp: sessionStart, pressureHPA: 831.4)],
            sessionStartedAt: sessionStart
        )

        #expect(String(decoding: empty.data, as: UTF8.self) == "timestamp_utc,elapsed_seconds,pressure_hpa\n")
        #expect(String(decoding: single.data, as: UTF8.self).contains("1970-01-01T00:00:00.000Z,0.0,831.4"))
    }

    @Test("pressure chart segments split at gaps longer than the trend tolerance", arguments: [5.0, 5.1])
    func pressureChartSegments(gap: Double) {
        let start = Date(timeIntervalSince1970: 10_000)
        let samples = [
            PressureSample(timestamp: start, pressureHPA: 831.4),
            PressureSample(timestamp: start.addingTimeInterval(1), pressureHPA: 831.5),
            PressureSample(timestamp: start.addingTimeInterval(1 + gap), pressureHPA: 831.9)
        ]

        let points = PressureChartData.points(from: samples)

        let expectedSeriesIDs = gap > PressureTrendCalculator.sampleTolerance ? [0, 0, 1] : [0, 0, 0]
        let expectedSeriesCounts = gap > PressureTrendCalculator.sampleTolerance ? [2, 2, 1] : [3, 3, 3]
        #expect(points.map(\.seriesID) == expectedSeriesIDs)
        #expect(points.map(\.seriesSampleCount) == expectedSeriesCounts)
        #expect(points.last?.sample.pressureHPA == 831.9)
    }

    @Test("pressure chart segmentation handles empty and single-sample history")
    func pressureChartEmptyAndSingleSample() {
        #expect(PressureChartData.points(from: []).isEmpty)

        let sample = PressureSample(timestamp: Date(timeIntervalSince1970: 10_000), pressureHPA: 831.4)
        let points = PressureChartData.points(from: [sample])

        #expect(points.count == 1)
        #expect(points[0].seriesID == 0)
        #expect(points[0].seriesSampleCount == 1)
    }

    @Test("sampling gap presentation retains tenths of a second")
    func samplingGapFormatting() {
        #expect(PressureObservationFormatting.samplingGap(5.1, locale: Locale(identifier: "en_US_POSIX")) == "5.1s")
        #expect(
            PressureObservationFormatting.samplingGap(5.001, locale: Locale(identifier: "en_US_POSIX")) == "5.01s"
        )
    }

    @Test("statistics summarize constant measurements")
    func constantStatistics() {
        let start = Date(timeIntervalSince1970: 10_000)
        let samples = (0..<3).map { second in
            PressureSample(timestamp: start.addingTimeInterval(Double(second)), pressureHPA: 842.25)
        }

        let statistics = PressureObservationStatistics(samples: samples)

        #expect(statistics.minimum == 842.25)
        #expect(statistics.maximum == 842.25)
        #expect(statistics.range == 0)
        #expect(statistics.mean == 842.25)
        #expect(statistics.standardDeviation == 0)
        #expect(statistics.sampleCount == 3)
        #expect(statistics.observationSpan == 2)
        #expect(statistics.largestSamplingGap == 1)
        #expect(statistics.yAxisDomain.lowerBound < 842.25)
        #expect(statistics.yAxisDomain.upperBound > 842.25)
    }

    @Test("statistics summarize monotonic and irregularly spaced measurements")
    func monotonicIrregularStatistics() {
        let start = Date(timeIntervalSince1970: 10_000)
        let samples = [0.0, 2.0, 10.0].enumerated().map { index, offset in
            PressureSample(timestamp: start.addingTimeInterval(offset), pressureHPA: 840 + Double(index))
        }

        let statistics = PressureObservationStatistics(samples: samples)

        #expect(statistics.minimum == 840)
        #expect(statistics.maximum == 842)
        #expect(statistics.range == 2)
        #expect(statistics.mean == 841)
        #expect(abs((statistics.standardDeviation ?? -1) - sqrt(2.0 / 3.0)) < 0.000001)
        #expect(statistics.sampleCount == 3)
        #expect(statistics.observationSpan == 10)
        #expect(statistics.largestSamplingGap == 8)
        #expect(statistics.yAxisDomain.lowerBound > 0)
    }

    @Test("empty and single-sample statistics have finite chart domains")
    func emptyAndSingleSampleStatistics() {
        let empty = PressureObservationStatistics(samples: [])
        #expect(empty.minimum == nil)
        #expect(empty.mean == nil)
        #expect(empty.sampleCount == 0)
        #expect(empty.yAxisDomain == 0...1)

        let single = PressureObservationStatistics(samples: [
            PressureSample(timestamp: Date(timeIntervalSince1970: 10_000), pressureHPA: 842.25)
        ])
        #expect(single.minimum == 842.25)
        #expect(single.standardDeviation == 0)
        #expect(single.observationSpan == 0)
        #expect(single.largestSamplingGap == 0)
        #expect(single.yAxisDomain.lowerBound.isFinite)
        #expect(single.yAxisDomain.upperBound.isFinite)
        #expect(single.yAxisDomain.lowerBound < single.yAxisDomain.upperBound)
    }

    @Test("converts kPa to hPa and calculates the signed fifteen-minute change")
    func calculatesChangeFromClosestRetainedSample() {
        let now = Date(timeIntervalSince1970: 10_000)
        var calculator = PressureTrendCalculator()
        calculator.addSample(timestamp: now.addingTimeInterval(-900), pressureKPA: 84.24)
        for second in 1...900 {
            calculator.addSample(timestamp: now.addingTimeInterval(Double(second - 900)),
                                 pressureKPA: 84.24 + 0.13 * Double(second) / 900)
        }

        let snapshot = calculator.snapshot(at: now)

        #expect(abs((snapshot.current?.pressureHPA ?? 0) - 843.7) < 0.001)
        #expect(abs((snapshot.baseline?.pressureHPA ?? 0) - 842.4) < 0.001)
        #expect(abs((snapshot.change ?? 0) - 1.3) < 0.001)
        #expect(snapshot.trend == .rising)
    }

    @Test("prunes samples older than sixty minutes")
    func prunesRollingWindow() {
        let now = Date(timeIntervalSince1970: 10_000)
        var calculator = PressureTrendCalculator()
        calculator.addSample(timestamp: now.addingTimeInterval(-3601), pressureKPA: 84.2)
        calculator.addSample(timestamp: now, pressureKPA: 84.3)

        #expect(calculator.samples.count == 1)
        #expect(calculator.samples[0].timestamp == now)
    }

    @Test("reports collecting until a complete window is available")
    func reportsIncompleteHistory() {
        let now = Date(timeIntervalSince1970: 10_000)
        var calculator = PressureTrendCalculator()
        calculator.addSample(timestamp: now.addingTimeInterval(-60), pressureKPA: 84.2)
        calculator.addSample(timestamp: now, pressureKPA: 84.3)

        let snapshot = calculator.snapshot(at: now)

        #expect(snapshot.change == nil)
        #expect(snapshot.trend == .collecting)
        #expect(snapshot.historyDuration == 60)
    }

    @Test("rolling jittered updates cross fifteen minutes and continue through retention pruning")
    func rollingUpdates() {
        let start = Date(timeIntervalSince1970: 10_000)
        var calculator = PressureTrendCalculator()
        for second in 0...4_000 {
            let elapsed = Double(second) * 1.001
            let timestamp = start.addingTimeInterval(elapsed)
            calculator.addSample(timestamp: timestamp, pressureKPA: 84 + elapsed / 10_000)
            let snapshot = calculator.snapshot(at: timestamp.addingTimeInterval(0.2))
            if elapsed < 900 {
                #expect(snapshot.change == nil)
            } else {
                #expect(abs((snapshot.change ?? 0) - 0.9) < 0.002)
            }
        }
        #expect(calculator.samples.count < 3_601)
        #expect((calculator.samples.first?.timestamp ?? start) > start)
        #expect(calculator.snapshot(at: start.addingTimeInterval(4_004)).historyDuration <= 3_600)
    }

    @Test("signed changes include rising, falling and stable", arguments: [-0.13, 0, 0.13])
    func signedChange(difference: Double) {
        let now = Date(timeIntervalSince1970: 10_000)
        var calculator = PressureTrendCalculator()
        calculator.addSample(timestamp: now.addingTimeInterval(-900), pressureKPA: 84)
        for second in 1...900 {
            calculator.addSample(timestamp: now.addingTimeInterval(Double(second - 900)),
                                 pressureKPA: 84 + difference * Double(second) / 900)
        }
        let snapshot = calculator.snapshot(at: now)
        #expect(abs((snapshot.change ?? 999) - difference * 10) < 0.0001)
        #expect(snapshot.trend == (difference > 0 ? .rising : difference < 0 ? .falling : .stable))
    }

    @Test("continuous history never substitutes an incomplete startup window")
    func baselineTolerance() {
        let now = Date(timeIntervalSince1970: 10_000)
        for offset in [-905, -900, -899] {
            var calculator = PressureTrendCalculator()
            calculator.addSample(timestamp: now.addingTimeInterval(Double(offset)), pressureKPA: 84)
            for second in (offset + 1)...0 {
                calculator.addSample(timestamp: now.addingTimeInterval(Double(second)), pressureKPA: 84.1)
            }
            #expect((calculator.snapshot(at: now).change != nil) == (offset <= -900))
        }
    }

    @Test("a bracketing baseline is accepted only near the target; stale readings cannot mature history")
    func gapsAndStaleness() {
        let now = Date(timeIntervalSince1970: 10_000)
        var calculator = PressureTrendCalculator()
        calculator.addSample(timestamp: now.addingTimeInterval(-1_000), pressureKPA: 84)
        calculator.addSample(timestamp: now.addingTimeInterval(-903), pressureKPA: 84)
        calculator.addSample(timestamp: now.addingTimeInterval(-898), pressureKPA: 84.05)
        for second in -897...0 {
            calculator.addSample(timestamp: now.addingTimeInterval(Double(second)), pressureKPA: 84.1)
        }
        #expect(calculator.snapshot(at: now).baseline?.timestamp == now.addingTimeInterval(-898))
        #expect(calculator.snapshot(at: now.addingTimeInterval(5)).change != nil)
        #expect(calculator.snapshot(at: now.addingTimeInterval(5.1)).change == nil)

        var gap = PressureTrendCalculator()
        gap.addSample(timestamp: now.addingTimeInterval(-1_000), pressureKPA: 84)
        gap.addSample(timestamp: now, pressureKPA: 84.1)
        #expect(gap.snapshot(at: now).change == nil)
        var short = PressureTrendCalculator()
        short.addSample(timestamp: now.addingTimeInterval(-899), pressureKPA: 84)
        short.addSample(timestamp: now, pressureKPA: 84.1)
        #expect(short.snapshot(at: now.addingTimeInterval(2)).historyDuration == 899)
        #expect(short.snapshot(at: now.addingTimeInterval(2)).change == nil)
    }

    @Test("a long outage requires a complete continuous window before recovery")
    func outageRecovery() {
        let start = Date(timeIntervalSince1970: 10_000)
        var calculator = PressureTrendCalculator()
        calculator.addSample(timestamp: start, pressureKPA: 84)
        calculator.addSample(timestamp: start.addingTimeInterval(900), pressureKPA: 85)
        #expect(calculator.snapshot(at: start.addingTimeInterval(900)).change == nil)
        for second in 901...1_801 {
            let now = start.addingTimeInterval(Double(second))
            calculator.addSample(timestamp: now, pressureKPA: 85 + Double(second - 900) / 9_000)
            let snapshot = calculator.snapshot(at: now)
            if second < 1_800 {
                #expect(snapshot.baseline == nil)
                #expect(snapshot.change == nil)
                #expect(snapshot.trend == .collecting)
            } else {
                #expect(abs((snapshot.change ?? 999) - 1) < 0.0001)
            }
        }
    }

    @Test("intersample gaps accept five seconds but reject longer gaps", arguments: [5.0, 5.1])
    func continuityTolerance(gap: Double) {
        let start = Date(timeIntervalSince1970: 10_000)
        var calculator = PressureTrendCalculator()
        for second in 0...450 {
            calculator.addSample(timestamp: start.addingTimeInterval(Double(second)), pressureKPA: 84)
        }
        calculator.addSample(timestamp: start.addingTimeInterval(450 + gap), pressureKPA: 84)
        for second in 456...900 {
            calculator.addSample(timestamp: start.addingTimeInterval(Double(second)), pressureKPA: 84)
        }
        #expect((calculator.snapshot(at: start.addingTimeInterval(900)).change != nil) == (gap == 5))
    }

    @MainActor
    @Test("restart clears the session, stops once and rejects old callbacks including errors")
    func restartIsolation() {
        var callbacks: [@MainActor (Date, Double?, String?) -> Void] = []
        var stops = 0
        let now = Date(timeIntervalSince1970: 10_000)
        let model = BarometricPressureModel(
            isAvailable: { true },
            startUpdates: { callbacks.append($0) },
            stopUpdates: { stops += 1 }
        )
        model.start(at: now)
        model.start(at: now)
        #expect(callbacks.count == 1)
        callbacks[0](now, 84, nil)
        model.restart(at: now.addingTimeInterval(20))
        #expect(stops == 1)
        #expect(callbacks.count == 2)
        #expect(model.sessionStartedAt == now.addingTimeInterval(20))
        #expect(model.calculator.samples.isEmpty)
        #expect(model.lastUpdated == nil)
        callbacks[0](now, 90, nil)
        callbacks[0](now, nil, "Old error")
        #expect(model.errorMessage == nil)
        #expect(model.isCollecting)
        #expect(model.calculator.samples.isEmpty)
        callbacks[1](now.addingTimeInterval(21), 85, nil)
        #expect(model.calculator.samples.count == 1)
        callbacks[1](now, nil, "Sensor error")
        #expect(model.errorMessage == "Sensor error")
        model.restart(at: now.addingTimeInterval(30))
        #expect(model.errorMessage == nil)
        #expect(model.calculator.samples.isEmpty)
        #expect(callbacks.count == 3)
        model.stop()
        callbacks[2](now.addingTimeInterval(31), 86, nil)
        #expect(model.calculator.samples.isEmpty)
        #expect(stops == 3)
    }
}
