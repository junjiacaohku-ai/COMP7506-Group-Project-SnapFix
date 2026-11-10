import 'package:flutter_test/flutter_test.dart';
import 'package:snapfix_solo/models.dart';

void main() {
  test('Qwen session keeps chunk provenance and repair status', () {
    final session = Session.fromJson({
      'id': 'session-1',
      'device_category': 'router',
      'brand': 'TP-Link',
      'decision': 'diy',
      'decision_reason': 'External checks only.',
      'safety_refused': false,
      'diagnosis_source': 'qwen',
      'status': 'awaiting_repair',
      'created_at': '2026-11-10T00:00:00Z',
      'steps': [
        {
          'id': 'step-1',
          'idx': 1,
          'content': 'Check the external cable.',
          'citation_manual': 'TP-Link User Guide',
          'citation_section': 'External checks · PDF p.12 · chunk-1',
          'citation_chunk_id': 'chunk-1',
          'citation_text': 'Check the external cable.',
          'feedback': null,
        },
      ],
    });

    expect(session.isDemo, isFalse);
    expect(session.status, 'awaiting_repair');
    expect(session.steps.single.citationChunkId, 'chunk-1');
    expect(session.steps.single.citationText, isNotEmpty);
    expect(repairStatusLabel(session.status), '待维修');
  });

  test('manual metadata keeps source URL, page and chunk ID', () {
    final manual = ManualInfo.fromJson({
      'title': 'Bosch washer instructions',
      'category': 'washing_machine',
      'brand': 'Bosch',
      'source_url': 'https://example.com/manual.pdf',
      'sections': [
        {
          'section': 'PDF page 35',
          'page': 35,
          'chunk_id': 'chunk-e24',
          'text': 'E:24 drainage fault',
        },
      ],
    });

    expect(manual.sourceUrl, contains('manual.pdf'));
    expect(manual.sections.single.page, 35);
    expect(manual.sections.single.chunkId, 'chunk-e24');
  });
}
