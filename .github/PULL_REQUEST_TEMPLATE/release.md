## Release preparation
- Marketing version (set manually in Xcode): `__`
- Purpose: [ ] TestFlight candidate  [ ] Public App Store finalization
- Distributed build number: assigned by Xcode Cloud (not a PR input)

## Included changes (user-facing)
<!-- 3–8 evidence-backed bullets; keep them concrete. -->
-

## Before merge

### Release artifacts
- [ ] `release/CHANGELOG.md` is the canonical, evidence-backed changelog
- [ ] `release/RELEASE_NOTES.md` is derived from the changelog
- [ ] `TestFlight/WhatToTest.en-US.txt` contains current, actionable tester instructions and is committed
- [ ] The verified previous **public App Store** source revision is the evidence baseline
- [ ] Historical build-number sections and `release/TESTFLIGHT_NOTES.md` are unchanged

### App metadata
- [ ] Read and verified matching `MARKETING_VERSION` in `SkyAware` and `SkyAwareWidgetsExtension`, Debug and Release
- [ ] Confirmed both shipping targets retain checked-in `CURRENT_PROJECT_VERSION = 1`
- [ ] No project build settings were modified by release-preparation tooling

### Quality gates
- [ ] Relevant local or CI checks passed
- [ ] Primary app flows checked on a device when affected
- [ ] Background refresh and notifications checked when affected

### Merge readiness
- Risk level: [ ] Low  [ ] Medium  [ ] High
- Rollback plan (if needed):
- Notes:

---

## After merge: TestFlight candidate

- [ ] Triggered the Xcode Cloud distribution workflow explicitly through the verified App Store Connect API CLI
- [ ] Confirmed the build completed processing and appeared in TestFlight
- [ ] Recorded the **actual** distributed marketing version, build number, and source revision from Xcode Cloud
- [ ] Confirmed TestFlight's **What to Test** matches the committed `TestFlight/WhatToTest.en-US.txt`
- [ ] No Git tag or GitHub Release was created for the candidate

## Only after the public App Store release is live

- [ ] Promoted the accepted TestFlight binary to App Store distribution
- [ ] Confirmed the marketed version is live on the App Store
- [ ] Verified the source commit that produced the accepted binary (not necessarily the current `main` tip)
- [ ] Created immutable stable tag `vMAJOR.MINOR.PATCH` at that exact source commit
- [ ] Published the matching GitHub Release from the verified release notes
- [ ] Recorded the shipped marketing version and actual distributed build number for operational traceability
