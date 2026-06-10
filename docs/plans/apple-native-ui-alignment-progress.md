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
| 3 | AN-03 | [#219](https://github.com/justinrooks/project-arcus/issues/219) | Convert the location reliability rail to native buttons | Not started | |
| 4 | AN-04 | [#220](https://github.com/justinrooks/project-arcus/issues/220) | Separate notification preference from authorization | Not started | |
| 5 | AN-05 | [#221](https://github.com/justinrooks/project-arcus/issues/221) | Remove raw diagnostics from production Settings | Not started | |
| 6 | AN-06 | [#222](https://github.com/justinrooks/project-arcus/issues/222) | Make launch and onboarding presentation state explicit | Not started | |
| 7 | AN-07 | [#223](https://github.com/justinrooks/project-arcus/issues/223) | Make onboarding resilient to Dynamic Type | Not started | |
| 8 | AN-08 | [#224](https://github.com/justinrooks/project-arcus/issues/224) | Apply Reduce Motion to onboarding and toasts | Not started | |
| 9 | AN-09 | [#225](https://github.com/justinrooks/project-arcus/issues/225) | Replace implementation language in user-facing copy | Not started | |
| 10 | AN-10 | [#226](https://github.com/justinrooks/project-arcus/issues/226) | Preserve optional Outlook metadata truthfully | Not started | |
| 11 | AN-11 | [#227](https://github.com/justinrooks/project-arcus/issues/227) | Use proportional typography for weather narratives | Not started | |
| 12 | AN-12 | [#228](https://github.com/justinrooks/project-arcus/issues/228) | Preserve cached Summary content while offline | Not started | |
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
