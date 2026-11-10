import json
from pathlib import Path

from experiments.build_quality_variants import ASSETS, OUTPUT, build, sha256
from image_quality import check_image


def test_transform_reproduction_and_source_preservation(tmp_path):
    committed = json.loads((OUTPUT / 'manifest.json').read_text())
    originals_before = {
        row['source_file']: sha256((ASSETS / row['source_file']).read_bytes())
        for row in committed['originals']
    }
    first, second = build(tmp_path / 'first'), build(tmp_path / 'second')
    assert first == second
    for source in first['originals']:
        assert sha256((ASSETS / source['source_file']).read_bytes()) == originals_before[source['source_file']]
        for variant in source['variants']:
            a = tmp_path / 'first' / variant['file']
            b = tmp_path / 'second' / variant['file']
            assert a.read_bytes() == b.read_bytes()
            assert sha256(a.read_bytes()) == variant['sha256']


def test_all_controlled_dark_and_blur_variants_require_retake():
    manifest = json.loads((OUTPUT / 'manifest.json').read_text())
    variants = [
        variant
        for source in manifest['originals']
        for variant in source['variants']
    ]
    assert len(variants) == 26
    for variant in variants:
        result = check_image((OUTPUT / variant['file']).read_bytes())
        assert not result.accepted, variant['file']
