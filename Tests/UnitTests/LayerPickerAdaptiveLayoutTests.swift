import SwiftUI

#if canImport(Testing)
import Testing
@testable import SkyAware

@Suite("Map Layer Menu")
struct MapLayerMenuTests {
    @Test("Picker selection only updates when the layer changes")
    func selectionOnlyUpdatesOnChange() {
        #expect(MapLayerMenu.shouldUpdateSelection(current: .categorical, to: .wind))
        #expect(MapLayerMenu.shouldUpdateSelection(current: .wind, to: .wind) == false)
    }

    @Test("Warning geometry toggle remains available at all Dynamic Type sizes")
    func warningToggle_staysVisible() {
        #expect(MapLayerMenu.showsWarningGeometryTogglePolicy(dynamicTypeSize: .large))
        #expect(MapLayerMenu.showsWarningGeometryTogglePolicy(dynamicTypeSize: .xxxLarge))
        #expect(MapLayerMenu.showsWarningGeometryTogglePolicy(dynamicTypeSize: .accessibility1))
        #expect(MapLayerMenu.showsWarningGeometryTogglePolicy(dynamicTypeSize: .accessibility3))
    }

    @Test("Duplicate layer selections do not request updates")
    func duplicateSelection_doesNotUpdate() {
        #expect(MapLayerMenu.shouldUpdateSelection(current: .categorical, to: .categorical) == false)
        #expect(MapLayerMenu.shouldUpdateSelection(current: .categorical, to: .wind))
    }

    @Test("Map layer menu accessibility state uses selected traits instead of label suffixes")
    func accessibilityState_marksOnlyTheSelectedLayer() {
        let selected = MapLayerMenu.accessibilityState(for: .wind, selection: .wind)
        let unselected = MapLayerMenu.accessibilityState(for: .hail, selection: .wind)

        #expect(selected.label == "Wind")
        #expect(selected.isSelected)
        #expect(unselected.label == "Hail")
        #expect(unselected.isSelected == false)
    }
}
#endif
