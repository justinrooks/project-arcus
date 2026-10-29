---
title: Delayed enable callbacks cannot lift an unconfirmed opt-out
author: Justinrooks
date: 2026-10-29
branch: issue-794
touches:
  - Sources/Infrastructure/Location/LocationSnapshotPusher.swift
  - Tests/UnitTests/LocationProviderTests.swift
  - docs/security/installation-enrollment.md
---

## Decided
PR #799 feedback establishes that independently scheduled settings callbacks can execute out of intent order. A Boolean enable callback must not override a disabled subscription provider or clear an outstanding restrictive opt-out. Only false callbacks install the temporary restriction. Current settings reconcile that restriction after disabled is observed; later observed enabled permits normal re-enablement.

## Tried and ruled out
Letting every callback replace subscriptionOverride treats execution order as user intent order. Clearing the restriction on a true callback fixes the already-disabled-provider case but leaks opt-in when the disable defaults write still lags. Test both provider states and immediate/delayed token arrival, checking preference and location payloads.

## Watch out
With Boolean inputs alone, a stale enable and genuine rapid re-enable before disabled is observed are indistinguishable. The coordinator conservatively retains opt-out for that lifetime if the intermediate disabled value is never observed. Do not claim latest-callback authority or introduce v3 consent revision architecture into #794. Signal #379 and SkyAware #798 retain their separate ownership.
