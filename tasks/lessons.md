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
