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

## 2026-05-25
- Repos scanned: SkyAware (`/Users/justin/Code/project-arcus`), arcus-signal (`/Users/justin/Code/arcus-signal`), ArcusCore (`/Users/justin/Code/ArcusCore`)
- Commit window: SkyAware `9c08b13..58272f4`, arcus-signal `4469c10..c4232cc`, ArcusCore `18f7861..618bf3d`
- Contract surfaces inspected: APNs hot-alert payload keys/types, targeted alert fetch query contract (`id`/`sent`), alert DTO revision fields, location snapshot payload enums/optionality
- Top finding: `revisionSent` date format drift in APNs hot-alert payload encoding path (server emits default `Date` encoding while shared/client contract expects ISO-8601)
- Recommended fix: Configure APNs request encoders in `arcus-signal` to `dateEncodingStrategy = .iso8601` for both sandbox and production containers so `HotAlertAPNsPayload.revisionSent` matches ArcusCore/SkyAware decode contract
- Watchlist items: `GET /api/v2/alerts?sent=` is currently accepted and intentionally ignored; keep docs and client assumptions aligned
- Implementation recommended: Yes
