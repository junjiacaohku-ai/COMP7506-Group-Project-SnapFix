"""Demo fixtures must not be mistaken for appliance recognition or real repairs."""
from io import BytesIO
from pathlib import Path
from unittest.mock import patch

from PIL import Image, ImageDraw
import pytest

import mock_data
import pipeline
from image_quality import check_image


DEMO_PHOTOS = Path(__file__).resolve().parents[2] / 'demo-photos'


def test_original_demo_photos_match_after_renaming():
    for filename, category in [
        ('router_red.jpg', 'router'),
        ('ikea_billy.jpg', 'ikea_furniture'),
        ('microwave.jpg', 'microwave'),
    ]:
        result = mock_data.route('IMG_1234.jpg', (DEMO_PHOTOS / filename).read_bytes())
        assert result is not None and result['device_category'] == category


def test_unrelated_gray_image_is_not_a_demo_photo():
    # This sharp, ordinary grey image has the same mean colour as the old
    # microwave fingerprint. Mean RGB must never act as appliance recognition.
    image = Image.new('RGB', (800, 800), (118, 118, 123))
    draw = ImageDraw.Draw(image)
    for x in range(0, 800, 20):
        draw.rectangle((x, 0, x + 9, 799), fill=(198, 198, 203))
    buffer = BytesIO()
    image.save(buffer, format='PNG')
    data = buffer.getvalue()
    assert check_image(data).accepted
    assert mock_data.route('IMG_5678.png', data) is None
    with pytest.raises(pipeline.AnalysisError) as error:
        pipeline._mock_session(data, 'IMG_5678.png')
    assert error.value.status_code == 422


def test_legacy_washer_photo_does_not_create_bosch_e24_diagnosis():
    data = (DEMO_PHOTOS / 'washer_e24.jpg').read_bytes()
    assert mock_data.route('washer_e24.jpg', data) is None
    assert mock_data.route('IMG_9012.jpg', data) is None


def test_mock_steps_cannot_bypass_safety_gate():
    fixture = {
        'device_category': 'water_heater',
        'brand': None,
        'model': None,
        'error_code': None,
        'decision': 'diy',
        'decision_reason': '演示',
        'steps': [('拆开电热水器侧盖，更换加热管。', 'demo', 'demo')],
    }
    with patch.object(mock_data, 'route', return_value=fixture):
        result = pipeline._mock_session(b'', 'water_heater.jpg', 'en')
    assert result['safety_refused'] and result['decision'] == 'refused'
    assert result['steps'] == []
    assert 'Stop and contact' in result['decision_reason']


def test_water_heater_demo_provides_no_internal_reset_instructions():
    result = pipeline._mock_session(b'', 'water_heater.jpg', 'en')
    assert result['safety_refused'] and result['steps'] == []
    assert 'mains voltage' in result['decision_reason']


def test_manual_mock_requires_supported_brand_and_does_not_guess_repairs(user):
    import db

    with db.connect() as conn:
        for brand in ['Bosch', '博世', ' bosch ']:
            result = pipeline.diagnose_manual(
                brand, ' E：24 ', None, conn, user[0]['id'], 'en'
            )
            assert result['device_category'] == 'dishwasher'
            assert result['error_code'] == 'E24'
            assert result['model'] is None and result['steps'] == []
            assert result['decision'] == 'professional'
            assert result['diagnosis_source'] == 'mock'
            assert 'Offline demo' in result['decision_reason']
        for brand, code in [('Samsung', 'E24'), ('', 'E24'), ('Bosch', 'E99')]:
            with pytest.raises(pipeline.AnalysisError) as error:
                pipeline.diagnose_manual(brand, code, None, conn, user[0]['id'])
            assert error.value.status_code == 422


def test_packaged_s1_to_s6_acceptance_scenarios(client, auth_headers):
    import json

    root = DEMO_PHOTOS.parent
    cases = json.loads((root / 'docs/demo-assets/demo-manifest.json').read_text())['cases']
    assert [case['id'] for case in cases] == ['S1', 'S2', 'S3', 'S4', 'S5', 'S6']
    expected = {
        'S1': ('router', 'diy'),
        'S2': ('dishwasher', 'professional'),
        'S3': ('ikea_furniture', 'diy'),
        'S4': ('microwave', 'refused'),
        'S6': ('router', 'diy'),
    }
    for case in cases:
        if case['input_kind'] == 'manual':
            response = client.post(
                '/api/diagnose/manual', json=case['payload'], headers=auth_headers
            )
        else:
            response = client.post(
                '/api/analyze/image',
                files={'file': (case['upload_name'], (root / case['source_file']).read_bytes(), 'image/jpeg')},
                headers=auth_headers,
            )
        if case['id'] == 'S5':
            assert response.status_code == 422
            assert '过暗' in response.json()['detail']
            continue
        assert response.status_code == 200
        result = response.json()
        assert result['diagnosis_source'] == 'mock'
        assert (result['device_category'], result['decision']) == expected[case['id']]
        if case['id'] == 'S2':
            assert result['model'] is None and result['steps'] == []
        if case['id'] == 'S3':
            assert any('防倾倒' in step['content'] for step in result['steps'])
        if case['id'] == 'S4':
            assert result['safety_refused'] and result['steps'] == []
        if case['id'] == 'S6':
            session_url = f"/api/sessions/{result['id']}"
            step_id = result['steps'][0]['id']
            response = client.post(
                f'{session_url}/steps/{step_id}/feedback',
                json={'feedback': 'done'},
                headers=auth_headers,
            )
            assert response.status_code == 200
            assert response.json()['steps'][0]['feedback'] == 'done'
            for language, expected_text in [('zh', '照片'), ('en', 'photo')]:
                response = client.post(
                    f'{session_url}/report', json={'lang': language}, headers=auth_headers
                )
                assert response.status_code == 200
                assert expected_text in response.json()['content'].lower()
