# SkyAware Design Documentation Consolidation Audit

- **Audit date:** 2026-10-08
- **Repository HEAD examined:** `791c94b`
- **Scope:** Three historical source documents and nine replacement canonical documents, using the current branch and working tree.
- **Disposition:** Audit findings for human review. No recommended corrections have been implemented.

Line references describe the files as examined during the audit. They may shift after subsequent edits.

The original documents are retired from the active tree. Audit source material remains available at the exact audited snapshot `791c94b`: [North Star Spec](https://github.com/justinrooks/project-arcus/blob/791c94b14db4390b7766080efa8164356dd395ad/docs/SkyAware%20North%20Star%20Spec.md), [Branding and Design Guide](https://github.com/justinrooks/project-arcus/blob/791c94b14db4390b7766080efa8164356dd395ad/docs/SkyAware%20Branding%20and%20Design%20Guide.md), and [Visual Implementation Contract](https://github.com/justinrooks/project-arcus/blob/791c94b14db4390b7766080efa8164356dd395ad/docs/design/visual-contract.md). Findings and migration-search results below describe the original audit, not the post-correction repository state.

## A. Executive Assessment

**Recommendation: Requires material corrections before retiring the originals.** The corrections are bounded; the nine-document structure is sound and does not need reorganizing.

The migration is **substantially complete**. The new documents preserve the major product, meteorological, visual, navigation, WidgetKit, state, accessibility, and review decisions. All decisions explicitly listed in the requested approved-decision checklist are represented.

However, retiring the originals now would lose some established knowledge:

- Conditional-intensity explanations retain the supported labels and eligibility rules, but weaken the original level-specific explanatory meaning and omit explicit limits on what intensity implies.
- Watch/detail presentation rules and the common outlook/watch/mesoscale detail structure have no substantive replacement.
- Some explicit refresh-status placement and marketing-art direction have become general principles rather than retained requirements.
- The exact Today section composition is independently specified in both Product and Today.
- Repository instructions still route design work to the retiring North Star.

**No Critical finding was identified.** No direct contradiction was found that changes warning precedence, intensity eligibility, accepted-state correctness, or the approved redesign. Ownership is generally clear, with one material duplication and several small clarity gaps.

### Audit evidence and limits

All three originals and all nine replacements were read completely from the working tree. All originals were present; no historical substitution was necessary. All targets contain substantive content. The audit checked 67 relative Markdown links, referenced local paths, and repository references to the retiring documents. Targeted source checks covered Map layer names, WidgetKit families/routing, refresh-status presentation, and alert-detail chips.

The audit did not modify files or run builds or tests. This report was subsequently saved at the user's request; source documents, code, tests, and configuration remain unchanged by the audit and report-writing work.

## B. Migration Coverage

“Preserved” includes requirements transferred to the appropriate canonical owner. “Partial” identifies meaningful detail that is weaker or absent; it does not mean the entire section failed migration.

### Original North Star — all substantive sections considered

Source: `docs/SkyAware North Star Spec.md`.

| Original section and lines | Canonical destination | Assessment |
| --- | --- | --- |
| Purpose and operating rules, 25–52 | Product §§1–4, 22–23; Design README §§2–4, 6 | Preserved. Authority is now assigned by responsibility. |
| Brand traits, premium quality, voice, vocabulary, 54–130 | Brand §§1–7; Product §4 | Preserved. Canonical labels and status language survive. |
| Native behavior, hierarchy, surfaces, typography, 132–180 | Foundations §§2–5, 8–10, 12–13 | Preserved with intentional newer surface rules. |
| Semantic colors and icons, 181–217 | Foundations §§6, 11; relevant surface specifications | Preserved. Storm ladder, hazard identities, distinct fire/mesoscale meaning, and neutral freshness remain. |
| Motion, 219–242 | Foundations §14; States §§17, 24; Today §7.8 | Preserved or intentionally superseded. Continuous awareness-gradient motion is explicitly rejected. |
| Summary composition and Current Conditions, 244–285 | Today §§2–3; Product §§6–7 | Preserved, but exact composition is duplicated between Product and Today. |
| Hero precedence and supporting risks, 286–312 | Product §§8–9; Today §§4–6, 9–11 | Preserved, with stronger vertical-stack and affordance rules. |
| Local intensity meaning, 314–340 | Product §10; Today §12; Map §§10, 13 | **Partial.** Labels, eligibility, omission policy, geometry derivation, and presentation ownership survive. Level-specific explanation is less complete. |
| Storm Setup and Location Reliability, 342–363 | Product §§13–14; Today §§16–17; Brand §§5, 10 | Preserved. Conditional placement, status states, provenance, and user agency remain. |
| Fire supporting row, 365–369 | Product §9.3; Today §11.4 | Preserved. |
| Atmospheric rail, 371–380 | Product §12; Today §15 | Intentionally superseded by five peer measurements and Storm Setup ownership of dew point. |
| Local Alerts, 382–388 | Product §11; Today §14 | Preserved. |
| Watch Detail and shared product-detail structure, 390–411 | Product §§11.2, 15; Brand §8 | **Partial.** Source information survives; the presentation contract does not. |
| Map, selector, legend, hatching, 413–440 | Map §§1, 6, 10–15 | Preserved. |
| Loading/resolving, 442–459 | Product §18; States §§3–9; Brand §7 | Core behavior preserved; explicit cached-refresh header placement is weakened. |
| Notifications, 461–484 | Brand §9; Product §19 | Preserved and better qualified against unjustified emergency instructions. |
| Asset generation, 486–533 | Brand §§11–14; Foundations; Visual Review §4 | **Partial.** Authenticity and semantic constraints survive; some established artistic direction is absent. |
| Widget semantic contract, 534–540 | Widgets §§7–9, 17, 20–22 | Preserved. Complete scoped meaning remains the priority. |
| Map/data visual generation, 542–551 | Map §§8–13; Visual Review §10 | Preserved. |
| Content/prompt generation, 553–570 | Brand §§4–7, 14–17; Design README §§3, 6–7 | Substantive guardrails preserved; prompt mechanics need not be reproduced verbatim. |
| Open tuning and review, 572–593 | Map §10.6; Visual Review §§17, 21–23 | Preserved in principle. Historical tuning status is appropriately omitted. |

### Original Branding and Design Guide — all 32 numbered sections considered

Source: `docs/SkyAware Branding and Design Guide.md`.

| Original sections and lines | Canonical destination | Assessment |
| --- | --- | --- |
| Purpose, guide map, decision status, 10–83 | Design README §§2–4 | Navigation and authority replaced appropriately; old guide-navigation machinery is historical. |
| §§1–2: identity, voice, positioning, 88–167 | Product §§1–4; Brand §§1–4 | Preserved. |
| §3: inspiration apps, 169–204 | Brand §12 | Preserved, including selective CARROT influence and exclusions. |
| §§4–6: visual quality, native behavior, shape, typography, 206–321 | Foundations §§1–5, 8–10, 12–13 | Preserved. The 30-point radius is retained as historical baseline rather than a universal instruction. |
| §§7–8: color and iconography, 323–407 | Foundations §§6, 11 | Preserved; obsolete safety wording and uniform gradient recipes are superseded. |
| §§9–12: Summary, header, awareness, supporting risks, 412–523 | Product §§6–9; Today §§2–11 | Preserved. |
| §13: atmospheric rail and conditional sections, 525–585 | Product §§12–14; Today §§15–17 | Atmospheric metric hierarchy intentionally superseded; conditional sections preserved. |
| §14: Local Alerts, 587–610 | Product §11; Today §14 | Preserved. |
| §§15–16: Watch Detail and common detail structure, 612–652 | Product §§11.2, 15; Brand §8 | **Partial.** Compact chips versus long textual metadata and summary-first detail structure are missing. |
| §§17–18: Map and legend, 654–716 | Map §§1, 6, 11–15 | Preserved, with more explicit adaptive presentation. |
| §19: conditional intensity, 718–743 | Product §10; Today §12; Map §§10, 13 | **Partial.** Core meaning survives; explicit “not storm mode, spatial coverage, or a broader event” guardrail does not. |
| §20: hatching, 745–767 | Map §10 | Preserved. Screen-space texture, constant geometry, and independent dark contrast remain. |
| §§21–22: initial resolving and cached-first presentation, 772–876 | Product §18; States §§3–9, 17; Brand §7 | Core behavior preserved. Some specific presentation guidance is weaker; routine blur/animation recipes are superseded by quiet refresh. |
| §§23–24: notifications and writing, 878–959 | Brand §§6–9 | Preserved, including lifecycle distinctions, tone inputs, and true ellipsis. |
| §§25–26: motion and controls, 961–1007 | Foundations §§12–14; States §24; Today §9; Map §6 | Preserved or intentionally superseded. |
| §§27–29: reusable patterns, anti-patterns, messaging, 1009–1053 | Foundations; Today; States; Brand §7 | Preserved in the relevant owners. |
| §§30–32: quality, tensions, review, intended use, 1058–1105 | Design README; Visual Review; Brand §17 | Preserved. Historical discussion and unresolved tuning labels need not remain canonical. |

### Original Visual Implementation Contract — all 26 numbered sections considered

Source: `docs/design/visual-contract.md`.

| Original sections and lines | Canonical destination | Assessment |
| --- | --- | --- |
| §§1–3: purpose, character, priorities, 8–75 | Product §§1–4; Design README §§1, 4 | Preserved; old document-ranking order is appropriately replaced by responsibility-based authority. |
| §§4–6: native SwiftUI, visual layers, Glass, 79–226 | Foundations §§2, 12–13 | Preserved, including simplification and no custom Glass framework. |
| §§7–8: hierarchy and warning hero, 230–278 | Product §§8, 11.1; Today §§4, 10 | Preserved. Emergency instructions remain source-dependent. |
| §§9–12: color, typography, icons, shape/density, 282–397 | Foundations §§6, 8–11 | Preserved. |
| §13 and §13.1: appearances and light grammar, 401–567 | Foundations §§3–5, 8; Today §20; Map §18; Widgets §4; Visual Review | Preserved, including sRGB, exact neutral values, borders, no ordinary shadow, Map shadow exception, and shared-consumer caution. Wave-specific implementation inventory is historical. |
| §14: atmospheric ingredient emphasis, 571–592 | Product §12; Today §15 | Intentionally superseded by peer measurements. |
| §15: supporting risk presentation, 596–612 | Today §§5–12 | Preserved and refined by the approved four-card treatment. |
| §16: Map, 616–644 | Map | Preserved. |
| §17: widgets, 648–677 | Widgets; Product §17 | Preserved, including the visible and accessible timestamp restriction. |
| §§18–20: motion, accessibility, state/behavior, 681–742 | States; Foundations §14 | Preserved. |
| §21: code simplification, 746–768 | Design README §6; Foundations §16; surface boundaries | Preserved. |
| §§22–23: references and generated mockups, 772–826 | Design README §7; Visual Review §4 | Preserved. Temporary gallery structure and per-issue mechanics are historical. |
| §24: previews and verification, 830–850 | Visual Review §§2, 12–16; surface validation sections | Preserved. |
| §25: agent guidance, 854–873 | Design README §6; surface implementation boundaries | Preserved. |
| §26: success, 877–896 | Product §24; Design README §10; surface success sections | Preserved. |

## C. Approved Decision Coverage

References identify the principal owner or the most specific statement. Grouped rows explicitly cover related decisions from the requested checklist.

| Approved decisions | Status | Evidence |
| --- | --- | --- |
| Hyper-local severe-weather assistant; awareness question; distinct from generic weather | Preserved | `docs/product/north-star.md:38`, `:44`, `:59` |
| Meteorological correctness and trust first; premium craftsmanship and accessibility | Preserved | `docs/product/north-star.md:109`, `:129` |
| Calm retains purposeful color | Preserved | `docs/brand/brand-and-voice.md:775`; `docs/design/foundations.md:65` |
| Compact open Current Conditions; Today's Awareness owns primary hierarchy | Preserved | `docs/design/today.md:77`, `:148` |
| One strongest-signal hero; Storm/Severe/Fire remain visible | Preserved | `docs/product/north-star.md:295`; `docs/design/today.md:197`, `:208` |
| Supporting cards full-width and vertical on every iPhone, including Pro Max | Preserved | `docs/design/today.md:283`, `:295`, `:1384` |
| Coordinated four-card language; narrow rails, gradients, symbols, honest chevrons | Preserved | `docs/design/today.md:235`, `:475`, `:519` |
| Quiet emerald/jade; smooth blend into opaque neutral base; static gradients | Preserved | `docs/design/today.md:339`, `:356`, `:379`, `:463` |
| No destination means no implied navigation; full-card native action | Preserved | `docs/design/today.md:509`, `:535`; `docs/design/foundations.md:842` |
| External Local Alerts/Atmospheric headings; embedded Storm Setup/Outlook headings | Preserved | `docs/design/today.md:791`, `:807` |
| Five atmospheric peers; ordinary 3+2 layout | Preserved | `docs/design/today.md:946`, `:960` |
| WeatherKit pressure trend; dew point in Fuel & Instability | Preserved | `docs/product/north-star.md:574`, `:590`; `docs/design/today.md:996`, `:1018` |
| Warning/watch precedence; distinct Storm/Severe/Fire domains | Preserved | `docs/product/north-star.md:303`, `:366`, `:495` |
| Probability distinct from intensity; color versus hatch; unsupported levels forbidden | Preserved | `docs/product/north-star.md:404`, `:416`, `:476`; `docs/design/map.md:563` |
| Intensity requires matching hazard, location, outlook, validity, stored polygons/base probability | Preserved | `docs/product/north-star.md:438`, `:457` |
| Severe supporting card is sole Today intensity owner | Preserved | `docs/product/north-star.md:455`; `docs/design/today.md:730` |
| Missing information is not quiet; quiet is not universal safety; model guidance is not official | Preserved | `docs/product/north-star.md:184`, `:204`, `:602`, `:630` |
| Independent light/dark design; #F5F6F7 canvas and #FCFCFD ordinary content | Preserved | `docs/design/foundations.md:187`, `:220` |
| Restrained light borders/no ordinary shadows; awareness-gradient exception | Preserved | `docs/design/foundations.md:273`, `:285`, `:318` |
| Preserve dark direction and semantic saturation; readable adaptive supporting text | Preserved | `docs/design/foundations.md:344`, `:379`, `:615` |
| Native Glass for controls/navigation; native SwiftUI preferred | Preserved | `docs/design/foundations.md:842`, `:896` |
| Map is awareness-focused and geographically dominant; native compact selector | Preserved | `docs/design/map.md:57`, `:80`, `:275` |
| Established layer names/destinations; adaptive legends; intensity hatch meaning | Preserved | `docs/design/map.md:234`, `:261`, `:505`, `:796` |
| Preserve camera/viewport; no mockup-authorized radar/layers/recenter | Preserved | `docs/design/map.md:188`, `:1250`; `docs/product/north-star.md:711` |
| WidgetKit-native; distinct small/medium/large/accessory roles | Preserved | `docs/design/widgets.md:120`, `:168`, `:218` |
| Large active-alert priority; accurate overflow; separate alert/overflow/footer regions | Preserved | `docs/design/widgets.md:723`, `:840`, `:966` |
| System outer shape/rendering; meaning survives tint/accent/vibrancy/background removal | Preserved | `docs/design/widgets.md:218`, `:1272` |
| No decorative widget “as of” timestamps | Preserved | `docs/design/widgets.md:1188`, including accessibility |
| Valid accepted cache remains visible; coherent replacement; no false ingestion changes | Preserved | `docs/design/states-accessibility.md:188`, `:267`, `:323` |
| Distinct current/cache/stale/resolving/empty/degraded/unavailable; identity respected | Preserved* | `docs/design/states-accessibility.md:232`, `:295`, `:671` |
| Routine refresh avoids churn | Preserved | `docs/design/states-accessibility.md:323`, `:854` |
| Dynamic Type, VoiceOver, contrast, motion, transparency, non-color meaning; no clipping | Preserved | `docs/design/states-accessibility.md` §§19–26, `:1487` |
| Whole compositions, representative states, both widths/appearances, deterministic rendered evidence | Preserved | `docs/design/visual-review.md:69`, `:105`, §§12–16 |
| Mockups illustrative; proportional review; avoid reopening approved decisions | Preserved | `docs/design/visual-review.md:262`, `:107`, `:1367`, `:1416` |

*The distinctions are repeatedly preserved, but the short definition of Current is imprecise; see F6. This does not negate the surrounding state contract.

The additional historical omissions below are outside the explicitly enumerated approved-decision list.

## D. Findings

### F1 — Important: Conditional-intensity explanatory meaning is less complete

**Sources:** `docs/SkyAware North Star Spec.md:324`; `docs/SkyAware Branding and Design Guide.md:735`.

**Targets:** `docs/product/north-star.md:424`, `:432`; `docs/design/today.md:756`.

The target preserves every supported intensity label, the conditional nature of intensity, the absence of hail Level 3, and the full eligibility/cache contract. However:

- The original specifies progressively different conditional explanations for tornado, wind, and hail levels. The replacement supplies only one generic example per hazard.
- The original explicitly says intensity does not imply storm mode, spatial coverage, or a broader event. That restriction appears nowhere in the nine replacements.

**Why it matters:** Future Today or Map explanation work could retain the labels while losing their intended explanatory distinctions or attaching unsupported implications.

**Smallest correction:** Add the level-specific explanatory meaning and the three excluded implications to Product §10.1. Keep Today and Map referencing that owner.

**Evidence status:** Explicit historical requirement; no new product decision is needed to preserve it. Exact editorial wording may be refined by Brand without changing meaning.

### F2 — Important: Detail-presentation requirements have no canonical replacement

**Sources:** `docs/SkyAware North Star Spec.md:390`; `docs/SkyAware Branding and Design Guide.md:612`, `:639`.

**Targets:** `docs/product/north-star.md:529`, `:671`; `docs/design/today.md:844`.

The source-information requirements survive, but these design decisions do not:

- Severity, certainty, and urgency use compact status chips.
- Sender, instruction, and response use textual rows/sections rather than chips.
- Outlooks, mesoscale discussions, and watches share a clean header → key metadata → summary-first → expanded/drill-in detail structure, without forcing identical content.

The narrow implementation check confirms that alert-detail chips remain real current behavior at `Sources/Features/Alert/AlertDetailView.swift:104`.

**Why it matters:** Product and Brand preserve which information exists, but future design work lacks the established presentation contract.

**Smallest correction:** Add a short “Related alert and weather-product detail presentation” subsection under Today's Local Alerts guidance. Retain shared typography/material references to Foundations.

**Evidence status:** Explicit source decisions. No newer canonical requirement was found superseding them. This is documentation loss, not a demonstrated implementation defect.

### F3 — Important: Exact Today composition has two detailed authoritative definitions

**Sources/targets:** `docs/product/north-star.md:245` (§6.2) and `docs/design/today.md:101` (§2).

Both documents independently enumerate the complete eight-part section order and conditional-slot behavior. They agree today.

**Why it matters:** This is detailed composition, which the declared ownership assigns to Today. A future section-placement change requires maintaining two specifications, despite the one-owner rule at `docs/design/README.md:95`.

**Smallest correction:** Keep the exact composition in Today §2. Replace Product §6.2's detailed sequence with a brief product-level summary and a section-specific link. Retain Product's behavioral invariants about optional sections and truthful Storm Setup states.

**Evidence status:** Explicit ownership rule. This is problematic duplication, not a current behavioral contradiction.

### F4 — Minor: Cached-refresh status placement is weakened

**Sources:** `docs/SkyAware North Star Spec.md:448`; `docs/SkyAware Branding and Design Guide.md:845`.

**Targets:** `docs/product/north-star.md:829`; `docs/design/states-accessibility.md:378`.

The original explicitly places cached-refresh status in the header as a subordinate line and excludes floating overlays. The new Product text permits an “appropriate existing status or header location”; States does not preserve the more specific constraint.

Current code still uses a header secondary line at `Sources/Features/Summary/SummaryStatus.swift:173`.

**Smallest correction:** State in States §7 that Today's visible cached-refresh progress belongs in the established header/status line and must not obscure accepted content with a floating overlay. Brand continues to own its wording.

**Evidence status:** Explicit source requirement and consistent current implementation. No need to restore blanket blur or animation recipes.

### F5 — Minor: Established marketing-art direction is only partially retained

**Source:** `docs/SkyAware North Star Spec.md:489`.

**Target:** `docs/brand/brand-and-voice.md:957`, especially `:992`.

The new Brand document substantially improves authenticity and capability-claim guidance. It does not retain the original preference for atmospheric skies, layered weather textures, soft gradients, typography-led composition, generous negative space, and one clear focal point. The corresponding exclusions of clipart-led and cartoon storm imagery are also less explicit.

**Why it matters:** These were established asset-generation directions, not newly proposed stylistic preferences.

**Smallest correction:** Add a compact “Supporting marketing artwork” paragraph under Brand §14. Keep these as preferences, not mandatory UI treatments.

**Evidence status:** Explicit source preferences. Human review can intentionally retire them, but the current documents do not establish that retirement.

### F6 — Minor: “Current” is defined too broadly in the shared state table

**Source/target:** `docs/design/states-accessibility.md:240`, compared with `:295`.

The table defines Current as “Applicable accepted information is available.” That also describes usable cached information. Later text correctly says cached information is not automatically current.

**Why it matters:** The quick-reference definition is less precise than the detailed contract it summarizes.

**Smallest correction:** Define Current as applicable accepted information meeting the content family's established current/freshness criteria. Define Cached as previously accepted information retained under that family's validity and provenance rules.

**Evidence status:** Internal documentary ambiguity; no new expiration policy should be invented.

### F7 — Minor: Accepted visual baselines are required but not identified

**Targets:** `docs/design/today.md:1532`; `docs/design/visual-review.md:241`; `docs/design/foundations.md:385`.

The documents require approved implemented screenshots and preservation of approved dark treatments, but do not identify the approved reference set. Existing images under `docs/images/issue-673/` include before/after quiet, elevated, and warning appearances, but the canonical documents do not designate them as approved.

**Why it matters:** Readers can locate screenshots but cannot reliably determine which establish accepted direction.

**Smallest correction:** In Visual Review §4, link the actual human-approved reference set and identify its scope. Today and Foundations should reference that entry.

**Evidence status:** The missing designation is explicit. Selecting which screenshots are approved requires human confirmation; approval has not been assigned based on filenames.

### F8 — Minor: Repository guidance still routes work to retiring documents

**Source:** `AGENTS.md:90`, plus the references in Section F.

**Target:** Design README already provides the intended navigation and ownership model at `docs/design/README.md:91`.

**Why it matters:** Retiring the original without updating this instruction leaves the repository's primary design routing broken.

**Smallest correction:** Route product behavior to Product, communication to Brand, and visual/interaction work to Design README. Update operational runbook references and preserve historical references as historical evidence.

**Evidence status:** Exact repository references; no product decision required.

### Consistency and architecture conclusions

The following repetition is **useful reinforcement**, not a defect:

- Today repeats warning precedence while explicitly deferring selection to Product.
- Brand gives intensity vocabulary examples while referring precise eligibility and meanings to Product.
- Map and Widgets restate shared accessibility/state principles in their constrained contexts.
- Visual Review checks approved surface requirements without authorizing new semantics.

Surface validation sections repeat some review criteria, but their local cases—such as large-widget overflow and Map viewport preservation—are useful. Retain those cases and their links to Visual Review.

No material introduction of persistence, networking, ingestion, or concurrency architecture by a surface specification was found. The implementation-boundary sections consistently protect existing owners. Foundations contains appropriate shared-consumer cautions rather than extensive Today implementation instructions. Visual Review explicitly integrates with existing engineering/lifecycle workflows and prohibits parallel approval ceremonies.

## E. Intentional Omissions

These requirements should remain excluded or qualified.

| Historical guidance | New controlling requirement | Why omission/change is intentional |
| --- | --- | --- |
| Dew-point-led atmospheric rail, warm emphasis, value-only popup: original North Star :371; Branding Guide :525 | Product :550, :590; Today :946, :1018 | Five peer measurements now own Atmospheric Conditions; dew point belongs in Fuel & Instability. Do not restore the old rail. |
| Unequal atmospheric measurement prominence: visual contract :577, :592 | Today :956 | Explicit peer hierarchy supersedes ingredient-led emphasis. |
| Broad “All Clear / safe” meaning: Branding Guide :339; old color labels in North Star :191 | Product :184; Brand :377 | Scoped quiet assessment replaces universal safety language. Internal enum names can remain implementation details. |
| Uniform base-to-darkened gradients: Branding Guide :349 | Today §§7.1–7.7 | The approved gradient blends into the opaque base and is independently tuned by appearance. |
| Broad restrictions against quiet/supporting color washes: visual contract :503 | Foundations :273; Today §7 | Today's four awareness cards are an explicit semantic-gradient exception. Other supporting content remains neutral. |
| Gentle gradient drift and looping glow timing: original North Star :226; Branding Guide :969, :980 | Today :463; Foundations :976 | Approved awareness gradients are static; motion must communicate meaningful transitions. |
| Mandatory cached-refresh blur/opacity recipe: Branding Guide :827 | States §§6–7, 17 | Routine refresh is now visually quiet; indiscriminate dimming and replayed transitions would conflict with approved continuity. |
| Universal application of the approximate 30-point fallback: Branding Guide :263 | Foundations :693 | Shared radius language survives, but the historical fallback is not a command to apply one radius to every component. |
| Wave-specific consumers, issue numbers, sequencing: visual contract :532 | Foundations §16 and surface boundaries | Durable shared-consumer safeguards survive; point-in-time implementation inventory belongs in history. |
| Generated gallery folder layout and per-issue reference-loading mechanics: visual contract :772 | Design README §7; Visual Review §4 | Reference authority survives without retaining temporary gallery organization. |
| Older competing document precedence: visual contract :64; original North Star :21 | Design README §4 | Responsibility-based authority replaces overlapping whole-document rankings. |

The originals already reject the paired Storm/Severe hero at Branding Guide :503. The replacement strengthens that rule to full-width vertical supporting cards across iPhone widths. There is no approved paired-layout requirement to restore.

The original “renderer architecture is correct” assertion at Branding Guide :764 is appropriately replaced by Map :561: preserve the existing strategy unless demonstrated correctness or accessibility evidence warrants change. A historical implementation assessment should not prevent future defect correction.

## F. Reference Migration

### Canonical-document checks

- **67 relative Markdown links checked; none broken.**
- No capitalization mismatches found in those paths.
- All referenced local source, asset, marketing, and redesign-directory paths checked exist.
- No relative links with fragment anchors were present, so there were no stale linked anchors to resolve.
- Document front-matter titles and H1 titles agree.
- None of the nine replacements references a retiring document.
- The visual-baseline problem in F7 is a missing approval designation, not a broken link.

### Repository references requiring disposition

These exact references remain outside the three originals:

| File and line | Recommended destination/disposition |
| --- | --- |
| AGENTS.md:90 | Product + Brand + Design README routing |
| docs/plans/today-refresh-performance-runbook.md:12 | Product §18; States |
| docs/plans/today-state-flow-runbook.md:21 | Product; States |
| docs/plans/codebase-simplification-runbook.md:18 | Product; Design README implementation boundaries |
| docs/plans/resolve-forward-ui-polish-playbook.md:28, :29 | States; Brand; relevant surface specification |
| docs/plans/resolve-forward-ui-polish-progress.md:31, :32 | Mark historical authority or update current routing |
| docs/plans/ingestion-ui-coherence-runbook.md:10 | Product §18; States |
| docs/plans/ingestion-ui-coherence-progress.md:45 | Mark historical authority or update current routing |
| docs/plans/air-quality-cache-forward-runbook.md:19 | Product §12; States |
| docs/plans/risk-profile-change-notifications-runbook.md:12 | Product §19; Brand §9 |
| docs/plans/storm-setup-runbook.md:26 | Product §13; Today §16; Brand provenance guidance |
| docs/plans/storm-setup-summary-stability-runbook.md:23 | States; Today §16 |
| docs/plans/apple-native-ui-alignment-runbook.md:19, :20 | Product; Brand; Design README |
| docs/plans/apple-native-ui-alignment-progress.md:62, :63 | Preserve historical meaning; identify canonical successors |
| docs/audits/resolve-forward-ui-polish-issues.md:376, :377 | Preserve historical evidence; identify successor docs or historical revision |
| docs/runbooks/archive/progress/FB-017-progress.md:895 | Historical reference; preserve with a resolvable historical location if needed |

Do not silently make an old audit appear to have used today's documentation. Historical records can retain their original citation with an archive or Git-revision reference; operational instructions should route to the new owners.

No references to `docs/design/visual-contract.md` were found outside the retiring contract itself. No additional README, `Sources/AGENTS.md`, or repository-local skill reference matched the retired paths. These search results describe the repository before this report was added; the report itself intentionally cites historical paths as audit evidence.

## G. Recommended Corrections

The smallest correction set is:

| File/section | Narrow correction |
| --- | --- |
| docs/product/north-star.md, §10.1 | Restore level-specific conditional explanatory meanings. Add: “Conditional intensity does not imply storm mode, spatial coverage, or a broader event.” Keep supported levels and existing eligibility unchanged. |
| docs/design/today.md, §14 | Add the retained detail-family pattern and compact-chip/text-row distinction from F2. Reference Product for required source information and Foundations for shared styling. |
| docs/product/north-star.md, §6.2 | Replace the duplicate exact section sequence with a summary and link to Today §2. Preserve optional-section/state invariants. |
| docs/design/states-accessibility.md, §7 | Add: “When Today shows progress with accepted cached content visible, use the established subordinate header/status line; do not obscure content with a floating progress overlay.” |
| docs/brand/brand-and-voice.md, §14 | Restore a brief preference for atmospheric skies/textures, restrained gradients, typography-led composition, negative space, and one focal point; exclude clipart-led/cartoon storm artwork. Scope this to supporting marketing assets. |
| docs/design/states-accessibility.md, §4 | Clarify Current and Cached using existing content-family freshness/validity contracts; introduce no new global policy. |
| docs/design/visual-review.md, §4 | Identify and link the human-approved implemented screenshot baseline. Link Today's baseline paragraph to it. |
| AGENTS.md and operational references listed above | Update routing to canonical owners. Preserve historical audit/progress citations without rewriting their provenance. |

The first two corrections preserve meaningful knowledge that would otherwise disappear. The remaining corrections make ownership, routing, and future verification dependable.

## H. Final Adoption Checklist

### Before making the nine documents authoritative

- [ ] Restore the intensity explanation guardrails and detail-presentation contract.
- [ ] Give Today sole ownership of its exact composition.
- [ ] Resolve the minor state, status-placement, artwork, and baseline-designation gaps.
- [ ] Update AGENTS.md to route work by canonical responsibility.

### Before retiring the three originals

- [ ] Update operational references and give historical citations a deliberate disposition.
- [ ] Confirm the originals remain recoverable through Git history or an explicitly historical archive.
- [ ] Recheck canonical links and the retirement-reference search after corrections.

### Before creating skyaware-design

- [ ] Use Design README's ownership map and authority rules as the entry point.
- [ ] Route meteorological truth to Product and communication to Brand.
- [ ] Load surface guidance progressively and reference canonical detail instead of duplicating it.
- [ ] Preserve existing engineering/lifecycle ownership and proportional visual verification.

**The new structure can safely replace the originals once these bounded corrections are reviewed and completed. The central redesign knowledge is preserved; immediate retirement would lose a small but meaningful set of established requirements.**
