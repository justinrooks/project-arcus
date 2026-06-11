//
//  ext+Image.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/25/25.
//

import SwiftUI

extension Image {
    func formatBadgeImage(size: CGFloat = 35) -> some View {
        self.resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .font(.largeTitle)
            .foregroundColor(.primary)
    }
}
