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
    # Original committed capture predates probe availability metadata; keep it verifiable.
    probes = read('probes') if 'capture/probes.json' in bodies else {
        'pagination': dict(status='captured', layer=1, minimum_features=2),
        'positive-point': dict(status='captured', layer=1, minimum_features=1),
    }
    assert set(probes) == {'pagination', 'positive-point'}
    outcomes = []
    for name, minimum in [('pagination', 2), ('positive-point', 1)]:
        probe = probes[name]
        assert probe['minimum_features'] == minimum
        candidates = {r['layer'] for r in rows
                      if r['strategy'] == 'nationwide' and r['count'] >= minimum}
        if probe['status'] == 'not_observable':
            assert not candidates and probe['reason']
            files = ['forced-page-1', 'forced-page-2'] if name == 'pagination' else [name]
            assert all('capture/' + f + '.json' not in bodies for f in files)
            outcomes.append(name + ': not observable in this capture')
            continue
        assert probe['status'] == 'captured' and probe['layer'] in candidates
        files = ['forced-page-1', 'forced-page-2'] if name == 'pagination' else [name]
        for filename in files:
            request = next(r for r in records if r['name'] == filename)
            assert '/' + str(probe['layer']) + '/query?' in request['url']
        if name == 'pagination':
            first, second = read('forced-page-1'), read('forced-page-2')
            assert first['exceededTransferLimit']
            assert len(first['features']) == len(second['features']) == 1
            assert first['features'][0]['attributes']['objectid'] != second['features'][0]['attributes']['objectid']
        else:
            positive = read(name)['features']
            assert positive and all('geometry' not in f for f in positive)
        outcomes.append(name + ': verified')
print(f'PASS: {len(records)} recorded responses; 60 complete layer/scope inventories; empty/error probes')
print('; '.join(outcomes))
