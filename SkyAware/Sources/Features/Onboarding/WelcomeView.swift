//
//  WelcomeView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/23/25.
//

import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App icon or weather-related graphic
            Image(systemName: "cloud.bolt.fill")
                .font(.system(size: 100))
                .foregroundColor(.skyAwareAccent)
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    Color.skyAwareAccent,
                    Color.skyAwareAccent.opacity(0.5)
                )
            
            Text("Welcome to SkyAware")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Know how weather-aware you need to be today—in seconds, with no clutter.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Text("Get simple, actionable severe weather intelligence based on official NOAA and NWS data.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.skyAwareAccent)
                    )
            }
            .padding(.horizontal, 32)
            Spacer() 
        }
        .padding()
        .background(Color.skyAwareBackground.ignoresSafeArea())
    }
}

#Preview {
    WelcomeView() { }
}
