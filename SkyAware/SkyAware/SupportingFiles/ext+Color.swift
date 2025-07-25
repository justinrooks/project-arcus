//
//  ext+Color.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI

extension Color {
    static let tornadoRed = Color(red: 0.8, green: 0.2, blue: 0.4)
    static let hailBlue = Color(red: 0.3, green: 0.6, blue: 0.9)
    static let windTeal = Color(red: 0.2, green: 0.7, blue: 0.7)
    
    func darken(by amount: Double = 0.2) -> Color {
        return self.opacity(1.0 - amount)
    }
}
