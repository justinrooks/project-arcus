# WSSI local geometry retention

The consolidated SwiftData store holds one accepted geometry payload per product and day, for at most 15 slots, and one manifest. The WSSI store actor validates each candidate and checks cancellation before committing. It replaces the prior row in the same save and rolls back failed saves. Readers receive value snapshots, so a later replacement can reclaim the old row while a reader still holds its snapshot.

Validity determines whether a revision is eligible for use. Expiry leaves the current accepted bytes readable for last-known-good recovery. Activation cleanup calls the SPC and Arcus alert purge owners, which operate on their own model types. WSSI has no persisted staging rows or revision history and needs no WSSI-specific cleanup pass.

The disk-backed regression runs five issuances across all 15 slots in one production-schema store. It checks reopen, repeated SPC purges, cancellation, invalid geometry, and overlapping read and replacement. The companion migration test injects a save failure and checks recovery across reopen. The `WSSIRetentionSizes.txt` test attachment records logical geometry bytes separately from SQLite and WAL allocated bytes at each issuance. SQLite allocation can include reusable pages and journal data. The measurements describe the simulator workload, which reuses captured full-resolution shapes across slots.

On iPhone 17 Simulator with iOS 26.5, each of the five issuances retained 15 slots and 33,957,096 logical geometry bytes. SQLite allocated 37,457,920 bytes and the WAL allocated 5,246,976 bytes at each sample. This workload showed no accumulation that warrants a pruning pass.
