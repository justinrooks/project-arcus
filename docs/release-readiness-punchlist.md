# SkyAware Release Readiness Punchlist

This punchlist turns the current review into concrete launch work.

The goal is not perfection. The goal is to make SkyAware feel reliable, trustworthy, and understandable to a public audience.

## Release ownership and version parity

The marketing version is manually maintained in Xcode. The shipping app (`SkyAware`) and widget
(`SkyAwareWidgetsExtension`) must use the same `MARKETING_VERSION` in Debug and Release. Their checked-in
`CURRENT_PROJECT_VERSION` values intentionally remain `1`; Xcode Cloud assigns the distributed build number.
The release-preparation skill validates these settings without changing them. Test and performance targets have
independent version settings and are not part of the shipping-target parity check.

`release/CHANGELOG.md` is the canonical, evidence-backed record of user-impacting changes. Maintain
`Unreleased` while changes land. When explicitly preparing a TestFlight candidate, the `skyaware-release` skill
uses the marketing version already set in Xcode and prepares a version-only heading (for example, `v1.6.0`),
along with the matching `release/RELEASE_NOTES.md` section. Use the verified source revision of the previous
**public App Store release** as the evidence baseline; do not infer it from the latest historical `v*` tag.
A prepared version heading does not itself mean the version shipped. Never rewrite legacy build-number headings.

`TestFlight/WhatToTest.en-US.txt` is the **single current candidate's** tester-facing notes file. Prepare
concise, actionable notes from the canonical changelog using `skyaware-release`, and commit them before
explicitly triggering the Xcode Cloud TestFlight distribution workflow through the App Store Connect API.
Xcode Cloud's documented TestFlight-notes integration reads the committed file; no post-build notes generator
or separate metadata upload is needed. Verify that the **processed build's** What to Test field actually
contains the intended text. A successful build trigger alone is not evidence of notes delivery.

The former `release/TESTFLIGHT_NOTES.md` remains untouched as historical documentation; do not append new
candidate entries. The active `ci_scripts/ci_post_xcodebuild.sh` still validates test results and does not
generate tester notes. Do not use Git tags to start new TestFlight candidates. The old Xcode Cloud tag trigger
remains configured temporarily until the API-based replacement is validated end-to-end.

Only after an accepted TestFlight build is live on the App Store should public-release finalization create a
stable Git tag such as `v1.6.0` at the **actual accepted binary's source commit**, then publish the matching
GitHub Release. GitHub Releases represent public App Store releases, not TestFlight builds.

## Launch Recommendation

Current recommendation: quiet public launch is reasonable if the `Must Before Public Launch` section is complete.

Do not market SkyAware as a guaranteed timely alerting app until the operational checks and client behavior below are verified end to end.

## Must Before Public Launch

### 1. Verify server notification control actually works

- [x] Turn `Server Notifications` off in the app and confirm the backend stops targeting that device within a defined time bound.
- [x] Turn `Send Location to Signal` off in the app and confirm no new location presence updates are accepted or used for targeting.
- [x] Re-enable both settings and confirm the device resumes targeting correctly without reinstalling the app.
- [x] Write down the expected propagation behavior for each toggle.

Pass criteria:
- A user can predict what each toggle does.
- Backend behavior matches the UI within a known and acceptable delay.

### 2. Fix partial-failure behavior on the Today screen

- [x] Change the Today refresh path so successful reads still update the UI even when one provider fails.
- [x] Keep the last good value only for the section that failed instead of blocking the full snapshot.
- [x] Surface a subtle degraded-freshness state when data is partially stale.

Pass criteria:
- One flaky feed does not leave the whole summary looking unresolved.
- Users still get the best available picture.

### 3. Make the Map stay in sync with current data

- [x] Refresh map state when new map products are synced.
- [x] Refresh map state when the app becomes active again.
- [x] Confirm Today and Map agree after a foreground refresh.

Pass criteria:
- The Map never feels obviously older than the Today tab.

### 4. Remove avoidable notification delay for urgent local notifications

- [x] Review local notification delivery paths and remove the default 10-second delay where urgency matters.
- [x] Keep any intentional delay only where it is product-driven, such as non-urgent summary behavior.
- [x] Verify duplicate suppression still works after the timing change.

Pass criteria:
- Local notifications are not artificially slower than they need to be.

### 5. Add real UI smoke coverage for trust-critical flows

- [x] Add a UI test for first launch and onboarding progression.
- [x] Add a UI test for location denied or restricted state.
- [x] Add a UI test for entering the main tab shell and switching across core tabs.
- [x] Add a UI test for opening alert detail from the Alerts tab or Today summary.

Pass criteria:
- The app has at least one automated smoke path for onboarding, main navigation, and alert drill-in.

## Should Do Before Or Immediately After Launch

### 6. Clean up settings so the product contract is honest

- [x] Audit every user-facing setting and classify it as active, experimental, internal-only, or retired.
- [x] Remove or hide settings that do not map cleanly to actual runtime behavior.
- [x] Add short explanatory copy for settings that affect background delivery or privacy-sensitive behavior.

Pass criteria:
- No setting feels misleading.
- Users can understand what they are opting into.

### 7. Document the real notification architecture

- [x] Update `docs/architecture/timely-notifications-strategy.md` so it reflects the current backend reality.
- [x] Document the current push path: ingestion, dedupe, H3 targeting, zone targeting, APNs delivery, and freshness constraints.
- [x] Document known limitations clearly.

Pass criteria:
- The docs match the actual system.
- Future decisions are based on truth, not outdated assumptions.

### 8. Tighten freshness ownership

- [x] Centralize or better coordinate foreground and background freshness bookkeeping.
- [x] Avoid marking feeds as freshly synced before the underlying work has actually succeeded.
- [x] Define what "fresh enough" means for each feed.

Pass criteria:
- Retry behavior is easier to reason about.
- Stale data is less likely to hide behind optimistic timestamps.

### 9. Improve degraded-state UX

- [x] Add a lightweight freshness signal for stale but usable data.
- [x] Distinguish "no alert" from "unable to confirm alerts right now."
- [x] Distinguish "all clear" from "data unavailable."

Pass criteria:
- Calm design is preserved without pretending uncertainty does not exist.

## Operational Validation

### 10. Run real-device drills

- [x] Test with `When In Use` location only.
- [x] Test with `Always` location enabled.
- [x] Test after denying location permission.
- [x] Test after downgrading location permission in Settings.
- [x] Test after denying notifications.
- [x] Test after force-quitting the app.
- [x] Test after reinstalling the app.
- [x] Test with stale location presence and confirm expiry behavior.

Pass criteria:
- You know exactly how SkyAware behaves in the states real users will hit.

Optional accessibility smoke for releases that change Today, Local Alerts, or Storm Setup:

- [ ] On a physical device, enable an accessibility Dynamic Type size and confirm current, resolving, alerts, empty,
  and Storm Setup content remains readable and reachable by scrolling.
- [ ] Exercise pull-to-refresh and open one Local Alert and Storm Setup detail; confirm controls remain reachable and
  no text overlaps adjacent content.
- [ ] Enable Reduce Motion, repeat the Today resolving and refresh paths, and confirm ambient movement stops and
  spatial transitions simplify without structural jumps.
- [ ] Restore Dynamic Type and Reduce Motion to their original device settings.

This is a release smoke check, not a completion gate or timing measurement.

### 11. Validate remote push open behavior

- [x] Send a remote notification to a test device.
- [x] Tap it from background state.
- [x] Tap it from terminated state.
- [x] Confirm the app lands in a coherent state and refreshes relevant data.

Pass criteria:
- Opening from a push never leaves the user confused about what happened or why they were alerted.

### 12. Establish a launch-watch dashboard

- [ ] Track APNs acceptance rate.
- [ ] Track device targeting success and rejection reasons.
- [ ] Track stale presence rate.
- [ ] Track client-side background run success and failure rates.
- [ ] Track top failure modes from logs and diagnostics.

Pass criteria:
- You can tell within a day whether launch behavior is healthy.

## Product Positioning

### 13. Keep launch messaging conservative

- [x] Use [app_store_docs.md](./app_store_docs.md) as the canonical baseline for App Store copy, in-app disclaimer language, and any launch messaging.
- [x] Audit user-facing copy across the app to ensure it stays aligned with the language in `app_store_docs.md`.
- [x] Describe SkyAware as a severe-weather awareness app.
- [x] Avoid implying guaranteed immediate alerts.
- [x] Keep the best-effort disclaimer in App Store copy and in-app surfaces.
- [x] Avoid overstating warning coverage until warning behavior is fully verified end to end.

Pass criteria:
- Marketing claims stay inside the envelope of what the system can reliably do.

## Nice To Have

### 14. Improve contributor safety and maintainability

- [ ] Reduce crash-prone `fatalError` dependency access in UI-facing code paths.
- [ ] Standardize DTO identity rules across feature areas.
- [ ] Remove or archive leftover NWS-watch migration dead weight.
- [ ] Expand diagnostics so they help explain freshness and targeting state, not just background history.

Pass criteria:
- The codebase becomes easier to evolve without accidental regressions.

## Suggested Launch Gate

Ship publicly when all of these are true:

- [x] Settings match backend behavior.
- [x] Today handles partial failures gracefully.
- [x] Map freshness is trustworthy.
- [x] Notification timing is intentional.
- [x] Core onboarding and navigation UI smoke tests exist.
- [x] Real-device push and permission drills have been completed.
- [x] App Store positioning remains conservative and accurate.

## Suggested Priority Order

1. Server-control verification
2. Today partial-failure handling
3. Map freshness
4. Notification timing
5. UI smoke coverage
6. Real-device drills
7. Documentation and messaging cleanup
