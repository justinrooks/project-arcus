SkyAware UNRELEASED build adds Fire Weather map/alert coverage, feed-driven polygon styling updates, and safer sync/network request handling.

Highlights:
- Fire Weather risk is now included in map layers and legend data from SPC wind/RH products
- Fire, Categorical, and Severe map overlays now use feed-provided fill/stroke styling with tuned alpha
- Local alert inclusion now accounts for Fire Weather zones
- Overlapping map sync requests now coalesce instead of replaying full SPC map-product loads
- SPC/NWS request failures now handle rate-limit/service-unavailable responses more consistently

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
