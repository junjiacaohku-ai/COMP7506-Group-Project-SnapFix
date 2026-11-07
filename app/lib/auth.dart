import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';
import 'models.dart';
import 'social_auth.dart';

class AuthController extends ChangeNotifier {
  AuthController({required this.api, FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          ) {
    api.onUnauthorized = _handleUnauthorized;
  }

  static const _tokenKey = 'snapfix_access_token';

  final ApiClient api;
  final FlutterSecureStorage _storage;
  late final SocialAuthService social = SocialAuthService(api: api);
  Future<void> Function()? onAuthenticated;

  AuthUser? _user;
  bool _restoring = true;
  String? _restoreError;

  AuthUser? get user => _user;
  bool get restoring => _restoring;
  String? get restoreError => _restoreError;

  Future<void> restore() async {
    _restoring = true;
    _restoreError = null;
    notifyListeners();
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty) {
        api.setAccessToken(null);
        _user = null;
      } else {
        api.setAccessToken(token);
        _user = await api.me();
        unawaited(onAuthenticated?.call());
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearSession();
      } else {
        _restoreError = error.message;
      }
    } catch (_) {
      _restoreError = '无法读取此设备上的登录状态';
    }
    _restoring = false;
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    final result = await api.register(name.trim(), email.trim(), password);
    await _acceptSession(result);
  }

  Future<void> login(String email, String password) async {
    final result = await api.login(email.trim(), password);
    await _acceptSession(result);
  }

  Future<void> loginWithApple() async {
    final result = await social.signInWithApple();
    await _acceptSession(result);
  }

  Future<void> loginWithGoogle() async {
    final result = await social.signInWithGoogle();
    await _acceptSession(result);
  }

  Future<void> _acceptSession(AuthResult result) async {
    await _storage.write(key: _tokenKey, value: result.token);
    api.setAccessToken(result.token);
    _user = result.user;
    _restoreError = null;
    notifyListeners();
    unawaited(onAuthenticated?.call());
  }

  Future<void> refreshUser() async {
    _user = await api.me();
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    final updated = await api.updateName(name.trim());
    _user = updated;
    notifyListeners();
  }

  Future<int> changePassword(
    String? currentPassword,
    String newPassword,
  ) async {
    final revoked = await api.changePassword(currentPassword, newPassword);
    await refreshUser();
    return revoked;
  }

  Future<void> deleteAccount() async {
    await api.deleteAccount();
    await _clearSession();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {
      // Local sign-out still completes when the server is unreachable.
    } finally {
      await _clearSession();
      notifyListeners();
    }
  }

  Future<void> _clearSession() async {
    api.setAccessToken(null);
    _user = null;
    _restoreError = null;
    await _storage.delete(key: _tokenKey);
  }

  void _handleUnauthorized() {
    api.setAccessToken(null);
    _user = null;
    _restoring = false;
    _restoreError = null;
    notifyListeners();
    unawaited(_storage.delete(key: _tokenKey));
  }
}
