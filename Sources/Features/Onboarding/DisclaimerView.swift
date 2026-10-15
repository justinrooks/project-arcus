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
                DisclaimerSection(
                    symbol: "info.circle.fill",
                    title: "Informational Only",
                    statements: [
                        "SkyAware provides severe weather awareness using public data from the Storm Prediction Center, National Weather Service, & Apple Weather.",
                        "Risk levels and badges shown in the app are computed estimates based on that data.",
                        "SkyAware does not issue official weather warnings."
                    ]
                )

                DisclaimerSection(
                    symbol: "clock.arrow.circlepath",
                    title: "Data Limitations",
                    statements: [
                        "SkyAware may not always refresh in the background.",
                        "Location-based awareness and notifications are provided on a best-effort basis and may not always reflect real-time conditions.",
                        "SkyAware should not be relied upon as your only source of severe weather information."
                    ]
                )

                DisclaimerSection(
                    symbol: "exclamationmark.triangle.fill",
                    title: "Emergency Information",
                    statements: [
                        "Always rely on official alerts from the National Weather Service, NOAA Weather Radio, and local authorities for emergency information."
                    ]
                )
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

private struct DisclaimerSection: View {
    let symbol: String
    let title: String
    let statements: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            ForEach(statements, id: \.self) { statement in
                Text(statement)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .skyAwareContentSurface(cornerRadius: SkyAwareRadius.card)
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
