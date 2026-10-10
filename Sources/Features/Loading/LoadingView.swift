//
//  LoadingView.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/12/25.
//

import SwiftUI

struct LoadingView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Image(decorative: "LaunchCyclone")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(.primary)
                .accessibilityHidden(true)
                .padding(.bottom, 24)

            Text("Preparing your local weather picture")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text("Checking conditions and alerts for your area.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            ProgressView()
                .controlSize(.regular)
                .tint(.skyAwareAccent)
                .accessibilityLabel("Loading conditions")
                .padding(.top, 24)
        }
        .safeAreaPadding(.horizontal, 24)
        .safeAreaPadding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TodaySurfaceStyle.canvas(for: colorScheme).ignoresSafeArea())
    }
}

#Preview {
    LoadingView()
        .padding(.horizontal, 16)
}

#Preview("Dark") {
    LoadingView()
        .padding(.horizontal, 16)
        .preferredColorScheme(.dark)
}

#Preview("Reduce Motion (Name Only)") {
    LoadingView()
        .padding(.horizontal, 16)
}
