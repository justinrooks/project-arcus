//
//  OnboardingView.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/22/25.
//

import CoreLocation
import OSLog
import SwiftUI
import UserNotifications

@MainActor
struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(LocationSession.self) private var locationSession

    private let logger = Logger.appMain
    private let locationReliabilityLogger = Logger.uiLocationReliability
    private let currentDisclaimerVersion = 1

    @AppStorage(
        "onboardingComplete",
        store: UserDefaults.shared
    ) private var onboardingComplete: Bool = false

    @AppStorage(
        "disclaimerAcceptedVersion",
        store: UserDefaults.shared
    ) private var disclaimerVersion = 0

    @State private var currentStep: OnboardingStep = .welcome
    @State private var locationStepState: PermissionStepState = .idle
    @State private var alwaysUpgradeStepState: PermissionStepState = .idle
    @State private var notificationStepState: PermissionStepState = .idle

    private var isArcusSignalPushEnabled: Bool {
        ArcusSignalConfiguration.configuredBaseURL() != nil
    }

    var body: some View {
        TabView(selection: $currentStep) {
            WelcomeView {
                advance(to: .disclaimer)
            }
            .tag(OnboardingStep.welcome)

            DisclaimerView {
                disclaimerVersion = currentDisclaimerVersion
                advance(to: .locationPermission)
            }
            .tag(OnboardingStep.disclaimer)

            LocationPermissionView(
                isWorking: locationStepState.isWorking,
                statusMessage: locationStepState.statusMessage,
                onEnable: requestLocationPermission,
                onSkip: skipLocationPermissionStep
            )
            .tag(OnboardingStep.locationPermission)

            OnboardingAlwaysUpgradeView(
                isWorking: alwaysUpgradeStepState.isWorking,
                statusMessage: alwaysUpgradeStepState.statusMessage,
                onEnableAlways: requestAlwaysUpgradeDuringOnboarding,
                onSkip: skipAlwaysUpgradeStep
            )
            .tag(OnboardingStep.alwaysUpgrade)

            NotificationPermissionView(
                isWorking: notificationStepState.isWorking,
                statusMessage: notificationStepState.statusMessage,
                onEnable: requestNotificationPermission,
                onSkip: completeOnboarding
            )
            .tag(OnboardingStep.notificationPermission)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .overlay {
            OnboardingPagerSwipeBlocker()
                .allowsHitTesting(false)
        }
        .background(.skyAwareBackground)
    }

    private func requestLocationPermission() {
        guard !locationStepState.isWorking else { return }

        Task { @MainActor in
            locationStepState = .working("Waiting for your location choice...")
            _ = await locationSession.prepareCurrentLocationContext(
                requiresFreshLocation: false,
                showsAuthorizationPrompt: true
            )

            if locationSession.authorizationStatus == .authorizedWhenInUse {
                locationStepState = .idle
                locationReliabilityLogger.notice("Onboarding routed to the Always upgrade page after While Using authorization")
                advance(to: .alwaysUpgrade)
                return
            }

            locationReliabilityLogger.info("Onboarding continued past the location step without While Using authorization")
            locationStepState = .idle
            advance(to: .notificationPermission)
        }
    }

    private func requestAlwaysUpgradeDuringOnboarding() {
        guard !alwaysUpgradeStepState.isWorking else { return }

        Task { @MainActor in
            alwaysUpgradeStepState = .working("Requesting Always for more reliable background alerts...")
            try? await Task.sleep(for: .milliseconds(300))
            let didRequestUpgrade = locationSession.requestAlwaysAuthorizationUpgradeIfNeeded()
            if didRequestUpgrade {
                locationReliabilityLogger.notice("Onboarding submitted the native Always upgrade request")
            } else {
                locationReliabilityLogger.info("Onboarding could not submit the native Always upgrade request; continuing to notifications")
            }
            alwaysUpgradeStepState = .idle
            advance(to: .notificationPermission)
        }
    }

    private func skipLocationPermissionStep() {
        locationReliabilityLogger.info("Onboarding skipped the location permission step")
        advance(to: .notificationPermission)
    }

    private func skipAlwaysUpgradeStep() {
        locationReliabilityLogger.info("Onboarding skipped the Always upgrade step")
        advance(to: .notificationPermission)
    }

    private func requestNotificationPermission() {
        guard !notificationStepState.isWorking else { return }

        Task { @MainActor in
            await finalizeNotificationOnboarding()
        }
    }

    @MainActor
    private func finalizeNotificationOnboarding() async {
        notificationStepState = .working("Requesting notification access...")
        let status = await RemoteNotificationRegistrar.shared.requestAuthorizationAndRegister()

        guard status.isRemoteRegistrationEligible else {
            notificationStepState = .idle
            completeOnboarding()
            return
        }

        guard isArcusSignalPushEnabled else {
            notificationStepState = .idle
            completeOnboarding()
            return
        }

        notificationStepState = .working("Finalizing device registration...")
        guard await RemoteNotificationRegistrar.shared.waitForDeviceToken() != nil else {
            logger.notice("Continuing onboarding without APNs token; token not received before timeout")
            notificationStepState = .idle
            completeOnboarding()
            return
        }

        let canCaptureFreshSnapshot = locationSession.authorizationStatus.isAuthorizedForOnboardingLocation
        if canCaptureFreshSnapshot {
            notificationStepState = .working("Capturing your first location context...")
            let context = await locationSession.prepareCurrentLocationContext(
                requiresFreshLocation: true,
                showsAuthorizationPrompt: false,
                uploadSource: nil,
                uploadReason: nil
            )
            if context == nil {
                logger.notice("Continuing onboarding without an uploaded location context; none became available")
            } else {
                await locationSession.enqueueCurrentLocationUpload(
                    source: .onboarding,
                    reason: .locationResolved
                )
            }
        }

        notificationStepState = .idle
        completeOnboarding()
    }

    @MainActor
    private func advance(to step: OnboardingStep) {
        withAnimation(SkyAwareMotion.onboardingStep(reduceMotion)) {
            currentStep = step
        }
    }

    @MainActor
    private func completeOnboarding() {
        onboardingComplete = true
    }
}

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case disclaimer
    case locationPermission
    case alwaysUpgrade
    case notificationPermission

    var id: Int { rawValue }

    func nextStep(locationAuthorizationStatus: CLAuthorizationStatus? = nil) -> OnboardingStep? {
        switch self {
        case .welcome:
            return .disclaimer
        case .disclaimer:
            return .locationPermission
        case .locationPermission:
            if locationAuthorizationStatus == .authorizedWhenInUse {
                return .alwaysUpgrade
            }
            return .notificationPermission
        case .alwaysUpgrade:
            return .notificationPermission
        case .notificationPermission:
            return nil
        }
    }
}

private enum PermissionStepState: Equatable {
    case idle
    case working(String)

    var isWorking: Bool {
        if case .working = self {
            return true
        }
        return false
    }

    var statusMessage: String? {
        switch self {
        case .idle:
            return nil
        case .working(let message):
            return message
        }
    }
}

private extension CLAuthorizationStatus {
    var isAuthorizedForOnboardingLocation: Bool {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }
}

private extension UNAuthorizationStatus {
    var isRemoteRegistrationEligible: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }
}

#Preview {
    OnboardingView()
        .environment(LocationSession.preview)
}
