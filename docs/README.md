# SkyAware Knowledge Index

Use this index to locate the knowledge relevant to work in SkyAware. [README.md](../README.md) introduces the project; [AGENTS.md](../AGENTS.md) and [Sources/AGENTS.md](../Sources/AGENTS.md) define repository and app-layer working requirements.

## Product, Brand, and Design

| Knowledge | Starting point |
| --- | --- |
| Product identity, behavioral expectations, and meteorological meaning | [North Star](product/north-star.md) |
| Brand identity, vocabulary, and user-facing communication | [Brand and Voice](brand/brand-and-voice.md) |
| Visual and interaction design, surface contracts, and acceptance | [Design System](design/README.md) |
| Visual reference and issue evidence | [Screenshots](images/) |

Product meaning belongs to North Star, communication to Brand, and visual and interaction decisions to Design. Screenshots are reference material, not exact implementation authority unless explicitly specified.

## Engineering and Integrations

| Knowledge | Starting point |
| --- | --- |
| Client architecture and runtime orientation | [App codebase summary](codebase/skyaware-app-summary.md) |
| Installation credentials, consent, and protocol safeguards | [Installation enrollment](security/installation-enrollment.md) |
| Local review expectations | [Code review guidance](code_review.md) |
| Shared principles and reusable capabilities | [Prompt_Fu knowledge index](https://github.com/justinrooks/Prompt_Fu/blob/main/docs/README.md) |
| Cross-system ownership and backend evolution | [Arcus ecosystem](https://github.com/justinrooks/Prompt_Fu/blob/main/docs/arcus/README.md) |

The existing app summary and installation document contain versioned implementation context that needs reconciliation as the code evolves. Verify current behavior against source, tests, contracts, and accepted decisions. Do not interpret a repository's configured integration as proof of live deployment.

## Build, Validation, and Evidence

| Knowledge | Starting point |
| --- | --- |
| Required local regression, performance, and UI navigation lanes | [CI and test-lane procedures](../tools/ci/README.md) |
| Location lifecycle and presence | [Presence lifecycle validation](validation/location-presence-lifecycle.md) |
| Location enrichment and timing | [Enrichment timing](validation/location-enrichment-timing.md) |
| WSSI persistence and retention | [Local retention](validation/wssi-local-retention.md) |
| WSSI physical-device observations | [Integrated device run](validation/wssi-integrated-device-run.md) |
| Investigation and audit evidence | [Audits](audits/) |

Keep deterministic, simulator UI, physical-device, and measurement evidence distinct. An investigation describes the source and conditions it examined, not necessarily current behavior.

## Release, Marketing, and Legal

- [Changelog](../release/CHANGELOG.md): canonical user-impacting release history.
- [Release notes](../release/RELEASE_NOTES.md): derived public-facing release notes.
- [TestFlight](../TestFlight/): current tester instructions and related artifacts.
- [App Store listing](marketing/app-store-listing.md) and [listing history](marketing/app-store-history.md): marketing copy and historical context; verify actual publication state separately.
- [Legal documents](../legal/): terms, privacy policy, and EULA.
- [Release preparation skill](https://github.com/justinrooks/Prompt_Fu/blob/main/skills/skyaware-release/SKILL.md): shared release workflow. Preparing release artifacts is distinct from publishing or initiating a build.

## Historical and Campaign Material

[Plans and progress records](plans/), [archived runbooks](runbooks/archive/), [audits](audits/), and other investigation notes preserve prior decisions, implementation rationale, and evidence. They are not blanket instructions for new work. Some remain unreconciled with later implementation or closed GitHub issues.

Consult historical material when the task requires it. Resolve contradictions against current authoritative evidence before reusing decisions; use GitHub issues and pull requests for implementation scope, status, and change-specific evidence.

## Knowledge Ownership

Keep SkyAware-specific product design, client architecture, domain invariants, and operational procedures here. Keep shared engineering guidance and cross-system decisions in Prompt_Fu; keep backend implementation, scientific methodology, and owned wire contracts with their owning repositories.

Prefer links to canonical knowledge rather than copies. Distinguish implemented behavior, deployment evidence, accepted decisions, proposals, and historical records. When transferring knowledge, establish destination authority before retiring the original.
