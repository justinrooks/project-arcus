import SwiftUI

#if canImport(Testing)
import Testing
@testable import SkyAware

@Suite("Layer Picker Adaptive Layout")
struct LayerPickerAdaptiveLayoutTests {
    @Test("Normal and xxxLarge keep grid layout")
    func normalAndXXXL_useGridLayout() {
        #expect(LayerPickerSheet.usesAccessibilityListLayoutPolicy(dynamicTypeSize: .large) == false)
        #expect(LayerPickerSheet.usesAccessibilityListLayoutPolicy(dynamicTypeSize: .xxxLarge) == false)
    }

    @Test("Accessibility sizes use vertical list layout")
    func accessibilitySizes_useListLayout() {
        #expect(LayerPickerSheet.usesAccessibilityListLayoutPolicy(dynamicTypeSize: .accessibility1))
        #expect(LayerPickerSheet.usesAccessibilityListLayoutPolicy(dynamicTypeSize: .accessibility3))
    }

    @Test("Warning geometry toggle is hidden in accessibility sizes")
    func warningToggle_visibilityMatchesPolicy() {
        #expect(LayerPickerSheet.showsWarningGeometryTogglePolicy(dynamicTypeSize: .large))
        #expect(LayerPickerSheet.showsWarningGeometryTogglePolicy(dynamicTypeSize: .xxxLarge))
        #expect(LayerPickerSheet.showsWarningGeometryTogglePolicy(dynamicTypeSize: .accessibility1) == false)
        #expect(LayerPickerSheet.showsWarningGeometryTogglePolicy(dynamicTypeSize: .accessibility3) == false)
    }
}
#endif
