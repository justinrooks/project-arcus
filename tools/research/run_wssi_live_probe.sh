#!/bin/bash
# Explicit live research only; never part of a deterministic test lane.
set -euo pipefail
cd "$(dirname "$0")/../.."
capture=${1:?Usage: run_wssi_live_probe.sh NEW_CAPTURE_DIRECTORY}
mkdir "$capture"
capture=$(cd "$capture" && pwd)
git rev-parse HEAD > "$capture/revision.txt"
sw_vers > "$capture/host.txt"
xcrun swiftc --version >> "$capture/host.txt"
# Extract the production response value and header lookup, excluding unrelated retry policy.
python3 - "$capture/HTTPResponse.swift" <<'PY'
import pathlib, sys
source = pathlib.Path('Sources/Infrastructure/Networking/HTTPDataDownloader.swift').read_text()
start = source.index('public struct HTTPResponse: Sendable {')
end = source.index('    public func classifyStatus(', start)
pathlib.Path(sys.argv[1]).write_text('import Foundation\n' + source[start:end] + '}\n')
PY
cp tools/research/WSSILiveProbe.swift.source "$capture/WSSILiveProbe.swift"
xcrun swiftc -swift-version 6 -O -parse-as-library -o "$capture/probe" \
    "$capture/HTTPResponse.swift" "$capture/WSSILiveProbe.swift" \
    Sources/Models/Coordinate2D.swift Sources/Utilities/Geometry/MesoGeometry.swift \
    Sources/Infrastructure/Parsing/GeoJSON/WSSIDecoder.swift \
    Sources/Clients/WSSIClient.swift Sources/Clients/WSSIObservedPublication.swift \
    Sources/Domain/WSSI/WSSIAssessment.swift Sources/Domain/WSSI/WSSISnapshot.swift \
    Sources/Repos/WSSISnapshotStore.swift Sources/Repos/WSSIAcceptanceCoordinator.swift
"$capture/probe" "$capture" acquire
# A separate process, never a second network attempt, verifies durable restart readback.
"$capture/probe" "$capture" readback
