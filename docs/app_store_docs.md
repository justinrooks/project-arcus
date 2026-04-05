# Documentation

## AppStore

### Promotional Text
How weather-aware do you need to be today? SkyAware gives you a clear, fast summary of local risk, Watches, and Mesoscale Discussions to help you stay aware of developing severe weather.  

### Description
How weather-aware do you need to be today?

SkyAware gives you a focused, fast summary of local severe-weather risk so you know when the weather deserves your attention, and when it doesn’t.

---

Clear awareness, without the noise

SkyAware is built for moments when you want clarity, not constant alerts or dense forecasts.

It uses authoritative public severe-weather data and presents it in a clean, glanceable summary, with optional server-assisted notifications to help you stay aware of changing conditions.

---

What SkyAware shows you

- A clear summary of today’s local convective risk  
- Nearby **Watches** and **Mesoscale Discussions** relevant to your location  
- Simple guidance on what matters now—and what can wait  
- Deeper context and official detail on demand  

Everything is designed to stay readable, calm, and intentional—never alarmist.

---

Designed for awareness, not certainty

Most weather apps show you everything.  
SkyAware helps you decide what actually matters.

By focusing on severe-weather awareness instead of raw data, SkyAware feels less like a feed and more like a quiet assistant—clear hierarchy, thoughtful design, and information that earns your attention.

Risk levels, badges, and summaries in SkyAware are derived from public weather products and app logic. They are meant to help you stay informed, not to replace official warnings or emergency guidance.

---

Privacy & data

SkyAware is privacy-first by design.

Your location is used to determine relevant weather information for your area. To support timely, location-based notifications, SkyAware may send derived location information—such as your county, fire zone, and a coarse geographic index—to the server.

This information is used only to deliver relevant weather awareness and notifications. SkyAware does not sell your data, track you across apps or websites, or build advertising profiles.

---

A calmer way to stay informed

SkyAware doesn’t try to predict your day.  
It helps you stay aware—clearly, calmly, and when it matters.

---

SkyAware is an informational severe-weather awareness app. It does not issue official warnings, and notifications—whether delivered via background updates or server-assisted delivery—may not always be immediate. Always rely on official alerts from the National Weather Service, NOAA Weather Radio, and local authorities for emergency information.

### Keywords
severe weather,storm risk,alerts,storm watch,tornado watch,mesoscale,spc,nws,convective outlook

## Github

### Readme
SkyAware is a SwiftUI-first iOS app focused on hyper-local severe weather awareness. It combines NWS and SPC data sources to visualize current risks and deliver weather notifications designed to help users stay informed. The repository is public, but this README is written primarily for internal development use.

#### Key Features
- Visualize current severe weather risks for your location
- Receive notifications about mesoscale discussions, watches, and warnings relevant to your location
- Morning severe weather risk summary
- Map layers for categorical and probabilistic severe risks (wind/hail/tornado) plus mesoscale overlays
- Background refresh with automatic data cleanup and cadence policies
- Localized risk queries driven by NWS gridpoint metadata (county/zone based watch lookup)
- In-app diagnostics, including a log viewer and background run health screen

#### Security & Privacy
- Keep private keys and WeatherKit credentials out of the repo.
- Do not log sensitive location or alert data in production code.

#### Weather Awareness Disclaimer
SkyAware provides informational severe-weather awareness only and does not issue official warnings. Risk summaries, badges, and notifications are provided on a best-effort basis and should not be relied upon as a sole source of emergency information. Always rely on official alerts from the National Weather Service, NOAA Weather Radio, and local authorities. See `EULA.md` for full terms.

#### License
Use of SkyAware is governed by the End-User License Agreement in `EULA.md`.


## In-App

### Disclaimer
SkyAware provides severe-weather awareness using public data from the Storm Prediction Center and National Weather Service.

Risk levels, badges, summaries, and notifications shown in the app are computed estimates based on that data.

SkyAware:
    - Does not issue official weather warnings
    - May not always refresh or notify immediately
    - Should not be relied upon as your only source of severe weather information

Always follow official guidance from the National Weather Service, NOAA Weather Radio, and local authorities.
