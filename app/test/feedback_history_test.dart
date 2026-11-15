import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snapfix/api.dart';
import 'package:snapfix/pages/feedback_history_page.dart';
import 'package:snapfix/settings.dart';
import 'package:snapfix/theme.dart';

void main() {
  testWidgets('feedback history renders localized timeout records', (
    tester,
  ) async {
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final api = ApiClient(
      client: MockClient((request) async {
        return http.Response(
          '''[
            {
              "id": "feedback-1",
              "event": "timeout",
              "language": "zh",
              "elapsed_seconds": 120,
              "error": "分析超时，请稍后重试",
              "platform": "android",
              "created_at": "2026-11-15T14:37:07Z"
            }
          ]''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
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
          home: FeedbackHistoryPage(api: api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Feedback history'), findsOneWidget);
    expect(find.text('Timeout feedback'), findsOneWidget);
    expect(find.text('120s timeout'), findsOneWidget);
    expect(find.text('android'), findsOneWidget);
    expect(find.text('Analysis timed out. Please try again.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
