# WSSI integrated iPhone validation for #917

## Physical iPhone observations

The owner reported an iPhone 18 Pro Max running iOS 27.2.1 on Wi-Fi with SkyAware 1.5.1 (1) for both captures. The owner perceived no change in Today’s responsiveness during the cold run. The owner installed locally through Xcode and shared the capture from Settings. The capture does not record debugger attachment state. The validation build used base `d228a7939527bbcb036efb29f2f5794b7a5d7393`, the issue implementation, and temporary Debug capture instrumentation. The source patch SHA-256 was `b02afb4794bd1bd78a6438d26498d210501846736d237092948e206d7283c6c0`. The first capture spans 2026-11-25 00:49:30–00:49:49 UTC. Its SHA-256 is `bedb7940c4be7078827d1612cf2d16e34c66c7b17157efdd43769b06cc7794a3`. It contains one completed physical-device foreground workload through the production HTTP, sync, acceptance, assessment, and shared SwiftData paths.

| Measurement | Observation |
| --- | --- |
| Cold sync | 16.293 s. One manifest and all 15 geometry requests returned HTTP 200. All 15 revisions were accepted. |
| Accepted store | 15 geometry rows, 1 manifest, and 25,855,710 logical geometry bytes (24.66 MiB). |
| Point assessment | 240.9 ms for 15 periods. All 15 returned no match with unknown coverage. |
| Sampled process footprint | 34.83 MiB at start. Highest of 46 samples was 96.86 MiB. |
| Shared database and WAL allocation | Database held at 2.78 MiB. WAL grew from 3.00 to 8.00 MiB during the run. This is a shared-store snapshot before reopen. |
| Transfer | The manifest reported Brotli and geometry reported gzip. The capture exposed no Content-Length or measured wire byte totals. |

| Product | Day 1 revision | Day 2 revision | Day 3 revision |
| --- | --- | --- | --- |
| Blowing Snow | d5adda72-e42a-4f4c-95aa-4292718bd141 | b12ceb95-1d45-4677-94c3-c726c3cafa56 | 376e25ff-ab7e-45f0-881a-41f932a50b51 |
| Ice Accumulation | fed3b6c1-eb50-4b7c-af52-eba1e65ab8fa | ff70939c-3004-45c3-869f-ffde32a1e9b2 | 8d9e32aa-c215-41ec-83bc-793759e86598 |
| Overall Impact | edaef688-227f-414a-971c-c0d6400ac40f | f1a0e002-d2fe-403e-8df0-9d86ddd6804b | b0108844-4a16-4521-ad3a-8b6c64df8f61 |
| Snow Amount | ab156854-ae68-40ab-9b69-eeec7ea32e87 | ce755253-4382-43f9-9f85-ca2d008aa6a4 | 30147d16-d0a7-4593-a727-9a7fed6f5906 |
| Snow Load | 1d8ba937-17f3-4273-94b2-df61b1e4827c | df696027-7e46-4ed5-beab-ea7990eae8eb | c3a88af1-c6ac-4776-8d2b-c3029de07173 |

### Reopen and warm revalidation

The second supplied capture preserves the first byte for byte and adds a launch and foreground workload at 2026-11-25 00:52:39–00:52:40 UTC. The full second capture SHA-256 is `dd7c69946ca3fdaf162b61d4cad28af4f71f1d9110f12a019a7fb22df127ef4d`.

- Manifest revalidation returned HTTP 304. Sync finished in 619.9 ms with all 15 original revision IDs current, zero geometry requests, and zero failed or unavailable slots.
- The reopened shared store held the same 15 rows, one manifest, and 25,855,710 logical geometry bytes. The shared DB allocation held at 30.16 MiB during this run. WAL allocation fell from 8.00 MiB at the start to 48 KiB at readback.
- Accepted-cache assessment took 274.4 ms. All 15 no-match periods retained unknown coverage. The highest of three process samples was 37.00 MiB.

The two captures cover cold acquisition and warm readback after relaunch. Later replacement and interrupted recovery have deterministic simulator coverage. Neither physical capture spans those cases or contains an iOS background grant. Residual time after core background work remains unmeasured, so production background acquisition remains deferred.

The representative foreground runs and deterministic interruption and retention evidence support keeping full-resolution GeoJSON, sequential acquisition, and one accepted payload per dataset. This issuance is one sample. It leaves performance on smaller devices and larger issuances unmeasured.
