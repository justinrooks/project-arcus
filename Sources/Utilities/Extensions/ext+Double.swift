//
//  ext+Double.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/13/25.
//

import Foundation

extension Double {
    func truncated(to places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded(.towardZero) / factor
    }
}
