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
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
        }
        .transition(.opacity.combined(with: .scale)) // Smooth fade & scale
    }
}

#Preview {
    LoadingView(message: "Syncing outlooks...")
}
