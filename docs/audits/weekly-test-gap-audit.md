# Weekly Test Gap Audit

## 2026-05-26
- Repos scanned: SkyAware (`/Users/justin/Code/project-arcus`), arcus-signal (`/Users/justin/Code/arcus-signal`), ArcusCore (`/Users/justin/Code/ArcusCore`)
- Commit window: last 7 days (2026-05-19 to 2026-05-26 UTC)
- High-risk areas inspected: APNs hot-alert payload contract, targeted alerts API (`/api/v2/alerts?id=`), geometry-vs-UGC targeting, notification dispatch fallback on unsupported geometry, remote hot-alert decoding, alert lifecycle filtering
- Top recommended test: `TargetEventRevisionJobTests.unsupportedGeometry_queuesUGCFallbackAndDrainsUGC` (Implemented)
  - Validation note (2026-05-28): Covered by `TargetEventRevisionJobFallbackTests.unsupportedGeometryUsesUGCFallbackDrainOnly` in `arcus-signal` and verified passing via targeted run.
- Watchlist items:
  - Verify cross-repo rollout sequencing for canonical `arcusAlertId` payload key to avoid mixed-client drift during staged deploys.
- Implementation recommended: Completed (no further action for this finding)
