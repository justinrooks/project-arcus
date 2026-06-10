//
//  AlertPresentationOrdering.swift
//  SkyAware
//
//  Created by Justin Rooks on 6/10/26.
//

import Foundation

enum AlertPresentationOrdering {
    private enum PresentationClass: Int {
        case warning
        case watch
        case mesoscale
    }

    static func ordered<Item: AlertItem>(
        _ items: [Item],
        endDate: KeyPath<Item, Date>
    ) -> [Item] {
        items.sorted { lhs, rhs in
            let lhsClass = presentationClass(for: lhs)
            let rhsClass = presentationClass(for: rhs)

            if lhsClass != rhsClass {
                return lhsClass.rawValue < rhsClass.rawValue
            }

            let lhsEndDate = lhs[keyPath: endDate]
            let rhsEndDate = rhs[keyPath: endDate]
            if lhsEndDate != rhsEndDate {
                return lhsEndDate < rhsEndDate
            }

            if lhs.issued != rhs.issued {
                return lhs.issued > rhs.issued
            }

            return String(describing: lhs.id) < String(describing: rhs.id)
        }
    }

    private static func presentationClass<Item: AlertItem>(for item: Item) -> PresentationClass {
        switch item.alertType {
        case .mesoscale:
            return .mesoscale
        case .watch:
            return presentationClass(forTitle: item.title)
        }
    }

    private static func presentationClass(forTitle title: String) -> PresentationClass {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase

        if normalizedTitle.contains("warning") {
            return .warning
        }

        if normalizedTitle.contains("watch") {
            return .watch
        }

        return .watch
    }
}
