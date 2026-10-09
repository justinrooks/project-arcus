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
        OnboardingStepShell {
            OnboardingStepHeading(
                symbol: "checkmark.shield.fill",
                title: "Important Information",
                subtitle: "Please review before continuing."
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("""
                    SkyAware provides severe weather awareness using public data from the Storm Prediction Center, National Weather Service, & Apple Weather.
                    
                    Risk levels and badges shown in the app are **computed estimates** based on that data.
                    
                    SkyAware:
                        - Does not issue official weather warnings
                        - May not always refresh in the background
                        - Should not be relied upon as your only source of severe weather information
                    
                    Location-based awareness and notifications are provided on a best-effort basis and may not always reflect real-time conditions. 
                    
                    Always rely on official alerts from the National Weather Service, NOAA Weather Radio, and local authorities for emergency information.
                    """)
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
        } footer: {
            Button(action: onAccept) {
                Text("I Understand")
            }
            .buttonStyle(OnboardingPrimaryActionStyle())
        }
    }
}

#Preview {
    DisclaimerView() { }
}

private struct DisclaimerViewAX5Preview: PreviewProvider {
    static var previews: some View {
        DisclaimerView() { }
            .previewDevice("iPhone SE (3rd generation)")
            .environment(\.dynamicTypeSize, .accessibility5)
    }
}
