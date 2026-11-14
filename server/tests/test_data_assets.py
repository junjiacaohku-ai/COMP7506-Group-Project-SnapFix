"""Keep the shipped corpus and public demo material traceable to their files."""
import json
import pytest

from experiments.validate_data_assets import ROOT, validate


def test_bundled_corpus_and_demo_integrity():
    result = validate()
    assert result['manuals'] == 16
    assert result['chunks'] == 2032
    assert result['unique_public_photos'] == 13
    assert result['quality_variants'] == 26


def test_altered_demo_attribution_manifest_is_rejected(tmp_path):
    # Reuse immutable fixture directories; change only the attribution checksum.
    (tmp_path / 'server').symlink_to(ROOT / 'server', target_is_directory=True)
    assets = tmp_path / 'docs/demo-assets'
    assets.mkdir(parents=True)
    for folder in ('quality', 'alternatives'):
        (assets / folder).symlink_to(ROOT / 'docs/demo-assets' / folder, target_is_directory=True)
    public = assets / 'public'
    public.mkdir()
    for image in (ROOT / 'docs/demo-assets/public').glob('*.jpg'):
        (public / image.name).symlink_to(image)
    manifest = json.loads((ROOT / 'docs/demo-assets/public/sources.json').read_text())
    manifest[0]['sha256'] = '0' * 64
    (public / 'sources.json').write_text(json.dumps(manifest))
    with pytest.raises(ValueError, match='SHA256 mismatch:.*public-01.jpg'):
        validate(tmp_path)
