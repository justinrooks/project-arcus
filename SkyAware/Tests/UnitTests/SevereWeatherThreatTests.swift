import Testing
@testable import SkyAware

@Suite("SevereWeatherThreat")
struct SevereWeatherThreatTests {
    @Test("probability returns 0 for allClear and preserves stored value for others")
    func probability_returnsExpectedValues() {
        #expect(SevereWeatherThreat.allClear.probability == 0.0)
        #expect(SevereWeatherThreat.wind(probability: 0.2).probability == 0.2)
        #expect(SevereWeatherThreat.hail(probability: 0.35).probability == 0.35)
        #expect(SevereWeatherThreat.tornado(probability: 0.7).probability == 0.7)
    }

    @Test("priority ordering matches tornado > hail > wind > allClear")
    func priority_ordering() {
        #expect(SevereWeatherThreat.tornado(probability: 0.1).priority == 3)
        #expect(SevereWeatherThreat.hail(probability: 0.1).priority == 2)
        #expect(SevereWeatherThreat.wind(probability: 0.1).priority == 1)
        #expect(SevereWeatherThreat.allClear.priority == 0)
    }

    @Test("Comparable uses priority for sorting")
    func comparable_sorting() {
        let items: [SevereWeatherThreat] = [
            .wind(probability: 0.3),
            .tornado(probability: 0.1),
            .allClear,
            .hail(probability: 0.2)
        ]
        let sorted = items.sorted()
        #expect(sorted.first == .allClear)
        #expect(sorted.last == .tornado(probability: 0.1))
    }

    @Test("message and summary strings are correct")
    func message_and_summary() {
        #expect(SevereWeatherThreat.allClear.message == "No Active Threats")
        #expect(SevereWeatherThreat.wind(probability: 0.1).message == "Wind")
        #expect(SevereWeatherThreat.hail(probability: 0.1).message == "Hail")
        #expect(SevereWeatherThreat.tornado(probability: 0.1).message == "Tornado")

        #expect(SevereWeatherThreat.allClear.summary == "No severe threats expected")
        #expect(SevereWeatherThreat.wind(probability: 0.1).summary == "Damaging wind possible")
        #expect(SevereWeatherThreat.hail(probability: 0.1).summary == "1in or larger hail possible")
        #expect(SevereWeatherThreat.tornado(probability: 0.1).summary == "Tornados are possible")
    }

    @Test("dynamicSummary formats percentages and is empty for allClear")
    func dynamicSummary_formatsPercent() {
        #expect(SevereWeatherThreat.allClear.dynamicSummary.isEmpty)
        #expect(SevereWeatherThreat.tornado(probability: 0.32).dynamicSummary == "32% chance of tornadoes")
        #expect(SevereWeatherThreat.hail(probability: 0.05).dynamicSummary == "5% chance of large hail")
        #expect(SevereWeatherThreat.wind(probability: 0.2).dynamicSummary == "20% chance of damaging winds")
    }

    @Test("with(probability:) preserves threat type")
    func with_preservesType() {
        #expect(SevereWeatherThreat.allClear.with(probability: 0.5) == .allClear)
        #expect(SevereWeatherThreat.wind(probability: 0.1).with(probability: 0.9) == .wind(probability: 0.9))
        #expect(SevereWeatherThreat.hail(probability: 0.1).with(probability: 0.9) == .hail(probability: 0.9))
        #expect(SevereWeatherThreat.tornado(probability: 0.1).with(probability: 0.9) == .tornado(probability: 0.9))
    }
}
