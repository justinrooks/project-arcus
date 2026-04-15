# SkyAware

SkyAware is an iOS app built for hyper-local severe weather awareness. It brings together NWS and SPC data to surface current risk, active alerts, and timely notifications in a clear, glanceable way. This repository contains the app and its supporting development context.

## Join the Beta
Try SkyAware on TestFlight and help shape the app.

[Join the SkyAware beta on TestFlight](https://testflight.apple.com/join/2hnEnj6e)

SkyAware is a severe-weather awareness app in active development. It does not issue official warnings and should not be relied upon as a sole source of emergency information.


## Key Features
- Visualize current severe weather risks for your location
- Receive notifications about mesoscale discussions, watches, and warnings relevant to your location
- Morning severe weather risk summary
- Map layers for categorical and probabilistic severe risks (wind/hail/tornado) plus mesoscale overlays
- Background refresh with automatic data cleanup and cadence policies
- Localized risk queries driven by NWS gridpoint metadata (county/zone based watch lookup)
- In-app diagnostics, including a log viewer and background run health screen

## Screenshots
| Today + Alerts | Today + Risks | Today (Clear) |
|---|---|---|
| ![](docs/images/1-TodayWithLocalAlerts.png) | ![](docs/images/2-TodayWithRisks.png) | ![](docs/images/10-TodayView.png) |

| Map (Categorical Risk) | Map Layers | Wind Risk |
|---|---|---|
| ![](docs/images/3-MapWithRisks.png) | ![](docs/images/6-MapLayers.png) | ![](docs/images/7-WindRisk.png) |

| Hail Risk | Active Alerts | Watch Detail |
|---|---|---|
| ![](docs/images/12-HailRisk.png) | ![](docs/images/4-ActiveAlerts.png) | ![](docs/images/5-ExampleTornadoWatch.png) |

## Getting Started
### Requirements
- Xcode 16+
- iOS 18+
- Swift 6+

### Open in Xcode
```sh
xed SkyAware.xcodeproj
```

## Build & Run
```sh
xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 15" build
```

## Testing
```sh
xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 15" test
```

## Configuration
- App configuration lives in `Config`.
- Shared assets and previews live in `Resources`.
- The app uses NWS and SPC as primary data sources.
- Ensure location and notification permissions are enabled when testing.

## Architecture
- **App**: app entry points and dependency wiring.
- **Features**: SwiftUI screens and feature logic (e.g., Map, Summary, Diagnostics).
- **Providers**: data fetch and sync (NWS/SPC).
- **Repos**: persistence and query logic.
- **Utilities / Views**: shared helpers, extensions, and reusable UI.

Data flow is Provider → Repo → Feature View, with background refresh orchestrated by app lifecycle and cadence policies.

## Logging & Diagnostics
- Logging categories are centralized under `Sources/Utilities/Extensions/Logger+Extension.swift`.
- Diagnostics screens include the log viewer and background run health.
- All logging is treated as public for now; revisit if sensitive data is introduced.

## Contributing
- Commits follow the project convention: single-line, short, imperative summaries prefixed with `- `.
- PRs should describe intent, list user-visible changes, and note testing performed.
- Avoid committing secrets or credentials.

## Security & Privacy
- Keep private keys and WeatherKit credentials out of the repo.
- Do not log sensitive location or alert data in production code.

## Weather Awareness Disclaimer
SkyAware provides informational severe-weather awareness only and does not issue official warnings. Risk summaries, badges, and notifications are provided on a best-effort basis and should not be relied upon as a sole source of emergency information. Always rely on official alerts from the National Weather Service, NOAA Weather Radio, and local authorities. See `legal/EULA.md` for full terms.

## License
Use of SkyAware is governed by the End-User License Agreement in `legal/EULA.md`.
