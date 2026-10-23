import Foundation
import Testing
@testable import SkyAware

@Suite("Barometric pressure trend")
struct BarometricPressureTrendTests {
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
