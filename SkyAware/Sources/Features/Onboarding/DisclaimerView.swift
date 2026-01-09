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
                
                Text("""
                    SkyAware provides severe weather awareness using public data from the Storm Prediction Center and National Weather Service.
                    
                    Risk levels and badges shown in the app are **computed estimates** based on that data.
                    
                    SkyAware:
                        - Does not issue official weather warnings
                        - May not always refresh in the background
                        - Should not be relied upon as your only source of severe weather information
                    
                    Always follow official guidance from the National Weather Service, NOAA Weather Radio, and local authorities.
                    """)
                    .font(.footnote)
                    .fontWeight(.bold)
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
