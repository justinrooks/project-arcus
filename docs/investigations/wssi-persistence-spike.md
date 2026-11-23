# WSSI isolated persistence spike

[#920](https://github.com/justinrooks/project-arcus/issues/920) exercises one source-faithful WSSI payload per product/day in a disposable, disk-backed SwiftData store. The probe validates the captured geometry with the #919 experiment and saves the original bytes with primitive product, day, and revision metadata. The isolated schema has one model, CloudKit is disabled, and each run owns a fresh temporary directory that it removes on success or failure.

## Fixture and method

Overall Impact Day 1 from [the #918 acquisition capture](wssi-acquisition-spike.md), revision `8afb87e2-451c-431c-8b0d-e18ea577ce0d`. The bundled `overall-1.geojson` contains 2,205,798 bytes (SHA-256 `397a1d717a96693f19429518d2d799de78d041deaf12682b91ad52747e486c0d`). Readback requires byte-for-byte equality, matching metadata, and exactly one row. The probe writes three synthetic revisions for the same slot by changing only the captured JSON's revision UUID. The geometry coordinates and payload byte count stay fixed, while both the expected source identity and the stored bytes change. The probe checks each revision after reopen. The final reopen verifies the third replacement.

The probe times insert/save, fetch with full payload access and equality verification, opening a fresh container after releasing the previous one, and delete/insert/save. Fixture load, validation, and preparation of each synthetic revision occur outside the storage timers. SQLite and WAL sizes are allocated bytes sampled from filesystem block counts. WAL bytes and database bytes describe current allocation at each stage, including any SQLite pages retained for reuse.

The process footprint samples include the test host, allocator, SwiftData, and input buffers while the measurement is active. Replacement samples can include both the previous and revised buffers. The final sample is taken after the probe releases its buffers and contexts, before it deletes the temporary directory. Stage-boundary samples can miss brief peaks, and other tests in the same host can affect the readings.

## Simulator observation

Captured November 23, 2026 using the Debug `SkyAware_Tests` plan, iPhone 17 Simulator on iOS 26.5 (23F77), Xcode 27.2 (27B52), and an arm64 Mac15,13 host on macOS 27.2.1. Reproduce with `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/WSSIPersistenceExperimentTests`. The native result (`skyaware-results.rMvCnR/unit.xcresult`) includes the unrounded stage readings and all three synthetic revision IDs in the `WSSI persistence simulator observation` attachment.

| Stage | Elapsed (ms) | SQLite allocated (bytes) | WAL allocated (bytes) | Sampled process footprint (bytes) |
| --- | ---: | ---: | ---: | ---: |
| Before fixture load | | | | 76,138,944 |
| Empty store |  | 69,632 | 0 | 80,464,320 |
| Insert + save | 47.73 | 69,632 | 2,289,664 | 81,922,496 |
| Initial fetch | 4.27 | 69,632 | 2,289,664 | 81,447,360 |
| Reopen 1 | 1.22 | 2,277,376 | 0 | 81,447,360 |
| Fetch 1 | 2.07 | 2,277,376 | 0 | 85,871,040 |
| Replace 1 + save | 14.63 | 2,277,376 | 2,285,568 | 83,642,816 |
| Reopen 2 | 1.39 | 2,277,376 | 0 | 79,186,368 |
| Fetch 2 | 1.39 | 2,277,376 | 0 | 81,398,208 |
| Replace 2 + save | 13.00 | 2,277,376 | 2,285,568 | 83,642,816 |
| Reopen 3 | 3.36 | 2,277,376 | 0 | 74,254,784 |
| Fetch 3 | 12.69 | 2,277,376 | 0 | 76,728,768 |
| Replace 3 + save | 22.87 | 2,277,376 | 2,285,568 | 78,989,760 |
| Reopen 4 | 1.53 | 2,277,376 | 0 | 74,566,080 |
| Fetch 4 | 1.46 | 2,277,376 | 0 | 76,777,920 |
| After buffer and context release | | | | 72,354,240 |

The store retained one 2,205,798-byte payload across all four reopen checks. SQLite and WAL together occupied 4,562,944 bytes after each replacement save and 2,277,376 bytes at the subsequent reopen. The final process footprint sample was 3,784,704 bytes below the pre-load sample. This is a process-wide observation with concurrent test-host activity and cannot isolate how much memory SwiftData released. The results establish a working one-slot simulator baseline across three same-size synthetic revisions. Physical-device performance, revisions with different geometry sizes, and multi-slot scaling remain outside this measurement.
