"""Check bundled corpus and demo provenance offline without changing source assets.

Run from server/: python experiments/validate_data_assets.py
This checks artifact integrity, not real-fault recognition or licence-page availability.
"""
import argparse
from collections import Counter, defaultdict
import csv
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify_file(base, filename, expected_hash):
    relative = Path(filename)
    require(not relative.is_absolute() and '..' not in relative.parts,
            f'non-local asset path: {filename}')
    path = base / relative
    require(path.is_file(), f'missing asset: {path}')
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    require(actual == expected_hash, f'SHA256 mismatch: {path}')
    return actual


def validate(root=ROOT):
    root = Path(root)
    data = root / 'server/data'
    manifest = read_json(data / 'manifest.json')
    manuals = read_json(data / 'manuals.json')
    chunks = read_json(data / 'chunks.json')
    audit = read_json(data / 'extraction-audit.json')
    with (data / 'inventory.csv').open(encoding='utf-8', newline='') as stream:
        inventory = list(csv.DictReader(stream))
    ids = [row['manual_id'] for row in manifest]
    require(len(set(ids)) == len(ids), 'duplicate manual ID in manifest')
    require({row['id'] for row in manuals} == set(ids), 'manual export differs from manifest')
    require({row['manual_id'] for row in inventory} == set(ids), 'inventory differs from manifest')
    hashes = {}
    records = {row['manual_id']: row for row in manifest}
    for row in inventory:
        original = records[row['manual_id']]
        hashes[row['manual_id']] = verify_file(data, original['file'], row['sha256'])
        pages = [entry for entry in audit if entry['manual_id'] == row['manual_id']]
        require([entry['page'] for entry in pages] == list(range(1, int(row['pages']) + 1)),
                f'audit page coverage differs: {row["manual_id"]}')
        counts = Counter(entry['status'] for entry in pages)
        require(counts['sparse_or_image_page'] == int(row['sparse_pages'])
                and counts['excluded_undecoded_glyphs'] == int(row['excluded_pages']),
                f'inventory extraction counts differ: {row["manual_id"]}')
    positions = defaultdict(list)
    seen = set()
    audit_pages = {(entry['manual_id'], entry['page']): entry for entry in audit}
    for chunk in chunks:
        manual_id = chunk['manual_id']
        require(manual_id in records, f'unknown manual: {manual_id}')
        require(chunk['id'] not in seen, f'duplicate chunk ID: {chunk["id"]}')
        seen.add(chunk['id'])
        positions[manual_id].append(chunk['idx'])
        require(chunk['source_sha256'] == hashes[manual_id]
                and chunk['source_url'] == records[manual_id]['source_url'],
                f'chunk provenance mismatch: {chunk["id"]}')
        require(chunk['text'] == chunk['content'] and chunk['text'].strip()
                and len(chunk['text']) <= 500, f'invalid chunk text: {chunk["id"]}')
        page = audit_pages.get((manual_id, chunk['page']))
        require(page is not None and page['status'] != 'excluded_undecoded_glyphs',
                f'chunk cites missing/excluded page: {chunk["id"]}')
    require(set(positions) == set(ids), 'manual without chunks')
    for manual_id, indexes in positions.items():
        require(sorted(indexes) == list(range(len(indexes))), f'non-contiguous chunk indexes: {manual_id}')

    assets = root / 'docs/demo-assets'
    public = read_json(assets / 'public/sources.json')
    alternative_sources = read_json(assets / 'alternatives/sources.json')
    for folder, sources in [('public', public), ('alternatives', alternative_sources)]:
        for source in sources:
            verify_file(assets / folder, source['file'], source['sha256'])
            require(source.get('artist') and source.get('license')
                    and (source.get('page') or source.get('source_page')),
                    f'missing attribution: {source["file"]}')
    quality = read_json(assets / 'quality/manifest.json')
    variants = []
    for source in quality['originals']:
        verify_file(assets / 'public', source['source_file'], source['source_sha256'])
        for variant in source['variants']:
            verify_file(assets / 'quality', variant['file'], variant['sha256'])
            variants.append(variant)
    require(quality['variants'] == len(variants)
            and quality['unique_originals'] == len(quality['originals']), 'quality manifest counts differ')
    alternative = read_json(assets / 'alternatives/manifest.json')
    for asset in alternative['assets']:
        verify_file(root, asset['source_file'], asset['sha256'])
    for case in read_json(assets / 'demo-manifest.json')['cases']:
        if 'source_file' in case:
            verify_file(root, case['source_file'], case['sha256'])
    return {
        'manuals': len(manifest), 'chunks': len(chunks), 'audited_pages': len(audit),
        'page_status': dict(Counter(entry['status'] for entry in audit)),
        'public_files': len(public), 'unique_public_photos': len({r['sha256'] for r in public}),
        'alternative_source_files': len(alternative_sources),
        'alternative_inputs': len(alternative['assets']), 'quality_variants': len(variants),
        'scope': 'Bundled file integrity and provenance only; no model calls or device validation',
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        print(json.dumps(validate(args.root), ensure_ascii=False, indent=2))
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f'Asset validation failed: {error}\n')
