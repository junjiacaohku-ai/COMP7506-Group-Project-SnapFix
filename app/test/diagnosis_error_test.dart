import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snapfix/api.dart';
import 'package:snapfix/pages/analyzing_page.dart';
import 'package:snapfix/pages/error_code_page.dart';
import 'package:snapfix/settings.dart';
import 'package:snapfix/theme.dart';

Future<void> openPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(390, 1400);
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('manual 422 preserves inputs and shows the service explanation', (
    tester,
  ) async {
    const detail = 'Offline demo supports only Bosch / E24 manual input.';
    final requests = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'detail': detail}),
          422,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await openPage(tester, ErrorCodePage(api: api, initialBrand: 'Samsung'));
    await tester.enterText(find.byType(TextFormField).last, 'E24');
    await tester.tap(find.text('Find repair guidance'));
    await tester.pumpAndSettle();

    expect(requests.single.url.path, '/api/diagnose/manual');
    expect(jsonDecode(requests.single.body)['brand'], 'Samsung');
    expect(find.byType(ErrorCodePage), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('We need a clearer photo'), findsNothing);
    expect(find.text(detail), findsOneWidget);
    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.first.controller!.text, 'Samsung');
    expect(fields.last.controller!.text, 'E24');
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo 422 keeps the retake explanation and action', (
    tester,
  ) async {
    const detail = 'The photo is too dark. Add light and take another photo.';
    await openPage(
      tester,
      AnalyzingPage(
        api: ApiClient(),
        start: () async => throw const ApiException(detail, statusCode: 422),
      ),
    );

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('We need a clearer photo'), findsOneWidget);
    expect(find.text(detail), findsOneWidget);
    expect(find.text('Choose another photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
