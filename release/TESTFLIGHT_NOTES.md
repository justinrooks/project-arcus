SkyAware v0.1.0(37) surfaces richer severe-weather context in supported alert views, makes active alert summaries more compact by default, and clarifies onboarding/privacy messaging around best-effort alerts and location-derived notification targeting.

Highlights:
- Supported alerts can now show severe-risk tags for tornado, wind, hail, and flash-flood threat context when the source data includes it
- Active alert summaries now default to fewer items and let you expand the full list with See all / Show less
- Condensed alert rows now have cleaner icon alignment
- Welcome, disclaimer, and permission screens now more clearly explain best-effort severe-weather awareness and official-warning guidance
- Privacy and public project documentation now describe WeatherKit usage and derived location data used for server-assisted notification targeting

SkyAware v0.1.0(33) makes local refreshes wait for complete area context, adds hot-alert fetching when your location changes in the background, and tightens watch filtering and presentation.

Highlights:
- SkyAware now waits for complete local context before loading location-based risks, alerts, and current conditions
- Onboarding now follows While Using permission with an Always Allow follow-up request so background alerts can stay current
- Background location changes now fetch hot mesos/watch data and can send a watch notification when a newly relevant watch is detected
- Cancelled and inactive Arcus watch payloads are filtered out before they reach local watch results
- Updated watches now show the correct "Updated" subtitle in watch details
- Summary/Home loading now shows clearer progress states while your location and local conditions are being prepared

SkyAware v0.1.0(29) build improves onboarding and location handoffs, keeps watch matching aligned with location changes, and hardens network/cache behavior.

Highlights:
- Onboarding now waits for the actual location-permission result and APNs token before sending the first location snapshot
- Foreground and background refresh can reuse recent location snapshots, prefer fresh fixes when available, and skip stale location-dependent work
- Active watch loading now uses the server alert feed, with UGC/H3 matching so local watch results follow location changes more reliably
- Settings now includes Server Notifications and Send Location to Signal toggles
- Diagnostics now lets you clear the shared network cache and shows longer log entries before truncating
- SPC/NWS/alert requests now have stronger retry, revalidation, and cached-fallback handling

SkyAware v0.1.0(25) build adds a new Atmosphere summary rail, expanded severe-map hatching/legend behavior, and notification/data freshness updates.

Highlights:
- Summary now includes an Atmosphere rail and more consistent placeholder loading states
- Severe map overlays now use layered hatch patterns with updated legend swatches for significant intensity levels
- Morning notifications now include Fire Weather risk context, and additional notification types are enabled
- Location snapshot payloads now use H3 cell identifiers with installation/region context instead of raw latitude/longitude
- Map product freshness filtering now reduces stale map layer displays
- Settings now hides AI options, fixes the location card width issue, and shows installation/device identifiers for debugging

SkyAware v0.1.0(22) build adds WeatherKit attribution/cadence updates, expanded Fire Weather surfacing, and continued map behavior fixes.

Highlights:
- Fire Weather risk now appears in both the Summary rail and the Fire map layer/legend
- Summary now shows current-location temperature and condition symbol from WeatherKit
- Summary now includes WeatherKit attribution with a provider/legal link
- Active watches are now filtered by validity window (effective through end time)
- Severe map overlays now maintain explicit severity ordering so higher-risk shading stays on top
- Map layer picker button interactions are more reliable during repeated taps

SkyAware v0.1.0(18) build focuses on map layering correctness and safer background refresh rescheduling behavior.

Highlights:
- Categorical outlook polygons now layer correctly so higher-risk areas render above lower-risk areas
- Map overlays update with less redraw churn and one-time initial auto-centering
- Pending app refresh tasks are replaced only when the new run time is materially earlier
- If refresh replacement fails, the previous scheduled refresh request is restored

SkyAware v0.1.0(16) focuses on startup polish and reliability for location + background sync behavior.

Highlights:
- New Home loading overlay with updated loading visuals
- More accurate location permission state updates from authorization callbacks
- Improved placemark stability by preventing overlapping/stale geocode results
- Smarter SPC sync ordering with convective outlook throttling to reduce redundant refreshes

SkyAware v0.1.0(10) focuses on watch accuracy and presentation, including timing display and links to the correct NWS alert page.

Highlights:
- Watch notifications now use watch end time for active checks
- Watch details and summary rows now display end times with "Ends in" messaging
- Watch links now open the correct NWS alert page
- Watch icons are corrected for tornado vs severe thunderstorm watches

SkyAware v0.1.0(3) focuses on core alerting and background refresh. You’ll find a full Watch/Meso/Outlook experience, improved summaries and map tools, and more reliable background notifications.

Highlights:
- Background alerting for morning summaries, mesos, and watches
- New watch detail experience and active alert surfacing
- Convective outlook and meso discussion improvements
- Map UI enhancements and better summary freshness indicators
