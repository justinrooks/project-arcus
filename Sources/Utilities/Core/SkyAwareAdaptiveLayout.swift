import SwiftUI

enum MapLegendMode {
    case inline
    case compactTrigger
    case sheetOnly
}

struct SkyAwareAdaptiveLayout {
    let dynamicTypeSize: DynamicTypeSize

    var usesAccessibilityLayout: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var mapLegendMode: MapLegendMode {
        if dynamicTypeSize >= .accessibility3 {
            return .sheetOnly
        }
        if dynamicTypeSize >= .accessibility1 {
            return .compactTrigger
        }
        return .inline
    }

    var usesStackedHeroTiles: Bool {
        usesAccessibilityLayout
    }

    var usesVerticalMetricRows: Bool {
        usesAccessibilityLayout
    }
}
