import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

enum AppLanguage { english, chinese }

enum AppAppearance { system, light, dark }

enum AppAccent { purple, teal, blue, amber }

enum AppTextScale { small, standard, large }

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
  String get code => name;
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

  static AppAppearance fromCode(String? code) =>
      AppAppearance.values.firstWhere(
        (value) => value.code == code,
        orElse: () => AppAppearance.system,
      );
}

extension AppAccentValues on AppAccent {
  String get code => name;
  String get label => switch (this) {
    AppAccent.purple => '紫色',
    AppAccent.teal => '青色',
    AppAccent.blue => '蓝色',
    AppAccent.amber => '琥珀色',
  };

  static AppAccent fromCode(String? code) => AppAccent.values.firstWhere(
    (value) => value.code == code,
    orElse: () => AppAccent.purple,
  );
}

extension AppTextScaleValues on AppTextScale {
  String get code => switch (this) {
    AppTextScale.small => 'small',
    AppTextScale.standard => 'default',
    AppTextScale.large => 'large',
  };

  String get label => switch (this) {
    AppTextScale.small => '较小',
    AppTextScale.standard => '标准',
    AppTextScale.large => '较大',
  };

  double get factor => switch (this) {
    AppTextScale.small => 0.92,
    AppTextScale.standard => 1,
    AppTextScale.large => 1.12,
  };

  static AppTextScale fromCode(String? code) => switch (code) {
    'small' => AppTextScale.small,
    'large' => AppTextScale.large,
    _ => AppTextScale.standard,
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
  static const _accentKey = 'snapfix_accent';
  static const _textScaleKey = 'snapfix_text_scale';
  static const _notificationsKey = 'snapfix_notifications';
  final FlutterSecureStorage _storage;
  ApiClient? _api;
  Locale _locale = const Locale('en');
  AppAppearance _appearance = AppAppearance.system;
  bool _reduceMotion = false;
  AppAccent _accent = AppAccent.purple;
  AppTextScale _textScale = AppTextScale.standard;
  bool _notifications = false;

  Future<bool> Function(bool)? onNotificationsChanged;

  Locale get locale => _locale;
  AppLanguage get language =>
      _locale.languageCode == 'zh' ? AppLanguage.chinese : AppLanguage.english;
  AppAppearance get appearance => _appearance;
  bool get reduceMotion => _reduceMotion;
  AppAccent get accent => _accent;
  AppTextScale get textScale => _textScale;
  bool get notifications => _notifications;

  void attachApi(ApiClient api) => _api = api;

  Future<void> load() async {
    try {
      final values = await Future.wait([
        _storage.read(key: _languageKey),
        _storage.read(key: _appearanceKey),
        _storage.read(key: _reduceMotionKey),
        _storage.read(key: _accentKey),
        _storage.read(key: _textScaleKey),
        _storage.read(key: _notificationsKey),
      ]);
      _locale = values[0] == 'zh' ? const Locale('zh') : const Locale('en');
      _appearance = AppAppearanceValues.fromCode(values[1]);
      _reduceMotion = values[2] == 'true';
      _accent = AppAccentValues.fromCode(values[3]);
      _textScale = AppTextScaleValues.fromCode(values[4]);
      _notifications = values[5] == 'true';
    } catch (_) {
      _locale = const Locale('en');
      _appearance = AppAppearance.system;
      _reduceMotion = false;
      _accent = AppAccent.purple;
      _textScale = AppTextScale.standard;
      _notifications = false;
    }
    notifyListeners();
  }

  Future<void> syncFromCloud() async {
    final api = _api;
    if (api == null || !api.hasAccessToken) return;
    try {
      final values = await api.getPreferences();
      if (values.isEmpty) {
        await _pushAll();
        await onNotificationsChanged?.call(_notifications);
        return;
      }
      if (values['language'] != null) {
        _locale = values['language'] == 'zh'
            ? const Locale('zh')
            : const Locale('en');
      }
      _appearance = AppAppearanceValues.fromCode(
        values['appearance'] ?? appearance.code,
      );
      _reduceMotion = values['reduce_motion'] == 'true';
      _accent = AppAccentValues.fromCode(values['accent'] ?? accent.code);
      _textScale = AppTextScaleValues.fromCode(
        values['text_scale'] ?? textScale.code,
      );
      if (values['notifications'] != null) {
        _notifications = values['notifications'] == 'true';
      }
      await _saveLocal();
      await onNotificationsChanged?.call(_notifications);
      notifyListeners();
    } catch (_) {
      // Local preferences remain available when the cloud is unreachable.
    }
  }

  Future<void> _saveLocal() async {
    await Future.wait([
      _storage.write(key: _languageKey, value: language.code),
      _storage.write(key: _appearanceKey, value: appearance.code),
      _storage.write(key: _reduceMotionKey, value: '$_reduceMotion'),
      _storage.write(key: _accentKey, value: accent.code),
      _storage.write(key: _textScaleKey, value: textScale.code),
      _storage.write(key: _notificationsKey, value: '$_notifications'),
    ]);
  }

  void _push(String key, String value) {
    final api = _api;
    if (api == null || !api.hasAccessToken) return;
    unawaited(api.updatePreference(key, value).catchError((_) {}));
  }

  Future<void> _pushAll() async {
    final api = _api;
    if (api == null || !api.hasAccessToken) return;
    await Future.wait([
      api.updatePreference('language', language.code),
      api.updatePreference('appearance', appearance.code),
      api.updatePreference('reduce_motion', '$_reduceMotion'),
      api.updatePreference('accent', accent.code),
      api.updatePreference('text_scale', textScale.code),
      api.updatePreference('notifications', '$_notifications'),
    ]);
  }

  Future<bool> setLanguage(AppLanguage language) async {
    if (this.language == language) return true;
    _locale = language.locale;
    notifyListeners();
    try {
      await _storage.write(key: _languageKey, value: language.code);
      _push('language', language.code);
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
      _push('appearance', appearance.code);
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
      _push('reduce_motion', '$value');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setAccent(AppAccent value) async {
    if (_accent == value) return true;
    _accent = value;
    notifyListeners();
    try {
      await _storage.write(key: _accentKey, value: value.code);
      _push('accent', value.code);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setTextScale(AppTextScale value) async {
    if (_textScale == value) return true;
    _textScale = value;
    notifyListeners();
    try {
      await _storage.write(key: _textScaleKey, value: value.code);
      _push('text_scale', value.code);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setNotifications(bool value) async {
    if (_notifications == value) return true;
    if (value && !(await onNotificationsChanged?.call(true) ?? true)) {
      return false;
    }
    _notifications = value;
    notifyListeners();
    if (!value) await onNotificationsChanged?.call(false);
    try {
      await _storage.write(key: _notificationsKey, value: '$value');
      _push('notifications', '$value');
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
