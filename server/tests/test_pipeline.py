from pathlib import Path
from unittest.mock import patch

import pytest

import pipeline
import providers
import retrieval


def image_bytes():
    return (
        Path(__file__).resolve().parents[2]
        / 'docs/demo-assets/public/public-01.jpg'
    ).read_bytes()


def vision(category='router', confidence=0.9):
    return providers.VisionResult(
        device_category=category,
        brand='TP-Link' if category == 'router' else 'Bosch',
        model=None,
        visible_faults=['指示灯异常'],
        confidence=confidence,
    )


def test_refusal_happens_before_retrieval(user):
    import db

    with db.connect() as conn:
        with patch.object(providers, 'extract', return_value=vision('microwave')), patch.object(
            retrieval, 'search', side_effect=AssertionError('retrieval must not run')
        ):
            result = pipeline.analyze_image(
                image_bytes(), 'photo.jpg', 'qwen', conn, user[0]['id'], 'en'
            )
    assert result['safety_refused'] and result['steps'] == []
    assert result['diagnosis_source'] == 'qwen'
    assert 'lethal' in result['decision_reason']


def test_low_confidence_abstains(user):
    import db

    with db.connect() as conn:
        with patch.object(
            providers, 'extract', return_value=vision(confidence=0.2)
        ), patch.object(
            retrieval, 'search', side_effect=AssertionError('retrieval must not run')
        ):
            result = pipeline.analyze_image(
                image_bytes(), 'photo.jpg', 'qwen', conn, user[0]['id']
            )
    assert result['decision'] == 'professional' and result['steps'] == []
    assert '置信度较低' in result['decision_reason']


def test_empty_retrieval_has_no_steps(user):
    import db

    with db.connect() as conn:
        with patch.object(providers, 'extract', return_value=vision()), patch.object(
            retrieval, 'search', return_value=[]
        ):
            result = pipeline.analyze_image(
                image_bytes(), 'photo.jpg', 'qwen', conn, user[0]['id']
            )
    assert result['decision'] == 'professional' and result['steps'] == []


def test_provider_failure_never_returns_mock(user):
    import db

    with db.connect() as conn:
        with patch.object(
            providers,
            'extract',
            side_effect=providers.ProviderError('AI 诊断服务暂时不可用，请稍后重试'),
        ):
            with pytest.raises(pipeline.AnalysisError) as error:
                pipeline.analyze_image(
                    image_bytes(), 'router.jpg', 'qwen', conn, user[0]['id']
                )
    assert error.value.status_code == 503


def test_unknown_image_is_rejected(user):
    import db

    with db.connect() as conn:
        with patch.object(
            providers,
            'extract',
            return_value=providers.VisionResult(device_category='unknown'),
        ):
            with pytest.raises(pipeline.AnalysisError) as error:
                pipeline.analyze_image(
                    image_bytes(), 'unknown.jpg', 'qwen', conn, user[0]['id']
                )
    assert error.value.status_code == 422


def test_chunk_citation_and_post_generation_safety():
    chunk = {
        'id': 'chunk-1',
        'title': 'TP-Link WR940N User Guide',
        'manual_id': 'tplink-wr940n',
        'page': 120,
        'section': 'External checks',
        'content': 'Check the external power and ethernet cable. Restart the router.',
        'device_category': 'router',
        'brand': 'TP-Link',
    }
    generated = providers.GenerationResult(
        decision='diy',
        decision_reason='External checks are supported by the manual.',
        steps=[
            providers.GeneratedStep(
                content='Check the external power and ethernet cable.',
                citation_chunk_id='chunk-1',
            ),
            providers.GeneratedStep(
                content='Invent a missing citation.', citation_chunk_id='missing'
            ),
            providers.GeneratedStep(
                content='配电箱带电维修', citation_chunk_id='chunk-1'
            ),
        ],
    )
    result = pipeline._generated_session(
        {'device_category': 'router', 'brand': 'TP-Link'}, generated, [chunk]
    )
    assert result['decision'] == 'diy' and len(result['steps']) == 1
    step = result['steps'][0]
    assert step[3] == 'chunk-1' and step[4] == chunk['content']
    assert 'PDF p.120' in step[2]


def test_real_corpus_retrieves_bosch_source_page():
    results = retrieval.search(
        '博世 E:24 排水', 'dishwasher', 'E24', brand='Bosch'
    )
    assert results
    assert any(
        row['manual_id'] == 'bosch-dishwasher-9001014024' and row['page'] == 35
        for row in results
    )
