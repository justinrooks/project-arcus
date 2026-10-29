# Privacy Policy

**Last Updated:** 01/09/2026

SkyAware (“the app”) is designed to provide clear, hyper-local severe weather awareness while respecting your privacy. This policy explains what information we use, how it is handled, what is stored on your device, and what limited information is sent to our server to support location-based weather notifications.

---

## Information We Collect

SkyAware does not require an account and does not collect names, email addresses, or advertising identifiers through the app. To operate location-based weather features and measure basic product usage, SkyAware processes limited device, usage, and derived-location information described below. This information can be associated with an app installation and should not be treated as anonymous.

- No user accounts
- Limited first-party usage measurement: when the app enters the foreground, it may send an app-generated installation identifier to SkyAware services. The service records a daily foreground-activity fact for usage metrics. This report does not include a screen, session, or precise location payload. It is separate from location and notification permission settings; disabling either permission does not itself disable this usage report.
- No tracking
- No advertising identifiers

---

## Location Data

SkyAware uses your device’s location to determine relevant severe-weather risk and nearby weather events.

To support timely, location-based notifications, SkyAware may send limited, derived location information to our server, including:
- A coarse geographic index
- County zone information
- Fire zone information

SkyAware does **not** send your precise latitude/longitude to our server for this purpose.

Notification registration and location updates may include a coarse H3 geographic cell and related county, forecast-zone, or fire-zone fields, along with timestamps and notification or installation metadata. These derived fields can remain linkable to an installation. The app's local use of precise device coordinates is distinct from the derived context sent to SkyAware services; the app does not send raw latitude and longitude to SkyAware for notification targeting.

This location-derived information:
- Is used only to determine relevant weather awareness and notifications
- Is **not** sold or shared with third parties for advertising or marketing
- Is **not** used for advertising or cross-app tracking
- Is **not** used to build advertising profiles

You can disable location access at any time in your device settings.

---

## Weather Data

The app retrieves public weather information from:
- The National Weather Service (NWS)
- The Storm Prediction Center (SPC)
- Apple WeatherKit

This data does not contain personal information.

When AirNow processing is enabled by the service and its AQI cache has no usable result, SkyAware services may request air-quality data from AirNow using a geographic centroid derived from the requested coarse H3 cell. This is derived location, not the device's measured precise coordinates; the described request does not include the app installation identifier or APNs token. AirNow is an independent service provider for that request and handles request information under its own practices. AirNow processing may be unavailable when it is not configured.

---

## Derived Risk Levels

SkyAware computes risk-level badges and summaries based on public SPC data.  
Risk calculations and notification targeting may use a combination of on-device processing and server-side processing.

These risk levels are informational and should not be considered official forecasts or warnings.

---

## What We Do Not Do

SkyAware does **not**:
- Collect names, email addresses, or advertising identifiers through the app
- Sell data or share it with third parties for advertising or marketing purposes
- Use third-party analytics or advertising SDKs
- Transmit precise location data to our server for notification targeting
- Process user data using AI or machine learning services
- Intend to retain inactive device notification records indefinitely; specific retention periods for all operational data are not established by this policy

---

## Data Storage and Retention

SkyAware stores app data on your device.

To support server-assisted notifications, SkyAware may store limited device and derived-location information on our server, including:
- An app-generated installation identifier
- APNs notification token and notification environment
- Coarse location context, such as H3 cell, county, forecast zone, and fire zone
- App version, platform, notification subscription status, and location authorization state
- Notification delivery and missed-notification records used to prevent duplicate sends and diagnose delivery reliability
- Daily foreground-activity facts associated with an app installation, used for basic usage metrics

SkyAware does not store precise latitude or longitude on our server for notification targeting.

Server-side device and location-context records support notification delivery, reliability, duplicate prevention, and troubleshooting. Current implementation and operational evidence do not establish a single retention period across current-presence records, delivery and heartbeat diagnostics, daily activity facts, logs, and backups. An inactive installation may be eligible for deletion after 30 days, but this is conditional and is not a guarantee that every related record is deleted at that time. Disabling notifications or location sharing stops the corresponding use for notification targeting when the service receives and applies the change; it does not promise immediate deletion of previously stored records. Applicable retention periods and deletion behavior remain subject to operational policy and review.

If you disable server notifications or location sharing in the app, SkyAware stops using your device for server-side notification targeting. Some previously stored operational records may remain temporarily for reliability, abuse prevention, debugging, and audit purposes, but are not sold, shared for advertising, or used to build profiles.

Public weather alert data may be retained separately. Aggregate operational metrics may also be retained; installation-linked daily activity facts are not described as anonymous aggregate data here.

---

## Children’s Privacy

SkyAware does not collect personal information and does not knowingly collect data from children.

---

## Changes to This Policy

If future features require changes to data handling, this policy will be updated and presented clearly within the app or through updated published policy text.

---

## Contact

For questions about this Privacy Policy, contact:  
_support@skyaware.app_

---

## Draft review appendix (not part of the approved public policy)

The following evidence map and checklist are for policy review. They do not establish legal compliance or approve publication.

### Policy-to-evidence matrix

| Policy statement | Evidence basis | Boundary or open question |
| --- | --- | --- |
| Foreground activity is linked to an installation and recorded daily for usage metrics | SkyAware `ForegroundActivityReporter` sends the installation identifier on foreground activation; Signal stores daily installation activity facts | Confirm product purpose, applicable disclosure purpose, and whether this report should have a separate user control before adoption |
| Precise coordinates are used on device; derived location context is sent for notification features | SkyAware location upload payload and Signal device/presence handling use H3 and related geographic fields | Derived fields remain linkable; this statement does not promise anonymity |
| AirNow may receive a centroid derived from a requested H3 cell on a cache miss when configured | Signal AirQualityProvider, AirNow client, and runtime configuration | Confirm provider terms/role and exact deployed configuration and cache behavior before publication |
| Operational diagnostics and activity records have no uniform deletion period established here | Signal #375 investigation found no general inactive-installation purge in repository source and assigned operational retention/log controls to that work | Production log, backup, and operator procedures need owner confirmation; no source-only conclusion establishes deployed retention |
| Inactive installations may be eligible for deletion after 30 days | Existing policy wording and conditional inactivity behavior | Do not state this as a hard deadline or as deletion of all linked records without operational evidence |
| Website policy currently makes broader hosting-provider and data-use statements | Public website policy at `https://skyaware.app/privacy/`, accessed 2026-10-28 | Website is a separate published surface; synchronize only after owner review and verify the deployed page after publication |
| Public App Store listing discloses coarse location, device identifiers, and product interaction | Public listing snapshot reviewed during #790 on 2026-10-27 | Snapshot is not App Store Connect configuration or binary verification; confirm purpose selections against current behavior |

### Publication checklist

- [ ] Human review approves the final policy wording and each material privacy commitment.
- [ ] Confirm the purpose and user-control decision for installation-linked foreground usage measurement.
- [ ] Signal #375 owner confirms current-presence, heartbeat/delivery diagnostics, daily activity, log, and backup retention/deletion behavior and any user-facing timeframe.
- [ ] Confirm AirNow provider disclosure, configuration, and deployed cache-miss behavior with the service owner.
- [ ] Reconcile and separately review the website policy before updating its published copy; verify the live page after an authorized publication.
- [ ] Review App Store privacy purposes against current behavior in App Store Connect; do not infer configuration from the public listing snapshot.
- [ ] Confirm the released app and deployed service behavior still match this draft at publication time.

https://www.skyaware.app
