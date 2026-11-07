import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppLanguage { english, chinese }

extension AppLanguageValues on AppLanguage {
  Locale get locale => switch (this) {
    AppLanguage.english => const Locale('en'),
    AppLanguage.chinese => const Locale('zh'),
  };

  String get code => locale.languageCode;
  String get label => switch (this) {
    AppLanguage.english => 'English',
    AppLanguage.chinese => '简体中文',
  };
}

class AppSettings extends ChangeNotifier {
  AppSettings({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _languageKey = 'snapfix_language';
  final FlutterSecureStorage _storage;
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  AppLanguage get language =>
      _locale.languageCode == 'zh' ? AppLanguage.chinese : AppLanguage.english;

  Future<void> load() async {
    try {
      final code = await _storage.read(key: _languageKey);
      _locale = code == 'zh' ? const Locale('zh') : const Locale('en');
    } catch (_) {
      _locale = const Locale('en');
    }
    notifyListeners();
  }

  Future<bool> setLanguage(AppLanguage language) async {
    if (this.language == language) return true;
    _locale = language.locale;
    notifyListeners();
    try {
      await _storage.write(key: _languageKey, value: language.code);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope is missing from the widget tree');
    return scope!.notifier!;
  }
}
