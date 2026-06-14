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
| 13 | AN-13 | [#229](https://github.com/justinrooks/project-arcus/issues/229) | Restore Summary hero category identity at large text sizes | Completed | Persistent category labels now stay visible on the resolved hero tiles, and the tiles can grow vertically instead of clipping longer values. |
| 14 | AN-14 | [#230](https://github.com/justinrooks/project-arcus/issues/230) | Define explicit semantics for custom controls | Completed | Summary hero controls, map selections, and legend rows now expose explicit label/value/hint/traits contracts without changing visuals or domain meaning. |
| 15 | AN-15 | [#231](https://github.com/justinrooks/project-arcus/issues/231) | Restore semantic color discipline | Not started | |
| 16 | AN-16 | [#232](https://github.com/justinrooks/project-arcus/issues/232) | Make static chips noninteractive and modernize haptics | Completed | Static status and metadata chips now use the noninteractive chip treatment, and map layer selection now routes feedback through SwiftUI `sensoryFeedback` on actual selection changes. |
| 17 | AN-17 | [#233](https://github.com/justinrooks/project-arcus/issues/233) | Make Liquid Glass opt-in | Completed | Glass is now opt-in on shared card backgrounds; ordinary content surfaces fall back to stable cards by default. |
| 18 | AN-18 | [#234](https://github.com/justinrooks/project-arcus/issues/234) | Reduce nested Summary surface chrome | Completed | Removed the outer Risk Snapshot surface so Current Conditions stays distinct while the hero tiles, rails, and supporting cards keep their own domain chrome. |
| 19 | AN-19 | [#235](https://github.com/justinrooks/project-arcus/issues/235) | Move Settings to native Form structure | Not started | |
| 20 | AN-20 | [#236](https://github.com/justinrooks/project-arcus/issues/236) | Native-align the Alerts list structure | Not started | |
| 21 | AN-21 | [#237](https://github.com/justinrooks/project-arcus/issues/237) | Native-align the Outlooks list structure | Not started | |
| 22 | AN-22 | [#238](https://github.com/justinrooks/project-arcus/issues/238) | Distinguish map unavailable, stale, and confirmed-empty states | Completed | Map scenes now carry explicit loading, resolving, current, confirmed-empty, stale, and unavailable presentation states so failed refreshes do not collapse to confirmed no-risk language. |
| 23 | AN-23 | [#239](https://github.com/justinrooks/project-arcus/issues/239) | Build the warning legend from rendered warnings | Completed | Legend rows now derive from the rendered warning overlays, dedupe by displayed warning type, and keep the warning-state legend truthful when overlay visibility or stale map state changes. |
| 24 | AN-24 | [#240](https://github.com/justinrooks/project-arcus/issues/240) | Replace the map layer sheet with a native current-state menu | Completed | Native `Menu` trigger now shows the current layer and semantic symbol, keeps warning overlays in a separate menu section, and preserves the existing selection / haptic / availability paths. |
| 25 | AN-25 | [#241](https://github.com/justinrooks/project-arcus/issues/241) | Add accessible equivalents for map overlays | Completed | Added a single accessible map summary derived from `MapLayerScene`, kept the warning toggle reachable at large text sizes, and added Differentiate Without Color overlay/legend distinctions without changing map geometry or warning-legend truthfulness. |
| 26 | AN-26 | [#242](https://github.com/justinrooks/project-arcus/issues/242) | Reduce map control and legend crowding | Completed | Legend controls now stack, compact, or collapse before they crowd the map, interactive map controls meet the 44-point target, and remaining sheets use native cancellation actions. |
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

- 2026-06-12, AN-17: `cardBackground` now defaults to stable content surfaces, with explicit `allowsGlass: true` opt-in retained for future hierarchy-bearing cards. Remaining glass usage lives in `skyAwareSurface`, `skyAwareChip`, and `.glass` button styles for navigation chrome and floating interactive controls.

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

### AN-13 / GitHub #229 - Restore Summary hero category identity at large text sizes

Status: Completed
Date: 2026-06-11
Model used: gpt-5.4 / medium

#### Scope

- Added persistent `Storm Risk` and `Severe Risk` header labels inside the resolved hero tiles, using a widget-like header/body hierarchy instead of an overlay that could sit behind the hero art.
- Let the hero tiles grow vertically instead of enforcing the previous square-ish cap, so longer values can wrap.
- Relaxed the resolved badge text so the value and supporting summary can wrap instead of shrinking or clipping.
- Reused the existing `SkyAwareAdaptiveLayout` accessibility threshold so the hero tiles follow the same stacked-hero policy as the Summary surface.
- Kept the hero tile size and semantic color treatment intact while making the layout feel closer to the small widgets.
- Updated representative badge previews to show default and accessibility-sized variants for both hero tiles.

#### Files Changed

- `Sources/Features/Badges/StormRiskBadgeView.swift`
- `Sources/Features/Badges/SevereWeatherBadgeView.swift`
- `Sources/Utilities/Extensions/ext+View.swift`
- `tasks/lessons.md`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Risk calculation, mapping, wording, and hazard semantics were unchanged.
- Navigation and tap destinations were unchanged.
- Cached/offline presentation behavior from AN-12 stayed intact.
- Resolved, resolving, cached, offline, unavailable, and confirmed-empty states still render through the same presentation-state path.
- Existing semantic risk colors and button interactions were preserved.
- The hero badge size was preserved; only the internal hierarchy and label placement changed.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath /private/tmp/SkyAwareDerivedData-AN13 build`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath /private/tmp/SkyAwareDerivedData-AN13 -only-testing:SkyAwareTests/SkyAwareAdaptiveLayoutTests test`
- XcodeBuildMCP `build_run_sim` on iPhone 17 with the app launched successfully.
- Simulator screenshot review at the default content-size override confirmed the resolved hero tiles now show `Storm Risk` and `Severe Risk` in the upper-left header area, above the icon and value content.
- Simulator screenshot review at `UICTContentSizeCategoryM` confirmed the same header placement at a normal content size.
- Simulator screenshot review at accessibility size confirmed the labels remain visible and do not sit behind the hero artwork.
- Simulator screenshot review confirmed the severe tile still expands to show `No Active Threats` without truncation in the compact layout.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iPhone Simulator,name=iPhone 17" -derivedDataPath /private/tmp/SkyAwareDerivedData-AN13 -only-testing:SkyAwareTests/SkyAwareAdaptiveLayoutTests test`

#### Deferred Work

- AN-14 still owns the accessibility semantics pass for hero buttons and legend rows.
- AN-18 still owns the broader Summary surface-chrome reduction.
- If future design feedback asks for further widget parity, that should be handled as a follow-on styling pass rather than broadening this fix into a new layout system.

#### Handoff Notes

- Keep the hero tiles custom; the fix here was about hierarchy and sizing, not replacing them with generic rows or cards.
- If later work changes hero chrome again, preserve the persistent category labels, the widget-like header/body split, and the vertical-growth behavior introduced here.
- The badge sizing helper now has a flexible branch; use it only for the Summary hero tiles unless another custom tile has the same accessibility problem.
- AN-14 should continue from the current header/body hierarchy, not from the old overlay-label implementation.
- AN-18 can still trim surface chrome later, but it should not undo the hero badge hierarchy established here.

### AN-14 / GitHub #230 - Define explicit semantics for custom controls

Status: Completed
Date: 2026-06-14
Model used: gpt-5.4 / medium

#### Scope

- Added explicit accessibility contracts for the Summary hero controls in `PrimaryAwarenessPanel.swift` so the visible category, current value, and action hint stay separate instead of collapsing into one inferred label.
- Kept the hero presentation unchanged while routing the accessible contract through the same visible state data used by the panel.
- Switched selected map-layer choices to native selected traits in `Picker.swift` instead of appending `selected` to labels.
- Added explicit semantic descriptions for legend rows in `MapLegendView.swift` so the layer or warning type and the displayed level or probability are exposed as label/value pairs.
- Preserved static legend content as static content; the rows are not exposed as buttons.

#### Files Changed

- `Sources/Features/Summary/PrimaryAwarenessPanel.swift`
- `Sources/Features/Map/Picker.swift`
- `Sources/Features/Map/MapLegendView.swift`
- `Tests/UnitTests/SummaryAwarenessPanelTests.swift`
- `Tests/UnitTests/LayerPickerAdaptiveLayoutTests.swift`
- `Tests/UnitTests/MapLegendAccessibilityTests.swift`
- `Tests/UITests/SkyAwareUITests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Summary hero visuals, hierarchy, category identity, and Dynamic Type behavior stayed intact.
- Risk calculation, map state, selection ownership, persistence, warning derivation, geometry, and navigation were unchanged.
- AN-03 reliability-rail actions stayed separate and untouched.
- AN-13 visible category labels remained the source of truth for the resolved hero layout.
- The map legend stayed domain-specific; no generic row replacement was introduced.
- Useful child content remains available unless a control is deliberately grouped for a clearer semantic result.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,OS=26.5,name=iPhone 17" build`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,OS=26.5,name=iPhone 17" -only-testing:SkyAwareTests/SummaryAwarenessPanelTests -only-testing:SkyAwareTests/LayerPickerAdaptiveLayoutTests -only-testing:SkyAwareTests/MapLegendAccessibilityTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,OS=26.5,name=iPhone 17" -only-testing:SkyAwareUITests/testMapLayerPickerCyclesThroughEveryLayerAndIgnoresDuplicateSelection -only-testing:SkyAwareUITests/testMapLayerMenuKeepsWarningToggleReachableAndFunctional -only-testing:SkyAwareUITests/testMapLayerMenuRemainsReachableAtAccessibilityTextSizes test`

#### Deferred Work

- A literal spoken VoiceOver pass in the simulator was not completed in this change.
- AN-28 still owns the full acceptance matrix across portrait, landscape, text-size, contrast, and VoiceOver permutations.
- The badge views are effectively legacy now; future cleanup should remove them only after later consumers stop referencing them.

#### Handoff Notes

- The contract now lives in presentation helpers, not scattered label literals, so future accessibility tweaks should reuse the same helpers instead of re-synthesizing strings at the call site.
- Keep map selection semantics on `.isSelected`; do not reintroduce manual `selected` suffixes in labels.
- Preserve visible category identity and Dynamic Type behavior from AN-13 while iterating on hero accessibility.
- AN-28 should verify the whole map and Summary acceptance matrix, including portrait and landscape VoiceOver order, because this change narrows semantics but intentionally does not widen layout coverage.

### AN-15 / GitHub #231 - Restore semantic color discipline

Status: Completed
Date: 2026-06-11
Model used: gpt-5.4 / medium

#### Scope

- Replaced the watch detail metadata chip tint ladder with a neutral semantic metadata tint so severity, certainty, and urgency no longer borrow tornado, wind, hail, or storm-risk colors.
- Recolored the Summary offline token to a neutral semantic surface tint instead of fire-weather orange.
- Switched Settings and Settings diagnostics section headings from decorative orange to primary text styling.
- Added a focused unit regression test that proves all watch chip kinds resolve to the same neutral metadata tint.
- Added representative previews for the metadata chips in light and dark mode.

#### Files Changed

- `Sources/Utilities/Extensions/ext+Color.swift`
- `Sources/Features/Alert/WatchStatusChip.swift`
- `Sources/Features/Summary/SummaryStatus.swift`
- `Sources/Features/Settings/SettingsView.swift`
- `Sources/Features/Settings/SettingsDiagnosticsView.swift`
- `Tests/UnitTests/AlertStylingTests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Actual hazard and risk color ladders stayed intact on the Summary hero tiles, alert rows, alert detail surfaces, map overlays, and other hazard-specific surfaces.
- Alert classification, severity mapping, risk calculation, persistence, and notification semantics were unchanged.
- The summary offline/freshness copy still communicates state without relying on color alone.
- Settings structure and navigation stayed unchanged; this only corrected heading color semantics.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/AlertStylingTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- XcodeBuildMCP `build_run_sim` on iPhone 17 with `UI_TESTS_STATIC_HOME=1` and `UI_TESTS_NOTIFICATION_AUTH_MODE=authorized`
- XcodeBuildMCP runtime snapshot and screenshot review of the Summary screen in light and dark appearance
- XcodeBuildMCP runtime snapshot and screenshot review of watch detail under Increased Contrast and an accessibility text size
- XcodeBuildMCP runtime snapshot and screenshot review of Settings in light and dark appearance

#### Deferred Work

- AN-17 still owns the broader Liquid Glass opt-in policy.
- AN-19 still owns the Settings structural migration.
- `Differentiate Without Color` could not be toggled directly in this simulator workflow because `simctl ui` exposes appearance, increase contrast, and content size controls but not that accessibility option; the neutral chip labels and icons are still the fallback semantic path.

#### Handoff Notes

- Keep hazard colors reserved for actual weather meaning. The only shared neutral palette introduced here is the metadata/offline tint in `ext+Color.swift`.
- The new watch-chip regression test should remain the guardrail if future metadata chips drift back toward weather-danger colors.
- Residual risk: the neutral chip tint is visually conservative by design, so if future copy makes the chips denser, they may need a small contrast tweak rather than a new color family.

### AN-16 / GitHub #232 - Make static chips noninteractive and modernize haptics

Status: Completed
Date: 2026-06-12
Model used: gpt-5.4 / medium

#### Scope

- Removed the interactive glass request from the watch-status chips in `WatchStatusChip.swift`.
- Removed the interactive glass request from the convective outlook metadata chips in `ConvectiveOutlookDetailView.swift`.
- Replaced the scoped UIKit impact generator in the map layer picker with SwiftUI `.sensoryFeedback(.selection, trigger: selection)`.
- Added a small selection-change guard so tapping the already-selected map layer dismisses the sheet without mutating selection or creating duplicate feedback.
- Added a focused unit test for the selection-change helper and a UI test that cycles every map layer while checking duplicate selection behavior.

#### Files Changed

- `Sources/Features/Alert/WatchStatusChip.swift`
- `Sources/Features/ConvectiveOutlookView/ConvectiveOutlookDetailView.swift`
- `Sources/Features/Map/Picker.swift`
- `Tests/UnitTests/LayerPickerAdaptiveLayoutTests.swift`
- `Tests/UITests/SkyAwareUITests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Chip copy, status meaning, hazard semantics, iconography, and semantic colors were unchanged.
- The watch-status and outlook metadata chip shapes, hierarchy, and domain identity were preserved.
- Map layer choices, map rendering, selection ownership, and navigation behavior stayed intact.
- Reduce Motion handling stayed delegated to the existing motion helpers.
- The AN-17 glass policy stayed intact; this change only removed interactive treatment from the scoped static chips.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iPhone Simulator,name=iPhone 17" -only-testing:SkyAwareTests/LayerPickerAdaptiveLayoutTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,id=EA7220E9-B3E8-401C-8E77-8967CA051A05" -only-testing:SkyAwareUITests/testMapLayerPickerCyclesThroughEveryLayerAndIgnoresDuplicateSelection test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,id=D074401E-6727-42D8-AF91-1DF0250EACDE" -only-testing:SkyAwareUITests/testSummaryAlertTapShowsSheetAndAlertTabTapShowsWatchDetailView -only-testing:SkyAwareUITests/testOutlookDetailOpensFromTheLatestOutlookRow test`
- XcodeBuildMCP runtime snapshot review of the seeded Summary screen in the light appearance
- XcodeBuildMCP screenshot review of the seeded watch detail path, Outlook detail screen, and map layer picker in the light appearance
- XcodeBuildMCP runtime snapshot review of the seeded map layer picker sequence, including the selected-state path

#### Deferred Work

- AN-24 replaced the map layer sheet with a native current-state menu.
- Dark-appearance visual verification was not achievable in this simulator workflow; the visible screenshots captured here are light appearance only.
- Direct haptic verification still depends on the runtime feedback path; this pass confirmed the code path and selection gating, not the physical vibration itself.

#### Handoff Notes

- Keep the static chips noninteractive; do not reintroduce `interactive: true` just to get glass to look fancier.
- The map picker now has a single selection-change gate, and AN-24 keeps that same `selection` binding while changing the presentation chrome.
- AN-24 now routes the control through a native menu, so `.sensoryFeedback` remains tied to real layer changes without reintroducing a modal chooser.
- Residual risk: the current manual validation proved the light appearance only, so a future dark-mode pass should still confirm the chip chrome remains noninteractive there.

### AN-17 / GitHub #233 - Make Liquid Glass opt-in

Status: Completed
Date: 2026-06-12
Model used: gpt-5.4 / medium

#### Scope

- Changed the shared `cardBackground` helper so stable content surfaces are the default on iOS 26+ instead of glass.
- Kept glass available as an explicit opt-in via `allowsGlass: true` and added `glassCardBackground(...)` for future call sites that genuinely need hierarchy-bearing glass.
- Removed redundant `allowsGlass: false` arguments from ordinary content cards, risk tiles, Summary sections, alert detail content, Outlook detail content, and the reliability explanation sheet.
- Left the floating map controls, map-layer trigger, and other intentional glass chrome in their existing `skyAwareSurface` / glass button paths.

#### Files Changed

- `Sources/Utilities/Extensions/ext+View.swift`
- `Sources/Features/Badges/FireWeatherRailView.swift`
- `Sources/Features/Badges/SevereWeatherBadgeView.swift`
- `Sources/Features/Badges/StormRiskBadgeView.swift`
- `Sources/Features/ConvectiveOutlookView/ConvectiveOutlookDetailView.swift`
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `Sources/Features/Summary/LocationReliabilitySummaryExplanationSheet.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Content hierarchy, navigation, data flow, and business logic were unchanged.
- Pre-iOS-26 behavior stayed on the existing opaque card fallback.
- Semantic risk and hazard surfaces kept their established colors, shapes, and readability.
- Floating map controls and navigation chrome kept their intentional glass treatment.
- Existing continuous corner language and the soft surface language remained intact.
- No new gradients, decorative blur, extra borders, or heavier shadows were introduced.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build` via `build_run_sim`
- XcodeBuildMCP runtime snapshot review of Summary in dark appearance
- XcodeBuildMCP screenshot review of Summary in dark appearance
- XcodeBuildMCP runtime snapshot and screenshot review of Alerts, Outlooks, Settings, alert detail, and Map in dark appearance
- `xcrun simctl ui F3BDA3CC-F088-40E2-8F34-825CA52C166F appearance light`
- XcodeBuildMCP runtime snapshot and screenshot review of Summary in light appearance
- XcodeBuildMCP runtime snapshot and screenshot review of Map in light appearance
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iPhone Simulator,name=iPhone 17" -only-testing:SkyAwareUITests/testTabNavigationLoadsEachPrimaryView -only-testing:SkyAwareUITests/testSummaryAlertTapShowsSheetAndAlertTabTapShowsWatchDetailView test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iPhone Simulator,name=iPhone 17" -only-testing:SkyAwareTests/SkyAwareAdaptiveLayoutTests test`

#### Deferred Work

- AN-19 still owns the native Settings structure migration.
- AN-20 still owns the native Alerts list structure.
- AN-21 still owns the native Outlooks list structure.
- Any future card that genuinely needs glass should use the explicit `allowsGlass: true` opt-in or the new `glassCardBackground(...)` helper rather than relying on a shared default.

#### Handoff Notes

- The shared policy is now content-first. If a surface does not need hierarchy or interaction, it should not ask for glass.
- Keep using `skyAwareSurface` and `.glass` button styles for navigation chrome and floating interactive controls; those are intentionally separate from content cards.
- AN-19 through AN-21 should inherit the stable card default rather than reintroducing glass as a visual crutch while moving to native structure.
- Residual risk: the XcodeBuildMCP test result summary did not report per-test counts even when the invoked smoke tests completed successfully, so future validation should still inspect the bundle or run additional targeted checks if exact per-test accounting matters.

### AN-18 / GitHub #234 - Reduce nested Summary surface chrome

Status: Completed
Date: 2026-06-12
Model used: gpt-5.4 / medium

#### Scope

- Removed the outer Risk Snapshot card wrapper from `SummaryView`, leaving the hero tiles, fire rail, and supporting rows as the visible hierarchy.
- Kept `Current Conditions` as the anchored top Summary card so the weather identity still has one clear entry point.
- Preserved the custom Summary content surfaces, including Storm Risk, Severe Risk, Fire Risk, Atmospheric Conditions, the local alerts card, and the outlook card.
- Preserved the cached-first and resolve-forward presentation paths from AN-12, the hero category hierarchy from AN-13, and the semantic color discipline from AN-15.

#### Files Changed

- `Sources/Features/Summary/SummaryView.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Summary section order, navigation, interactions, refresh behavior, loading behavior, persistence, and weather semantics were unchanged.
- The existing summary cards, rails, and hero tiles kept their identity and their existing state handling.
- The AN-17 opt-in glass policy stayed intact; this change only removed a redundant outer card wrapper instead of broadening shared surface material behavior.
- Cached, resolving, offline, unavailable, and confirmed-empty states still route through the same presentation-state logic.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/HomeViewLoadingOverlayStateTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`

#### Deferred Work

- AN-19 still owns the native Settings structure migration.
- AN-20 still owns the native Alerts list structure.
- AN-21 still owns the native Outlooks list structure.
- AN-27 still owns the final spacing-scale polish pass once the remaining native-structure issues land.

#### Handoff Notes

- Keep `Current Conditions` as the only top-level Summary card; any future Summary hierarchy work should trim within the remaining content stack rather than adding another wrapper around the risk snapshot.
- The risk tiles and rails should continue to own their own identity through typography, spacing, and semantic color instead of extra chrome.
- AN-27 should treat this as the baseline: hierarchy first, spacing second, and no new decorative surface layers.

### AN-22 / GitHub #238 - Distinguish map unavailable, stale, and confirmed-empty states

Status: Completed
Date: 2026-06-12
Model used: gpt-5 / medium

#### Scope

- Added explicit map presentation states for loading, resolving, current, confirmed-empty, stale, and unavailable layers.
- Carried availability metadata through `MapFeatureModel`, layer scenes, legend state, and map rendering plans instead of flattening failures into empty arrays.
- Preserved successful empty responses as confirmed-empty while keeping failed refreshes from rendering as confirmed no-risk.
- Preserved previously rendered saved data when refreshes fail and marked those layers as stale instead of discarding the overlays.
- Updated legend text and accessibility labels so VoiceOver can distinguish loading, resolving, stale, unavailable, and confirmed-empty states without relying on color alone.
- Added focused unit coverage for loading, success, confirmed-empty, failure, stale saved data, layer switching, and refresh transitions.

#### Files Changed

- `Sources/Features/Map/MapFeatureModel.swift`
- `Sources/Features/Map/MapLegendView.swift`
- `Sources/Features/Map/MapScreenView.swift`
- `Tests/UnitTests/MapFeatureModelTests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- SPC/NWS ingestion, acceptance rules, persistence, retry policy, and refresh timing were unchanged.
- Existing polygon geometry, hatching, map styling, and layer selection behavior were left intact.
- Successful populated responses still render as current and successful empty responses still render calm no-risk language.
- Saved overlays remain visible after failed refreshes; the new state only changes how availability is described.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/MapFeatureModelTests`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`

#### Deferred Work

- AN-23 still owns the warning legend source-of-truth cleanup.
- AN-24 replaced the layer sheet with a native current-state menu.
- AN-25 still owns accessible overlay equivalents; this issue only adds the state text and accessibility cues for the map scene itself.
- Broader map control and legend spacing cleanup was completed in AN-26.

#### Handoff Notes

- The root rule is now: only a successful empty response may produce `No … risk`; a failed request must go through unavailable or stale state.
- Keep future map legend work keyed off the scene presentation state, not off empty arrays alone.
- Preserve saved overlays on refresh failure. The map should surface stale/saved data quietly rather than erase it.
- AN-23 should build on the new presentation state model when deriving warning legend content from rendered warnings.
- AN-24 kept the current layer-selection state machine intact and only changed the control surface.
- AN-25 should use the same availability metadata for accessible overlay equivalents instead of inventing new state.

### AN-23 / GitHub #239 - Build the warning legend from rendered warnings

Status: Completed
Date: 2026-06-12
Model used: gpt-5 / medium

#### Scope

- Replaced the static warning legend rows with legend items derived from the warning overlays currently rendered in the map scene.
- Added a small deterministic derivation helper that normalizes supported warning kinds, deduplicates repeated displayed types, and keeps a stable urgency-aware order.
- Preserved the existing warning overlay colors and fallback renderer style for unsupported warning events while keeping unknown events explicit instead of inventing a new category.
- Kept the warning legend hidden when warning geometry is disabled or when the scene contains no rendered warnings.
- Added focused unit coverage for overlay-disabled, empty, single-type, duplicate-type, mixed-type, unknown-event, and stale-refresh warning legend states.

#### Files Changed

- `Sources/Utilities/Core/AlertStyling.swift`
- `Sources/Features/Map/MapLegendView.swift`
- `Sources/Features/Map/MapScreenView.swift`
- `Tests/UnitTests/MapFeatureModelTests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Warning ingestion, filtering, persistence, expiration, geospatial matching, and refresh behavior were unchanged.
- Warning geometry colors, overlay composition, and overlay visibility behavior were preserved.
- AN-22 availability, freshness, stale, and confirmed-empty presentation stayed intact.
- The map layer selector and broader legend layout were left for later work.
- The static `Warning styles` preview remains a development-only reference and is not used as current-state UI.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/MapFeatureModelTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- `xcrun xccov view --report /Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.06.12_14-32-43--0600.xcresult | rg "MapLegendView.swift|MapScreenView.swift|AlertStyling.swift|MapFeatureModelTests.swift"`

#### Deferred Work

- AN-25 still owns accessible map overlay equivalents.
- AN-26 completed the remaining map control and legend crowding pass.
- AN-28 still owns the broader acceptance matrix across the finished map surface.

#### Handoff Notes

- `WarningLegendItem.rendered(from:)` is now the legend source of truth for rendered warnings. Keep future legend work on that path, not on a static supported-type list.
- Supported warning ordering is intentionally urgency-first: tornado, severe thunderstorm, flash flood, then explicit fallback rows for unsupported events.
- Unknown warning events intentionally keep their raw event text and fallback renderer styling so the legend stays honest instead of pretending they are one of the supported warning classes.
- AN-26 treated this warning legend as stateful current conditions while reducing crowding and reorganizing controls.

### AN-24 / GitHub #240 - Replace the map layer sheet with a native current-state menu

Status: Completed
Date: 2026-06-12
Model used: gpt-5 / medium

#### Scope

- Replaced the large single-selection map layer sheet with a native floating `Menu` trigger.
- The closed trigger now shows the selected layer’s semantic SF Symbol and concise title.
- Layer selection stays on the existing `selection` binding, and the menu uses native picker semantics for the existing six choices.
- The active-warning overlay control moved into the same menu as a clearly separated section and remains available at all Dynamic Type sizes.
- Removed the sheet-only close affordance and grid/list picker layout; no separate sheet remains for layer selection.
- Stabilized the closed trigger so layer swaps no longer reflow the button chrome by reserving icon/chevron space in the label, keeping the trigger on the current selection only, and suppressing implicit animation on the label subtree.
- Preserved the existing map layer selection state, persistence, default selection, data loading, refresh behavior, and rendering path.

#### Files Changed

- `Sources/Features/Map/MapScreenView.swift`
- `Sources/Features/Map/Picker.swift`
- `Tests/UnitTests/LayerPickerAdaptiveLayoutTests.swift`
- `Tests/UITests/SkyAwareUITests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- The map still uses the same layer-selection state machine and the same `MapFeatureModel` rendering path.
- AN-16 sensory feedback remains tied to actual selection changes only.
- AN-22 availability, freshness, stale, and confirmed-empty semantics remain intact.
- All six map layers remain available.
- The map remains more visually dominant because the chooser no longer opens a large modal sheet.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/MapLayerMenuTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareUITests/testMapLayerPickerCyclesThroughEveryLayerAndIgnoresDuplicateSelection -only-testing:SkyAwareUITests/testMapLayerMenuKeepsWarningToggleReachableAndFunctional test -resultBundlePath /private/tmp/SkyAware-AN24-ui.xcresult`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareUITests/testMapLayerMenuRemainsReachableAtAccessibilityTextSizes test`
- `xcrun xccov view --report /Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.06.12_10-53-24--0600.xcresult | rg "MapScreenView.swift|Picker.swift|LayerPickerAdaptiveLayoutTests.swift"`
- After the trigger-stability refinement, reran `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build` and `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareUITests/testMapLayerPickerCyclesThroughEveryLayerAndIgnoresDuplicateSelection test`.
- Coverage report signal on the touched files was minimal: `MapScreenView.swift` showed 2.84% (9/317) and `Picker.swift` showed 0.00% (0/162) in the captured report, so there is no meaningful coverage gain to claim from this slice.

#### Deferred Work

- AN-25 still owns the accessible overlay equivalents and related overlay summaries.
- AN-26 completed the remaining control / legend crowding pass around the now-menu-driven selector.

#### Handoff Notes

- Keep the trigger label tied to the current selected layer and its semantic symbol; do not replace it with generic layers chrome.
- Keep the trigger label’s reserved icon/chevron widths and the current-selection-only label sizing unless the menu changes materially; widening the label with hidden measurement content will reintroduce the dead space this pass removed.
- Keep the label subtree transaction override in place unless you have a clear replacement for the same no-reflow behavior.
- If the warning overlay control moves again, keep it in a clearly separated menu section rather than folding it into the layer list.
- AN-25 should reuse the same current-value and availability semantics rather than inventing a second overlay state model.
- AN-26 treated the menu as the new baseline and only trimmed the surrounding control chrome.

### AN-25 / GitHub #241 - Add accessible equivalents for map overlays

Status: Completed
Date: 2026-06-12
Model used: gpt-5.4 / high reasoning

#### Scope

- Added `MapAccessibilitySummary`, a single semantic summary derived from the same `MapLayerScene` and `MapLegendState` used to render the map.
- The summary contract now covers the selected layer, availability or freshness state, confirmed-empty state when present, local relationship when it is known, and the active-warning overlay state.
- Added Differentiate Without Color distinctions for applicable thematic overlay strokes and matching legend swatches by reusing a shared `MapOverlayDifferentiationStyle`.
- Kept the raw `MKMapView` from exposing individual overlay geometry to VoiceOver, while preserving direct map interaction and adding a concise summary outside the map.
- Preserved the AN-24 menu-based control surface so the active-warning overlay toggle stays reachable at large Dynamic Type sizes.
- Preserved AN-23 warning-legend truthfulness by deriving warning-summary text from `WarningLegendItem.rendered(from:)` instead of synthesizing new warning categories.

#### Accessible Summary Contract

- Source of truth is `MapLayerScene`; no second accessibility-only map state model was introduced.
- Base summary text comes from `MapLegendState.voiceOverText`, so loading, unavailable, saved/stale, populated, and confirmed-empty wording stays aligned with the rendered legend state.
- Local relationship only uses the known user coordinate plus rendered thematic `RiskPolygonOverlay` geometry for the selected layer.
- If the selected layer is confirmed empty, the summary does not invent a local relationship sentence.
- If the user coordinate is unavailable, the summary says `Local relationship unavailable.`
- If geometry needed for a local relationship is unavailable, the summary says `Local relationship unknown.` rather than inferring from the viewport or visible colors.
- Warning overlay text reports whether the overlay is hidden, enabled with active warning areas, or enabled with no rendered warning areas.

#### Differentiate Without Color Treatment

- Categorical, severe, fire, and mesoscale legend swatches now add stroke-pattern distinctions when Differentiate Without Color is enabled.
- Matching thematic polygon overlays use the same dashed-outline vocabulary, with modest line-width emphasis, while keeping existing colors, fills, geometry, and hatching intact.
- Warning overlays and warning legend semantics were not redefined here; AN-23 warning behavior remains the source of truth.

#### Controls At Large Text Sizes

- The active-warning overlay control remains in the AN-24 native menu path, which already keeps it reachable through AX5.
- This issue did not redesign the menu or broader control/legend layout; it only preserved that reachability while adding the new summary layer.

#### Files Changed

- `Sources/Features/Map/MapAccessibilitySupport.swift`
- `Sources/Features/Map/MapCanvasView.swift`
- `Sources/Features/Map/MapFeatureModel.swift`
- `Sources/Features/Map/MapLegendView.swift`
- `Sources/Features/Map/MapScreenView.swift`
- `Sources/Features/Map/RiskPolygonOverlay.swift`
- `Sources/Features/Map/RiskPolygonRenderer.swift`
- `Tests/UnitTests/MapFeatureModelTests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- AN-22 availability, freshness, stale, and confirmed-empty semantics remain the visible and accessible source of truth.
- AN-23 warning legend rendering and unknown-warning truthfulness remain intact.
- AN-24 layer selection, persistence, menu behavior, and warning-toggle reachability remain intact.
- Overlay colors, geometry, hatching semantics, refresh timing, and layer definitions remain unchanged.
- The implementation does not derive local relationship from screen position, map framing, or visual appearance.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/MapFeatureModelTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareUITests/testMapLayerPickerCyclesThroughEveryLayerAndIgnoresDuplicateSelection -only-testing:SkyAwareUITests/testMapLayerMenuKeepsWarningToggleReachableAndFunctional -only-testing:SkyAwareUITests/testMapLayerMenuRemainsReachableAtAccessibilityTextSizes test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`

#### Deferred Work

- A manual VoiceOver pass across the full map scene was not completed in this change.
- Manual simulator inspection for Differentiate Without Color on/off, Increased Contrast, and light/dark mode remains outstanding.
- AN-26 completed the broader visible control and legend crowding work around the map chrome.
- AN-28 still owns the broader end-to-end acceptance sweep across the completed map surface.

### AN-26 / GitHub #242 - Reduce map control and legend crowding

Status: Completed
Date: 2026-06-12
Model used: gpt-5.4 / high reasoning

#### Scope

- Reworked the bottom map chrome so the warning legend and layer legend can stack, compact, or collapse instead of staying side by side when space gets tight.
- Added a compact legend trigger that appears before the combined control cluster consumes too much of the map, with a short warning subtitle so the current-state legend stays readable at a glance.
- Reflowed the hatching explainer into a narrower wrapped layout so the severe legend grows taller instead of wider when hatching is present.
- Increased the interactive hit targets for the map layer trigger, compact legend trigger, hatch explainer row, and remaining legend controls to at least 44 by 44 points.
- Replaced the remaining custom legend-sheet close control with a native toolbar cancellation action.
- Added focused UI coverage for the compact legend path, 44-point target checks, and native sheet cancellation.

#### Files Changed

- `Sources/Features/Map/MapLegendView.swift`
- `Sources/Features/Map/MapScreenView.swift`
- `Sources/Features/Map/Picker.swift`
- `Tests/UITests/SkyAwareUITests.swift`
- `docs/plans/apple-native-ui-alignment-progress.md`

#### Behavior Preserved

- Map data loading, selection, refresh, availability, rendering, hatching, and persistence behavior were unchanged.
- AN-23 warning legend truthfulness remains intact.
- AN-24 native layer menu behavior and current-state selection semantics remain intact.
- AN-25 accessible map summary, Differentiate Without Color treatment, and warning-toggle reachability remain intact.
- The map still keeps its visual priority; this only trims the surrounding chrome.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareUITests/testMapLayerMenuRemainsReachableAtAccessibilityTextSizes test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareUITests/testMapLegendCompactTriggerOpensSheetWithNativeCancellationAction test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareUITests/testMapLegendCompactTriggerOpensSheetWithNativeCancellationAction test`
- `xcrun xcresulttool export attachments --path /Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.06.12_15-28-17--0600.xcresult --output-path /private/tmp/AN26-attachments`
- `xcrun xcresulttool export attachments --path /Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.06.12_15-32-24--0600.xcresult --output-path /private/tmp/AN26-attachments`

#### Deferred Work

- AN-27 still owns the final shared spacing-scale polish pass.
- AN-28 still owns the complete acceptance matrix sweep, including the remaining manual device and accessibility permutations.
- Manual inspection across every layout permutation in the matrix was only partially automated here; the UI tests cover the representative compact path and target sizes.
- Screenshot attachment export did not produce a host-visible file, so no screenshot artifact is being claimed for this pass.

#### Handoff Notes

- Keep compact legend behavior driven by the current available width and Dynamic Type, not by device-model breakpoints.
- Preserve the current menu-based layer selector and stateful warning legend truth source when tuning any remaining map chrome.
- The compact trigger is the pressure valve for future map chrome changes; do not replace it with a permanent control panel.
- AN-27 should treat this compact legend behavior as the baseline spacing reference, not as an invitation to add more chrome.
- AN-28 should verify the remaining portrait, landscape, contrast, and VoiceOver permutations against this completed control layout.
