import SwiftUI

#if canImport(Testing)
import Testing
@testable import SkyAware

@Suite("SkyAware Adaptive Layout")
struct SkyAwareAdaptiveLayoutTests {
    @Test("Map legend mode stays inline through xxxLarge")
    func mapLegendMode_inlineForNormalAndXXXL() {
        #expect(SkyAwareAdaptiveLayout(dynamicTypeSize: .large).mapLegendMode == .inline)
        #expect(SkyAwareAdaptiveLayout(dynamicTypeSize: .xxxLarge).mapLegendMode == .inline)
    }

    @Test("Map legend mode uses compact trigger at accessibility1")
    func mapLegendMode_compactAtAccessibility1() {
        #expect(SkyAwareAdaptiveLayout(dynamicTypeSize: .accessibility1).mapLegendMode == .compactTrigger)
    }

    @Test("Map legend mode uses sheet-only at accessibility3")
    func mapLegendMode_sheetOnlyAtAccessibility3() {
        #expect(SkyAwareAdaptiveLayout(dynamicTypeSize: .accessibility3).mapLegendMode == .sheetOnly)
    }

    @Test("Hero cards stack in accessibility sizes")
    func heroCards_stackForAccessibilitySizes() {
        #expect(SkyAwareAdaptiveLayout(dynamicTypeSize: .accessibility1).usesStackedHeroTiles)
        #expect(SkyAwareAdaptiveLayout(dynamicTypeSize: .accessibility3).usesStackedHeroTiles)
    }

    @Test("Metric rows become vertical in accessibility sizes")
    func metricRows_verticalForAccessibilitySizes() {
        #expect(SkyAwareAdaptiveLayout(dynamicTypeSize: .accessibility1).usesVerticalMetricRows)
        #expect(SkyAwareAdaptiveLayout(dynamicTypeSize: .accessibility3).usesVerticalMetricRows)
    }
}
#endif
