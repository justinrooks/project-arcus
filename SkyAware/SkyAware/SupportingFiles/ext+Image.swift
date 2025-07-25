//
//  ext+Image.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI

extension Image {
    func formatBadgeImage() -> some View {
        self.resizable()
            .scaledToFit()
            .frame(width: 35, height: 35)
            .font(.largeTitle)
            .foregroundColor(.primary)
    }
}
