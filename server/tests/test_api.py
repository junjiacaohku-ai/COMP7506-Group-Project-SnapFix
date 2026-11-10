from pathlib import Path


def upload(client, headers, name='router.jpg', source='public-01.jpg'):
    data = (
        Path(__file__).resolve().parents[2]
        / 'docs/demo-assets/public'
        / source
    ).read_bytes()
    return client.post(
        '/api/analyze/image',
        files={'file': (name, data, 'image/jpeg')},
        headers=headers,
    )


def test_mock_scenarios_quality_and_account_isolation(client, auth_headers, user):
    health = client.get('/api/health').json()
    assert health['mock'] is True and health['provider'] == 'mock'

    router = upload(client, auth_headers).json()
    assert router['brand'] == 'TP-Link' and router['steps']
    assert router['diagnosis_source'] == 'mock' and router['status'] == 'investigating'

    for code in ['E:24', ' E：24 ', 'e24']:
        response = client.post(
            '/api/diagnose/manual',
            json={'brand': 'Bosch', 'error_code': code},
            headers=auth_headers,
        )
        assert response.status_code == 200
        assert response.json()['error_code'] == 'E24'

    microwave = upload(client, auth_headers, 'microwave.jpg').json()
    assert microwave['safety_refused'] and microwave['steps'] == []
    assert upload(client, auth_headers, source='public-09.jpg').status_code == 422
    from io import BytesIO
    from PIL import Image, ImageDraw

    unrelated = Image.new('RGB', (900, 900), '#79b7d8')
    draw = ImageDraw.Draw(unrelated)
    draw.ellipse((180, 140, 720, 680), fill='#f0ca62')
    buffer = BytesIO()
    unrelated.save(buffer, format='JPEG')
    unknown = client.post(
        '/api/analyze/image',
        files={'file': ('random.jpg', buffer.getvalue(), 'image/jpeg')},
        headers=auth_headers,
    )
    assert unknown.status_code == 422

    import auth
    import db

    with db.connect() as conn:
        other = auth.create_user(
            conn, 'Other', 'other-isolation@example.com', 'other-password-2026'
        )
        other_token = auth.issue_token(conn, other['id'])
    try:
        response = client.get(
            f"/api/sessions/{router['id']}",
            headers={'Authorization': f'Bearer {other_token}'},
        )
        assert response.status_code == 404
    finally:
        with db.connect() as conn:
            conn.execute('DELETE FROM users WHERE id=?', (other['id'],))


def test_feedback_status_report_drafts_and_delete(client, auth_headers):
    session = upload(client, auth_headers).json()
    session_url = f"/api/sessions/{session['id']}"
    step_id = session['steps'][0]['id']

    invalid = client.post(
        f'{session_url}/steps/{step_id}/feedback',
        json={'feedback': 'invented'},
        headers=auth_headers,
    )
    assert invalid.status_code == 400

    done = client.post(
        f'{session_url}/steps/{step_id}/feedback',
        json={'feedback': 'done'},
        headers=auth_headers,
    ).json()
    assert done['steps'][0]['feedback'] == 'done'
    undone = client.post(
        f'{session_url}/steps/{step_id}/feedback',
        json={'feedback': ''},
        headers=auth_headers,
    ).json()
    assert undone['steps'][0]['feedback'] is None

    resolved = client.post(
        f'{session_url}/status', json={'status': 'resolved'}, headers=auth_headers
    ).json()
    assert resolved['status'] == 'resolved'

    for lang in ['zh', 'en']:
        generated = client.post(
            f'{session_url}/report', json={'lang': lang}, headers=auth_headers
        ).json()['content']
        assert 'Photos attached' not in generated
        assert '照片' in generated if lang == 'zh' else 'photo' in generated.lower()

        custom = f"Custom draft {lang}"
        saved = client.put(
            f'{session_url}/report',
            json={'lang': lang, 'content': custom},
            headers=auth_headers,
        )
        assert saved.status_code == 200
        loaded = client.post(
            f'{session_url}/report', json={'lang': lang}, headers=auth_headers
        ).json()['content']
        assert loaded == custom
        reset = client.post(
            f'{session_url}/report?reset=true',
            json={'lang': lang},
            headers=auth_headers,
        ).json()['content']
        assert reset != custom

    assert client.delete(session_url, headers=auth_headers).status_code == 200
    assert client.get(session_url, headers=auth_headers).status_code == 404
