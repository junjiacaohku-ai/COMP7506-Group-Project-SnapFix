import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snapfix_solo/api.dart';
import 'package:snapfix_solo/models.dart';
import 'package:snapfix_solo/pages/result_page.dart';
import 'package:snapfix_solo/settings.dart';
import 'package:snapfix_solo/theme.dart';

Map<String, dynamic> fixture() => {
  'id': 'session-1',
  'device_category': 'router',
  'brand': 'TP-Link',
  'model': null,
  'error_code': null,
  'decision': 'diy',
  'decision_reason': 'External checks are supported by the manual.',
  'safety_refused': false,
  'diagnosis_source': 'qwen',
  'status': 'investigating',
  'confidence': 0.9,
  'created_at': '2026-11-10T00:00:00Z',
  'steps': [
    {
      'id': 'step-1',
      'idx': 1,
      'content': 'Check the external cable.',
      'citation_manual': 'TP-Link Wireless Router Quick Guide',
      'citation_section': 'External checks · PDF p.12 · chunk-1',
      'citation_chunk_id': 'chunk-1',
      'citation_text': 'Check the external cable before restarting.',
      'feedback': null,
    },
  ],
};

({ApiClient api, List<http.Request> requests, Map<String, String> drafts})
fakeApi() {
  final requests = <http.Request>[];
  final drafts = <String, String>{};
  var session = fixture();
  final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    Object result = <String, dynamic>{};
    if (path.endsWith('/feedback')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      session['steps'][0]['feedback'] = body['feedback'] as String?;
      result = session;
    } else if (path.endsWith('/status')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      session['status'] = body['status'];
      result = session;
    } else if (path.endsWith('/report') && request.method == 'PUT') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      drafts[body['lang'] as String] = body['content'] as String;
      result = body;
    } else if (path.endsWith('/report')) {
      final lang =
          (jsonDecode(request.body) as Map<String, dynamic>)['lang'] as String;
      final content = request.url.queryParameters['reset'] == 'true'
          ? 'Reset $lang'
          : drafts[lang] ?? 'Report $lang';
      result = {'lang': lang, 'content': content};
    }
    return http.Response(
      jsonEncode(result),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  return (api: ApiClient(client: client), requests: requests, drafts: drafts);
}

Future<void> openResult(WidgetTester tester, ApiClient api) async {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final settings = AppSettings();
  addTearDown(settings.dispose);
  await tester.pumpWidget(
    AppSettingsScope(
      settings: settings,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildAppTheme(Brightness.light),
        home: ResultPage(api: api, session: Session.fromJson(fixture())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapTarget(WidgetTester tester, Finder finder) async {
  final target = finder.first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) {
  return tapTarget(tester, find.text(text, skipOffstage: false));
}

void main() {
  testWidgets('chunk source expands and step feedback can be undone', (
    tester,
  ) async {
    final fake = fakeApi();
    await openResult(tester, fake.api);

    await tapTarget(tester, find.byKey(const Key('citation-step-1')));
    expect(
      find.text('Check the external cable before restarting.'),
      findsOneWidget,
    );

    await tapText(tester, 'Done');
    await tapText(tester, 'Done');
    final feedback = fake.requests
        .where((request) => request.url.path.endsWith('/feedback'))
        .toList();
    expect(feedback, hasLength(2));
    expect(jsonDecode(feedback[0].body)['feedback'], 'done');
    expect(jsonDecode(feedback[1].body)['feedback'], '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('repair status requires confirmation and persists', (
    tester,
  ) async {
    final fake = fakeApi();
    await openResult(tester, fake.api);

    await tapText(tester, 'Resolved');
    expect(find.text('Change repair status?'), findsOneWidget);
    await tapText(tester, 'Confirm');
    final request = fake.requests.singleWhere(
      (request) => request.url.path.endsWith('/status'),
    );
    expect(jsonDecode(request.body)['status'], 'resolved');
    expect(tester.takeException(), isNull);
  });

  testWidgets('report edits survive language switches and save as drafts', (
    tester,
  ) async {
    final fake = fakeApi();
    await openResult(tester, fake.api);

    await tapText(tester, 'Create bilingual repair request');
    expect(find.byKey(const Key('report-editor')), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('report-editor')).first,
      'Custom Chinese draft',
    );
    await tapText(tester, 'English');
    await tapText(tester, '中文');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('report-editor')).first)
          .controller!
          .text,
      'Custom Chinese draft',
    );
    await tapText(tester, 'Save draft');
    expect(fake.drafts['zh'], 'Custom Chinese draft');
    expect(tester.takeException(), isNull);
  });
}
