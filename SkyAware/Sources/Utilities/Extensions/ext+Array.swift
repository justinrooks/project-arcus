//
//  ext+Array.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/20/26.
//

import Foundation

extension Array {
    func removingDuplicates<Key: Hashable>(by key: KeyPath<Element, Key>) -> [Element] {
        var seen = Set<Key>()
        return filter { element in
            let propertyValue = element[keyPath: key]
            return seen.insert(propertyValue).inserted
        }
    }
}
