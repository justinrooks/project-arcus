//
//  LoadingView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/12/25.
//

import SwiftUI

struct LoadingView: View {
    var message: String = "Refreshing data..."

    var body: some View {
        ZStack {
            Color.skyAwareBackground
                .opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                ProgressView()
                    .tint(.skyAwareAccent)
                    .scaleEffect(1.2)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .skyAwareSurface(
                cornerRadius: 16,
                tint: .skyAwareAccent.opacity(0.18),
                shadowOpacity: 0.2,
                shadowRadius: 12,
                shadowY: 8
            )
        }
        .transition(.opacity.combined(with: .scale)) // Smooth fade & scale
    }
}

#Preview {
    LoadingView(message: "Syncing outlooks...")
}
