"""Replay the attributed alternative fixtures through today's authenticated API.

Uses conftest's temporary database and forced mock provider; no live model calls.
"""
import json
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = json.loads((ROOT / 'docs/demo-assets/alternatives/manifest.json').read_text())
ASSETS = {asset['id']: asset for asset in MANIFEST['assets']}


@pytest.mark.parametrize('case', MANIFEST['cases'], ids=lambda case: case['id'])
def test_alternative_demo_case(case, client, auth_headers):
    if case['kind'] == 'manual':
        response = client.post('/api/diagnose/manual', json=case['payload'], headers=auth_headers)
    else:
        asset = ASSETS[case['asset']]
        path = ROOT / asset['source_file']
        media = 'image/png' if path.suffix == '.png' else 'image/jpeg'
        response = client.post('/api/analyze/image',
                               files={'file': (asset['demo_name'], path.read_bytes(), media)},
                               headers=auth_headers)
    assert response.status_code == case['expected']['status'], response.text
    result = response.json()
    for key, value in case['expected'].items():
        if key not in {'status', 'retake', 'unsupported_mock_scenario'}:
            assert result[key] == value, f'{case["id"]}: {key}'
    if response.status_code == 422:
        assert result['detail']
        return
    assert result['diagnosis_source'] == 'mock'
    if not case.get('exercise_report'):
        return
    session_url = f'/api/sessions/{result["id"]}'
    step = result['steps'][0]
    done = client.post(f'{session_url}/steps/{step["id"]}/feedback',
                       json={'feedback': 'done'}, headers=auth_headers)
    assert done.status_code == 200
    assert done.json()['steps'][0]['feedback'] == 'done'
    for lang in ('zh', 'en'):
        report = client.post(f'{session_url}/report', json={'lang': lang}, headers=auth_headers)
        assert report.status_code == 200 and report.json()['content']
        assert '照片' in report.json()['content'] if lang == 'zh' else 'photo' in report.json()['content'].lower()
    saved = client.get(session_url, headers=auth_headers)
    assert saved.status_code == 200 and saved.json()['steps'][0]['feedback'] == 'done'
