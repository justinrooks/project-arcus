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
                .opacity(0.62)
                .ignoresSafeArea()

            VStack(spacing: 10) {
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
            .cardBackground(cornerRadius: SkyAwareRadius.row, shadowOpacity: 0.16, shadowRadius: 10, shadowY: 6)
        }
        .transition(.opacity.combined(with: .scale))
    }
}

#Preview {
    LoadingView(message: "Syncing outlooks...")
}
