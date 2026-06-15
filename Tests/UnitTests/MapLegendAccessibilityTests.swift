#if canImport(Testing)
import Testing
@testable import SkyAware

@Suite("Map Legend Accessibility")
struct MapLegendAccessibilityTests {
    @Test("categorical legend exposes layer and level separately")
    func categoricalLegend_exposesLayerAndLevelSeparately() {
        let contract = MapLegendAccessibility.categorical(risk: .moderate)

        #expect(contract.label == "Severe Risk")
        #expect(contract.value == "Moderate Risk")
    }

    @Test("severe legend exposes layer and probability separately")
    func severeLegend_exposesLayerAndProbabilitySeparately() {
        let contract = MapLegendAccessibility.severe(
            layer: .tornado,
            probability: .significant(25)
        )

        #expect(contract.label == "Tornado Risk")
        #expect(contract.value == "25 percent significant probability")
    }

    @Test("mesoscale and fire legends keep their visible meaning concise")
    func mesoAndFireLegends_keepTheirVisibleMeaningConcise() {
        let meso = MapLegendAccessibility.meso()
        let fire = MapLegendAccessibility.fire(riskLabel: "Critical")

        #expect(meso.label == "Mesoscale")
        #expect(meso.value == "Displayed area")
        #expect(fire.label == "Fire Risk")
        #expect(fire.value == "Critical")
    }

    @Test("hatching legend remains a semantic label and value pair")
    func hatchingLegend_remainsSemantic() {
        let contract = MapLegendAccessibility.hatch()

        #expect(contract.label == "Hatching")
        #expect(contract.value == "Stronger storms possible")
    }
}
#endif
