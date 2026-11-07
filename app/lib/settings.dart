import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppLanguage { english, chinese }

enum AppAppearance { system, light, dark }

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

extension AppAppearanceValues on AppAppearance {
  String get code => switch (this) {
    AppAppearance.system => 'system',
    AppAppearance.light => 'light',
    AppAppearance.dark => 'dark',
  };

  String get label => switch (this) {
    AppAppearance.system => '跟随系统',
    AppAppearance.light => '日间',
    AppAppearance.dark => '夜间',
  };

  ThemeMode get themeMode => switch (this) {
    AppAppearance.system => ThemeMode.system,
    AppAppearance.light => ThemeMode.light,
    AppAppearance.dark => ThemeMode.dark,
  };

  static AppAppearance fromCode(String? code) => switch (code) {
    'light' => AppAppearance.light,
    'dark' => AppAppearance.dark,
    _ => AppAppearance.system,
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
  static const _appearanceKey = 'snapfix_appearance';
  static const _reduceMotionKey = 'snapfix_reduce_motion';
  final FlutterSecureStorage _storage;
  Locale _locale = const Locale('en');
  AppAppearance _appearance = AppAppearance.system;
  bool _reduceMotion = false;

  Locale get locale => _locale;
  AppLanguage get language =>
      _locale.languageCode == 'zh' ? AppLanguage.chinese : AppLanguage.english;
  AppAppearance get appearance => _appearance;
  bool get reduceMotion => _reduceMotion;

  Future<void> load() async {
    try {
      final values = await Future.wait([
        _storage.read(key: _languageKey),
        _storage.read(key: _appearanceKey),
        _storage.read(key: _reduceMotionKey),
      ]);
      _locale = values[0] == 'zh' ? const Locale('zh') : const Locale('en');
      _appearance = AppAppearanceValues.fromCode(values[1]);
      _reduceMotion = values[2] == 'true';
    } catch (_) {
      _locale = const Locale('en');
      _appearance = AppAppearance.system;
      _reduceMotion = false;
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

  Future<bool> setAppearance(AppAppearance appearance) async {
    if (_appearance == appearance) return true;
    _appearance = appearance;
    notifyListeners();
    try {
      await _storage.write(key: _appearanceKey, value: appearance.code);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setReduceMotion(bool value) async {
    if (_reduceMotion == value) return true;
    _reduceMotion = value;
    notifyListeners();
    try {
      await _storage.write(key: _reduceMotionKey, value: '$value');
      return true;
    } catch (_) {
      return false;
    }
  }
}

extension AppMotionContext on BuildContext {
  bool get reduceMotion =>
      AppSettingsScope.of(this).reduceMotion ||
      MediaQuery.disableAnimationsOf(this);
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
