import SwiftUI

struct OnboardingWinterImpactsView: View {
    let onChoice: (Bool) -> Void

    var body: some View {
        OnboardingStepShell {
            OnboardingStepHeading(symbol: "snowflake", title: "Winter Impacts")

            Text("See where snow, ice, and blowing snow could cause impacts, based on NOAA’s Winter Storm Severity Index.")
                .font(.body)
                .multilineTextAlignment(.center)

            Text("You can change this anytime in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } footer: {
            VStack(spacing: 12) {
                Button("Enable Winter Impacts") { onChoice(true) }
                    .buttonStyle(OnboardingPrimaryActionStyle())

                Button("Not Now") { onChoice(false) }
                    .buttonStyle(OnboardingSecondaryActionStyle())
                    .accessibilityIdentifier("onboarding-winter-impacts-not-now")
            }
        }
    }
}

#Preview {
    OnboardingWinterImpactsView(onChoice: { _ in })
}
