import Testing
@testable import SkyAware

@Suite("Widget gallery metadata")
struct WidgetGalleryMetadataTests {
    @Test("gallery names match FB-017 brief")
    func names_matchBrief() {
        #expect(WidgetGalleryMetadata.stormRiskName == "Storm Risk")
        #expect(WidgetGalleryMetadata.severeRiskName == "Severe Risk")
        #expect(WidgetGalleryMetadata.combinedName == "Combined")
    }

    @Test("gallery descriptions match FB-017 brief")
    func descriptions_matchBrief() {
        #expect(WidgetGalleryMetadata.stormRiskDescription == "See current local storm risk.")
        #expect(WidgetGalleryMetadata.severeRiskDescription == "See current local severe weather risk.")
        #expect(WidgetGalleryMetadata.combinedDescription == "See local risk and the highest-priority active alert.")
    }
}
