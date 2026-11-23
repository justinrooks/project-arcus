# WSSI Forge acquisition spike

The DEBUG probe in `Sources/Infrastructure/Networking/WSSIAcquisitionProbe.swift` accepts a configured Forge origin and a product/day slot. Each run reads the 15-slot manifest, requests one accepted immutable geometry, and conditionally requests that same revision once when an ETag is present. Use one probe instance for a sequence. The probe retains at most three request records per run and provides the manifest identities and geometry bytes to the diagnostic caller. It checks the GeoJSON type and revision identity in the first 4 KiB using Forge’s current header-before-features layout. Feature and coordinate validation belongs to the downstream decode stage.

## Captures

On November 23, 2026, the LAN development Forge API returned a 15-entry manifest and full-resolution Overall Impact GeoJSON for Days 1 and 2. Both had five MultiPolygon features. Both revisions were issued at 19:15 UTC with assessment coverage reported as unknown. At capture time Day 1 was valid and Day 2 was not yet valid.

[The fixture archive](fixtures/wssi-918.tar.gz) contains the manifest and both unmodified response bodies after HTTP decompression. The archive is for replay and includes no development hostname or credentials.

| Fixture | Accepted revision | Decoded body bytes | SHA-256 |
| --- | --- | ---: | --- |
| `overall-1.geojson` | `8afb87e2-451c-431c-8b0d-e18ea577ce0d` | 2,205,798 | `397a1d717a96693f19429518d2d799de78d041deaf12682b91ad52747e486c0d` |
| `overall-2.geojson` | `f3b03d05-427e-4c78-bcd6-165060247a54` | 2,298,769 | `51720147c3c6c6c607370915c3997429d65131d5d47ed16bc81e53171bd5712e` |

To replay the archived bodies, extract with `tar -xzf docs/investigations/fixtures/wssi-918.tar.gz` and verify with `shasum -a 256 overall-*.geojson`. Fixture playback provides decode inputs and records no live transfer metrics. To recapture, use a configured development Forge origin, GET `/v1/wssi/manifest`, and request the accepted entry's exact `geometryPath` with `curl --compressed`. Check the response metadata against the manifest and record the new hash and ETag. For conditional verification, repeat that path with the returned ETag in `If-None-Match`. The retained revision can age out of Forge, so a new manifest may identify different geometry.

## Manual simulator observation

A standalone DEBUG harness compiled the probe for iPhone 17 Simulator, iOS 26.5 (23F77). It supplied the probe's usual foreground timeouts and a harness user agent, then ran against the LAN development API without app ATS overrides. This was a manual request, separate from the automated tests and the SkyAware app's eventual diagnostic screen.

| Request | HTTP | URLSession network body bytes | Decoded response bytes | Reused URLCache bytes | Elapsed |
| --- | ---: | ---: | ---: | ---: | ---: |
| Manifest | 200 | 8,287 | 8,287 | — | 46 ms |
| Overall Impact Day 1, cold | 200 | 1,377,127 | 2,205,798 | — | 295 ms |
| Same revision, conditional | 304 | 0 | 0 | 2,205,798 | 124 ms |

The geometry ETag was the weak validator containing the Day 1 hash above in uppercase. Transfer bytes are URLSession's attributed network response-body bytes before decompression. They exclude response headers and should not be read as total on-the-wire traffic. The probe leaves the network count absent when it cannot attribute a single network transaction. A separate host curl capture of the same two revisions measured 1,375,780 and 1,430,754 compressed response bytes respectively. These are individual observations on the development LAN. Physical-device local network authorization and performance remain for the integrated probe.
