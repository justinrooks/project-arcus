# Apple-Native UI Alignment Progress

This is the durable handoff ledger for the Apple-native UI alignment epic.

Update it after every issue. Keep entries factual and concise so the next agent can resume without reconstructing
decisions from Git history.

## GitHub Coordination

- Parent epic: [#216](https://github.com/justinrooks/project-arcus/issues/216)
- Project: [Project Arcus](https://github.com/users/justinrooks/projects/1)
- Native hierarchy verified 2026-06-10: 28 ordered sub-issues, #217 through #244
- Project membership verified 2026-06-10: parent plus all 28 sub-issues, 29 unique items

## Current Status

| Order | ID | GitHub | Title | Status | Notes |
|---:|---|---|---|---|---|
| 1 | AN-01 | [#217](https://github.com/justinrooks/project-arcus/issues/217) | Enforce warning-first alert presentation | Completed | Shared ordering helper now enforces warning, watch, mesoscale precedence with deterministic tie-breakers. |
| 2 | AN-02 | [#218](https://github.com/justinrooks/project-arcus/issues/218) | Preserve critical alert text for VoiceOver | Completed | VoiceOver now reads the visible instruction and summary text directly, while grouped detail rows still read as coherent sections. |
| 3 | AN-03 | [#219](https://github.com/justinrooks/project-arcus/issues/219) | Convert the location reliability rail to native buttons | Completed | Native sibling buttons now replace the parent tap gesture while preserving the existing rail styling, copy, and dismissal flow. |
| 4 | AN-04 | [#220](https://github.com/justinrooks/project-arcus/issues/220) | Separate notification preference from authorization | Completed | Stored notification preferences now survive denied authorization, effective availability is derived from authorization plus stored choice, and Settings surfaces an Open Settings recovery action. |
| 5 | AN-05 | [#221](https://github.com/justinrooks/project-arcus/issues/221) | Remove raw diagnostics from production Settings | Not started | |
| 6 | AN-06 | [#222](https://github.com/justinrooks/project-arcus/issues/222) | Make launch and onboarding presentation state explicit | Completed | Launch presentation now uses a single routed item and onboarding uses typed steps with swipe blocked. |
| 7 | AN-07 | [#223](https://github.com/justinrooks/project-arcus/issues/223) | Make onboarding resilient to Dynamic Type | Not started | |
| 8 | AN-08 | [#224](https://github.com/justinrooks/project-arcus/issues/224) | Apply Reduce Motion to onboarding and toasts | Completed | Onboarding and toast motion now route through `SkyAwareMotion` and respect `accessibilityReduceMotion`. |
| 9 | AN-09 | [#225](https://github.com/justinrooks/project-arcus/issues/225) | Replace implementation language in user-facing copy | Completed | Canonical terminology now replaces subsystem language in Settings, Outlooks, and onboarding progress copy. |
| 10 | AN-10 | [#226](https://github.com/justinrooks/project-arcus/issues/226) | Preserve optional Outlook metadata truthfully | Completed | Detail presentation now preserves optional day and valid-until metadata truthfully without inventing fallback precision. |
| 11 | AN-11 | [#227](https://github.com/justinrooks/project-arcus/issues/227) | Use proportional typography for weather narratives | Completed | Narrative paragraphs now use proportional Dynamic Type typography, with monospaced digits preserved for compact technical values. |
| 12 | AN-12 | [#228](https://github.com/justinrooks/project-arcus/issues/228) | Preserve cached Summary content while offline | Completed | Cached Storm Risk, Severe Risk, Fire Risk, Atmospheric Conditions, and Local Alerts now remain visible offline with a quiet freshness/availability cue instead of being replaced by generic offline cards. |
| 13 | AN-13 | [#229](https://github.com/justinrooks/project-arcus/issues/229) | Restore Summary hero category identity at large text sizes | Not started | |
| 14 | AN-14 | [#230](https://github.com/justinrooks/project-arcus/issues/230) | Define explicit semantics for custom controls | Not started | |
| 15 | AN-15 | [#231](https://github.com/justinrooks/project-arcus/issues/231) | Restore semantic color discipline | Not started | |
| 16 | AN-16 | [#232](https://github.com/justinrooks/project-arcus/issues/232) | Make static chips noninteractive and modernize haptics | Not started | |
| 17 | AN-17 | [#233](https://github.com/justinrooks/project-arcus/issues/233) | Make Liquid Glass opt-in | Not started | |
| 18 | AN-18 | [#234](https://github.com/justinrooks/project-arcus/issues/234) | Reduce nested Summary surface chrome | Not started | |
| 19 | AN-19 | [#235](https://github.com/justinrooks/project-arcus/issues/235) | Move Settings to native Form structure | Not started | |
| 20 | AN-20 | [#236](https://github.com/justinrooks/project-arcus/issues/236) | Native-align the Alerts list structure | Not started | |
| 21 | AN-21 | [#237](https://github.com/justinrooks/project-arcus/issues/237) | Native-align the Outlooks list structure | Not started | |
| 22 | AN-22 | [#238](https://github.com/justinrooks/project-arcus/issues/238) | Distinguish map unavailable, stale, and confirmed-empty states | Not started | |
| 23 | AN-23 | [#239](https://github.com/justinrooks/project-arcus/issues/239) | Build the warning legend from rendered warnings | Not started | |
| 24 | AN-24 | [#240](https://github.com/justinrooks/project-arcus/issues/240) | Replace the map layer sheet with a native current-state menu | Not started | |
| 25 | AN-25 | [#241](https://github.com/justinrooks/project-arcus/issues/241) | Add accessible equivalents for map overlays | Not started | |
| 26 | AN-26 | [#242](https://github.com/justinrooks/project-arcus/issues/242) | Reduce map control and legend crowding | Not started | |
| 27 | AN-27 | [#243](https://github.com/justinrooks/project-arcus/issues/243) | Add a minimal spacing scale during final polish | Not started | |
| 28 | AN-28 | [#244](https://github.com/justinrooks/project-arcus/issues/244) | Run the Apple-native acceptance matrix | Not started | |

## Global Decisions

- The audit's 24 findings are covered by AN-01 through AN-27.
- NAV-2 is intentionally split by screen: Settings, Alerts, and Outlooks.
- NATIVE-4 is intentionally split into notification state correctness and production diagnostics.
- AN-28 is a verification gate, not permission for a broad cleanup pass.
- Work proceeds from semantic correctness and accessibility foundations to shared visual policy, native utility
  structure, map work, spacing cleanup, and final acceptance.
- The preferred implementation model is `gpt-5.4-mini / medium` unless the runbook assigns a stronger model.

## Baseline Artifacts

- Audit: `docs/audits/apple-native-ui-audit.md`
- Runbook: `docs/plans/apple-native-ui-alignment-runbook.md`
- North Star: `docs/SkyAware North Star Spec.md`
- Brand guide: `docs/SkyAware Branding and Design Guide.md`

## Cross-Issue Discoveries

Record facts that affect more than one issue here. Include the date, source issue, affected later issues, and the
decision made.

None yet.

## Issue Log Template

Copy this section for each completed or active issue.

### AN-01 / GitHub #217 - Enforce warning-first alert presentation

Status: Completed
Date: 2026-06-10
Model used: gpt-5.4-mini / high

#### Scope

- Added a shared `AlertPresentationOrdering` helper that orders warnings before watches before mesoscale discussions.
- Wired Summary local alerts and the Alerts screen to the same helper.
- Added focused unit tests for mixed warning/watch/discussion ordering and temporal tie-breakers.

#### Files Changed

- `Sources/Features/Alert/AlertPresentationOrdering.swift`
- `Sources/Features/Alert/AlertView.swift`
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `Tests/UnitTests/AlertPresentationOrderingTests.swift`
- `SkyAware.xcodeproj/project.pbxproj`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Ingestion, persistence, notification delivery, and refresh behavior were unchanged.
- Screen layout and row design were unchanged.
- Existing per-surface temporal ordering remained the tie-breaker within each class.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/AlertPresentationOrderingTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`

#### Deferred Work

- None for AN-01.

#### Handoff Notes

- The alert ordering helper is the only place that should encode class precedence going forward.
- New files under the synchronized `Tests` folder need target exception updates in `SkyAware.xcodeproj/project.pbxproj` or Xcode will compile them into the app target.
- Residual risk: warning classification currently keys off canonical NWS title strings, so any new warning label that does not include `warning` will fall back to the watch bucket.

### AN-02 / GitHub #218 - Preserve critical alert text for VoiceOver

Status: Completed
Date: 2026-06-10
Model used: gpt-5.4-mini / medium

#### Scope

- Removed the overriding `Instructions` and `Summary` accessibility labels from `AlertDetailView`.
- Added `accessibilityElement(children: .combine)` grouping to the alert detail sections that already expose visible heading + text pairs.
- Kept the visual presentation unchanged and left alert ingestion, ordering, persistence, notification, and refresh logic untouched.
- Expanded the UI test fixture text under `UI_TESTS_STATIC_HOME` so the regression test exercises representative long instruction and summary content.

#### Files Changed

- `Sources/Features/Alert/AlertDetailView.swift`
- `Sources/App/SkyAwareApp.swift`
- `Tests/UITests/SkyAwareUITests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Visible alert layout and weather copy in production screens remained unchanged.
- Alert ordering, ingestion, persistence, notification delivery, and refresh behavior were unchanged.
- The alert detail sections still read in logical order; only the accessibility wrappers changed.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath /private/tmp/SkyAwareDerivedData -clonedSourcePackagesDirPath /private/tmp/SkyAwareSPM -only-testing:SkyAwareUITests/testAlertDetailVoiceOverKeepsFullInstructionAndSummaryText test -resultBundlePath /tmp/SkyAware-AN02-3.xcresult`
- `xcrun xccov view --report /tmp/SkyAware-AN02-3.xcresult`

#### Deferred Work

- No follow-up was required for A11Y-1.
- Broader accessibility audit items remain in the epic backlog.

#### Handoff Notes

- The default `SkyAware` test plan excludes UI tests; use `SkyAware_All_Tests` when validating UI coverage like this one.
- The UI test now checks that the generic `Instructions` and `Summary` labels do not survive as accessibility replacements for the visible weather copy.
- Residual risk: this change improves the accessible reading path, but it does not replace a full manual VoiceOver walkthrough on device or simulator.

### AN-03 / GitHub #219 - Convert the location reliability rail to native buttons

Status: Completed
Date: 2026-06-10
Model used: gpt-5.4-mini / medium

#### Scope

- Replaced the parent tap gesture in `LocationReliabilitySummaryRailView` with a native primary `Button`.
- Kept `Not Now` as a separate sibling `Button` with its own accessibility identifier and hint.
- Preserved the existing rail styling, copy, state transitions, and same-day suppression behavior.
- Added focused UI coverage that verifies the two rail actions are independently exposed and that `Not Now` does not trigger the explanation sheet.

#### Files Changed

- `Sources/Features/Summary/LocationReliabilitySummaryRailView.swift`
- `Tests/UITests/SkyAwareUITests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- The rail still opens the location reliability explanation sheet from the primary action.
- `Not Now` still dismisses the rail for the day and suppresses repeat presentation.
- The surrounding Summary layout, copy, and business logic paths were unchanged.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath /private/tmp/SkyAwareDerivedData -resultBundlePath /private/tmp/SkyAware-AN03b.xcresult -only-testing:SkyAwareUITests/testSummaryReliabilityRailOpensExplanationSheetAndNotNowDismisses -only-testing:SkyAwareUITests/testSummaryReliabilityRailPrimaryAndDismissActionsAreIndependentButtons test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath /private/tmp/SkyAwareDerivedData build`
- XcodeBuildMCP simulator launch on iPhone 17 (iOS 26.5) with the reliability rail forced visible.
- XcodeBuildMCP runtime snapshot inspection confirmed separate `summary-reliability-rail` and `summary-reliability-not-now` buttons.
- XcodeBuildMCP runtime interaction confirmed the primary button opens the explanation sheet and `Not Now` dismisses it.
- XcodeBuildMCP screenshot review confirmed the rail still renders with the expected SkyAware styling.

#### Deferred Work

- Manual VoiceOver focus-order inspection was not available in this environment, so accessibility semantics were validated through runtime snapshot output and the UI tests instead.
- Exact hit-target dimensions were not mechanically measured here, but both buttons were given explicit minimum frames in code and verified visually in the simulator.

#### Handoff Notes

- Keep the primary rail action as a native button; do not reintroduce a parent gesture or nested interactive controls.
- The runtime snapshot now exposes the rail and `Not Now` as distinct accessibility buttons, which is the shape later accessibility work should preserve.
- Residual risk: the actual VoiceOver rotor order still deserves a manual device pass if someone wants absolute proof instead of a simulator/runtime snapshot proxy.

### AN-04 / GitHub #220 - Separate notification preference from authorization

Status: Completed
Date: 2026-06-10
Model used: gpt-5.4-mini / high

#### Scope

- Added a deterministic `NotificationPreferenceState` helper in `SettingsView.swift` to derive effective notification availability from stored preferences and `UNAuthorizationStatus`.
- Kept stored notification toggles intact when authorization is denied; Settings no longer mutates them back to `false`.
- Added a notification authorization status row plus explanatory copy in Settings, with an `Open Settings` recovery button for denied authorization.
- Added a test-only notification authorization override for UI tests so authorized, denied, and not-determined states can be inspected deterministically.
- Added focused unit coverage for denied, provisional, ephemeral, and not-determined states.
- Added focused UI coverage for denied, authorized, and not-determined Settings states, including the Open Settings handoff.

#### Files Changed

- `Sources/Features/Settings/SettingsView.swift`
- `Tests/UnitTests/RemoteNotificationRegistrarTests.swift`
- `Tests/UITests/SkyAwareUITests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`
- `docs/superpowers/plans/2026-06-10-notification-preference-authorization.md`

#### Behavior Preserved

- Notification delivery and preference synchronization flows were left intact.
- APNs registration, backend contracts, and unrelated preferences were unchanged.
- The existing Settings screen structure stayed in place; this did not attempt the broader AN-19 Form migration.
- Location reliability behavior and diagnostics surfaces were untouched.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/NotificationPreferenceStateTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareUITests/testSettingsShowsNotificationRecoveryCopyWhenAuthorizationDenied test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareUITests/testSettingsShowsNotificationAvailabilityCopyWhenAuthorizationAuthorized -only-testing:SkyAwareUITests/testSettingsShowsNotificationPendingCopyWhenAuthorizationNotDetermined test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`

#### Deferred Work

- AN-05 still owns removing raw diagnostics from production Settings.
- AN-19 still owns the broader native `Form`/`Section` Settings migration.
- A future OS adding a new `UNAuthorizationStatus` case will fall through `@unknown default` until the helper is updated.

#### Handoff Notes

- The notification preference helper is the only place that should encode availability semantics for Settings.
- The UI test override is intentionally test-only and does not alter production notification delivery behavior.
- Residual risk: `Open Settings` was verified in the simulator via the UI test, but the actual handoff path still merits a manual device pass if someone wants to validate Apple’s Settings app transition outside XCTest.

### AN-06 / GitHub #222 - Make launch and onboarding presentation state explicit

Status: Completed
Date: 2026-06-10
Model used: gpt-5.4 / medium

#### Scope

- Replaced the competing launch booleans in `SkyAwareApp` with a single item-driven `LaunchPresentationState` and `sheet(item:)` routing.
- Made launch priority explicit: a stale disclaimer always wins over the restricted-location sheet, and the restricted-location sheet is re-resolved after the disclaimer is accepted.
- Replaced onboarding page indexes with a typed `OnboardingStep` enum and switched the pager selection to that enum.
- Kept button actions authoritative for onboarding progression and disabled pager swiping so required steps cannot be bypassed.
- Added focused unit tests for launch presentation priority and onboarding step transitions.
- Added UI tests for launch-sheet ordering, launch-sheet independence, and swipe bypass prevention.

#### Files Changed

- `Sources/App/SkyAwareApp.swift`
- `Sources/Features/Onboarding/OnboardingView.swift`
- `Tests/UnitTests/LaunchAndOnboardingStateTests.swift`
- `Tests/UITests/SkyAwareUITests.swift`
- `SkyAware.xcodeproj/project.pbxproj`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Launch-sheet dismissal, onboarding completion, and location/notification permission request semantics were unchanged.
- The disclaimer and restricted-location sheets kept their current copy, navigation chrome, and interactive-dismiss lockout.
- Onboarding still follows the same visible sequence and uses the same underlying permission request calls.
- No visual redesign was introduced, and onboarding motion stayed as-is.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/LaunchAndOnboardingStateTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareUITests/testLaunchPresentsDisclaimerBeforeRestrictedLocationWhenBothApply -only-testing:SkyAwareUITests/testLaunchPresentsDisclaimerOnlyWhenDisclaimerIsStale -only-testing:SkyAwareUITests/testLaunchPresentsRestrictedLocationOnlyWhenDisclaimerIsCurrent -only-testing:SkyAwareUITests/testOnboardingSwipeCannotBypassRequiredSteps test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`

#### Deferred Work

- AN-07 still owns onboarding layout resilience for Dynamic Type and smaller devices.
- AN-08 still owns Reduce Motion-specific onboarding treatment.
- AN-09 still owns user-facing copy normalization.

#### Handoff Notes

- `LaunchPresentationState.resolve(...)` is now the single launch-routing helper; keep any future launch-sheet priority changes there.
- `OnboardingStep` is the only place that should encode step order. The pager should stay button-driven, not gesture-driven.
- The UI test coverage proves the current sequence cannot be bypassed by a swipe gesture in the simulator; if anyone changes the pager implementation later, that regression should be rechecked first.

### AN-07 / GitHub #223 - Make onboarding resilient to Dynamic Type

Status: Completed
Date: 2026-06-11
Model used: gpt-5.4-mini / high

#### Scope

- Added a shared `OnboardingStepShell` that gives each onboarding page a vertical `ScrollView` and a pinned bottom `safeAreaInset` action area.
- Added a targeted `OnboardingPagerSwipeBlocker` so the page-style `TabView` keeps its AN-06 swipe protection without disabling descendant vertical scrolling.
- Reserved extra bottom clearance in the shared shell so the footer buttons sit above the page indicator instead of crowding it at smaller text sizes.
- Reworked `WelcomeView`, `DisclaimerView`, `LocationPermissionView`, `OnboardingAlwaysUpgradeView`, and `NotificationPermissionView` to use the scrollable shell without changing step order, copy, or permission behavior.
- Replaced fixed decorative symbol sizes with `@ScaledMetric` so the onboarding glyphs scale with Dynamic Type instead of dominating the layout.
- Kept the primary and secondary actions as the same buttons, just moved into the safe-area footer so they remain reachable.
- Added representative default and AX5 previews for each onboarding step.

#### Files Changed

- `Sources/Features/Onboarding/OnboardingStepShell.swift`
- `Sources/Features/Onboarding/OnboardingPagerSwipeBlocker.swift`
- `Sources/Features/Onboarding/WelcomeView.swift`
- `Sources/Features/Onboarding/DisclaimerView.swift`
- `Sources/Features/Onboarding/LocationPermissionView.swift`
- `Sources/Features/Onboarding/OnboardingAlwaysUpgradeView.swift`
- `Sources/Features/Onboarding/NotificationPermissionView.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Onboarding step order and completion behavior were unchanged.
- The permission request flow and persistence behavior from AN-06 stayed intact.
- No copy was rewritten; AN-09 still owns vocabulary changes.
- Motion policy was not touched; AN-08 still owns Reduce Motion treatment.
- The welcome, disclaimer, and permission screens kept their existing tone and visual hierarchy at default sizes.
- The page-style onboarding container still blocks horizontal swipe navigation, but only by disabling the paging scroll view instead of the onboarding screens' own vertical `ScrollView`s.

#### Validation

- `mcp__xcodebuildmcp.build_run_sim` on iPhone 16e with `UI_TESTS_RESET_ONBOARDING=1` to inspect the default-size onboarding flow.
- `mcp__xcodebuildmcp.launch_app_sim` on iPhone 16e with `UI_TESTS_RESET_ONBOARDING=1`, `UI_TESTS_LOCATION_AUTH_MODE=authorized`, and `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` to inspect the AX5 flow.
- `mcp__xcodebuildmcp.build_run_sim` and screenshot inspection on iPhone 16e with `UICTContentSizeCategoryXS` to confirm the footer clears the page indicator at smaller text sizes.
- `mcp__xcodebuildmcp.snapshot_ui`, `touch`, and `swipe` across Welcome, Disclaimer, Location Access, More Reliable Alerts, and Stay Aware screens.
- `mcp__xcodebuildmcp.build_sim`
- `mcp__xcodebuildmcp.test_sim` with `-only-testing:SkyAwareTests/LaunchPresentationStateTests -only-testing:SkyAwareTests/OnboardingStepTests` (`8` passed, `0` failed)
- `mcp__xcodebuildmcp.test_sim` with `-testPlan SkyAware_All_Tests -only-testing:SkyAwareUITests/testOnboardingSwipeCannotBypassRequiredSteps`
- `mcp__xcodebuildmcp.test_sim` with `-testPlan SkyAware_All_Tests -only-testing:SkyAwareUITests/testOnboardingSwipeCannotBypassRequiredSteps` rerun after the final footer-clearance tweak

#### Deferred Work

- AN-08 still owns Reduce Motion-specific onboarding treatment.
- AN-09 still owns user-facing copy normalization.
- If onboarding copy grows again, the AX5 and small-device pass should be repeated to confirm the shell still provides enough headroom.

#### Handoff Notes

- `OnboardingStepShell` is the shared layout contract for onboarding pages now; future onboarding content should use it instead of reintroducing non-scrollable vertical stacks.
- The iPhone 16e AX5 pass kept the primary and secondary actions visible and operable, and the welcome screen still demonstrates actual vertical scrolling in the simulator; a genuinely smaller device or future copy expansion should still be rechecked.
- Residual risk: the current simulator evidence proves reachability and layout resilience on the tested device/class, but it is not a substitute for a final pass on any newly introduced onboarding copy.

### AN-08 / GitHub #224 - Apply Reduce Motion to onboarding and toasts

Status: Completed
Date: 2026-06-11
Model used: gpt-5.4-mini / medium

#### Scope

- Routed onboarding step changes through `SkyAwareMotion.onboardingStep(_:)` so `accessibilityReduceMotion` now controls whether the step change animates.
- Moved toast presentation and dismissal onto the shared `SkyAwareMotion` policy so the stack uses a calmer default animation and switches to opacity-only transitions under Reduce Motion.
- Kept toast queueing, dismissal timing, and onboarding progression logic intact.
- Added focused unit coverage for the onboarding motion policy and toast list mutation.
- Verified the onboarding flow in Simulator with Reduce Motion on and off.

#### Files Changed

- `Sources/Utilities/Core/SkyAwareMotion.swift`
- `Sources/Features/Onboarding/OnboardingView.swift`
- `Sources/Features/Loading/Toast/ToastManager.swift`
- `Sources/Features/Loading/Toast/ToastView.swift`
- `Tests/UnitTests/SkyAwareMotionTests.swift`
- `Tests/UnitTests/ToastManagerTests.swift`
- `SkyAware.xcodeproj/project.pbxproj`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Onboarding routing, step order, permission prompts, dismissal, and persistence were unchanged.
- Summary and map motion were left alone.
- Toast queueing, duration, priority, and business behavior were unchanged.
- Default motion remains subtle and still animates state changes without resorting to springy or bounce-heavy motion.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/SkyAwareMotionTests -only-testing:SkyAwareTests/LaunchAndOnboardingStateTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- XcodeBuildMCP simulator session on iPhone 17 Pro with `ReduceMotionEnabled` toggled on and off in the Simulator preferences.
- XcodeBuildMCP runtime snapshot walkthrough of onboarding progression with Reduce Motion on and off.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/SkyAwareMotionTests -only-testing:SkyAwareTests/ToastManagerTests -only-testing:SkyAwareTests/LaunchAndOnboardingStateTests test`

#### Deferred Work

- Toast visuals were verified at the state and transition-policy level, but not via a live toast trigger sequence in Simulator.
- AN-09 still owns user-facing copy normalization.

#### Handoff Notes

- `SkyAwareMotion` is now the shared place for onboarding and toast motion policy; future accessibility-aware animation changes should start there.
- The onboarding flow still needs manual simulator inspection only if a later change reintroduces movement-based transitions.
- Residual risk: this work confirms the reduced-motion paths and default policy, but it does not replace a full visual review of live toast presentation timing in every state.

### AN-09 / GitHub #225 - Replace implementation language in user-facing copy

Status: Completed
Date: 2026-06-11
Model used: gpt-5.4-mini / medium

#### Scope

- Renamed Settings toggles and helper copy to the canonical SkyAware vocabulary: `Mesoscale Discussion Alerts`,
  `Local Severe-Weather Alerts`, and `Share Approximate Location for Alerts`.
- Reworded Settings location-sharing and alert helper text to describe user intent instead of server or Signal
  plumbing.
- Reworded Outlooks copy so the latest card uses `SPC discussion` provenance and the loading/empty-state message now
  says outlooks will appear once they are ready.
- Replaced onboarding progress strings that described registration mechanics with calm progress copy such as
  `Getting alerts ready…` and `Adding your approximate location for alerts…`.
- Updated the onboarding alert permission bullet copy to say `mesoscale discussion alerts`.
- Added focused copy assertions for the new Settings labels and the Outlooks overview helper.

#### Files Changed

- `Sources/Features/Settings/SettingsView.swift`
- `Sources/Features/ConvectiveOutlookView/ConvectiveOutlookView.swift`
- `Sources/Features/Onboarding/OnboardingView.swift`
- `Sources/Features/Onboarding/LocationPermissionView.swift`
- `Sources/Features/Onboarding/NotificationPermissionView.swift`
- `Sources/Features/Onboarding/OnboardingAlwaysUpgradeView.swift`
- `Tests/UITests/SkyAwareUITests.swift`
- `Tests/UnitTests/ConvectiveOutlookRepoTests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Navigation, onboarding sequencing, permission prompts, notification behavior, and loading timing were unchanged.
- Provider attribution was kept where it helps the user understand what they are seeing.
- No native Settings or Outlooks restructuring was introduced.
- No new promises about delivery, coverage, or protection were added.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/ConvectiveOutlookViewCopyTests -only-testing:SkyAwareTests/NotificationPreferenceStateTests -only-testing:SkyAwareUITests/testSettingsShowsNotificationRecoveryCopyWhenAuthorizationDenied -only-testing:SkyAwareUITests/testFirstLaunchOnboardingCompletesSuccessfully -only-testing:SkyAwareUITests/testOnboardingWhileUsingShowsAlwaysUpgradePageAndAllowsNotNow test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- `xcrun xccov view --report /Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.06.11_11-11-15--0600.xcresult`
- Repository search for deprecated user-facing phrases after the edit.

#### Deferred Work

- AN-19 still owns the broader native Settings structure migration.
- AN-21 still owns the broader native Outlooks structure migration.

#### Handoff Notes

- `ConvectiveOutlookView.overviewMessage(for:)` is now the copy seam for the Outlooks loading/empty-state helper text.
- Settings terminology is now aligned with the approved SkyAware vocabulary, so later structure work should keep these
  labels intact.
- Onboarding progress copy should stay calm and progressive; do not reintroduce registration or subsystem language in
  the same flow.

### AN-10 / GitHub #226 - Preserve optional Outlook metadata truthfully

Status: Completed
Date: 2026-06-11
Model used: gpt-5.4-mini / medium

#### Scope

- Added a small `ConvectiveOutlookDetailPresentation` helper so the detail surface derives header/title metadata from
  the DTO without inventing fallback day values.
- Preserved day metadata only when the DTO supplies it or the existing verified `Day 1/2/3` title rule can derive it.
- Kept publication time distinct from validity time by making `SpcProductHeader` and `SpcProductFooter` respect
  optional `validUntil` values instead of reusing publication time.
- Kept the existing detail screen structure, row structure, and provider attribution intact.
- Added focused unit coverage for the four required metadata combinations plus a preview for the partial-metadata
  case.

#### Files Changed

- `Sources/Features/ConvectiveOutlookView/ConvectiveOutlookDetailView.swift`
- `Sources/Utilities/Core/SpcProductFooter.swift`
- `Sources/Utilities/Core/SpcProductHeader.swift`
- `Tests/UnitTests/ConvectiveOutlookRepoTests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Outlook ingestion, decoding, persistence, refresh, and provider behavior were unchanged.
- The Outlook list structure and navigation stay the same; AN-21 still owns the native list/section migration.
- Canonical copy and provider attribution from AN-09 were preserved.
- Existing known day and valid-until values still format and display normally.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/ConvectiveOutlookDetailPresentationTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- `mcp__xcodebuildmcp.build_run_sim` on iPhone 17 with `UI_TESTS_STATIC_HOME=1`
- `mcp__xcodebuildmcp.screenshot` of the launched simulator after the static-home boot

#### Deferred Work

- AN-21 still owns the broader native Outlooks structure migration.
- Manual Xcode preview-canvas inspection of the added partial-metadata preview was not available in this environment,
  so the preview change was validated by compilation and the focused unit tests instead.

#### Handoff Notes

- `ConvectiveOutlookDetailPresentation` is the narrow seam for future Outlook detail metadata rules.
- `SpcProductHeader` and `SpcProductFooter` now treat validity as optional, so future Outlook work should not
  reintroduce a publication-time fallback.
- If a future Outlook title format expands beyond `Day 1/2/3`, update the derived-day helper deliberately rather than
  falling back to an assumed day.

### AN-11 / GitHub #227 - Use proportional typography for weather narratives

Status: Completed
Date: 2026-06-11
Model used: gpt-5.4-mini / medium

#### Scope

- Switched alert detail narrative sections from monospaced body text to proportional Dynamic Type text while preserving monospaced digits where they appear in compact technical values.
- Switched Mesoscale Discussion full-discussion copy to proportional text and kept digits monospaced where they appear in compact technical values.
- Switched Convective Outlook summary and full-discussion copy to proportional text and kept digits monospaced where they appear in compact technical values.
- Added representative AX5 previews for the affected detail surfaces.

#### Files Changed

- `Sources/Features/Alert/AlertDetailView.swift`
- `Sources/Features/MesoscaleDiscussion/MesoscaleDiscussionCard.swift`
- `Sources/Features/ConvectiveOutlookView/ConvectiveOutlookDetailView.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Official weather text content was left verbatim.
- Ingestion, parsing, persistence, refresh behavior, and presentation semantics were unchanged.
- Screen structure and hierarchy were unchanged.
- VoiceOver reading order and visible text content were not intentionally altered.
- Monospaced treatment remains in place for compact technical values, numeric measurements, and identifier-like text.

#### Validation

- Reviewed the diff for the three feature views and confirmed only typography modifiers and previews changed.
- Confirmed the official weather strings in the affected source files were not rewritten, normalized, or truncated.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath /private/tmp/SkyAwareDerivedData -only-testing:SkyAwareTests/ConvectiveOutlookRepoTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath /private/tmp/SkyAwareDerivedData -only-testing:SkyAwareUITests/testAlertDetailVoiceOverKeepsFullInstructionAndSummaryText test`
- Captured a simulator screenshot of the current Home screen after the UI-test run and confirmed the app remained stable at the root surface.

#### Deferred Work

- I did not complete a direct simulator screenshot of the alert, mesoscale discussion, or outlook detail screens in this session because the current UI-test harness does not expose a deterministic launch hook for those detail states.
- AN-21 still owns native Outlook list structure work; this issue only changes the narrative typography inside the existing detail surface.

#### Handoff Notes

- Keep narrative typography proportional in these surfaces; do not reintroduce `monospaced()` on full prose blocks.
- Preserve monospaced digits only where the text is acting like a compact technical value, not as a formatting crutch for paragraphs.
- The AX5 preview additions give future agents a concrete place to check wrapping behavior without touching production data flow.

### AN-12 / GitHub #228 - Preserve cached Summary content while offline

Status: Completed
Date: 2026-06-11
Model used: gpt-5.4 / medium

#### Scope

- Added a small shared `SummaryContentPresentationState` helper to distinguish current, stale, resolving, unavailable, and confirmed-empty presentation.
- Updated Storm Risk and Severe Risk badges to keep cached values visible offline and layer a compact offline badge instead of swapping in generic offline cards.
- Updated Fire Risk to keep the cached rail visible offline when data exists, and to fall back to an explicit unavailable card only when there is no cached value to show.
- Updated Atmospheric Conditions to keep the cached rail visible offline with a calm saved-data line, while still falling back to an unavailable card when no weather is cached.
- Updated Local Alerts to keep the existing content states visible offline and add a quiet offline status line instead of replacing the summary with a generic offline card.
- Added focused unit coverage for the presentation-state matrix.

#### Files Changed

- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Badges/StormRiskBadgeView.swift`
- `Sources/Features/Badges/SevereWeatherBadgeView.swift`
- `Sources/Features/Badges/FireWeatherRailView.swift`
- `Sources/Features/Badges/AtmosphereRailView.swift`
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Provider behavior, refresh orchestration, refresh timing, persistence, cache invalidation, and loading timing were unchanged.
- Cached-first, resolve-forward behavior stayed intact; this issue only changed presentation when connectivity drops.
- Custom risk badges, rails, and Summary containers were preserved.
- No spinner-first fallback was introduced.
- No new freshness thresholds were invented; offline connectivity is the only stale signal used here because the Summary models do not currently expose per-surface freshness metadata.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/HomeViewLoadingOverlayStateTests test`
- `xcrun xccov view --report /Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.06.11_11-58-33--0600.xcresult`

#### Deferred Work

- AN-13 still owns the Summary hero category-label and large Dynamic Type pass.
- AN-15 still owns the semantic color cleanup for metadata and offline state.
- I did not run the requested simulator/preview/manual VoiceOver matrix in this session.

#### Handoff Notes

- `SummaryContentPresentationState` is the narrow helper that should carry future presentation-state decisions for cached-versus-unavailable behavior.
- Offline content should stay content-first; the correct pattern is to layer a quiet status cue, not to swap the card out for a generic offline placeholder.
- If future work adds explicit freshness metadata to the Summary model, that should feed this helper rather than bypass it.
