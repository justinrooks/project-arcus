## Release
- Version: `__`
- Build: `__`  <!-- If manual. If CI-generated, leave blank -->
- Target: [ ] TestFlight  [ ] App Store

## Included changes (user-facing)
<!-- 3–8 bullets max. Keep it concrete. -->
- 

## Pre-merge (must be true before merging)

### Release documentation
- [ ] `CHANGELOG.md` updated (canonical)
- [ ] `RELEASE_NOTES.md` updated (derived from changelog)
- [ ] `TESTFLIGHT_NOTES.md` updated (derived; concise)

### App metadata
- [ ] MARKETING_VERSION updated to `__`
- [ ] CURRENT_PROJECT_VERSION incremented (build number)

### Quality gates
- [ ] Tests pass (local or CI)
- [ ] App launches and primary flows sanity-checked
- [ ] Build info in Settings displays correct version/build (for this commit)
- [ ] Background refresh / notifications sanity-checked (if touched)

### Merge readiness
- Risk level: [ ] Low  [ ] Medium  [ ] High
- Rollback plan (if needed):
- Notes:

---

## Post-merge (complete after PR is merged)

> These items are completed after merge so they reference the actual merge commit on `main`.

### Xcode Cloud / TestFlight
- [ ] Xcode Cloud build succeeded for the merge commit on `main`
- [ ] Build processed and visible in TestFlight
- [ ] “What to Test” pasted from `TESTFLIGHT_NOTES.md`
- [ ] Version/build confirmed in TestFlight and in-app

### Tagging (version-only)
- [ ] Tag created and pushed: `v__`
- [ ] Tag points to the shipped merge commit

### Release log
- [ ] PR comment added: `Shipped: v__ (build __)`
