//
//  OnboardingView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/22/25.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dependencies) private var deps
    
    // MARK: Local handles
    private var sync: any SpcSyncing { deps.spcSync }
    
//    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @AppStorage(
        "onboardingComplete",
        store: UserDefaults.shared
    ) private var onboardingComplete: Bool = false
    
    @AppStorage(
        "disclaimerAcceptedVersion",
        store: UserDefaults.shared
    ) private var disclaimerVersion = 0
    
    @State private var currentPage = 0
    
    let currentDisclaimerVersion = 1
    
    let locationMgr: LocationManager
    
    var body: some View {
        TabView(selection: $currentPage) {
            // Page 0: Welcome
            WelcomeView {
                withAnimation {
                    currentPage = 1
                }
            }
            .tag(0)
            
            // Page 1: Disclaimer
            DisclaimerView {
                disclaimerVersion = currentDisclaimerVersion
                withAnimation {
                    currentPage = 2
                }
            }
            .tag(1)
            
            // Page 2: Location Permission
            LocationPermissionView(locationMgr: locationMgr) {
                withAnimation {
                    currentPage = 3
                }
            }
            .tag(2)
            
            // Page 3: Notification Permission
            NotificationPermissionView {
                // This is the last step—mark onboarding complete
                onboardingComplete = true
                Task {
                    await sync.sync()
                }
            }
            .tag(3)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(.skyAwareBackground)
    }
}

#Preview {
    let provider = LocationProvider()
    let sink: LocationSink = { [provider] update in await provider.send(update: update) }
    let locationMgr = LocationManager(onUpdate: sink)
    
    OnboardingView(locationMgr: locationMgr)
}
