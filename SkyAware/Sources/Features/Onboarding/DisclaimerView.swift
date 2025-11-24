//
//  DisclaimerView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/22/25.
//

import SwiftUI

struct DisclaimerView: View {
    let onAccept: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.skyAwareAccent)
            
            Text("Important Information")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("SkyAware provides severe weather awareness using data from:")
                    .font(.body)
                
                VStack(alignment: .leading, spacing: 4) {
//                    Text("• Apple WeatherKit")
                    Text("• NOAA Storm Prediction Center")
                    Text("• National Weather Service")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                Text("This app is not a substitute for official weather alerts. Always verify critical information with official sources.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 32)
            
            Spacer()
            
            Button(action: onAccept) {
                Text("I Understand")
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
    DisclaimerView() { }
}
