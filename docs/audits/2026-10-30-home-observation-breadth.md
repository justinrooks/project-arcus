# Home presentation Observation breadth — #810

Home's presentation call eagerly read transient pipeline payloads even though production selects accepted `HomeVisibleRevision` values. The correction defers those payload reads to static UI-test mode. Production still observes the resolved-location and committed-alert keys; the remaining Home modifiers, refresh state, acceptance authority, and side effects retain their existing reads. No new view boundary, conversion cache, or decoding optimization is introduced.

## Method and results

The measurement reuses #805's ten-retained-projection fixture and 2,329-byte detailed Storm Setup response. The baseline replays the eager argument evaluation from `ac714a6`; the candidate invokes the production `HomeView.presentationSnapshot` factory. Scoped `withObservationTracking` registrations are rearmed before each mutation. Weather and enrichment steps represent individual transient publications during cached foreground/manual refresh; they do not execute a live refresh or measure its event frequency. Accepted-core steps replace a revision with changed risk, independently of pipeline payloads.

| Scoped scenario | Mutations | Baseline notifications → candidate | Selected output changes, both |
| --- | --- | --- | --- |
| Transient weather | 20 | 20 → 0 | 0 |
| Transient Storm Setup response | 20 | 20 → 0 | 0 |
| Accepted core revision | 20 | 20 → 20 | 20 |

A hosted `HomeProjectionObservation` with a minimal Text consumer measures content-closure evaluations after mounting. Twenty transient location-snapshot publications, separated by 50 ms, produced 20 additional evaluations with eager reads and zero with the candidate. Both hosts initially evaluated twice. This exercises the real observer body and its projection sampling, but replaces Home's tabs and side-effect modifiers with a minimal consumer. It does not count descendant rendering, frames, or hitches. The hosted replay uses accepted fixture state independently from the observer's callback arguments to isolate pipeline dependencies; existing observation regressions cover actual accepted-state promotion.

Presentation construction itself is small: the pre-correction scoped replay measured median 0.019 ms eager versus 0.018 ms gated, with p95 0.021 ms for both (nine batches of 1,000 evaluations, per-evaluation averages). These timings exclude observation registration, projection conversion, query fetch, and rendering; the difference is not evidence of a useful direct speedup. The useful reduction is avoiding observer reevaluation. #805's unchanged single-sample factory measured 7.075 ms median keyed and 6.396 ms startup in the same hosted-probe run. These are separate replay timings, not measured latency savings for a complete refresh. The dependency reduction avoids repeating this material work in the hosted fixture, justifying the small argument-read correction.

## Reproduction and evidence

- Measurement: `tools/ci/run_test_lane.sh performance '-only-testing:SkyAwarePerformanceTests/HomeProjectionStoreScalingMeasurementTests/presentationDependencies_reportObservationBreadth()'`.
- Focused regression: `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/HomeProjectionStoreScalingMeasurementTests -only-testing:SkyAwareTests/HomeViewProjectionLaunchTests -only-testing:SkyAwareTests/HomeVisibleRevisionTests`.
- Required final regression: `tools/ci/run_test_lane.sh unit`.
- The original #805 benchmark remains unchanged. The new measurement is separately registered in the performance lane and excluded from the unit lane.

The exploratory hosted run passed native verification with exactly one selected test, no failures/skips, Debug, `SkyAware_Performance`, iPhone 17 simulator, iOS 26.5 (23F77), Xcode 27.2. Bundle: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.lWtCfn/performance.xcresult`; attachment: `HomePresentationDependencies810.txt`. This run used a temporary gated baseline call before the production correction; the committed measurement exercises the production candidate directly. The temporary probe and exported attachments are retained at `/tmp/skyaware-810-evidence`.

Apple `swiftui-specialist` (dataflow) and `xctrace` skill guidance were loaded. No Instruments capture, physical-device trace, full Home UI/hitch measurement, or coverage comparison was performed. Measurements do not establish that every transient publication invalidates the full production hierarchy, nor that visible hitches occurred or were fixed. Other meaningful Home dependencies still invalidate their consumers. Unit coverage checks accepted presentation and static-mode fallback/observation behavior; existing launch/accepted-revision tests protect cache-forward and location semantics.

The final production-candidate measurement passed native verification with exactly one selected test, zero failures/skips, on the same configuration/runtime: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.Aqg4js/performance.xcresult`, attachment `HomePresentationDependencies810.txt`. It reproduced all scoped notification/output counts and hosted 20 → 0 additional evaluations. Presentation-only median was 0.019 ms eager versus 0.020 ms production candidate, again showing no direct construction-time improvement. An earlier permanent-probe run failed because its first step assigned nil to an already-nil snapshot, yielding 19 actual publications; the fixture now initializes a nonnil snapshot before mounting so all 20 steps change it. No assertion or test selection was weakened.

Focused `SkyAware_Tests` regression passed with 28 logical tests / 32 parameter-expanded executions, zero failures/skips: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.Q1TMvx/unit.xcresult`, Debug, iPhone 17 simulator, iOS 26.5 (23F77). Independent `skyaware_reviewer` review found no actionable introduced defects and independently verified both finalized production-candidate artifacts. A first overlapping unit build attempt failed on Xcode's build-database lock with zero tests; the passing focused run was sequential after performance completed.

Required full `tools/ci/run_test_lane.sh unit` passed finalized native verification: 1,605 logical tests, 1,604 passed, zero failed, one allowed skip; parameter-expanded counts were 1,897 passed and one skipped. Environment: Debug, `SkyAware_Tests`, iPhone 17 simulator, iOS 26.5 (23F77). Bundle: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.SroUuN/unit.xcresult`. Source and tests matched the reviewed diff; subsequent changes only completed this evidence note.
