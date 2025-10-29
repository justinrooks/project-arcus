//
//  LoadingView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/12/25.
//

import SwiftUI

struct LoadingView: View {
    var message: String = "Fetching Data..."

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    .scaleEffect(1.3)

                Text(message)
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
        }
        .transition(.opacity.combined(with: .scale)) // Smooth fade & scale
    }
}

#Preview {
    LoadingView(message: "Fetching SPC Data...")
}
