#!/usr/bin/env python3
"""Deterministic capture/verifier regressions; no NOAA requests."""
import contextlib
import io
import json
from pathlib import Path
import runpy
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit

SCRIPTS = Path(__file__).resolve().parent
LAYERS = [1, 2, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14, 16, 17, 18, 19, 24, 25, 26, 27]


class ProbeTests(unittest.TestCase):
    def capture(self, root, count):
        # Layer 1 stays empty; only layer 6 may be populated.
        def response(url, timeout):
            path = urlsplit(url).path
            params = parse_qs(urlsplit(url).query)
            if path.endswith('MapServer'):
                data = dict(layers=[dict(id=lid, name=str(lid), type='Feature Layer') for lid in LAYERS])
            elif not path.endswith('/query'):
                data = {}
            elif params['where'] == ['nonexistent_field = 1']:
                data = dict(error=dict(code=400))
            else:
                lid = int(path.split('/')[-2])
                size = count if lid == 6 and params.get('geometry') != ['0,0'] else 0
                if params.get('returnIdsOnly') == ['true']:
                    data = dict(objectIds=list(range(1, size + 1)))
                else:
                    offset = int(params.get('resultOffset', ['0'])[0])
                    limit = int(params.get('resultRecordCount', ['2000'])[0])
                    features = []
                    for oid in range(1, size + 1)[offset:offset + limit]:
                        feature = dict(attributes=dict(objectid=oid))
                        if params.get('returnGeometry') == ['true']:
                            feature['geometry'] = dict(rings=[[[1, 1], [2, 1], [1, 1]]])
                        features.append(feature)
                    data = dict(features=features, exceededTransferLimit=offset + limit < size)
            result = io.BytesIO(json.dumps(data).encode())
            result.headers = {}
            result.status = 200
            return result

        capture = root / 'capture'
        with patch.object(sys, 'argv', ['benchmark_wssi.py', str(capture)]), \
                patch('urllib.request.urlopen', side_effect=response), contextlib.redirect_stdout(io.StringIO()):
            runpy.run_path(str(SCRIPTS / 'benchmark_wssi.py'), run_name='__main__')
        return capture

    def verify(self, root, capture):
        archive = root / 'fixture.tar.gz'
        with tarfile.open(archive, 'w:gz') as output:
            output.add(capture, arcname='capture')
        stdout = io.StringIO()
        with patch.object(sys, 'argv', ['verify_wssi_capture.py', str(archive)]), contextlib.redirect_stdout(stdout):
            runpy.run_path(str(SCRIPTS / 'verify_wssi_capture.py'), run_name='__main__')
        return stdout.getvalue()

    def test_seasonal_availability(self):
        for count in [0, 1, 2]:
            with self.subTest(count=count), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                capture = self.capture(root, count)
                probes = json.loads((capture / 'probes.json').read_text())
                for name, minimum in [('pagination', 2), ('positive-point', 1)]:
                    self.assertEqual(probes[name]['status'], 'captured' if count >= minimum else 'not_observable')
                    if count >= minimum:
                        self.assertEqual(probes[name]['layer'], 6)
                output = self.verify(root, capture)
                for name, minimum in [('pagination', 2), ('positive-point', 1)]:
                    self.assertIn(name + (': verified' if count >= minimum else ': not observable in this capture'), output)

    def test_missing_positive_response_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            capture = self.capture(root, 2)
            (capture / 'positive-point.json').unlink()
            with self.assertRaises(KeyError):
                self.verify(root, capture)

    def test_unjustified_skip_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            capture = self.capture(root, 2)
            path = capture / 'probes.json'
            probes = json.loads(path.read_text())
            probes['pagination'] = dict(status='not_observable', minimum_features=2, reason='quiet')
            path.write_text(json.dumps(probes))
            with self.assertRaises(AssertionError):
                self.verify(root, capture)


if __name__ == '__main__':
    unittest.main()
