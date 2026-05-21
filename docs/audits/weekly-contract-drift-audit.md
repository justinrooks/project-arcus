# Weekly Contract Drift Audit

## 2026-05-20
- Repos scanned: SkyAware, arcus-signal, ArcusCore
- Commit window: SkyAware `b5d15fe..HEAD` (recent history reviewed via `git log -n 20`), arcus-signal `ebbfd07..HEAD` (recent history reviewed via `git log -n 20`), ArcusCore `85c3d20..HEAD`
- Contract surfaces inspected: device registration/location snapshot payloads, alert/device DTOs, APNs payload keys and client handlers, revision/timestamp mapping
- Top finding: APNs payload contract drift between arcus-signal and SkyAware remote hot-alert ingestion
- Recommended fix: Add explicit APNs custom payload fields (`alertID` or `seriesId`, plus `revisionSent`) and define/share payload contract in ArcusCore
- Watchlist items: None
- Implementation recommended: Yes
- Status: Resolved on 2026-05-21
- Resolution notes:
  - Canonical APNs hot-alert identifier is now `arcusAlertId` (Arcus graph series id).
  - Compatibility aliases are still emitted/accepted: `alertID` and `seriesId`.
  - Decode precedence is `arcusAlertId` -> `alertID` -> `seriesId`.
  - `revisionSent` remains part of the payload contract.
  - ArcusCore contract tests and app/server focused validations were updated and passed.
