import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snapfix/api.dart';
import 'package:snapfix/pages/analyzing_page.dart';
import 'package:snapfix/settings.dart';
import 'package:snapfix/theme.dart';

void main() {
  test('diagnosis timeout defaults to 120 seconds', () {
    expect(ApiClient().diagnosisTimeout, const Duration(seconds: 120));
  });

  testWidgets('analysis page can return while diagnosis is pending', (
    tester,
  ) async {
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final pending = Completer<Never>();
    late DiagnosisCancellation capturedCancellation;
    final api = ApiClient(
      client: MockClient((request) async => http.Response('{}', 200)),
    );

    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildAppTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AnalyzingPage(
                          api: api,
                          start: (cancellation) {
                            capturedCancellation = cancellation;
                            return pending.future;
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open analysis'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open analysis'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const Key('analyzing-back-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('analyzing-back-button')));
    await tester.pumpAndSettle();

    expect(capturedCancellation.isCancelled, isTrue);
    expect(find.byType(AnalyzingPage), findsNothing);
    expect(find.text('Open analysis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final scenario in [
    (
      locale: const Locale('en'),
      title: 'Diagnosis timed out',
      exit: 'Exit and choose again',
      feedback: 'Report timeout',
    ),
    (
      locale: const Locale('zh'),
      title: '诊断超时',
      exit: '退出并重新选择',
      feedback: '反馈超时问题',
    ),
  ]) {
    testWidgets(
      'timeout actions are localized for ${scenario.locale.languageCode}',
      (tester) async {
        final settings = AppSettings();
        addTearDown(settings.dispose);
        final api = ApiClient(
          client: MockClient((request) async => http.Response('{}', 200)),
        );

        await tester.pumpWidget(
          AppSettingsScope(
            settings: settings,
            child: MaterialApp(
              locale: scenario.locale,
              supportedLocales: const [Locale('en'), Locale('zh')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: buildAppTheme(Brightness.light),
              home: AnalyzingPage(
                api: api,
                start: (cancellation) async {
                  throw const ApiException('分析超时，请稍后重试', isTimeout: true);
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text(scenario.title), findsOneWidget);
        expect(find.byKey(const Key('timeout-exit-button')), findsOneWidget);
        expect(
          find.byKey(const Key('timeout-feedback-button')),
          findsOneWidget,
        );
        expect(find.text(scenario.exit), findsOneWidget);
        expect(find.text(scenario.feedback), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('timeout feedback is submitted and acknowledged', (tester) async {
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final requests = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'id': 'feedback-1', 'status': 'recorded'}),
          201,
        );
      }),
    );

    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildAppTheme(Brightness.light),
          home: AnalyzingPage(
            api: api,
            start: (cancellation) async {
              throw const ApiException('分析超时，请稍后重试', isTimeout: true);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final feedbackButton = find.byKey(const Key('timeout-feedback-button'));
    await tester.ensureVisible(feedbackButton);
    await tester.tap(feedbackButton);
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/diagnosis-feedback');
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['event'], 'timeout');
    expect(body['language'], 'en');
    expect(body['elapsed_seconds'], 120);
    expect(find.text('Feedback recorded'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
