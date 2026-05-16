# Dead / Commented Code Audit

## Summary
- Total findings: 10
- High-confidence cleanup candidates: 5
- Medium-confidence candidates: 3
- Low-confidence / needs review: 2
- Files with most cleanup potential: `Sources/Models/Meso/MesoscaleDiscussion.swift`, `Sources/Models/GeoFeature/WeatherRisk.swift`, `Sources/Models/GeoFeature/RiskProduct.swift`, `Sources/Features/Settings/SettingsView.swift`, `Sources/Features/Map/MapFeatureModel.swift`
- Build/test verification performed: None. Discovery-only audit; no build or test commands were run.

## Recommended Cleanup Order
1. Safe removals
   - `Sources/Features/Diagnostics/CadenceSandboxView.swift`
   - `Sources/Models/GeoFeature/WeatherRisk.swift`
   - `Sources/Models/GeoFeature/RiskProduct.swift`
   - `Sources/Models/Meso/MesoscaleDiscussion.swift`
   - `Tests/UnitTests/NwsProviderSyncTests.swift`
   - `Sources/Features/Map/Picker.swift` demo scaffolding
   - `Sources/Providers/NWS/GridPointProvider.swift` unused cache accessor
2. Human-review removals
   - `Sources/Features/Summary/OutlookView.swift`
   - `Sources/Features/Settings/SettingsView.swift`
3. Deferred / risky areas
   - `Sources/Features/Map/MapFeatureModel.swift` temporary warning injection scaffold

## Findings

### Finding 1: Entire cadence sandbox view is commented out
- Category: `commented_out_code`
- Confidence: `high`
- Risk: `low`
- File: [`Sources/Features/Diagnostics/CadenceSandboxView.swift`](/Users/justin/Code/project-arcus/Sources/Features/Diagnostics/CadenceSandboxView.swift)
- Lines: `10-86`
- Symbol / area: `CadenceSandboxView`
- Evidence: The file contains only commented SwiftUI view code and a commented `#Preview`; there are no live declarations left.
- Why it appears dead or stale: The sandbox was fully disabled and has no references elsewhere in the repo.
- Why it may still matter: It may have been useful for cadence experimentation, so the file could still be informative history.
- Recommendation: Safe removal after a quick reference check.
- Suggested cleanup action: Delete the file once the maintainer confirms the sandbox is no longer needed.
- Verification needed: Search for `CadenceSandboxView` references, then build the app once after deletion.

### Finding 2: Legacy WeatherRisk model is kept only as comments
- Category: `commented_out_code`
- Confidence: `high`
- Risk: `low`
- File: [`Sources/Models/GeoFeature/WeatherRisk.swift`](/Users/justin/Code/project-arcus/Sources/Models/GeoFeature/WeatherRisk.swift)
- Lines: `1-200`
- Symbol / area: `WeatherRisk`, `SevereType`, adapter extensions
- Evidence: The file is entirely commented out, including the enum, helper projections, and adapter extensions.
- Why it appears dead or stale: The file no longer contributes compiled code and appears to be an old UI model replacement.
- Why it may still matter: The commented implementation documents the earlier model shape and could still be useful as reference history.
- Recommendation: Safe removal if the current model stack is authoritative.
- Suggested cleanup action: Delete the file and rely on git history for the old implementation.
- Verification needed: Confirm no docs or code still reference `WeatherRisk` before removing it.

### Finding 3: Legacy RiskProduct / RiskFeature model is kept only as comments
- Category: `commented_out_code`
- Confidence: `high`
- Risk: `low`
- File: [`Sources/Models/GeoFeature/RiskProduct.swift`](/Users/justin/Code/project-arcus/Sources/Models/GeoFeature/RiskProduct.swift)
- Lines: `1-220`
- Symbol / area: `RiskProduct`, `RiskFeature`, key builders, DTO inits
- Evidence: The entire file is commented out, including the SwiftData model, computed projections, and init helpers.
- Why it appears dead or stale: Nothing in the compiled target depends on this file; the newer data model lives elsewhere.
- Why it may still matter: It documents a previous persistence strategy and may be useful if anyone needs to compare schema history.
- Recommendation: Safe removal after a quick reference audit.
- Suggested cleanup action: Delete the file if the old persistence model is truly retired.
- Verification needed: Search for `RiskFeature` and `RiskProduct` references outside this file, then build.

### Finding 4: Old MesoscaleDiscussion model/parser is still parked in the source file
- Category: `commented_out_code`
- Confidence: `high`
- Risk: `low`
- File: [`Sources/Models/Meso/MesoscaleDiscussion.swift`](/Users/justin/Code/project-arcus/Sources/Models/Meso/MesoscaleDiscussion.swift)
- Lines: `133-386`
- Symbol / area: Legacy `MesoscaleDiscussion` model and parser pipeline
- Evidence: Below the active `MD` model, the file contains a fully commented-out `MesoscaleDiscussion` type plus parsing helpers and RSS conversion logic.
- Why it appears dead or stale: The active model is `MD`; the commented parser path is not compiled and does not feed any current code.
- Why it may still matter: This is domain logic, not throwaway UI scaffolding, so deleting it should wait until someone is comfortable losing the old parser reference.
- Recommendation: Safe removal once the maintainer confirms the old parser path is no longer needed.
- Suggested cleanup action: Delete the commented legacy block and keep any historical notes in docs or git history instead.
- Verification needed: Confirm no tests or docs still mention the old `MesoscaleDiscussion` type before removal.

### Finding 5: Old NWS sync tests are commented out
- Category: `commented_out_code`
- Confidence: `high`
- Risk: `low`
- File: [`Tests/UnitTests/NwsProviderSyncTests.swift`](/Users/justin/Code/project-arcus/Tests/UnitTests/NwsProviderSyncTests.swift)
- Lines: `43-69`
- Symbol / area: `NwsProviderSyncTests`
- Evidence: Two test cases are commented out; only the provider factory helper remains live.
- Why it appears dead or stale: The tests are no longer executing, and there are no alternate references to those cases.
- Why it may still matter: They describe historical behavior for old watch-sync semantics, so the intent may still be valuable even if the assertions are not.
- Recommendation: Safe removal if the old sync contract is gone.
- Suggested cleanup action: Delete the commented test cases or rewrite them against the current behavior if the scenarios still matter.
- Verification needed: Run the current NWS-related tests after pruning to make sure coverage has not regressed.

### Finding 6: OutlookView still carries an unused parsing helper and a disabled toolbar path
- Category: `likely_dead_code`
- Confidence: `medium`
- Risk: `low`
- File: [`Sources/Features/Summary/OutlookView.swift`](/Users/justin/Code/project-arcus/Sources/Features/Summary/OutlookView.swift)
- Lines: `12-13, 25-44, 66-88`
- Symbol / area: `dismiss`, `parseOutlookText(_:)`, disabled Done toolbar
- Evidence: The body now renders `Text(outlook.fullText)` directly, while the old formatted-text path and `Done` toolbar remain commented out; `parseOutlookText(_:)` is defined but never called.
- Why it appears dead or stale: Search only finds the helper in this file, and the only active use of `dismiss` was inside the commented toolbar.
- Why it may still matter: If the formatted outlook rendering is coming back, this helper is the obvious starting point.
- Recommendation: Remove the helper and commented toolbar if the plain-text outlook display is final.
- Suggested cleanup action: Delete the dead helper and keep the view minimal.
- Verification needed: Confirm no product requirement still calls for highlighted section headers in the outlook text.

### Finding 7: SettingsView keeps a dormant AI settings branch and unused backing state
- Category: `possibly_dead_code`
- Confidence: `medium`
- Risk: `medium`
- File: [`Sources/Features/Settings/SettingsView.swift`](/Users/justin/Code/project-arcus/Sources/Features/Settings/SettingsView.swift)
- Lines: `12-100, 161-186`
- Symbol / area: `BrevityLevel`, `AudienceLevel`, `aiSummariesEnabled`, `aiShareLocation`, `brevityBinding`, `audienceBinding`
- Evidence: The entire AI summary preferences section is commented out, and the associated enums, AppStorage keys, and bindings only feed that disabled branch.
- Why it appears dead or stale: No live UI uses these values, and repo-wide search does not find other references.
- Why it may still matter: These settings are persisted user preferences; deleting them changes on-disk state and could complicate re-enabling the feature later.
- Recommendation: Review with product before deleting.
- Suggested cleanup action: Remove the dormant AI settings code only if the feature is intentionally retired.
- Verification needed: Check whether any other module reads the `ai*` AppStorage keys before pruning them.

### Finding 8: Temporary warning injection scaffold is effectively dead
- Category: `likely_dead_code`
- Confidence: `medium`
- Risk: `medium`
- File: [`Sources/Features/Map/MapFeatureModel.swift`](/Users/justin/Code/project-arcus/Sources/Features/Map/MapFeatureModel.swift)
- Lines: `20-26, 264-322`
- Symbol / area: `shouldInjectTemporaryWarningSamples`, `temporaryWarningSamples`, `warningSample`
- Evidence: The debug toggle is hardcoded to `false`, and the only callers for the sample generators sit behind that permanently false guard.
- Why it appears dead or stale: The sample injection path cannot run as written, so the helper methods are dead at runtime.
- Why it may still matter: This is map warning data, which affects UI test fixtures, debug inspection, and overlay behavior if the guard is ever re-enabled.
- Recommendation: Deferred until someone confirms the samples are not used for manual map verification.
- Suggested cleanup action: Remove the sample injection helpers if no debug or UI-test path depends on them.
- Verification needed: Verify no tests or debug workflows rely on injected warning samples.

### Finding 9: Map layer demo view is unused scaffolding
- Category: `possibly_dead_code`
- Confidence: `low`
- Risk: `low`
- File: [`Sources/Features/Map/Picker.swift`](/Users/justin/Code/project-arcus/Sources/Features/Map/Picker.swift)
- Lines: `308-341`
- Symbol / area: `MapWithLayerPickerDemo`
- Evidence: Repo search finds no reference to `MapWithLayerPickerDemo`; the app uses `LayerPickerSheet` directly.
- Why it appears dead or stale: The block is clearly labeled as an example integration and is not wired into any production surface.
- Why it may still matter: It can be useful as a manual demo or scratchpad when testing picker behavior.
- Recommendation: Safe to remove if nobody is using it for local experimentation.
- Suggested cleanup action: Delete the demo view once its value as a manual harness is no longer needed.
- Verification needed: Confirm no previews or local notes depend on the demo before deleting it.

### Finding 10: Grid point provider exposes an unused cache accessor
- Category: `possibly_dead_code`
- Confidence: `low`
- Risk: `low`
- File: [`Sources/Providers/NWS/GridPointProvider.swift`](/Users/justin/Code/project-arcus/Sources/Providers/NWS/GridPointProvider.swift)
- Lines: `13-17, 64-66`
- Symbol / area: `currentGridPointMetadata()`
- Evidence: Repo search finds only the declaration; nothing else calls the accessor.
- Why it appears dead or stale: The actor already publishes the snapshot through its main resolve path, so this accessor looks like leftover scaffolding.
- Why it may still matter: It could still be a harmless diagnostic hook for future async observation work.
- Recommendation: Safe to remove only after checking whether any external debug harness depends on it.
- Suggested cleanup action: Delete the accessor if no code outside the repo or hidden test harness uses it.
- Verification needed: Search for any indirect usage in tests or tooling before deleting it.

## Commented-Out Code Inventory

| File | Lines | Description | Confidence | Risk | Recommendation |
|---|---:|---|---|---|---|
| [`Sources/Features/Diagnostics/CadenceSandboxView.swift`](/Users/justin/Code/project-arcus/Sources/Features/Diagnostics/CadenceSandboxView.swift) | 10-86 | Entire SwiftUI sandbox view and preview are commented out. | high | low | Delete if the sandbox is retired. |
| [`Sources/Models/GeoFeature/WeatherRisk.swift`](/Users/justin/Code/project-arcus/Sources/Models/GeoFeature/WeatherRisk.swift) | 13-200 | Obsolete `WeatherRisk` model, helpers, and adapters. | high | low | Delete after checking git history. |
| [`Sources/Models/GeoFeature/RiskProduct.swift`](/Users/justin/Code/project-arcus/Sources/Models/GeoFeature/RiskProduct.swift) | 13-220 | Obsolete `RiskFeature` SwiftData model and key builders. | high | low | Delete after reference search. |
| [`Sources/Models/Meso/MesoscaleDiscussion.swift`](/Users/justin/Code/project-arcus/Sources/Models/Meso/MesoscaleDiscussion.swift) | 133-386 | Full legacy `MesoscaleDiscussion` model and parser pipeline. | high | low | Delete if the old parser is no longer needed. |
| [`Tests/UnitTests/NwsProviderSyncTests.swift`](/Users/justin/Code/project-arcus/Tests/UnitTests/NwsProviderSyncTests.swift) | 43-69 | Two old NWS sync tests are commented out. | high | low | Remove or rewrite for current behavior. |
| [`Sources/Features/Settings/SettingsView.swift`](/Users/justin/Code/project-arcus/Sources/Features/Settings/SettingsView.swift) | 161-186 | Entire AI summary preferences section is commented out. | medium | medium | Decide whether the feature is retired. |
| [`Sources/Features/Summary/OutlookView.swift`](/Users/justin/Code/project-arcus/Sources/Features/Summary/OutlookView.swift) | 25-44 | Commented `Text(parseOutlookText(...))` and Done toolbar. | medium | low | Delete if plain-text rendering is final. |
| [`Sources/Features/Map/MapFeatureModel.swift`](/Users/justin/Code/project-arcus/Sources/Features/Map/MapFeatureModel.swift) | 21-25 | Commented debug guard for temporary warning samples. | medium | medium | Remove with the sample helpers if unused. |
| [`Sources/Features/Badges/FireWeatherRailView.swift`](/Users/justin/Code/project-arcus/Sources/Features/Badges/FireWeatherRailView.swift) | 65-77 | Commented `fireRiskState` helper. | medium | low | Delete if the caller now owns fire-risk derivation. |
| [`Sources/Utilities/Core/SkyAwareErrors.swift`](/Users/justin/Code/project-arcus/Sources/Utilities/Core/SkyAwareErrors.swift) | 56-70 | Commented `DownloaderError` enum and localized error conformance. | high | low | Delete unless the old downloader path returns. |
| [`Resources/PreviewContent/PreviewContainer.swift`](/Users/justin/Code/project-arcus/Resources/PreviewContent/PreviewContainer.swift) | 19, 37-38 | Commented preview provider property and mock location setup. | medium | low | Delete if preview scaffolding is complete. |
| [`Sources/Models/Convective/ConvectiveOutlookDTO.swift`](/Users/justin/Code/project-arcus/Sources/Models/Convective/ConvectiveOutlookDTO.swift) | 42-68 | Commented `String.truncateToSentences` extension. | medium | low | Delete if sentence truncation is unused. |
| [`Sources/Policies/RefreshPolicy.swift`](/Users/justin/Code/project-arcus/Sources/Policies/RefreshPolicy.swift) | 43-52 | Commented top-of-hour scheduling algorithm. | medium | low | Delete if the jittered cadence is final. |
| [`Sources/Infrastructure/Parsing/Regex/ConvectiveParser.swift`](/Users/justin/Code/project-arcus/Sources/Infrastructure/Parsing/Regex/ConvectiveParser.swift) | 263-294 | Commented alternate regex and risk extraction helper. | medium | low | Delete if the newer parser path is authoritative. |
| [`Sources/Infrastructure/Parsing/Regex/WatchParser.swift`](/Users/justin/Code/project-arcus/Sources/Infrastructure/Parsing/Regex/WatchParser.swift) | 27-30 | Commented day-field extraction for valid-time parsing. | medium | low | Delete if day tokens are no longer needed. |
| [`Sources/Infrastructure/Parsing/NWS/NWSGridPointJson.swift`](/Users/justin/Code/project-arcus/Sources/Infrastructure/Parsing/NWS/NWSGridPointJson.swift) | 12, 19 | Commented `@context` decoding fields. | medium | low | Delete if the response shape is settled. |
| [`Sources/Notifications/Meso/MesoContext.swift`](/Users/justin/Code/project-arcus/Sources/Notifications/Meso/MesoContext.swift) | 24-25 | Commented `quietHours` and duplicate `placeMark` notes. | medium | low | Delete if context shape is final. |
| [`Sources/Notifications/Meso/MesoGate.swift`](/Users/justin/Code/project-arcus/Sources/Notifications/Meso/MesoGate.swift) | 21-24 | Commented `localDay` gate branch. | medium | low | Delete if the gate keys only on meso ID now. |
| [`Sources/Notifications/Morning/MorningComposer.swift`](/Users/justin/Code/project-arcus/Sources/Notifications/Morning/MorningComposer.swift) | 17 | Commented `localDay` extraction. | medium | low | Delete if that payload field is gone. |
| [`Sources/Interfaces/SPC/SpcFreshnessPublishing.swift`](/Users/justin/Code/project-arcus/Sources/Interfaces/SPC/SpcFreshnessPublishing.swift) | 26-28 | Commented future `issueUpdates` overloads. | medium | low | Delete if push-based freshness is not planned. |

## Likely Dead Symbols

| Symbol | File | Evidence | Confidence | Risk | Recommendation |
|---|---|---|---|---|---|
| `parseOutlookText(_:)` | [`Sources/Features/Summary/OutlookView.swift`](/Users/justin/Code/project-arcus/Sources/Features/Summary/OutlookView.swift) | Search finds only the declaration; the only call site in the file is commented out. | medium | low | Remove if the formatted outlook path will not return. |
| `BrevityLevel`, `AudienceLevel`, `aiSummariesEnabled`, `aiShareLocation`, `brevityBinding`, `audienceBinding` | [`Sources/Features/Settings/SettingsView.swift`](/Users/justin/Code/project-arcus/Sources/Features/Settings/SettingsView.swift) | These types and bindings only feed the commented AI settings section. | medium | medium | Remove only after product confirms AI settings are retired. |
| `temporaryWarningSamples(around:)`, `warningSample(id:event:center:)` | [`Sources/Features/Map/MapFeatureModel.swift`](/Users/justin/Code/project-arcus/Sources/Features/Map/MapFeatureModel.swift) | The only caller sits behind a `false` guard; no other references exist. | medium | medium | Remove if debug warning injection is no longer needed. |
| `MapWithLayerPickerDemo` | [`Sources/Features/Map/Picker.swift`](/Users/justin/Code/project-arcus/Sources/Features/Map/Picker.swift) | Repo search finds only the type definition; production code uses `LayerPickerSheet` directly. | low | low | Safe to delete after confirming no local demo usage. |
| `currentGridPointMetadata()` | [`Sources/Providers/NWS/GridPointProvider.swift`](/Users/justin/Code/project-arcus/Sources/Providers/NWS/GridPointProvider.swift) | Repo search finds only the method declaration. | low | low | Remove if no tooling or tests need the cached snapshot. |

## Stale TODO / FIXME / Notes

| File | Lines | Text | Assessment | Recommendation |
|---|---:|---|---|---|
| None found | - | No clearly stale TODO/FIXME notes were strong enough to classify as obsolete. | The remaining notes read like active backlog or feature placeholders. | Leave them in place until the product decides. |

## Build / Script / Config Artifacts

| File | Lines | Artifact | Assessment | Recommendation |
|---|---:|---|---|---|
| None found | - | No obvious obsolete build settings, dead scripts, or config leftovers stood out in the scanned project and config files. | Nothing suspicious enough to flag. | No action. |

## Do Not Remove Yet
- `Sources/Features/Map/MapFeatureModel.swift` temporary warning sample helpers: they are dead as written, but they touch map overlays and UI-test/debug behavior.
- `Sources/Features/Settings/SettingsView.swift` AI settings branch: those keys are persisted, so deletion changes user defaults and future reactivation.
- `Sources/Features/Summary/OutlookView.swift` parsing helper: the helper is unused now, but the formatted outlook path may still be an intentional product option.

## Follow-up Cleanup Plan
1. Delete the fully commented-out sandbox and legacy model files once reference searches come back clean.
2. Remove the commented NWS sync tests and replace them with current behavioral coverage if the scenarios still matter.
3. Prune the dead `OutlookView` helper and commented toolbar, then confirm the plain-text outlook rendering is still the intended UX.
4. Decide whether the AI settings branch in `SettingsView` is retired; if yes, remove the dormant storage and bindings together.
5. Remove the map warning sample scaffold only after confirming no debug or UI-test workflow depends on it.
6. Drop the unused `MapWithLayerPickerDemo` and `currentGridPointMetadata()` accessor if no local tooling still needs them.
