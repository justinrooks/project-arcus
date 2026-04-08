# SkyAware Release Readiness Punchlist

This punchlist turns the current review into concrete launch work.

The goal is not perfection. The goal is to make SkyAware feel reliable, trustworthy, and understandable to a public audience.

## Launch Recommendation

Current recommendation: quiet public launch is reasonable if the `Must Before Public Launch` section is complete.

Do not market SkyAware as a guaranteed timely alerting app until the operational checks and client behavior below are verified end to end.

## Must Before Public Launch

### 1. Verify server notification control actually works

- [ ] Turn `Server Notifications` off in the app and confirm the backend stops targeting that device within a defined time bound.
- [ ] Turn `Send Location to Signal` off in the app and confirm no new location presence updates are accepted or used for targeting.
- [ ] Re-enable both settings and confirm the device resumes targeting correctly without reinstalling the app.
- [ ] Write down the expected propagation behavior for each toggle.

Pass criteria:
- A user can predict what each toggle does.
- Backend behavior matches the UI within a known and acceptable delay.

### 2. Fix partial-failure behavior on the Today screen

- [ ] Change the Today refresh path so successful reads still update the UI even when one provider fails.
- [ ] Keep the last good value only for the section that failed instead of blocking the full snapshot.
- [ ] Surface a subtle degraded-freshness state when data is partially stale.

Pass criteria:
- One flaky feed does not leave the whole summary looking unresolved.
- Users still get the best available picture.

### 3. Make the Map stay in sync with current data

- [ ] Refresh map state when new map products are synced.
- [ ] Refresh map state when the app becomes active again.
- [ ] Confirm Today and Map agree after a foreground refresh.

Pass criteria:
- The Map never feels obviously older than the Today tab.

### 4. Remove avoidable notification delay for urgent local notifications

- [ ] Review local notification delivery paths and remove the default 10-second delay where urgency matters.
- [ ] Keep any intentional delay only where it is product-driven, such as non-urgent summary behavior.
- [ ] Verify duplicate suppression still works after the timing change.

Pass criteria:
- Local notifications are not artificially slower than they need to be.

### 5. Add real UI smoke coverage for trust-critical flows

- [ ] Add a UI test for first launch and onboarding progression.
- [ ] Add a UI test for location denied or restricted state.
- [ ] Add a UI test for entering the main tab shell and switching across core tabs.
- [ ] Add a UI test for opening alert detail from the Alerts tab or Today summary.

Pass criteria:
- The app has at least one automated smoke path for onboarding, main navigation, and alert drill-in.

## Should Do Before Or Immediately After Launch

### 6. Clean up settings so the product contract is honest

- [ ] Audit every user-facing setting and classify it as active, experimental, internal-only, or retired.
- [ ] Remove or hide settings that do not map cleanly to actual runtime behavior.
- [ ] Add short explanatory copy for settings that affect background delivery or privacy-sensitive behavior.

Pass criteria:
- No setting feels misleading.
- Users can understand what they are opting into.

### 7. Document the real notification architecture

- [ ] Update `docs/architecture/timely-notifications-strategy.md` so it reflects the current backend reality.
- [ ] Document the current push path: ingestion, dedupe, H3 targeting, zone targeting, APNs delivery, and freshness constraints.
- [ ] Document known limitations clearly.

Pass criteria:
- The docs match the actual system.
- Future decisions are based on truth, not outdated assumptions.

### 8. Tighten freshness ownership

- [ ] Centralize or better coordinate foreground and background freshness bookkeeping.
- [ ] Avoid marking feeds as freshly synced before the underlying work has actually succeeded.
- [ ] Define what "fresh enough" means for each feed.

Pass criteria:
- Retry behavior is easier to reason about.
- Stale data is less likely to hide behind optimistic timestamps.

### 9. Improve degraded-state UX

- [ ] Add a lightweight freshness signal for stale but usable data.
- [ ] Distinguish "no alert" from "unable to confirm alerts right now."
- [ ] Distinguish "all clear" from "data unavailable."

Pass criteria:
- Calm design is preserved without pretending uncertainty does not exist.

## Operational Validation

### 10. Run real-device drills

- [ ] Test with `When In Use` location only.
- [ ] Test with `Always` location enabled.
- [ ] Test after denying location permission.
- [ ] Test after downgrading location permission in Settings.
- [ ] Test after denying notifications.
- [ ] Test after force-quitting the app.
- [ ] Test after reinstalling the app.
- [ ] Test with stale location presence and confirm expiry behavior.

Pass criteria:
- You know exactly how SkyAware behaves in the states real users will hit.

### 11. Validate remote push open behavior

- [ ] Send a remote notification to a test device.
- [ ] Tap it from background state.
- [ ] Tap it from terminated state.
- [ ] Confirm the app lands in a coherent state and refreshes relevant data.

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

- [ ] Use [app_store_docs.md](./app_store_docs.md) as the canonical baseline for App Store copy, in-app disclaimer language, and any launch messaging.
- [ ] Audit user-facing copy across the app to ensure it stays aligned with the language in `app_store_docs.md`.
- [ ] Describe SkyAware as a severe-weather awareness app.
- [ ] Avoid implying guaranteed immediate alerts.
- [ ] Keep the best-effort disclaimer in App Store copy and in-app surfaces.
- [ ] Avoid overstating warning coverage until warning behavior is fully verified end to end.

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

- [ ] Settings match backend behavior.
- [ ] Today handles partial failures gracefully.
- [ ] Map freshness is trustworthy.
- [ ] Notification timing is intentional.
- [ ] Core onboarding and navigation UI smoke tests exist.
- [ ] Real-device push and permission drills have been completed.
- [ ] App Store positioning remains conservative and accurate.

## Suggested Priority Order

1. Server-control verification
2. Today partial-failure handling
3. Map freshness
4. Notification timing
5. UI smoke coverage
6. Real-device drills
7. Documentation and messaging cleanup
