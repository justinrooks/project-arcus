#!/usr/bin/env python3
"""Offline integrity checks for the committed WSSI research capture."""
import json
import sys
import tarfile

with tarfile.open(sys.argv[1], 'r:gz') as archive:
    bodies = {member.name: archive.extractfile(member).read()
              for member in archive if member.isfile()}

    def read(name):
        return json.loads(bodies['capture/' + name + '.json'])

    records = read('requests')
    rows = read('summary')
    layers = {x['id'] for x in read('service')['layers'] if x['type'] == 'Feature Layer'}
    assert layers == {1, 2, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14, 16, 17, 18, 19, 24, 25, 26, 27}
    assert len(rows) == 60
    assert {(r['layer'], r['strategy']) for r in rows} == {
        (layer, strategy) for layer in layers for strategy in ('nationwide', 'bbox', 'point')}
    for record in records:
        raw = bodies['capture/' + record['name'] + '.json']
        assert len(raw) == record['bytes']
        assert record['status'] == 200
        assert ('error' in json.loads(raw)) == (record['name'] == 'error')
    for row in rows:
        prefix = str(row['layer']) + '-' + row['strategy']
        before = set(read(prefix + '-ids')['objectIds'] or [])
        after = set(read(prefix + '-ids-after')['objectIds'] or [])
        features = []
        for offset in range(0, max(1, len(before)), 2000):
            page = read(prefix + '-page-' + str(offset))
            features.extend(page['features'])
            if offset + len(page['features']) >= len(before):
                assert not page.get('exceededTransferLimit', False)
        ids = [f['attributes']['objectid'] for f in features]
        assert set(ids) == before == after
        assert len(ids) == len(set(ids)) == row['count']
        assert [f['attributes'] for f in features] == row['attributes']
    assert not read('empty')['features']
    assert 'issue_time' not in read('empty')
    assert read('forced-page-1')['exceededTransferLimit']
    assert read('forced-page-1')['features'][0]['attributes']['objectid'] != read('forced-page-2')['features'][0]['attributes']['objectid']
    positive = read('positive-point')['features']
    assert positive and all('geometry' not in f for f in positive)
print(f'PASS: {len(records)} recorded responses; 60 complete layer/scope inventories; empty/error/positive/pagination probes')
