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
        calculator.addSample(timestamp: now, pressureKPA: 84.37)

        let snapshot = calculator.snapshot(at: now)

        #expect(abs((snapshot.current?.pressureHPA ?? 0) - 843.7) < 0.001)
        #expect(abs((snapshot.baseline?.pressureHPA ?? 0) - 842.4) < 0.001)
        #expect(abs((snapshot.change ?? 0) - 1.3) < 0.001)
        #expect(snapshot.trend == .rising)
    }

    @Test("prunes samples older than fifteen minutes")
    func prunesRollingWindow() {
        let now = Date(timeIntervalSince1970: 10_000)
        var calculator = PressureTrendCalculator()
        calculator.addSample(timestamp: now.addingTimeInterval(-901), pressureKPA: 84.2)
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
}
