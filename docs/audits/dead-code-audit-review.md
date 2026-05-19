# Dead Code Audit Review

## Review Summary
- Original audit reviewed: `docs/audits/dead-code-audit.md`
- Total findings reviewed: 10 numbered findings, plus the supporting inventory/symbol tables
- Findings confirmed accurate: 6
- Findings partially confirmed: 4
- Findings disputed: 0
- Findings needing human review: 4
- New findings added: 2
- Build/test verification performed: None. This was a source/reference review only; no source cleanup was performed.

## Bottom Line
The original audit is useful but needs corrections before cleanup. The simple commented-out files and unreferenced demo/accessor findings are actionable, but several items are domain logic, disabled tests, or dormant product settings where deletion should be explicit maintainer/product intent, not janitorial enthusiasm with a broom.

## Highest-Confidence Cleanup Candidates

| Original Finding | File | Reason | Risk | Required Verification |
|---|---|---|---|---|
| Finding 1: Entire cadence sandbox view is commented out | `Sources/Features/Diagnostics/CadenceSandboxView.swift` | File has only `import SwiftUI` plus commented view/preview. Repo search finds no live references. | Low | Remove file, confirm synced-folder behavior, build app. |
| Finding 2: Legacy WeatherRisk model is kept only as comments | `Sources/Models/GeoFeature/WeatherRisk.swift` | Entire file is commented; no live symbol references outside the file. | Low | Remove file, build app. |
| Finding 3: Legacy RiskProduct / RiskFeature model is kept only as comments | `Sources/Models/GeoFeature/RiskProduct.swift` | Entire file is commented; only unrelated logger category text contains `riskProduct`. | Low | Remove file, build app. |
| Finding 5: Old NWS sync tests are commented out | `Tests/UnitTests/NwsProviderSyncTests.swift` | Disabled test methods are non-executing; the remaining helper/test doubles are also unused outside that file. | Low | Prefer deleting the obsolete test file, then run unit tests or at least the test target build. |
| Finding 9: Map layer demo view is unused scaffolding | `Sources/Features/Map/Picker.swift` | `MapWithLayerPickerDemo` is standalone example code; no production, test, or preview references found. | Low | Remove demo type, build app/previews touching `LayerPickerSheet`. |
| Finding 10: Grid point provider exposes an unused cache accessor | `Sources/Providers/NWS/GridPointProvider.swift` | `currentGridPointMetadata()` has no repo references and is internal to the app module. | Low | Remove accessor, build app/tests. |

## Findings That Should Not Be Removed Yet

| Original Finding | File | Concern | What to verify next |
|---|---|---|---|
| Finding 4: Old MesoscaleDiscussion model/parser is still parked in the source file | `Sources/Models/Meso/MesoscaleDiscussion.swift` | The block is non-compiling commented code, but it contains parser/domain logic and old type references also appear in commented preview samples. | Confirm the active `MDParser`/`MdDTO` path fully replaces the old parser reference before deleting. |
| Finding 6: OutlookView still carries an unused parsing helper and disabled toolbar path | `Sources/Features/Summary/OutlookView.swift` | `parseOutlookText(_:)` is unused, but it represents a visible formatting choice for SPC outlook text. | Product/UX should confirm plain text is final. |
| Finding 7: SettingsView keeps a dormant AI settings branch and unused backing state | `Sources/Features/Settings/SettingsView.swift` | The code is unused, but the `@AppStorage` keys are persisted product settings. | Product should confirm AI summaries are retired or intentionally deferred. |
| Finding 8: Temporary warning injection scaffold is effectively dead | `Sources/Features/Map/MapFeatureModel.swift` | Runtime path is disabled by `false`, but the helpers are a map overlay debug fixture. | Maintainer should confirm no manual map/debug workflow relies on flipping the guard locally. |

## Disputed Findings

None. The audit did not produce a clear false positive among the 10 numbered findings, but several classifications were too optimistic.

## Corrected Findings

### Corrected Finding 1: Old MesoscaleDiscussion model/parser is still parked in the source file
- File: `Sources/Models/Meso/MesoscaleDiscussion.swift`
- Original classification: `commented_out_code`
- Corrected classification: `commented_out_code`, human-approved cleanup
- Original confidence/risk: high / low
- Corrected confidence/risk: high / medium
- Evidence: Lines 133-386 are fully commented, but they include parser logic, watch probability modeling, and RSS conversion. `Resources/PreviewContent/MesoDiscussionSamples.swift` also has commented `MesoscaleDiscussion` sample blocks.
- Recommendation: Do not batch this with trivial comment deletion. Delete only after confirming the active `MDParser` and sample DTO path are authoritative.

### Corrected Finding 2: Old NWS sync tests are commented out
- File: `Tests/UnitTests/NwsProviderSyncTests.swift`
- Original classification: `commented_out_code`
- Corrected classification: `commented_out_code` plus unused test scaffolding
- Original confidence/risk: high / low
- Corrected confidence/risk: high / low
- Evidence: Lines 43-69 are commented tests. `CountingNwsClient`, `StubGeocoder`, and `makeProvider(client:)` remain live but are not referenced by active tests.
- Recommendation: Remove the obsolete test file or rewrite the scenarios against current Arcus/NWS metadata behavior. Removing only the comments leaves pointless compiled scaffolding behind.

### Corrected Finding 3: OutlookView unused parsing helper
- File: `Sources/Features/Summary/OutlookView.swift`
- Original classification: `likely_dead_code`
- Corrected classification: `likely_dead_code`, UX-dependent
- Original confidence/risk: medium / low
- Corrected confidence/risk: high / low-medium
- Evidence: `parseOutlookText(_:)` is declared at lines 66-88; the only call is commented at line 25. The `dismiss` environment value is only used in the commented toolbar.
- Recommendation: Remove after confirming the product no longer wants highlighted SPC section headers.

### Corrected Finding 4: SettingsView dormant AI settings
- File: `Sources/Features/Settings/SettingsView.swift`
- Original classification: `possibly_dead_code`
- Corrected classification: `dormant_feature_code`
- Original confidence/risk: medium / medium
- Corrected confidence/risk: high / medium
- Evidence: Repo search found the AI enums, storage keys, and bindings only in `SettingsView`; the entire settings UI branch is commented.
- Recommendation: Human/product review. If retired, remove the enums, storage wrappers, bindings, and commented section together.

### Corrected Finding 5: Temporary warning injection scaffold
- File: `Sources/Features/Map/MapFeatureModel.swift`
- Original classification: `likely_dead_code`
- Corrected classification: `disabled_debug_scaffold`
- Original confidence/risk: medium / medium
- Corrected confidence/risk: high / medium
- Evidence: `shouldInjectTemporaryWarningSamples` always returns `false`; sample helpers are only reached through that guard. The live reload path still calls `injectTemporaryWarningSamples(into:)`.
- Recommendation: Defer unless the maintainer confirms this debug fixture is no longer useful for map overlay validation.

### Corrected Finding 6: Map layer demo view
- File: `Sources/Features/Map/Picker.swift`
- Original classification: `possibly_dead_code`
- Corrected classification: `unused_demo_scaffolding`
- Original confidence/risk: low / low
- Corrected confidence/risk: high / low
- Evidence: `MapWithLayerPickerDemo` has no repo references and is not used by any preview.
- Recommendation: Safe mechanical cleanup.

### Corrected Finding 7: Grid point provider cache accessor
- File: `Sources/Providers/NWS/GridPointProvider.swift`
- Original classification: `possibly_dead_code`
- Corrected classification: `unused_internal_accessor`
- Original confidence/risk: low / low
- Corrected confidence/risk: high / low
- Evidence: `currentGridPointMetadata()` has no repo references. The actor is internal; no package/public API concern was found.
- Recommendation: Safe mechanical cleanup.

## Confirmed Findings

| Finding | File | Confidence | Risk | Review note |
|---|---|---|---|---|
| Finding 1 | `Sources/Features/Diagnostics/CadenceSandboxView.swift` | High | Low | Line range 10-86 is accurate; no live references found. |
| Finding 2 | `Sources/Models/GeoFeature/WeatherRisk.swift` | High | Low | File is entirely commented; line range 1-200 is accurate. |
| Finding 3 | `Sources/Models/GeoFeature/RiskProduct.swift` | High | Low | File is entirely commented; line range 1-220 is accurate. |
| Finding 4 | `Sources/Models/Meso/MesoscaleDiscussion.swift` | High | Medium | Accurate dead-code claim; risk should be higher due parser/domain content. |
| Finding 5 | `Tests/UnitTests/NwsProviderSyncTests.swift` | High | Low | Commented test lines are accurate; remaining live test scaffolding also appears unused. |
| Finding 6 | `Sources/Features/Summary/OutlookView.swift` | High | Low-medium | Unused helper claim is accurate; line range includes `dynamicTypeSize`, which is live. |
| Finding 7 | `Sources/Features/Settings/SettingsView.swift` | High | Medium | No external references to AI storage keys or bindings found. |
| Finding 8 | `Sources/Features/Map/MapFeatureModel.swift` | High | Medium | Disabled by hardcoded `false`; treat as debug scaffold, not ordinary dead code. |
| Finding 9 | `Sources/Features/Map/Picker.swift` | High | Low | Demo view is unreferenced and not previewed. |
| Finding 10 | `Sources/Providers/NWS/GridPointProvider.swift` | High | Low | Internal accessor is unreferenced. |

## Missing Findings

### New Finding 1: Deprecated convective parser stack is unused
- Category: `likely_dead_code`
- Confidence: high
- Risk: medium
- File: `Sources/Infrastructure/Parsing/Regex/ConvectiveParser.swift`, `Sources/Models/Convective/ConvectiveOutlookDTO.swift`
- Lines: `ConvectiveParser.swift` 10-201 and 225-295; `ConvectiveOutlookDTO.swift` 71-97
- Evidence: `convictParser` and `ConvectiveParser` are deprecated in favor of `OutlookParser`. Repo search found no production/test references to either deprecated parser. `coDTO` is only used by the deprecated parser stack.
- Recommendation: Human-approved cleanup. Remove the deprecated parser stack and legacy `coDTO` together if the current `OutlookParser` coverage is considered sufficient.
- Verification needed: Run convective outlook parser/repo tests after removal.

### New Finding 2: Old NWS watch DTO/parser path appears production-unused
- Category: `likely_dead_code`
- Confidence: medium
- Risk: medium
- File: `Sources/Infrastructure/Parsing/NWS/NWSWatchJson.swift`, `Sources/Infrastructure/Parsing/Regex/WatchParser.swift`, `Tests/UnitTests/WatchParserTests.swift`
- Lines: `NWSWatchJson.swift` 12-162; `WatchParser.swift` 10-55; `WatchParserTests.swift` 5-171
- Evidence: `NWSWatchJson` types have no repo references outside their own file. `WatchParser` is referenced only by `WatchParserTests`. Current app docs and code point to Arcus as the active alert/watch source of truth.
- Recommendation: Defer to the Arcus migration owner. This is probably retired NWS-watch-era code, but active tests mean cleanup should be deliberate.
- Verification needed: Confirm no fallback/debug path still decodes NWS watch JSON, then remove or replace tests accordingly.

## Cleanup Recommendation

### Batch 1: Safe mechanical cleanup
- Delete fully commented files: `CadenceSandboxView.swift`, `WeatherRisk.swift`, `RiskProduct.swift`.
- Remove `MapWithLayerPickerDemo`.
- Remove `currentGridPointMetadata()`.
- Delete or rewrite `NwsProviderSyncTests.swift` as a focused test cleanup, not just comment pruning.

### Batch 2: Human-approved cleanup
- Remove the legacy commented `MesoscaleDiscussion` parser/model block after confirming the active MD parser path fully supersedes it.
- Remove `OutlookView.parseOutlookText(_:)` and disabled toolbar after confirming plain-text outlook rendering is final.
- Remove dormant AI settings state after product confirms the feature is retired.
- Remove deprecated `ConvectiveParser`/`convictParser`/`coDTO` if `OutlookParser` is authoritative.
- Decide whether old `NWSWatchJson`/`WatchParser` code is still needed during the Arcus migration.

### Batch 3: Defer
- `MapFeatureModel` temporary warning samples until debug/manual map validation needs are settled.
- Small parser/API comment fragments in the inventory unless touched nearby; they are low-value churn by themselves.

## Review Notes
- The original audit was strongest on fully commented files and weakest where code was dormant feature/product logic.
- Line numbers were mostly accurate. The notable loose range is `OutlookView` lines 12-13: `dismiss` is unused, but `dynamicTypeSize` is live.
- The NWS-to-Arcus migration needs a dedicated follow-up audit. There is more old NWS watch-era code than the first audit captured, and some of it is protected only by tests for behavior the app may no longer use.
- Existing stale docs can mislead cleanup. `docs/LifecycleInvestigationNotes.md` still mentions `placeholderAlertsContent`/`PlaceholderAlertSection`, but those symbols are no longer present in `ActiveAlertSummaryView.swift`.
- No build or tests were run. Confidence is based on direct file inspection and repo-wide `rg` reference searches.
