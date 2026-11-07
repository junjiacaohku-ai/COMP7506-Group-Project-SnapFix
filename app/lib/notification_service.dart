import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'models.dart';

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _enabled = false;
  String languageCode = 'en';

  Future<void> _initialize() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  Future<bool> setEnabled(bool value) async {
    if (!value) {
      _enabled = false;
      await _plugin.cancelAll();
      return true;
    }
    await _initialize();
    final iOS = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final macOS = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    final granted =
        await iOS?.requestPermissions(alert: true, badge: true, sound: true) ??
        await macOS?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;
    _enabled = granted;
    return granted;
  }

  Future<void> showDiagnosisComplete(Session session) async {
    debugPrint('SnapFix diagnosis notification requested: enabled=$_enabled');
    if (!_enabled) return;
    try {
      await _initialize();
      final chinese = languageCode == 'zh';
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: chinese ? '诊断已完成' : 'Diagnosis ready',
        body: chinese
            ? '${deviceCategoryLabel(session.deviceCategory)}的维修建议已生成，点击查看。'
            : 'Your ${deviceCategoryLabel(session.deviceCategory)} repair plan is ready to review.',
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (error) {
      debugPrint('SnapFix diagnosis notification failed: $error');
    }
  }
}
