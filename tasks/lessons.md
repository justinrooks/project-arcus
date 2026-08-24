# Lessons

## 2026-04-22

- When the user says `AGENTS.md` changed, re-read the root and the nearest source-level guidance before doing anything else.
- For intermittent map-product bugs, audit time-window predicates in the repo layer before assuming the failure is purely in the SwiftUI or MapKit surface.
- When a refactor replaces direct view loading with a feature model, preserve refresh semantics and cache invalidation behavior, not just the rendered output.

## 2026-05-03

- During final reviews, distinguish written brief language from later accepted platform/product decisions in the implementation and progress log before labeling behavior as a blocker.
- For FB-017 widgets, preserve the intentional choices that watches outrank mesoscale discussions, small widgets omit visible freshness to stay single-signal, and freshness copy avoids `Updated` language.

## 2026-05-27

- For SwiftUI transition-state fixes, do not gate the first render of a new input state on state that is only set from `onChange`; derive first-frame behavior from the previous stable phase already held in `@State`, then let `onChange` advance the phase for the remainder of the transition.

## 2026-06-11

- For hero badges and cards, move important category labels into the content flow instead of floating them over decorative art; overlay-only labels are easy to bury behind icons and break the visual hierarchy the user asked for.

## 2026-06-15

- When a native list migration has an immediately preceding sibling migration, mirror that sibling's row padding and inset baseline first; spacing drift is not a design system, it's just inconsistency with extra steps.

## 2026-07-02

- When planning a new Today data feed, state cache-forward behavior, SwiftData persistence, background participation,
  and expected endpoint latency explicitly. Naming the unified ingestion path is not enough; each lifecycle guarantee
  needs its own acceptance criteria and failure tests.
- When a server field carries prose or confidence semantics, preserve the text boundary explicitly instead of routing
  it through a generic ingredient signal enum. Valid domain meaning should not be collapsed into `.unknown` just
  because the token family differs from the other assessment rows.
- When a broad eligibility test depends on async request startup, keep the default foreground timeout close to the
  production shape and override only the deliberate timeout cases. A 50 ms default is a flake generator, not a test.

## 2026-07-03

- When a new async test suite mirrors an existing serialized suite, copy its task and polling pattern exactly before
  blaming production code. Detached `Task {}` bodies, throwing spin-loop wait helpers, and timeout gates left closed
  after assertions can poison a full Xcode run even when an isolated test looks fine.

## 2026-07-12

- Do not infer SwiftData Codable storage behavior from JSON Codable behavior. SwiftData may flatten nested values and
  use framework-specific encoders that trap on otherwise valid custom enum conformances. Inspect the SQLite schema and
  reproduce an actual save/reopen path before prescribing a shared-model decoder fix.

## 2026-07-16

- For background cadence work, preserve the established 20/40/60-minute bands: marginal-or-higher categorical risk,
  active alerts, or active mesos use 20 minutes; thunderstorm-only uses 40; all-clear uses 60. Missing context and
  failures retry at 20, but the next successful run must authoritatively restore the condition-appropriate band.
- When coalescing one notification channel into another, include the source channel's preference in the coalescing
  predicate. A disabled delivery must remain pending rather than becoming unrequested content in the alternate channel.
- Coalescing a newer occurrence must pass through the delivery gate's supersession logic; otherwise a stale pending
  occurrence for the same projection can escape immediately after the combined notification.

## 2026-07-23

- Treat checked-in marketing versions and build numbers as placeholders when Xcode Cloud owns release numbering.
  Monitor only app/widget parity unless the user or release workflow identifies a different repository-owned
  invariant; do not create speculative release-provenance work from those values.

## 2026-07-24

- Do not report a Swift change as build-validated until a successful Xcode build has compiled the affected target;
  an unfinalized result bundle or a zero-test summary is evidence of an interrupted run, not validation.
- When a large SwiftUI `TabView` reports a type-checking timeout on an innocent later tab, split every primary tab
  into an opaque helper before retrying; the failure is usually accumulated result-builder complexity.
- When extracting SwiftUI structure to resolve a compiler limit, preserve existing presentation predicates verbatim;
  do not substitute a nearby feature-level loading heuristic for the surface's established state machine.

## 2026-07-26

- When a test passes repeated isolated runs but Xcode Cloud still reports it as crashed, treat the test name as process
  attribution rather than root-cause evidence. Audit the parallel unit lane for abandoned tasks, continuations, shared
  state, and configuration differences before changing the named test again.
- Never let a persisted test fixture hard-code authorization or preference state while the operation under test reads
  that state from the simulator. Inject matching providers so a developer simulator cannot hide clean-Cloud behavior.

## 2026-07-28

- For durable background diagnostics, persist each completed phase at its boundary; terminal finalization is not a
  substitute because process termination can occur between phases. Prove schema evolution against a legacy disk store,
  not merely a current-schema reopen, and never synthesize a phase outcome for work that did not start.

- When characterizing coordinator compatibility, construct requests exactly as production does. A trigger without its
  production-required context can bypass a compatibility guard and turn a queued request into a synthetic join.
- For background deadlines, distinguish request admission from a hard in-flight transfer bound, propagate expiry as an
  observable execution outcome rather than relying on task cancellation alone, and retain task-local budget context
  with queued coordinator work instead of assuming later child tasks inherit the original caller's scope.
- When background and foreground ingestion ownership can share a coordinator, never let deadline state fail a
  foreground waiter merely because plans are compatible; queue it for an unbudgeted follow-up and track waiter/run
  eligibility so the preceding background result cannot resolve it.
- When deciding whether cancellation has removed the final owner of an actor-serialized run, count the remaining
  active-run owners directly. Do not use a predicate that classifies them as cancelable, because a cancelable waiter
  remains an owner until it is actually removed.
- Test seams that expose terminal execution must acknowledge both success and cancellation before rethrowing; a
  success-only completion counter turns cancellation tests into deadlocks.
- For background cache-reuse policy, validate every freshness horizon against the actual 20/40/60-minute scheduling
  cadence, but never present `earliestBeginDate` delay as bounded. State any longer reuse window as an explicit
  product privacy tolerance and test the intentional skip behavior beyond it; a threshold that expires before the
  first scheduled successor is dead code for When-In-Use background refresh.
- When cached metadata is combined with a newer snapshot, run eligibility policy against the exact composite returned.
  If the composite fails, explicitly evaluate the original cached value before discarding an otherwise valid fallback.

## 2026-08-24

- Do not infer an Xcode Cloud workflow's selected Xcode, runtime, or destination matrix from local Xcode evidence.
  Inspect the actual configured workflow or ask the owner before documenting or changing its topology; external
  workflow state can conflict with an issue's proposed target configuration.
- When an issue's proposed CI topology conflicts with the established Xcode Cloud job, preserve the job unless the
  user explicitly authorizes changing it. Make result validation matrix-aware instead of forcing a local-canonical
  topology onto Cloud.
- Do not construct legacy and current SwiftData containers with same-named versioned `@Model` types inside a unit
  process that is also creating current-schema containers in parallel. SwiftData's global entity registration can
  cross-wire the model metadata nondeterministically. Validate migration from a frozen disk fixture or a genuinely
  isolated test process, then prove the complete parallel unit plan—not only a focused lane or one lucky full run.
- Confirm whether a persistence shape has actually shipped before designing a migration graph. For unreleased,
  developer-only schemas, prefer a clean store reset and keep production free of speculative compatibility code.
