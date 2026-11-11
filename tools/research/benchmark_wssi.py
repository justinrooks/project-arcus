#!/usr/bin/env python3
"""Bounded, sequential NOAA WSSI research capture; no app dependencies.
Usage: python3 tools/research/benchmark_wssi.py OUTPUT_DIRECTORY
Each response and exact URL is retained; never overwrite an existing capture.
"""
import datetime
import json
import pathlib
import sys
import time
import tracemalloc
import urllib.parse
import urllib.request

BASE = 'https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/wpc_wssi/MapServer'
OUT = pathlib.Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=False)
records = []


def fetch(name, path='', **params):
    url = BASE + path + '?' + urllib.parse.urlencode({'f': 'json', **params})
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    tick = time.perf_counter()
    with urllib.request.urlopen(url, timeout=90) as response:
        raw = response.read()
        headers = dict(response.headers)
        status = response.status
    elapsed = time.perf_counter() - tick
    tracemalloc.start()
    tick = time.perf_counter()
    data = json.loads(raw)
    decode_ms = (time.perf_counter() - tick) * 1000
    _, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    (OUT / (name + '.json')).write_bytes(raw)
    records.append(dict(name=name, url=url, started=started, status=status,
                        headers=headers, bytes=len(raw), seconds=elapsed,
                        python_decode_ms=decode_ms, python_decode_peak_bytes=peak))
    (OUT / 'requests.json').write_text(json.dumps(records, indent=2) + '\n')
    return data


def query(name, layer, **params):
    return fetch(name, f'/{layer}/query', where='1=1', **params)


service = fetch('service')
layers = [layer for layer in service['layers'] if layer['type'] == 'Feature Layer']
summary = []
for layer in layers:
    lid = layer['id']
    metadata = fetch(f'layer-{lid}', f'/{lid}')
    for strategy, spatial in [
        ('nationwide', {}),
        ('bbox', dict(geometry='-112,36,-102,43', geometryType='esriGeometryEnvelope', inSR=4326)),
        ('point', dict(geometry='-105,40', geometryType='esriGeometryPoint', inSR=4326)),
    ]:
        params = dict(spatialRel='esriSpatialRelIntersects', **spatial)
        ids = query(f'{lid}-{strategy}-ids', lid, returnIdsOnly='true', **params)
        if 'error' in ids or 'objectIds' not in ids:
            raise RuntimeError(ids)
        expected = set(ids['objectIds'] or [])
        features = []
        for offset in range(0, max(1, len(expected)), 2000):
            page = query(f'{lid}-{strategy}-page-{offset}', lid, outFields='*',
                         outSR=4326, returnGeometry=str(strategy != 'point').lower(),
                         orderByFields='objectid ASC', resultOffset=offset,
                         resultRecordCount=2000, **params)
            if 'error' in page:
                raise RuntimeError(page)
            features.extend(page['features'])
            if offset + len(page['features']) >= len(expected) and page.get('exceededTransferLimit'):
                raise RuntimeError('Pagination changed during capture')
        actual = [f['attributes']['objectid'] for f in features]
        if len(actual) != len(set(actual)) or set(actual) != expected:
            raise RuntimeError('Incomplete or changed ID inventory')
        after = query(f'{lid}-{strategy}-ids-after', lid, returnIdsOnly='true', **params)
        if 'error' in after or set(after.get('objectIds') or []) != expected:
            raise RuntimeError('ID inventory changed during capture')
        summary.append(dict(layer=lid, name=layer['name'], strategy=strategy,
                            count=len(features), attributes=[f['attributes'] for f in features]))
# Force pagination with a small page, test invalid SQL, and legitimate geographic absence.
query('forced-page-1', 1, outFields='*', returnGeometry='false', resultRecordCount=1, orderByFields='objectid ASC')
query('forced-page-2', 1, outFields='*', returnGeometry='false', resultRecordCount=1, resultOffset=1, orderByFields='objectid ASC')
fetch('error', '/1/query', where='nonexistent_field = 1', outFields='*')
query('empty', 1, geometry='0,0', geometryType='esriGeometryPoint', inSR=4326, returnGeometry='false', outFields='*')
first = json.loads((OUT / '1-nationwide-page-0.json').read_text())['features']
if first:
    point = first[0]['geometry']['rings'][0][0]
    query('positive-point', 1, geometry=','.join(map(str, point)),
          geometryType='esriGeometryPoint', inSR=4326, returnGeometry='false', outFields='*')
(OUT / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(f'Captured {len(records)} requests; {len(summary)} comparisons in {OUT}')
